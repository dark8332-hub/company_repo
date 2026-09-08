// ===== 작업 이력 =====
const workTypeLabels = {inspection:'점검', incident:'장애 대응', change:'설정 변경', restart:'재시작', deployment:'배포', maintenance:'유지보수', other:'기타'};
const workStatusLabels = {planned:'예정', approved:'승인', in_progress:'진행 중', completed:'완료', failed:'실패'};
const historyFields = ['Title','Provider','Type','Status','Operator','Target','Ticket','StartedAt','CompletedAt','Description','Commands','BeforeState','AfterState','Result','FollowUp'];
// Quick actions offered on a card for each status (예정 → 승인 → 진행 중 → 완료/실패).
const workTransitions = {
  planned: [['approved', '승인'], ['in_progress', '시작']],
  approved: [['in_progress', '시작'], ['planned', '승인 취소']],
  in_progress: [['completed', '완료'], ['failed', '실패']],
  completed: [['in_progress', '다시 진행']],
  failed: [['in_progress', '다시 진행'], ['planned', '예정으로']]
};
// Built-in templates: scaffolds with placeholders the operator fills in.
const workTemplates = [
  {key:'restart', name:'서비스 재시작', work_type:'restart', title:'<서비스명> 재시작 (<노드>)', description:'## 목적\n- 재시작 사유: <증상/알림 번호>\n\n## 영향 범위\n- 대상 노드: <노드>\n- 예상 영향: <API 지연 등>', commands:'# 상태 확인\nsystemctl status <서비스>\n\n# 재시작\nsystemctl restart <서비스>\n\n# 확인\nsystemctl is-active <서비스>\njournalctl -u <서비스> --since "-5min" | tail -50'},
  {key:'compute_add', name:'Compute 노드 추가', work_type:'deployment', title:'Compute 노드 추가 (<호스트명>)', description:'## 목적\n- 용량 확장: <vCPU/메모리>\n\n## 사전 확인\n- [ ] OS·커널 버전 표준 일치\n- [ ] 관리·스토리지 네트워크 연결\n- [ ] known_hosts·SSH 계정 준비', commands:'# 배포 후 확인\nopenstack compute service list --service nova-compute\nopenstack hypervisor list\nopenstack network agent list --host <호스트명>\n\n# 시험 인스턴스\nopenstack server create --flavor <flavor> --image <image> --network <net> --availability-zone nova:<호스트명> test-<호스트명>'},
  {key:'patch', name:'패치 적용', work_type:'change', title:'패치 적용 (<패키지/CVE>)', description:'## 목적\n- 대상 패키지: <패키지>\n- 참고: <CVE/벤더 공지>\n\n## 계획\n- 순서: Controller → Compute (라이브 마이그레이션 후)\n- 롤백: <스냅샷/이전 패키지 버전>', commands:'# 적용 전\ndpkg -l | grep <패키지>   # 또는 rpm -q <패키지>\n\n# 적용\napt-get install -y <패키지>=<버전>   # 또는 yum update <패키지>\n\n# 적용 후\nsystemctl restart <관련 서비스>\nopenstack compute service list'},
  {key:'incident', name:'장애 대응', work_type:'incident', title:'장애 대응: <증상 요약>', description:'## 장애 요약\n- 발생 시각: <YYYY-MM-DD HH:MM>\n- 영향: <서비스/프로젝트>\n- 알림: <알림 제목>\n\n## 원인 분석\n- <로그·지표 근거>\n\n## 조치\n- <임시 조치>\n- <근본 조치>', commands:'# 수집\njournalctl -u <서비스> --since "<시각>" > /tmp/<서비스>.log\nopenstack <리소스> show <ID>'},
  {key:'change', name:'설정 변경', work_type:'change', title:'설정 변경: <파일/항목>', description:'## 변경 내용\n- 파일: <경로>\n- 항목: `<key>` : <이전 값> → <새 값>\n\n## 사유\n- <변경 근거>\n\n## 롤백\n- 백업 파일 <경로>.bak 복원 후 서비스 재시작', commands:'cp <경로> <경로>.bak.$(date +%Y%m%d)\n# 편집 후\ndiff <경로>.bak.* <경로>\nsystemctl restart <서비스>'},
  {key:'maintenance', name:'정기 유지보수', work_type:'maintenance', title:'정기 유지보수 (<월/분기>)', description:'## 점검 항목\n- [ ] 디스크·로그 정리\n- [ ] 인증서 만료 확인\n- [ ] 백업 상태 확인\n- [ ] 펌웨어·SMART 상태 확인\n\n## 결과\n- <항목별 결과>', commands:'df -h\njournalctl --disk-usage\nopenssl x509 -in <인증서> -noout -enddate\nsmartctl -H /dev/<디스크>'},
  {key:'deployment', name:'배포', work_type:'deployment', title:'배포: <서비스/버전>', description:'## 배포 내용\n- 버전: <이전> → <신규>\n- 변경 사항: <요약>\n\n## 검증 계획\n- <헬스체크/시험 시나리오>', commands:'# 배포\n<배포 명령>\n\n# 검증\ncurl -s -o /dev/null -w "%{http_code}" <헬스체크 URL>\nopenstack endpoint list'},
  {key:'backup', name:'백업', work_type:'maintenance', title:'백업: <대상>', description:'## 대상\n- <DB/설정/이미지>\n\n## 보관\n- 위치: <경로/버킷>\n- 보관 기간: <일>', commands:'mysqldump --all-databases --single-transaction | gzip > /backup/db-$(date +%F).sql.gz\ntar -czf /backup/etc-openstack-$(date +%F).tgz /etc/nova /etc/neutron /etc/cinder\nls -lh /backup | tail'}
];
let currentWorkHistories = [];
let currentSessionUsername = '';
let historyView = 'list';
const historyCalendar = {year: new Date().getFullYear(), month: new Date().getMonth(), day: ''};
const workCheckPollers = {};

