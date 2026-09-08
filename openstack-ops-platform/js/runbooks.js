// ===== 조치 가이드(런북): 항목별 기본 가이드 + 공급자별 사이트 가이드 =====
// renderRunbookMarkdown: a deliberately small Markdown subset (## 제목, 번호·불릿 목록, **강조**, `명령`), escaped first.
function renderRunbookMarkdown(text) {
  const inline = value => escapeText(value)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  const lines = String(text || '').replace(/\r/g, '').split('\n');
  const html = [];
  let list = null;
  const closeList = () => { if (list) { html.push(`</${list}>`); list = null; } };
  lines.forEach(line => {
    const trimmed = line.trim();
    if (!trimmed) { closeList(); return; }
    const heading = /^(#{1,3})\s+(.*)$/.exec(trimmed);
    if (heading) { closeList(); html.push(`<h4>${inline(heading[2])}</h4>`); return; }
    const numbered = /^\d+[.)]\s+(.*)$/.exec(trimmed);
    const bullet = /^[-*]\s+(.*)$/.exec(trimmed);
    if (numbered || bullet) {
      const kind = numbered ? 'ol' : 'ul';
      if (list !== kind) { closeList(); html.push(`<${kind}>`); list = kind; }
      html.push(`<li>${inline((numbered || bullet)[1])}</li>`);
      return;
    }
    closeList();
    html.push(`<p>${inline(trimmed)}</p>`);
  });
  closeList();
  return html.join('');
}
const runbookSourceLabels = {provider:'사이트 가이드', builtin:'기본 가이드', generic:'공통 가이드'};
function runbookItemName(itemKey) {
  const key = String(itemKey || '').split(':').pop();
  if (typeof inspectionGroups !== 'undefined') {
    for (const group of inspectionGroups) { const item = group.items.find(entry => entry[3] === key); if (item) return item[1]; }
  }
  return key;
}
async function fetchRunbook(itemKey, providerId) {
  const key = String(itemKey || '').split(':').pop();
  const response = await fetch(`/api/runbooks/${encodeURIComponent(key)}${providerId ? `?provider_id=${encodeURIComponent(providerId)}` : ''}`, {cache:'no-store'});
  const data = await response.json();
  if (!response.ok) throw new Error(data.detail || '조치 가이드를 불러오지 못했습니다.');
  return data;
}
async function saveRunbookOverride(providerId, itemKey, text) {
  const key = String(itemKey || '').split(':').pop();
  const current = await fetch(`/api/providers/${encodeURIComponent(providerId)}/settings/runbooks`, {cache:'no-store'});
  const entry = await current.json();
  if (!current.ok) throw new Error(entry.detail || '기존 가이드를 불러오지 못했습니다.');
  const value = {...(entry.value || {})};
  if (text.trim()) value[key] = text; else delete value[key];
  const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/settings/runbooks`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({value})});
  const data = await response.json();
  if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '가이드를 저장하지 못했습니다.');
  return data;
}
// Modal used by other screens (e.g. the inspection detail row): openRunbook('nova', providerId).
function ensureRunbookModal() {
  let modal = document.querySelector('#runbookModal');
  if (modal) return modal;
  modal = document.createElement('div');
  modal.id = 'runbookModal';
  modal.className = 'runbook-modal';
  modal.hidden = true;
  modal.innerHTML = '<div class="runbook-dialog" role="dialog" aria-modal="true" aria-labelledby="runbookModalTitle"><header><div><h2 id="runbookModalTitle">조치 가이드</h2><small id="runbookModalMeta">-</small></div><div class="runbook-modal-actions"><button type="button" id="runbookModalEdit" hidden>편집</button><button type="button" id="runbookModalClose">닫기</button></div></header><div id="runbookModalBody" class="runbook-body"></div><form id="runbookModalForm" class="runbook-form" hidden><textarea id="runbookModalText" maxlength="20000" spellcheck="false"></textarea><div class="runbook-form-actions"><small>Markdown(제목 ##, 번호 목록, **강조**, `명령`)을 지원합니다. 비워 저장하면 기본 가이드로 돌아갑니다.</small><button type="button" id="runbookModalCancel">취소</button><button type="submit" class="primary-button">사이트 가이드로 저장</button></div></form></div>';
  document.body.appendChild(modal);
  modal.addEventListener('click', event => { if (event.target === modal) modal.hidden = true; });
  modal.querySelector('#runbookModalClose').addEventListener('click', () => { modal.hidden = true; });
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && !modal.hidden) modal.hidden = true; });
  modal.querySelector('#runbookModalEdit').addEventListener('click', () => { modal.querySelector('#runbookModalText').value = modal.dataset.text || ''; modal.querySelector('#runbookModalForm').hidden = false; modal.querySelector('#runbookModalBody').hidden = true; });
  modal.querySelector('#runbookModalCancel').addEventListener('click', () => { modal.querySelector('#runbookModalForm').hidden = true; modal.querySelector('#runbookModalBody').hidden = false; });
  modal.querySelector('#runbookModalForm').addEventListener('submit', async event => {
    event.preventDefault();
    const button = event.currentTarget.querySelector('button[type="submit"]');
    button.disabled = true;
    try {
      await saveRunbookOverride(modal.dataset.providerId, modal.dataset.itemKey, modal.querySelector('#runbookModalText').value);
      showToast('조치 가이드를 저장했습니다.', '이 공급자의 사이트 가이드로 표시됩니다.');
      await openRunbook(modal.dataset.itemKey, modal.dataset.providerId);
    } catch (error) { showToast('조치 가이드를 저장하지 못했습니다.', error.message); }
    finally { button.disabled = false; }
  });
  return modal;
}
async function openRunbook(itemKey, providerId) {
  const modal = ensureRunbookModal();
  modal.hidden = false;
  modal.querySelector('#runbookModalForm').hidden = true;
  modal.querySelector('#runbookModalBody').hidden = false;
  modal.querySelector('#runbookModalTitle').textContent = `조치 가이드 · ${runbookItemName(itemKey)}`;
  modal.querySelector('#runbookModalBody').innerHTML = '<div class="empty-provider">불러오는 중입니다.</div>';
  modal.dataset.itemKey = String(itemKey || '').split(':').pop();
  modal.dataset.providerId = providerId || '';
  try {
    const data = await fetchRunbook(itemKey, providerId);
    modal.dataset.text = data.source === 'provider' ? data.text : '';
    modal.querySelector('#runbookModalMeta').textContent = `${runbookSourceLabels[data.source] || data.source}${providerId ? '' : ' · 공급자를 선택하면 사이트 가이드를 편집할 수 있습니다'}`;
    modal.querySelector('#runbookModalBody').innerHTML = renderRunbookMarkdown(data.text);
    modal.querySelector('#runbookModalEdit').hidden = !data.editable;
  } catch (error) { modal.querySelector('#runbookModalBody').innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
