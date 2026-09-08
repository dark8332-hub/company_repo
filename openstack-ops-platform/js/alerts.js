// ===== 알림 및 장애 =====
const alertSeverityLabels = {critical:'위험', warning:'주의', info:'정보'};
const alertStatusLabels = {open:'미확인', acknowledged:'확인', resolved:'해소'};
const alertGroupKey = 'okestro-alert-grouping';
const alertEventLabels = {detected:'감지', redetected:'재감지', acknowledged:'확인', resolved:'해소', auto_resolved:'자동 해소', reopened:'재오픈', assigned:'담당자', comment:'코멘트', suppressed:'억제', note:'기록'};
const alertShortDate = value => value ? new Intl.DateTimeFormat('ko-KR', {dateStyle:'short', timeStyle:'short'}).format(new Date(value)) : '-';
const staleThresholdMs = 3 * 24 * 3600 * 1000;
let currentAlertGroups = [];

function renderAlertSummary(summary, alerts = []) {
  document.querySelector('#activeAlertCount').textContent = summary.active || 0;
  document.querySelector('#criticalAlertCount').textContent = summary.critical || 0;
  document.querySelector('#warningAlertCount').textContent = (summary.groups || []).filter(item => item.status !== 'resolved' && item.severity === 'warning').reduce((sum, item) => sum + item.count, 0);
  document.querySelector('#resolvedAlertCount').textContent = (summary.groups || []).filter(item => item.status === 'resolved').reduce((sum, item) => sum + item.count, 0);
  const suppressedCount = document.querySelector('#suppressedAlertCount');
  if (suppressedCount) suppressedCount.textContent = summary.suppressed || 0;
  document.querySelectorAll('.alert-count').forEach(element => { element.textContent = summary.active || 0; element.hidden = !(summary.active || 0); });
  const bell = document.querySelector('#topAlertButton');
  const badge = document.querySelector('#topAlertCount');
  if (bell && badge) {
    const active = summary.active || 0;
    badge.textContent = active > 99 ? '99+' : active;
    badge.hidden = !active;
    bell.classList.toggle('critical', (summary.critical || 0) > 0);
    bell.classList.toggle('warning', active > 0 && !(summary.critical || 0));
    bell.title = active ? `활성 알림 ${active}건 (위험 ${summary.critical || 0}건)${summary.suppressed ? ` · 억제 중 ${summary.suppressed}건` : ''} · 클릭하면 알림 및 장애로 이동합니다` : '활성 알림 없음';
  }
}

async function loadServerHealth() {
  const connection = document.querySelector('#serverConnection');
  const info = document.querySelector('#platformInfo');
  try {
    const response = await fetch('/api/health', {cache:'no-store'});
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    const running = data.running_checks || 0;
    connection.className = `connection${running ? ' busy' : ''}`;
    connection.innerHTML = `<i></i>${running ? `점검 실행 중 ${running}건` : '서버 연결 정상'}`;
    if (info) info.textContent = `v${data.version || '-'} · ${data.timezone || '-'} · 공급자 ${data.providers ?? 0}개`;
  } catch (error) {
    connection.className = 'connection offline';
    connection.innerHTML = '<i></i>서버 연결 끊김';
    if (info) info.textContent = '서버에 연결할 수 없습니다';
  }
}
loadServerHealth();
setInterval(loadServerHealth, 30000);
setInterval(loadAlertSummary, 60000);

async function loadAlertSummary() {
  try { const response = await fetch('/api/alerts/summary', {cache:'no-store'}); if (response.ok) renderAlertSummary(await response.json()); } catch (_) { /* Badge is non-critical. */ }
}