function localDateTimeValue(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}
function localDateKey(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}
function formatHistoryTime(value) {
  return value ? new Intl.DateTimeFormat('ko-KR', {dateStyle:'medium', timeStyle:'short'}).format(new Date(value)) : '-';
}

// Small safe Markdown renderer: the text is HTML-escaped first, then headings, bold, code, lists and http(s) links are recognised.
function renderMarkdown(text) {
  if (!text) return '';
  const inline = value => value
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
  const lines = escapeText(text).replace(/\r\n?/g, '\n').split('\n');
  const html = [];
  let paragraph = [], list = null, code = null;
  const flushParagraph = () => { if (paragraph.length) { html.push(`<p>${paragraph.map(inline).join('<br>')}</p>`); paragraph = []; } };
  const flushList = () => { if (list) { html.push(`<${list.type}>${list.items.map(item => `<li>${inline(item)}</li>`).join('')}</${list.type}>`); list = null; } };
  lines.forEach(line => {
    if (code !== null) {
      if (/^```/.test(line)) { html.push(`<pre class="md-code">${code.join('\n')}</pre>`); code = null; } else code.push(line);
      return;
    }
    if (/^```/.test(line)) { flushParagraph(); flushList(); code = []; return; }
    const heading = /^(#{1,3})\s+(.*)$/.exec(line);
    if (heading) { flushParagraph(); flushList(); html.push(`<h${heading[1].length + 2}>${inline(heading[2])}</h${heading[1].length + 2}>`); return; }
    const bullet = /^\s*[-*]\s+(.*)$/.exec(line);
    const numbered = /^\s*\d+[.)]\s+(.*)$/.exec(line);
    if (bullet || numbered) {
      flushParagraph();
      const type = bullet ? 'ul' : 'ol';
      if (!list || list.type !== type) { flushList(); list = {type, items:[]}; }
      list.items.push((bullet || numbered)[1]);
      return;
    }
    if (!line.trim()) { flushParagraph(); flushList(); return; }
    flushList();
    paragraph.push(line);
  });
  if (code !== null) html.push(`<pre class="md-code">${code.join('\n')}</pre>`);
  flushParagraph(); flushList();
  return `<div class="markdown">${html.join('')}</div>`;
}

async function loadSessionUsername() {
  if (currentSessionUsername) return currentSessionUsername;
  try {
    const response = await fetch('/api/auth/session', {cache:'no-store'});
    if (response.ok) currentSessionUsername = (await response.json()).username || '';
  } catch (_) { /* offline: the server fills the operator from the session anyway */ }
  return currentSessionUsername;
}

function renderTemplateOptions() {
  const select = document.querySelector('#historyTemplate');
  select.innerHTML = '<option value="">선택 안 함</option>' + workTemplates.map(template => `<option value="${template.key}">${escapeText(template.name)}</option>`).join('');
}
function applyWorkTemplate(key) {
  const template = workTemplates.find(item => item.key === key);
  if (!template) return;
  const fields = [['#historyTitle', template.title], ['#historyDescription', template.description], ['#historyCommands', template.commands]];
  const filled = fields.some(([selector]) => document.querySelector(selector).value.trim());
  if (filled && !window.confirm('입력한 제목·내용·절차를 템플릿 내용으로 바꿀까요?')) { document.querySelector('#historyTemplate').value = ''; return; }
  fields.forEach(([selector, value]) => { document.querySelector(selector).value = value; });
  document.querySelector('#historyType').value = template.work_type;
  if (!document.querySelector('#historyTarget').value.trim()) document.querySelector('#historyTarget').placeholder = '노드, 서비스 또는 리소스 (템플릿의 <…>를 채우세요)';
  showToast(`${template.name} 템플릿을 적용했습니다.`, '<…> 자리를 실제 값으로 바꾸세요.');
}

async function resetWorkHistoryForm() {
  document.querySelector('#workHistoryForm').reset();
  document.querySelector('#workHistoryId').value = '';
  document.querySelector('#historyTemplate').value = '';
  document.querySelector('#historyStartedAt').value = localDateTimeValue();
  document.querySelector('#workHistoryFormTitle').textContent = '작업 이력 등록';
  const providerFilter = document.querySelector('#historyProviderFilter').value;
  if (providerFilter) document.querySelector('#historyProvider').value = providerFilter;
  const operator = document.querySelector('#historyOperator');
  if (!operator.value.trim()) operator.value = await loadSessionUsername();
}

function workHistoryPayload() {
  const value = id => document.querySelector(`#history${id}`).value;
  return {provider_id:value('Provider') || null, title:value('Title'), work_type:value('Type'), status:value('Status'), operator:value('Operator'), target:value('Target'), ticket:value('Ticket'), description:value('Description'), commands:value('Commands'), before_state:value('BeforeState'), after_state:value('AfterState'), result:value('Result'), follow_up:value('FollowUp'), started_at:new Date(value('StartedAt')).toISOString(), completed_at:value('CompletedAt') ? new Date(value('CompletedAt')).toISOString() : null};
}

function quickInspectionKeys() {
  if (typeof inspectionGroups === 'undefined') return null;
  const quickGroups = new Set(['시스템 기본 점검', 'Middleware 점검', 'OpenStack 서비스 점검', 'OpenStack 리소스 점검']);
  return inspectionGroups.filter(group => quickGroups.has(group.title)).flatMap(group => group.items.map(item => item[3]));
}
function inspectionItemName(key) {
  if (typeof itemNameMap === 'function') { const names = itemNameMap(); if (names[key]) return names[key]; }
  return key;
}

function workHistoryCard(item) {
  const approval = item.approved_by ? `<small class="history-approval">승인 ${escapeText(item.approved_by)} · ${escapeText(formatHistoryTime(item.approved_at))}</small>` : '';
  const actions = (workTransitions[item.status] || []).map(([status, label]) => `<button type="button" data-history-transition="${status}" class="transition ${status}">${label}</button>`).join('');
  const checkSection = item.provider_id ? `<section class="history-check-section" data-check-section><b>작업 전후 점검</b><div class="history-check-controls"><select data-check-preset><option value="all">전체 항목</option><option value="quick">빠른 점검(로그 제외)</option></select><button type="button" data-history-check="before" ${item.before_check_id ? 'title="다시 실행하면 새 결과로 바뀝니다"' : ''}>작업 전 점검 실행</button><button type="button" data-history-check="after">작업 후 점검 실행</button><span class="history-check-progress" data-check-progress hidden></span></div><div class="history-check-summary" data-check-summary><div class="empty-provider">상세를 열면 전후 점검 결과를 불러옵니다.</div></div></section>` : '<section class="history-check-section muted"><b>작업 전후 점검</b><small>공급자를 지정한 작업만 전후 점검을 실행할 수 있습니다.</small></section>';
  return `<article class="work-history-card status-${item.status}" data-history-id="${item.id}" data-provider-id="${escapeText(item.provider_id || '')}">
    <header><div><span class="history-type">${workTypeLabels[item.work_type] || escapeText(item.work_type)}</span><span class="history-status ${item.status}">${workStatusLabels[item.status] || escapeText(item.status)}</span>${item.before_check_id || item.after_check_id ? `<span class="history-check-badge">${item.before_check_id ? '전' : ''}${item.before_check_id && item.after_check_id ? '·' : ''}${item.after_check_id ? '후' : ''} 점검</span>` : ''}<h2>${escapeText(item.title)}</h2><small>${escapeText(item.provider_name || '공통')} · ${escapeText(item.target || '대상 미지정')} · ${escapeText(item.operator)}${item.ticket ? ` · ${escapeText(item.ticket)}` : ''}</small>${approval}</div><div class="history-card-side"><time>${escapeText(formatHistoryTime(item.started_at))}</time>${item.completed_at ? `<time class="completed">완료 ${escapeText(formatHistoryTime(item.completed_at))}</time>` : ''}<div class="history-quick-actions">${actions}</div></div></header>
    <div class="history-description">${renderMarkdown(item.description)}</div>
    <div class="history-detail" hidden>
      ${item.commands ? `<section><b>실행 명령 / 절차</b><pre>${escapeText(item.commands)}</pre></section>` : ''}
      ${item.before_state ? `<section><b>변경 전 상태</b><pre>${escapeText(item.before_state)}</pre></section>` : ''}
      ${item.after_state ? `<section><b>변경 후 상태</b><pre>${escapeText(item.after_state)}</pre></section>` : ''}
      ${item.result ? `<section><b>결과 및 검증</b>${renderMarkdown(item.result)}</section>` : ''}
      ${item.follow_up ? `<section><b>후속 조치</b>${renderMarkdown(item.follow_up)}</section>` : ''}
      ${checkSection}
      <section class="history-attachments" data-attachments><b>첨부 파일</b><div data-attachment-list><div class="empty-provider">상세를 열면 첨부 파일을 불러옵니다.</div></div><label class="history-upload">파일 추가 (최대 10개, 10 MB)<input type="file" data-attachment-input></label></section>
    </div>
    <footer><button data-history-action="toggle" type="button">상세 보기</button><button data-history-action="edit" type="button">수정</button><button class="danger" data-history-action="delete" type="button">삭제</button></footer>
  </article>`;
}

function visibleWorkHistories() {
  if (historyView === 'calendar' && historyCalendar.day) return currentWorkHistories.filter(item => localDateKey(item.started_at) === historyCalendar.day);
  return currentWorkHistories;
}
function renderWorkHistoryList() {
  const list = document.querySelector('#workHistoryList');
  const items = visibleWorkHistories();
  if (!items.length) {
    list.innerHTML = `<div class="empty-provider">${historyView === 'calendar' && historyCalendar.day ? `${historyCalendar.day}에 시작한 작업이 없습니다.` : '조건에 맞는 작업 이력이 없습니다.'}</div>`;
    return;
  }
  list.innerHTML = items.map(workHistoryCard).join('');
}

async function loadWorkHistories() {
  const params = new URLSearchParams();
  [['provider_id','#historyProviderFilter'],['work_type','#historyTypeFilter'],['status','#historyStatusFilter'],['q','#historySearch']].forEach(([key, selector]) => { const value = document.querySelector(selector).value.trim(); if (value) params.set(key, value); });
  const list = document.querySelector('#workHistoryList');
  list.innerHTML = '<div class="empty-provider">작업 이력을 불러오는 중입니다.</div>';
  try {
    const response = await fetch(`/api/work-histories?${params}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '작업 이력을 불러오지 못했습니다.');
    currentWorkHistories = data.histories;
    renderWorkHistoryList();
    if (historyView === 'calendar') renderWorkCalendar();
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}

// --- Card detail: attachments and before/after inspections ---------------------------------------
async function loadAttachments(card) {
  const id = card.dataset.historyId;
  const box = card.querySelector('[data-attachment-list]');
  try {
    const response = await fetch(`/api/work-histories/${encodeURIComponent(id)}/attachments`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '첨부 파일을 불러오지 못했습니다.');
    box.innerHTML = data.attachments.length ? `<ul class="attachment-list">${data.attachments.map(file => `<li><a href="/api/work-histories/${encodeURIComponent(id)}/attachments/${encodeURIComponent(file.id)}" download="${escapeText(file.filename)}">${escapeText(file.filename)}</a><small>${escapeText(formatBytes(file.size))} · ${escapeText(file.uploaded_by || '-')} · ${escapeText(formatHistoryTime(file.uploaded_at))}</small><button type="button" data-attachment-delete="${escapeText(file.id)}" class="danger">삭제</button></li>`).join('')}</ul>` : '<div class="empty-provider">첨부 파일이 없습니다.</div>';
    card.querySelector('[data-attachment-input]').disabled = data.attachments.length >= data.max_files;
  } catch (error) { box.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
async function uploadAttachment(card, file) {
  const id = card.dataset.historyId;
  if (file.size > 10 * 1024 * 1024) return showToast('첨부하지 못했습니다.', '파일은 10 MB 이하여야 합니다.');
  const body = new FormData();
  body.append('file', file, file.name);
  try {
    const response = await fetch(`/api/work-histories/${encodeURIComponent(id)}/attachments`, {method:'POST', body});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '첨부하지 못했습니다.');
    showToast('파일을 첨부했습니다.', `${file.name} · ${formatBytes(file.size)}`);
    await loadAttachments(card);
  } catch (error) { showToast('첨부하지 못했습니다.', error.message); }
}
async function deleteAttachment(card, attachmentId) {
  if (!window.confirm('이 첨부 파일을 삭제할까요?')) return;
  const id = card.dataset.historyId;
  const response = await fetch(`/api/work-histories/${encodeURIComponent(id)}/attachments/${encodeURIComponent(attachmentId)}`, {method:'DELETE'});
  if (response.ok) { showToast('첨부 파일을 삭제했습니다.', ''); await loadAttachments(card); }
  else showToast('첨부 파일을 삭제하지 못했습니다.', (await response.json().catch(() => ({}))).detail || '');
}

const checkStatusLabels = {healthy:'정상', warning:'주의', unavailable:'확인 불가', pending:'수집 대기', excepted:'예외', skipped:'제외'};
const changeLabelMap = {new_issue:'신규 이상', resolved:'해소', changed:'상태 변경', added:'추가', removed:'제외'};
function checkBrief(check, label, providerId) {
  if (!check) return `<article class="history-check-card muted"><small>${label}</small><strong>미실행</strong><em>아직 점검 결과가 없습니다.</em></article>`;
  return `<article class="history-check-card ${check.status}"><small>${label}</small><strong>${escapeText(checkStatusLabels[check.status] || check.status)}</strong><em>${escapeText(formatHistoryTime(check.checked_at))} · 정상 ${check.items.healthy} · 주의 ${check.items.warning} · 확인 불가 ${check.items.unavailable}</em><button type="button" data-open-check="${escapeText(check.id)}" data-open-provider-id="${escapeText(providerId)}">점검 결과 보기</button></article>`;
}
async function loadComparison(card) {
  const id = card.dataset.historyId;
  const box = card.querySelector('[data-check-summary]');
  if (!box) return;
  try {
    const response = await fetch(`/api/work-histories/${encodeURIComponent(id)}/comparison`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '전후 점검 결과를 불러오지 못했습니다.');
    const providerId = data.provider_id || '';
    let html = `<div class="history-check-cards">${checkBrief(data.before, '작업 전', providerId)}${checkBrief(data.after, '작업 후', providerId)}</div>`;
    if (data.diff) {
      const counts = data.diff.counts || {};
      const signed = value => (value > 0 ? `+${value}` : `${value}`);
      html += `<div class="history-diff"><div class="history-diff-counts"><span class="${counts.new_issue ? 'crit' : ''}">신규 이상 ${counts.new_issue || 0}</span><span class="${counts.resolved ? 'ok' : ''}">해소 ${counts.resolved || 0}</span><span>상태 변경 ${counts.changed || 0}</span><span>주의 ${signed(counts.warning_delta || 0)} · 확인 불가 ${signed(counts.unavailable_delta || 0)} · 정상 ${signed(counts.healthy_delta || 0)}</span></div>`;
      html += data.diff.items.length ? `<ul class="history-diff-items">${data.diff.items.map(entry => `<li class="${entry.change}"><em>${changeLabelMap[entry.change] || entry.change}</em><strong>${escapeText(inspectionItemName(entry.key))}</strong><small>${escapeText(checkStatusLabels[entry.before] || entry.before || '-')} → ${escapeText(checkStatusLabels[entry.after] || entry.after || '-')}</small></li>`).join('')}</ul>` : '<p class="history-diff-none">작업 전후 항목 상태가 모두 같습니다.</p>';
      if (data.diff.nodes.length) html += `<ul class="history-diff-nodes">${data.diff.nodes.map(node => `<li><strong>${escapeText(node.hostname)}</strong><small>${escapeText(node.before || '-')} → ${escapeText(node.after || '-')}${node.new_items.length ? ` · 신규 ${node.new_items.map(inspectionItemName).map(escapeText).join(', ')}` : ''}${node.resolved_items.length ? ` · 해소 ${node.resolved_items.map(inspectionItemName).map(escapeText).join(', ')}` : ''}</small></li>`).join('')}</ul>`;
      html += '</div>';
    } else if (data.before || data.after) {
      html += '<p class="history-diff-none">작업 전과 후 점검이 모두 있어야 비교합니다.</p>';
    }
    box.innerHTML = html;
    if (data.running && !workCheckPollers[id]) followWorkCheck(card, providerId, null);
  } catch (error) { box.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
async function startWorkCheck(card, phase) {
  const id = card.dataset.historyId;
  const providerId = card.dataset.providerId;
  const preset = card.querySelector('[data-check-preset]')?.value || 'all';
  const selected = preset === 'quick' ? quickInspectionKeys() : null;
  const buttons = card.querySelectorAll('[data-history-check]');
  buttons.forEach(button => { button.disabled = true; });
  try {
    const response = await fetch(`/api/work-histories/${encodeURIComponent(id)}/checks/${phase}`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({selected_items: selected})});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '점검을 시작하지 못했습니다.');
    showToast(`${phase === 'before' ? '작업 전' : '작업 후'} 점검을 시작했습니다.`, '완료되면 전후 비교가 갱신됩니다.');
    followWorkCheck(card, providerId, phase);
  } catch (error) { showToast('점검을 시작하지 못했습니다.', error.message); buttons.forEach(button => { button.disabled = false; }); }
}
async function followWorkCheck(card, providerId, phase) {
  const id = card.dataset.historyId;
  const progress = card.querySelector('[data-check-progress]');
  const buttons = card.querySelectorAll('[data-history-check]');
  buttons.forEach(button => { button.disabled = true; });
  workCheckPollers[id] = true;
  if (progress) { progress.hidden = false; progress.textContent = '점검 실행 중…'; }
  for (let attempt = 0; attempt < 900; attempt += 1) {
    await new Promise(resolve => setTimeout(resolve, 2000));
    try {
      const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks/progress`, {cache:'no-store'});
      if (!response.ok) continue;
      const state = await response.json();
      if (progress) progress.textContent = state.running ? `${state.message || '점검 실행 중'} · ${state.percent ?? 0}%` : (state.stage === 'completed' ? '점검 완료' : (state.message || '점검 종료'));
      if (!state.running) break;
    } catch (_) { /* keep polling */ }
  }
  delete workCheckPollers[id];
  buttons.forEach(button => { button.disabled = false; });
  // The background task stores the check id right after the run; give it a moment before reading it back.
  await new Promise(resolve => setTimeout(resolve, 800));
  await loadComparison(card);
  await loadWorkHistoriesQuietly();
  if (progress) setTimeout(() => { progress.hidden = true; }, 4000);
}
async function loadWorkHistoriesQuietly() {
  // Refresh the badge/list without collapsing the card the operator is looking at.
  const open = [...document.querySelectorAll('.work-history-card')].filter(card => !card.querySelector('.history-detail').hidden).map(card => card.dataset.historyId);
  await loadWorkHistories();
  open.forEach(id => { const card = document.querySelector(`.work-history-card[data-history-id="${id}"]`); if (card) openCardDetail(card); });
}
function openCardDetail(card) {
  const detail = card.querySelector('.history-detail');
  detail.hidden = false;
  card.querySelector('[data-history-action="toggle"]').textContent = '상세 닫기';
  loadAttachments(card);
  if (card.querySelector('[data-check-summary]')) loadComparison(card);
}

// --- Calendar view ---------------------------------------------------------------------------------
function renderWorkCalendar() {
  const {year, month} = historyCalendar;
  document.querySelector('#calendarMonthLabel').textContent = `${year}년 ${month + 1}월`;
  const first = new Date(year, month, 1);
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const byDay = {};
  currentWorkHistories.forEach(item => { const key = localDateKey(item.started_at); (byDay[key] = byDay[key] || []).push(item); });
  const todayKey = localDateKey(new Date());
  const cells = ['일', '월', '화', '수', '목', '금', '토'].map(name => `<div class="calendar-weekday">${name}</div>`);
  for (let blank = 0; blank < first.getDay(); blank += 1) cells.push('<div class="calendar-cell empty"></div>');
  for (let day = 1; day <= daysInMonth; day += 1) {
    const key = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    const items = byDay[key] || [];
    cells.push(`<button type="button" class="calendar-cell${key === todayKey ? ' today' : ''}${historyCalendar.day === key ? ' selected' : ''}${items.length ? ' has-items' : ''}" data-calendar-day="${key}"><span class="calendar-date">${day}</span>${items.slice(0, 3).map(item => `<span class="calendar-item ${item.status}" title="${escapeText(item.title)}">${escapeText(item.title)}</span>`).join('')}${items.length > 3 ? `<span class="calendar-more">+${items.length - 3}</span>` : ''}</button>`);
  }
  document.querySelector('#calendarGrid').innerHTML = cells.join('');
  const filter = document.querySelector('#calendarDayFilter');
  filter.hidden = !historyCalendar.day;
  filter.textContent = historyCalendar.day ? `${historyCalendar.day} 시작 작업만 표시` : '';
  document.querySelector('#calendarClearDay').hidden = !historyCalendar.day;
}
function setHistoryView(view) {
  historyView = view;
  document.querySelector('#historyViewList').classList.toggle('active', view === 'list');
  document.querySelector('#historyViewCalendar').classList.toggle('active', view === 'calendar');
  document.querySelector('#workHistoryCalendar').hidden = view !== 'calendar';
  if (view === 'calendar') renderWorkCalendar();
  renderWorkHistoryList();
}
function shiftCalendarMonth(delta) {
  const date = new Date(historyCalendar.year, historyCalendar.month + delta, 1);
  historyCalendar.year = date.getFullYear(); historyCalendar.month = date.getMonth(); historyCalendar.day = '';
  renderWorkCalendar(); renderWorkHistoryList();
}