function alertFilterParams() {
  const params = new URLSearchParams();
  [['provider_id','#alertProviderFilter'],['severity','#alertSeverityFilter'],['status','#alertStatusFilter'],['q','#alertSearch']].forEach(([key, selector]) => { const value = document.querySelector(selector).value.trim(); if (value) params.set(key, value); });
  return params;
}
function isStaleAlert(item) {
  return item.status !== 'resolved' && !item.suppressed && item.first_detected_at && (Date.now() - new Date(item.first_detected_at).getTime()) > staleThresholdMs;
}
function alertCard(item) {
  const stale = isStaleAlert(item);
  const badges = `<span class="alert-severity ${item.severity}">${alertSeverityLabels[item.severity] || escapeText(item.severity)}</span><span class="alert-state ${item.status}">${alertStatusLabels[item.status] || escapeText(item.status)}</span>${item.suppressed ? `<span class="alert-state suppressed" title="정비 시간 창에 포함되어 ${escapeText(alertShortDate(item.suppressed_until))}까지 억제됩니다">억제 중</span>` : ''}${stale ? '<span class="alert-state stale" title="3일 이상 처리되지 않은 알림입니다">3일 이상</span>' : ''}`;
  return `<article class="managed-alert ${item.severity} ${item.status}${item.suppressed ? ' suppressed' : ''}${stale ? ' stale' : ''}" data-alert-id="${escapeText(item.id)}"><span class="managed-alert-icon">${item.severity === 'critical' ? '!' : (item.severity === 'warning' ? '△' : 'i')}</span><div><header>${badges}<h2>${escapeText(item.title)}</h2></header><p>${escapeText(item.description)}</p><small>${escapeText(item.provider_name || '공통')} · ${escapeText(item.target || '대상 미지정')} · 최초 ${escapeText(alertShortDate(item.first_detected_at))} · 최근 감지 ${escapeText(alertShortDate(item.last_detected_at))}</small>${item.assignee || item.work_history_title ? `<div class="alert-links">${item.assignee ? `<span>담당자 ${escapeText(item.assignee)}</span>` : ''}${item.work_history_title ? `<a href="#history">작업이력: ${escapeText(item.work_history_title)}</a>` : ''}</div>` : ''}${item.resolution_note ? `<blockquote>${escapeText(item.resolution_note)}</blockquote>` : ''}</div><div class="managed-alert-actions"><button data-alert-action="manage" type="button">${item.status === 'resolved' ? '내용 보기' : '처리'}</button><button data-alert-action="runbook" type="button" title="이 항목의 조치 가이드">가이드</button></div></article>`;
}
function groupCard(group) {
  const open = group.open + group.acknowledged;
  const actions = open ? `<div class="alert-group-actions"><button type="button" data-group-action="acknowledge" data-group-key="${escapeText(group.key)}">모두 확인</button><button type="button" data-group-action="resolve" data-group-key="${escapeText(group.key)}">모두 해소</button></div>` : '';
  const cause = group.cause ? `<p class="alert-group-cause">${escapeText(group.cause)}</p>` : '';
  const kindLabel = {controller:'Controller 연결', node:'노드', service:'서비스 계열', single:'단일'}[group.kind] || group.kind;
  return `<section class="alert-group ${group.severity}${open ? '' : ' closed'}" data-group-key="${escapeText(group.key)}"><header class="alert-group-head" role="button" tabindex="0" data-group-toggle="${escapeText(group.key)}"><span class="alert-group-count ${group.severity}">${group.count}</span><div><h3>${escapeText(group.title)}</h3><small>${escapeText(kindLabel)} · 미확인 ${group.open} · 확인 ${group.acknowledged}${group.suppressed ? ` · 억제 ${group.suppressed}` : ''}${group.resolved ? ` · 해소 ${group.resolved}` : ''} · 최근 감지 ${escapeText(alertShortDate(group.last_detected_at))}</small>${cause}</div>${actions}<b class="alert-group-chevron">›</b></header><div class="alert-group-body" hidden>${group.alerts.map(alertCard).join('')}</div></section>`;
}
// Each summary card is a shortcut to the filter that produces exactly the alerts it counts, so the
// number and the list below can never disagree.
const alertScopes = {
  active: {status:'active', severity:'', label:'활성 알림'},
  critical: {status:'active', severity:'critical', label:'위험'},
  warning: {status:'active', severity:'warning', label:'주의'},
  suppressed: {status:'suppressed', severity:'', label:'억제 중'},
  resolved: {status:'resolved', severity:'', label:'해소'},
};

function currentAlertScope() {
  const status = document.querySelector('#alertStatusFilter').value;
  const severity = document.querySelector('#alertSeverityFilter').value;
  return Object.keys(alertScopes).find(key => alertScopes[key].status === status && alertScopes[key].severity === severity) || '';
}