async function exportWorkHistoryCsv() {
  const defaultMonth = `${historyCalendar.year}-${String(historyCalendar.month + 1).padStart(2, '0')}`;
  const month = window.prompt('내보낼 달을 YYYY-MM 형식으로 입력하세요.', defaultMonth);
  if (month === null) return;
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month.trim())) return showToast('월 형식이 올바르지 않습니다.', '예: 2026-09');
  const providerId = document.querySelector('#historyProviderFilter').value;
  const button = document.querySelector('#exportWorkHistoryCsv');
  button.disabled = true;
  try {
    const response = await fetch(`/api/work-history-reports/monthly.csv?month=${encodeURIComponent(month.trim())}${providerId ? `&provider_id=${encodeURIComponent(providerId)}` : ''}`, {cache:'no-store'});
    if (!response.ok) { const data = await response.json().catch(() => ({})); throw new Error(typeof data.detail === 'string' ? data.detail : `서버 오류 (${response.status})`); }
    const url = URL.createObjectURL(await response.blob());
    const link = document.createElement('a'); link.href = url; link.download = `작업이력_${month.trim()}.csv`; document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
    showToast('월간 보고서를 내려받았습니다.', `작업이력_${month.trim()}.csv`);
  } catch (error) { showToast('월간 보고서를 만들지 못했습니다.', error.message); }
  finally { button.disabled = false; }
}

// --- Event wiring -----------------------------------------------------------------------------------
renderTemplateOptions();
document.querySelector('#historyTemplate').addEventListener('change', event => applyWorkTemplate(event.target.value));
document.querySelector('#newWorkHistory').addEventListener('click', async () => { await resetWorkHistoryForm(); document.querySelector('#workHistoryEditor').hidden = false; document.querySelector('#workHistoryEditor').scrollIntoView({behavior:'smooth'}); });
document.querySelector('#closeWorkHistory').addEventListener('click', () => { document.querySelector('#workHistoryEditor').hidden = true; });
document.querySelector('#searchWorkHistory').addEventListener('click', loadWorkHistories);
document.querySelector('#historySearch').addEventListener('keydown', event => { if (event.key === 'Enter') loadWorkHistories(); });
document.querySelector('#exportWorkHistoryCsv').addEventListener('click', exportWorkHistoryCsv);
document.querySelector('#historyViewList').addEventListener('click', () => setHistoryView('list'));
document.querySelector('#historyViewCalendar').addEventListener('click', () => setHistoryView('calendar'));
document.querySelector('#calendarPrevMonth').addEventListener('click', () => shiftCalendarMonth(-1));
document.querySelector('#calendarNextMonth').addEventListener('click', () => shiftCalendarMonth(1));
document.querySelector('#calendarClearDay').addEventListener('click', () => { historyCalendar.day = ''; renderWorkCalendar(); renderWorkHistoryList(); });
document.querySelector('#calendarGrid').addEventListener('click', event => {
  const cell = event.target.closest('[data-calendar-day]');
  if (!cell) return;
  historyCalendar.day = historyCalendar.day === cell.dataset.calendarDay ? '' : cell.dataset.calendarDay;
  renderWorkCalendar(); renderWorkHistoryList();
});
document.querySelector('#workHistoryForm').addEventListener('submit', async event => {
  event.preventDefault(); const id = document.querySelector('#workHistoryId').value; const button = event.submitter; button.disabled = true;
  try { const response = await fetch(id ? `/api/work-histories/${id}` : '/api/work-histories', {method:id ? 'PUT' : 'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(workHistoryPayload())}); const data = await response.json(); if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '입력값을 확인하세요.'); document.querySelector('#workHistoryEditor').hidden = true; showToast(id ? '작업 이력을 수정했습니다.' : '작업 이력을 등록했습니다.', '저장된 기록은 작업 이력에서 조회할 수 있습니다.'); await loadWorkHistories(); } catch (error) { showToast('작업 이력을 저장하지 못했습니다.', error.message); } finally { button.disabled = false; }
});
document.querySelector('#workHistoryList').addEventListener('change', event => {
  const input = event.target.closest('[data-attachment-input]');
  if (!input || !input.files?.length) return;
  const card = input.closest('[data-history-id]');
  uploadAttachment(card, input.files[0]).then(() => { input.value = ''; });
});
document.querySelector('#workHistoryList').addEventListener('click', async event => {
  const card = event.target.closest('[data-history-id]');
  if (!card) return;
  const id = card.dataset.historyId;
  const transition = event.target.closest('[data-history-transition]');
  if (transition) {
    const status = transition.dataset.historyTransition;
    if ((status === 'failed' || status === 'completed') && !window.confirm(`이 작업을 '${workStatusLabels[status]}' 상태로 바꿀까요?`)) return;
    transition.disabled = true;
    try {
      const response = await fetch(`/api/work-histories/${encodeURIComponent(id)}/transition`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({status})});
      const data = await response.json();
      if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '상태를 바꾸지 못했습니다.');
      showToast(`작업 상태를 '${workStatusLabels[status]}'(으)로 바꿨습니다.`, data.approved_by && status === 'approved' ? `승인자 ${data.approved_by}` : '');
      await loadWorkHistoriesQuietly();
    } catch (error) { showToast('상태를 바꾸지 못했습니다.', error.message); transition.disabled = false; }
    return;
  }
  const checkButton = event.target.closest('[data-history-check]');
  if (checkButton) { startWorkCheck(card, checkButton.dataset.historyCheck); return; }
  const openCheck = event.target.closest('[data-open-check]');
  if (openCheck) {
    const providerId = openCheck.dataset.openProviderId;
    if (typeof selectProvider === 'function') selectProvider(providerId);
    history.replaceState(null, '', '#daily-inspection'); showPage('daily-inspection');
    if (typeof viewCheck === 'function') setTimeout(() => viewCheck(providerId, openCheck.dataset.openCheck), 300);
    return;
  }
  const attachmentDelete = event.target.closest('[data-attachment-delete]');
  if (attachmentDelete) { deleteAttachment(card, attachmentDelete.dataset.attachmentDelete); return; }
  const button = event.target.closest('[data-history-action]'); if (!button) return;
  if (button.dataset.historyAction === 'toggle') {
    const detail = card.querySelector('.history-detail');
    if (detail.hidden) openCardDetail(card); else { detail.hidden = true; button.textContent = '상세 보기'; }
    return;
  }
  if (button.dataset.historyAction === 'delete') { if (!confirm('이 작업 이력을 삭제하시겠습니까? 첨부 파일도 함께 삭제됩니다.')) return; const response = await fetch(`/api/work-histories/${id}`, {method:'DELETE'}); if (response.ok) { showToast('작업 이력을 삭제했습니다.', '삭제한 기록은 복구할 수 없습니다.'); loadWorkHistories(); } return; }
  const response = await fetch(`/api/work-histories/${id}`); const item = await response.json(); if (!response.ok) return showToast('작업 이력을 불러오지 못했습니다.', item.detail || '다시 시도하세요.');
  const values = {Title:item.title, Provider:item.provider_id || '', Type:item.work_type, Status:item.status, Operator:item.operator, Target:item.target, Ticket:item.ticket, StartedAt:localDateTimeValue(item.started_at), CompletedAt:item.completed_at ? localDateTimeValue(item.completed_at) : '', Description:item.description, Commands:item.commands, BeforeState:item.before_state, AfterState:item.after_state, Result:item.result, FollowUp:item.follow_up};
  historyFields.forEach(name => { if (name in values) document.querySelector(`#history${name}`).value = values[name] || ''; }); document.querySelector('#historyTemplate').value = ''; document.querySelector('#workHistoryId').value = id; document.querySelector('#workHistoryFormTitle').textContent = '작업 이력 수정'; document.querySelector('#workHistoryEditor').hidden = false; document.querySelector('#workHistoryEditor').scrollIntoView({behavior:'smooth'});
});