function markAlertScope() {
  const active = currentAlertScope();
  document.querySelectorAll('#alertSummaryGrid [data-alert-scope]').forEach(card => {
    const selected = card.dataset.alertScope === active;
    card.classList.toggle('selected', selected);
    card.setAttribute('aria-pressed', selected ? 'true' : 'false');
  });
}

function applyAlertScope(scope) {
  const target = alertScopes[scope];
  if (!target) return;
  // Clicking the card that is already applied clears the filter, so one card toggles both ways.
  const clear = currentAlertScope() === scope;
  document.querySelector('#alertStatusFilter').value = clear ? '' : target.status;
  document.querySelector('#alertSeverityFilter').value = clear ? '' : target.severity;
  loadAlerts();
}

async function loadAlerts() {
  const params = alertFilterParams();
  const grouped = document.querySelector('#alertGroupToggle').checked;
  const list = document.querySelector('#alertManagementList'); list.innerHTML = '<div class="empty-provider">알림을 불러오는 중입니다.</div>';
  const refreshButton = document.querySelector('#refreshAlerts');
  // Without a busy state a refresh that returns the same alerts looks like nothing happened.
  refreshButton.disabled = true;
  refreshButton.classList.add('busy');
  markAlertScope();
  loadAlertStats();
  loadMaintenanceWindows();
  try {
    const response = await fetch(`/api/alerts${grouped ? '/groups' : ''}?${params}`, {cache:'no-store'}); const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '알림을 불러오지 못했습니다.'); renderAlertSummary(data.summary, data.alerts || []);
    if (grouped) {
      currentAlertGroups = data.groups || [];
      document.querySelector('#alertListMeta').textContent = `${data.total}건을 ${currentAlertGroups.length}개 원인으로 묶었습니다${alertMetaSuffix()}`;
      if (!currentAlertGroups.length) { list.innerHTML = `<div class="empty-provider">${escapeText(emptyAlertMessage())}</div>`; return; }
      list.innerHTML = currentAlertGroups.map(groupCard).join('');
      const single = currentAlertGroups.filter(group => group.kind === 'single' || group.count === 1);
      list.querySelectorAll('.alert-group').forEach((section, index) => { if (single.includes(currentAlertGroups[index]) || index === 0) section.querySelector('.alert-group-body').hidden = false; });
      return;
    }
    currentAlertGroups = [];
    document.querySelector('#alertListMeta').textContent = `${data.alerts.length}건${alertMetaSuffix()}`;
    if (!data.alerts.length) { list.innerHTML = `<div class="empty-provider">${escapeText(emptyAlertMessage())}</div>`; return; }
    list.innerHTML = data.alerts.map(alertCard).join('');
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
  finally { refreshButton.disabled = false; refreshButton.classList.remove('busy'); }
}

function alertMetaSuffix() {
  const scope = currentAlertScope();
  const time = new Intl.DateTimeFormat('ko-KR', {timeStyle:'medium'}).format(new Date());
  return `${scope ? ` · ${alertScopes[scope].label}만 표시` : ''} · ${time} 갱신`;
}

function emptyAlertMessage() {
  const scope = currentAlertScope();
  return scope ? `${alertScopes[scope].label}에 해당하는 알림이 없습니다. 카드를 다시 누르면 전체를 표시합니다.` : '조건에 맞는 알림이 없습니다.';
}

function formatSeconds(seconds) {
  if (seconds == null) return '-';
  if (seconds < 3600) return `${Math.max(1, Math.round(seconds / 60))}분`;
  if (seconds < 86400) return `${(seconds / 3600).toFixed(1)}시간`;
  return `${(seconds / 86400).toFixed(1)}일`;
}
async function loadAlertStats() {
  const strip = document.querySelector('#alertStatsStrip');
  try {
    const response = await fetch('/api/alerts/stats?days=30', {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '통계를 불러오지 못했습니다.');
    const recurring = (data.recurring || []).slice(0, 3).map(item => `<button type="button" class="stat-chip" data-stat-search="${escapeText(item.title)}" title="${escapeText(item.provider_name || '')} · 30일 동안 ${item.repeats}회 재감지">${escapeText(item.title)} ×${item.repeats}</button>`).join('');
    strip.innerHTML = `<article><span>평균 확인 시간</span><strong>${escapeText(formatSeconds(data.mtta_seconds))}</strong><small>최근 ${data.days}일 확인 처리 ${data.acknowledged}건</small></article>
      <article><span>평균 해소 시간</span><strong>${escapeText(formatSeconds(data.mttr_seconds))}</strong><small>해소 ${data.resolved}건 · 자동 해소 ${data.auto_resolved}건 · 신규 ${data.created}건</small></article>
      <article class="${data.stale_count ? 'stale' : ''}"><span>${data.stale_days}일 이상 미처리</span><strong>${data.stale_count}</strong><small>${data.stale_count ? '오래된 순으로 우선 처리하세요' : '오래된 미처리 알림이 없습니다'}</small>${data.stale_count ? '<button type="button" id="showStaleAlerts">보기</button>' : ''}</article>
      <article class="recurring"><span>반복 감지 상위</span><div class="stat-chips">${recurring || '<small>최근 30일 반복 감지 없음</small>'}</div></article>`;
  } catch (error) { strip.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
document.querySelector('#alertStatsStrip').addEventListener('click', event => {
  const chip = event.target.closest('[data-stat-search]');
  if (chip) { document.querySelector('#alertSearch').value = chip.dataset.statSearch; document.querySelector('#alertStatusFilter').value = ''; loadAlerts(); return; }
  if (event.target.closest('#showStaleAlerts')) {
    document.querySelector('#alertStatusFilter').value = ''; document.querySelector('#alertSearch').value = ''; document.querySelector('#alertGroupToggle').checked = false; localStorage.setItem(alertGroupKey, '0');
    loadAlerts().then(() => { const first = document.querySelector('.managed-alert.stale'); if (first) first.scrollIntoView({behavior:'smooth', block:'center'}); });
  }
});

// --- Timeline, comments and runbook inside the editor -------------------------------------------
function renderAlertTimeline(events) {
  const box = document.querySelector('#alertTimeline');
  document.querySelector('#alertTimelineMeta').textContent = events.length ? `${events.length}건` : '감지·처리·코멘트 기록';
  box.innerHTML = events.length ? events.map(event => `<div class="timeline-item ${escapeText(event.kind)}"><em>${escapeText(alertEventLabels[event.kind] || event.kind)}</em><div><p>${escapeText(event.text || '-')}</p><small>${escapeText(alertShortDate(event.created_at))} · ${escapeText(event.actor || 'system')}</small></div></div>`).join('') : '<div class="empty-provider">기록이 없습니다.</div>';
}
async function loadAlertTimeline(alertId) {
  try {
    const response = await fetch(`/api/alerts/${encodeURIComponent(alertId)}/events`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '타임라인을 불러오지 못했습니다.');
    renderAlertTimeline(data.events || []);
  } catch (error) { document.querySelector('#alertTimeline').innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
let editorRunbook = {itemKey:'', providerId:'', text:''};
async function loadEditorRunbook(item) {
  const body = document.querySelector('#alertRunbook');
  const meta = document.querySelector('#alertRunbookMeta');
  const editButton = document.querySelector('#editAlertRunbook');
  document.querySelector('#alertRunbookForm').hidden = true;
  body.hidden = false;
  editorRunbook = {itemKey:(item.source_key || '').split(':').pop(), providerId:item.provider_id || '', text:''};
  if (!editorRunbook.itemKey) { body.innerHTML = '<div class="empty-provider">이 알림에는 연결된 점검 항목이 없습니다.</div>'; meta.textContent = '-'; editButton.hidden = true; return; }
  try {
    const data = await fetchRunbook(editorRunbook.itemKey, editorRunbook.providerId);
    editorRunbook.text = data.source === 'provider' ? data.text : '';
    meta.textContent = `${runbookItemName(editorRunbook.itemKey)} · ${runbookSourceLabels[data.source] || data.source}`;
    body.innerHTML = renderRunbookMarkdown(data.text);
    editButton.hidden = !data.editable;
  } catch (error) { body.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; editButton.hidden = true; }
}
document.querySelector('#editAlertRunbook').addEventListener('click', () => { document.querySelector('#alertRunbookText').value = editorRunbook.text; document.querySelector('#alertRunbookForm').hidden = false; document.querySelector('#alertRunbook').hidden = true; });
document.querySelector('#cancelAlertRunbook').addEventListener('click', () => { document.querySelector('#alertRunbookForm').hidden = true; document.querySelector('#alertRunbook').hidden = false; });
document.querySelector('#alertRunbookForm').addEventListener('submit', async event => {
  event.preventDefault();
  const button = event.currentTarget.querySelector('button[type="submit"]');
  button.disabled = true;
  try {
    await saveRunbookOverride(editorRunbook.providerId, editorRunbook.itemKey, document.querySelector('#alertRunbookText').value);
    showToast('조치 가이드를 저장했습니다.', '이 공급자의 사이트 가이드로 표시됩니다.');
    await loadEditorRunbook({source_key:editorRunbook.itemKey, provider_id:editorRunbook.providerId});
  } catch (error) { showToast('조치 가이드를 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
document.querySelector('#alertCommentForm').addEventListener('submit', async event => {
  event.preventDefault();
  const id = document.querySelector('#alertActionId').value;
  const input = document.querySelector('#alertCommentText');
  if (!id || !input.value.trim()) return;
  const button = event.currentTarget.querySelector('button');
  button.disabled = true;
  try {
    const response = await fetch(`/api/alerts/${encodeURIComponent(id)}/comments`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({text:input.value.trim()})});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '코멘트를 저장하지 못했습니다.');
    input.value = '';
    await loadAlertTimeline(id);
  } catch (error) { showToast('코멘트를 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});

let currentAlertActionItem = null;
document.querySelector('#alertCreateIssue')?.addEventListener('click', () => {
  const item = currentAlertActionItem; if (!item) return;
  openIssueEditorFrom({alert_id:item.id, provider_id:item.provider_id || '', title:item.title, target:item.target || '', severity:item.severity === 'critical' ? 'critical' : 'high', category:'incident',
    body:`## 알림\n- ${item.title}\n- 최초 감지: ${alertShortDate(item.first_detected_at)} · 최근 감지: ${alertShortDate(item.last_detected_at)}\n\n## 증상\n${item.description ? `- ${item.description}` : '- '}\n\n## 원인 분석\n- \n\n## 조치\n- `});
});
async function openAlertAction(id) {
  const [alertResponse, historiesResponse] = await Promise.all([fetch(`/api/alerts/${id}`), fetch('/api/work-histories')]);
  const item = await alertResponse.json(); if (!alertResponse.ok) return showToast('알림을 불러오지 못했습니다.', item.detail || '다시 시도하세요.');
  const histories = historiesResponse.ok ? (await historiesResponse.json()).histories : [];
  const select = document.querySelector('#alertWorkHistory'); select.innerHTML = '<option value="">연결하지 않음</option>' + histories.map(history => `<option value="${history.id}">${escapeText(history.title)} · ${escapeText(history.operator)}</option>`).join('');
  currentAlertActionItem = item;
  document.querySelector('#alertActionId').value = item.id; document.querySelector('#alertActionStatus').value = item.status; document.querySelector('#alertAssignee').value = item.assignee || ''; select.value = item.work_history_id || ''; document.querySelector('#alertResolutionNote').value = item.resolution_note || ''; document.querySelector('#alertActionTitle').textContent = item.title;
  document.querySelector('#alertActionMeta').textContent = `${item.provider_name || '공통'} · ${item.target || '대상 미지정'} · ${alertSeverityLabels[item.severity] || item.severity} · ${alertStatusLabels[item.status] || item.status}${item.suppressed ? ` · 정비 시간 창으로 ${alertShortDate(item.suppressed_until)}까지 억제 중` : ''}`;
  document.querySelector('#alertActionHint').textContent = item.suppressed ? '억제 중인 알림도 상태와 담당자를 기록할 수 있습니다. 억제는 정비 시간 창이 끝나거나 삭제되면 풀립니다.' : '상태 변경 시 처리 시각이 자동 기록됩니다.';
  document.querySelector('#alertCommentText').value = '';
  document.querySelector('#alertActionEditor').hidden = false; document.querySelector('#alertActionEditor').scrollIntoView({behavior:'smooth'});
  loadAlertTimeline(item.id);
  loadEditorRunbook(item);
}

// --- Group actions ---------------------------------------------------------------------------
async function bulkUpdateGroup(groupKey, status) {
  const group = currentAlertGroups.find(entry => entry.key === groupKey);
  if (!group) return;
  const ids = group.alerts.filter(alert => alert.status !== 'resolved').map(alert => alert.id);
  if (!ids.length) return;
  let resolutionNote = '';
  if (status === 'resolved') {
    resolutionNote = (window.prompt(`${group.title}\n알림 ${ids.length}건을 해소 처리합니다. 조치 내용을 입력하세요.`, '') || '').trim();
    if (!resolutionNote) return;
  } else if (!window.confirm(`${group.title}\n알림 ${ids.length}건을 확인 처리할까요?`)) return;
  try {
    const response = await fetch('/api/alerts/bulk', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({ids, status, assignee:'', resolution_note:resolutionNote})});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '일괄 처리하지 못했습니다.');
    showToast('알림을 일괄 처리했습니다.', `${data.updated}건을 ${alertStatusLabels[status]} 상태로 반영했습니다.`);
    await loadAlerts();
  } catch (error) { showToast('일괄 처리하지 못했습니다.', error.message); }
}

// --- Maintenance windows ---------------------------------------------------------------------
const maintenanceStateLabels = {active:'진행 중', upcoming:'예정', past:'종료'};
function localInputToIso(value) { const date = new Date(value); return Number.isNaN(date.getTime()) ? '' : date.toISOString(); }
function fillMaintenanceItems() {
  const select = document.querySelector('#maintenanceItems');
  if (select.options.length || typeof inspectionGroups === 'undefined') return;
  select.innerHTML = inspectionGroups.filter(group => group.items.length).map(group => `<optgroup label="${escapeText(group.title)}">${group.items.map(item => `<option value="${escapeText(item[3])}">${escapeText(item[1])}</option>`).join('')}</optgroup>`).join('');
}
async function fillMaintenanceNodes(providerId) {
  const select = document.querySelector('#maintenanceNodes');
  select.innerHTML = '';
  select.disabled = !providerId;
  if (!providerId) return;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/nodes`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) return;
    select.innerHTML = (data.nodes || []).map(node => `<option value="${escapeText(node.hostname)}">${escapeText(node.hostname)} · ${node.role === 'controller' ? 'Controller' : 'Compute'}</option>`).join('');
  } catch (_) { /* the node list is optional */ }
}
async function fillMaintenanceWorkHistories() {
  const select = document.querySelector('#maintenanceWorkHistory');
  try {
    const response = await fetch('/api/work-histories', {cache:'no-store'});
    const data = await response.json();
    const candidates = (data.histories || []).filter(item => item.status === 'planned' || item.status === 'in_progress');
    select.innerHTML = '<option value="">연결하지 않음</option>' + candidates.map(item => `<option value="${escapeText(item.id)}" data-started="${escapeText(item.started_at || '')}" data-completed="${escapeText(item.completed_at || '')}" data-provider="${escapeText(item.provider_id || '')}" data-title="${escapeText(item.title)}">${escapeText(item.title)} · ${escapeText(workStatusLabels[item.status] || item.status)} · ${escapeText(item.provider_name || '공통')}</option>`).join('');
  } catch (_) { /* optional */ }
}
function toLocalInput(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const pad = number => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
async function loadMaintenanceWindows() {
  const list = document.querySelector('#maintenanceList');
  try {
    const response = await fetch('/api/maintenance-windows', {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '정비 시간 창을 불러오지 못했습니다.');
    const windows = data.windows || [];
    const active = windows.filter(item => item.state === 'active').length;
    const upcoming = windows.filter(item => item.state === 'upcoming').length;
    document.querySelector('#maintenanceMeta').textContent = windows.length ? `진행 중 ${active} · 예정 ${upcoming} · 종료 ${windows.length - active - upcoming}. 진행 중인 창에 해당하는 알림은 활성 건수에서 제외되고 "억제 중" 필터로 볼 수 있습니다.` : '정비 중인 공급자·노드·항목의 알림을 정해진 기간 동안 억제합니다. 억제된 알림은 활성 건수에서 제외되고 "억제 중" 필터로 볼 수 있습니다.';
    if (!windows.length) { list.innerHTML = '<div class="empty-provider">등록된 정비 시간 창이 없습니다.</div>'; return; }
    list.innerHTML = windows.slice(0, 30).map(item => `<article class="maintenance-window ${item.state}"><em>${escapeText(maintenanceStateLabels[item.state] || item.state)}</em><div><strong>${escapeText(item.title)}</strong><small>${escapeText(item.provider_name || '전체 공급자')} · ${escapeText(alertShortDate(item.starts_at))} ~ ${escapeText(alertShortDate(item.ends_at))} · 노드 ${item.nodes.length ? escapeText(item.nodes.join(', ')) : '전체'} · 항목 ${item.item_keys.length ? item.item_keys.length + '개' : '전체'}${item.work_history_title ? ` · 작업 이력 ${escapeText(item.work_history_title)}` : ''}${item.note ? ` · ${escapeText(item.note)}` : ''}</small></div><button type="button" data-window-delete="${escapeText(item.id)}">삭제</button></article>`).join('');
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
document.querySelector('#toggleMaintenanceForm').addEventListener('click', async () => {
  const form = document.querySelector('#maintenanceForm');
  form.hidden = !form.hidden;
  if (form.hidden) return;
  fillMaintenanceItems();
  const providerSelectBox = document.querySelector('#maintenanceProvider');
  if (providerSelectBox.options.length <= 1 && typeof knownProviders !== 'undefined') knownProviders.forEach(provider => { const option = document.createElement('option'); option.value = provider.id; option.textContent = `${provider.name} (${provider.vip})`; providerSelectBox.appendChild(option); });
  if (!form.elements.starts_at.value) { const now = new Date(); form.elements.starts_at.value = toLocalInput(now); form.elements.ends_at.value = toLocalInput(new Date(now.getTime() + 2 * 3600 * 1000)); }
  fillMaintenanceWorkHistories();
  fillMaintenanceNodes(providerSelectBox.value);
});
document.querySelector('#cancelMaintenanceForm').addEventListener('click', () => { document.querySelector('#maintenanceForm').hidden = true; });
document.querySelector('#maintenanceProvider').addEventListener('change', event => fillMaintenanceNodes(event.target.value));
document.querySelector('#maintenanceWorkHistory').addEventListener('change', event => {
  const option = event.target.selectedOptions[0];
  if (!option || !option.value) return;
  const form = document.querySelector('#maintenanceForm');
  if (!form.elements.title.value) form.elements.title.value = option.dataset.title || '';
  if (option.dataset.started) form.elements.starts_at.value = toLocalInput(option.dataset.started);
  if (option.dataset.completed) form.elements.ends_at.value = toLocalInput(option.dataset.completed);
  if (option.dataset.provider && form.elements.provider_id.value !== option.dataset.provider) { form.elements.provider_id.value = option.dataset.provider; fillMaintenanceNodes(option.dataset.provider); }
});
document.querySelector('#maintenanceForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const payload = {
    title: form.elements.title.value.trim(), provider_id: form.elements.provider_id.value || null,
    starts_at: localInputToIso(form.elements.starts_at.value), ends_at: localInputToIso(form.elements.ends_at.value),
    nodes: [...document.querySelector('#maintenanceNodes').selectedOptions].map(option => option.value),
    item_keys: [...document.querySelector('#maintenanceItems').selectedOptions].map(option => option.value),
    work_history_id: form.elements.work_history_id.value || null, note: form.elements.note.value.trim(),
  };
  const button = form.querySelector('button[type="submit"]');
  button.disabled = true;
  try {
    const response = await fetch('/api/maintenance-windows', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '정비 시간 창을 등록하지 못했습니다.');
    showToast('정비 시간 창을 등록했습니다.', `${data.title} · ${maintenanceStateLabels[data.state] || data.state}`);
    form.reset(); form.hidden = true;
    await loadAlerts();
  } catch (error) { showToast('정비 시간 창을 등록하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
document.querySelector('#maintenanceList').addEventListener('click', async event => {
  const button = event.target.closest('[data-window-delete]');
  if (!button || !window.confirm('이 정비 시간 창을 삭제할까요? 진행 중인 창이면 억제된 알림이 다시 활성화됩니다.')) return;
  try {
    const response = await fetch(`/api/maintenance-windows/${encodeURIComponent(button.dataset.windowDelete)}`, {method:'DELETE'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '삭제하지 못했습니다.');
    showToast('정비 시간 창을 삭제했습니다.', data.window?.title || '');
    await loadAlerts();
  } catch (error) { showToast('삭제하지 못했습니다.', error.message); }
});

// --- Wiring ----------------------------------------------------------------------------------
document.querySelector('#alertGroupToggle').checked = localStorage.getItem(alertGroupKey) !== '0';
document.querySelector('#alertGroupToggle').addEventListener('change', event => { localStorage.setItem(alertGroupKey, event.target.checked ? '1' : '0'); loadAlerts(); });
document.querySelector('#refreshAlerts').addEventListener('click', loadAlerts);
document.querySelector('#alertSummaryGrid').addEventListener('click', event => {
  const card = event.target.closest('[data-alert-scope]');
  if (card) applyAlertScope(card.dataset.alertScope);
});
[['#alertStatusFilter'], ['#alertSeverityFilter'], ['#alertProviderFilter']].forEach(([selector]) =>
  document.querySelector(selector).addEventListener('change', loadAlerts));
document.querySelector('#searchAlerts').addEventListener('click', loadAlerts);
document.querySelector('#alertSearch').addEventListener('keydown', event => { if (event.key === 'Enter') loadAlerts(); });
document.querySelector('#closeAlertAction').addEventListener('click', () => { document.querySelector('#alertActionEditor').hidden = true; });
document.querySelector('#alertManagementList').addEventListener('click', event => {
  const historyLink = event.target.closest('.alert-links a');
  if (historyLink) { event.preventDefault(); history.replaceState(null, '', '#history'); showPage('history'); loadWorkHistories(); return; }
  const groupAction = event.target.closest('[data-group-action]');
  if (groupAction) { event.stopPropagation(); bulkUpdateGroup(groupAction.dataset.groupKey, groupAction.dataset.groupAction === 'resolve' ? 'resolved' : 'acknowledged'); return; }
  const toggle = event.target.closest('[data-group-toggle]');
  if (toggle) { const body = toggle.closest('.alert-group').querySelector('.alert-group-body'); body.hidden = !body.hidden; toggle.closest('.alert-group').classList.toggle('expanded', !body.hidden); return; }
  const button = event.target.closest('[data-alert-action]');
  if (!button) return;
  const card = button.closest('[data-alert-id]');
  if (button.dataset.alertAction === 'runbook') {
    const item = currentAlertGroups.flatMap(group => group.alerts).find(alert => alert.id === card.dataset.alertId);
    if (item) openRunbook((item.source_key || '').split(':').pop(), item.provider_id || '');
    else fetch(`/api/alerts/${card.dataset.alertId}`).then(response => response.json()).then(item => openRunbook((item.source_key || '').split(':').pop(), item.provider_id || ''));
    return;
  }
  openAlertAction(card.dataset.alertId);
});
document.querySelector('#alertManagementList').addEventListener('keydown', event => {
  if ((event.key === 'Enter' || event.key === ' ') && event.target.matches('[data-group-toggle]')) { event.preventDefault(); event.target.click(); }
});
document.querySelector('#alertActionForm').addEventListener('submit', async event => {
  event.preventDefault(); const id = document.querySelector('#alertActionId').value; const payload = {status:document.querySelector('#alertActionStatus').value, assignee:document.querySelector('#alertAssignee').value, work_history_id:document.querySelector('#alertWorkHistory').value || null, resolution_note:document.querySelector('#alertResolutionNote').value}; const button = event.submitter; button.disabled = true;
  try { const response = await fetch(`/api/alerts/${id}`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)}); const data = await response.json(); if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '처리 내용을 확인하세요.'); document.querySelector('#alertActionEditor').hidden = true; showToast('알림 처리 내용을 저장했습니다.', `${alertStatusLabels[data.status]} 상태로 반영되었습니다.`); await loadAlerts(); } catch (error) { showToast('알림을 처리하지 못했습니다.', error.message); } finally { button.disabled = false; }
});
