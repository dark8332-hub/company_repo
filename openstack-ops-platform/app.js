const menuButton = document.querySelector('#menuButton');
const sidebar = document.querySelector('#sidebar');
const runInspection = document.querySelector('#runInspection');
const toast = document.querySelector('#toast');
const clock = document.querySelector('#clock');
const providerSelect = document.querySelector('#providerSelect');
const inspectionProviderSelect = document.querySelector('#inspectionProviderSelect');
const infrastructureProviderSelect = document.querySelector('#infrastructureProviderSelect');
const historyProvider = document.querySelector('#historyProvider');
const historyProviderFilter = document.querySelector('#historyProviderFilter');
const alertProviderFilter = document.querySelector('#alertProviderFilter');
const dailyRunInspection = document.querySelector('#dailyRunInspection');
const exportInspectionPdf = document.querySelector('#exportInspectionPdf');
const discoverCluster = document.querySelector('#discoverCluster');
const exceptionItem = document.querySelector('#exceptionItem');
const exceptionNode = document.querySelector('#exceptionNode');
const exceptionReason = document.querySelector('#exceptionReason');

const menuPreferenceKey = 'okestro-visible-menus';
const configurableMenus = [
  ['dashboard', '대시보드', '운영 현황 요약'], ['daily-inspection', '일일점검', '클러스터 일일 점검'],
  ['providers', '공급자 연결', 'OpenStack 환경 연결 관리'], ['infrastructure', '인프라 현황', '노드와 자원 상태'],
  ['monitoring', '모니터링', '실시간 메트릭'], ['alerts', '알림 및 장애', '장애와 알림 확인'], ['history', '작업 이력', '운영 작업 기록']
];

function loadVisibleMenus() {
  try {
    const saved = JSON.parse(localStorage.getItem(menuPreferenceKey));
    if (Array.isArray(saved)) return new Set(saved.filter(key => configurableMenus.some(menu => menu[0] === key)));
  } catch (_) { /* Invalid settings fall back to all menus. */ }
  return new Set(configurableMenus.map(menu => menu[0]));
}

let visibleMenus = loadVisibleMenus();

function applyMenuPreferences() {
  document.querySelectorAll('[data-menu-key]').forEach(link => { link.hidden = !visibleMenus.has(link.dataset.menuKey); });
  document.querySelectorAll('.navigation>p').forEach(heading => {
    let item = heading.nextElementSibling;
    let hasVisibleItem = false;
    while (item && item.tagName !== 'P') { if (item.tagName === 'A' && !item.hidden) hasVisibleItem = true; item = item.nextElementSibling; }
    heading.hidden = !hasVisibleItem;
  });
}

function renderMenuSettings() {
  const list = document.querySelector('#menuSettingsList');
  if (!list) return;
  list.innerHTML = configurableMenus.map(([key, name, description]) => `<label class="menu-setting-item${visibleMenus.has(key) ? ' selected' : ''}"><input type="checkbox" value="${key}" ${visibleMenus.has(key) ? 'checked' : ''}><span><strong>${name}</strong><small>${description}</small></span><em>${visibleMenus.has(key) ? '사용' : '숨김'}</em></label>`).join('');
}

function saveMenuPreferences() {
  localStorage.setItem(menuPreferenceKey, JSON.stringify([...visibleMenus]));
  applyMenuPreferences();
  renderMenuSettings();
}

document.querySelectorAll('[data-page]').forEach(link => link.addEventListener('click', event => {
  event.preventDefault();
  history.replaceState(null, '', link.getAttribute('href'));
  showPage(link.dataset.page);
  if (link.dataset.page === 'history') loadWorkHistories();
  if (link.dataset.page === 'alerts') loadAlerts();
}));

const inspectionGroups = [
  {title:'시스템 기본 점검', description:'Controller의 운영체제와 기본 자원 상태', items:[
    ['Resource','CPU 사용률','수집: top으로 노드별 사용률 확인 · 판정: 80% 이상 주의','cpu'], ['Resource','Memory 사용률','수집: MemTotal/Available 기반 실사용률 계산 · 판정: 80% 이상 주의','memory'], ['Resource','Disk 사용률','수집: df로 루트 파일시스템 용량 확인 · 판정: 80% 이상 주의','disk'],
    ['System','Chrony 동기화','수집: chronyc sources/tracking · 판정: 시간원 연결 및 동기화 실패 시 주의','chrony'], ['System','Bonding 인터페이스','수집: Bond별 MII/Slave 상태 · 판정: 링크 Down 또는 비정상 Slave 확인','bonding'], ['System','Mount 상태','수집: Glance/Cinder 데이터 경로 · 판정: Controller 필수 마운트 누락 확인','mount']
  ]},
  {title:'Middleware 점검', description:'고가용성 및 데이터베이스 클러스터 상태', items:[
    ['Clustering','PCS cluster','수집: pcs status · 판정: Offline/Stopped/Failed/Unclean 리소스 탐지','pcs'], ['Clustering','VIP 통신','수집: VIP ICMP 응답 · 판정: 패킷 손실 및 접근 실패 확인','vip'], ['Clustering','RabbitMQ cluster','수집: rabbitmqctl cluster_status · 판정: 노드·파티션·알람 이상 확인','rabbitmq'], ['Clustering','MySQL cluster','수집: wsrep_cluster_weight · 판정: Galera 구성원 수와 쿼럼 이상 확인','mysql'],
    ['Database','MySQL Host Blocked Errors','수집: performance_schema.host_cache의 COUNT_HOST_BLOCKED_ERRORS · 판정: 출력값이 모두 0이면 정상, 1 이상이면 주의, 행이 없으면 확인 불가','mysql_host_blocked_errors'],
    ['Database','WSREP Local Cert Failures','수집: wsrep_local_cert_failures Global Status · 판정: 0이면 정상, 1 이상이면 주의','wsrep_local_cert_failures']
  ]},
  {title:'OpenStack 서비스 점검', description:'서비스 및 에이전트 가용 상태', items:[
    ['Service','Endpoint','수집: openstack endpoint list · 판정: 서비스별 Endpoint 존재 여부 확인','endpoint'], ['Service','Nova','수집: compute service list · 판정: 서비스 Down/Disabled 탐지','nova'], ['Service','Neutron','수집: network agent list · 판정: 에이전트 Down 탐지','neutron'],
    ['Service','Cinder','수집: volume service list · 판정: cinder 서비스 Down/Disabled 탐지','cinder'], ['Service','Manila','수집: share service list · 판정: manila 서비스 Down/Disabled 탐지','manila'], ['Service','Octavia','수집: loadbalancer API 조회 · 판정: 명령 실패와 오류 상태 탐지','octavia'], ['Service','Nova-compute','수집: 프로세스·systemd 상태 · 판정: Compute 노드의 nova-compute 비활성 탐지','nova_compute'],
    ['Service','Masakari','수집: segment 또는 서비스 목록 · 판정: API 실패와 비정상 상태 확인','masakari'], ['Service','Swift','수집: object store account · 판정: API 접근 및 계정 상태 확인','swift'], ['Service','Heat','수집: orchestration service list · 판정: Down/Disabled/Failed 탐지','heat']
  ]},
  {title:'OpenStack 리소스 점검', description:'사용자 리소스의 비정상 상태 확인', items:[
    ['Resource','VM state','수집: 전체 프로젝트 서버 목록 · 판정: ERROR 상태 인스턴스 탐지','vm'], ['Resource','Network state','수집: Neutron 에이전트 상태 · 판정: Down 에이전트 탐지','network'], ['Resource','Volume state','수집: 전체 프로젝트 볼륨 · 판정: ERROR 상태 탐지','volume'],
    ['Resource','Snapshot state','수집: 전체 스냅샷 · 판정: Creating 장기 지속 또는 Error 상태 탐지','snapshot'], ['Resource','Share state','수집: 전체 Manila Share · 판정: Creating/Error 상태 탐지','share'], ['Resource','LB state','수집: Load Balancer 목록 · 판정: ERROR 상태 탐지','lb'], ['Resource','Amphora state','수집: Amphora 상세 목록 · 판정: ERROR 상태 탐지','amphora'],
    ['Resource','Masakari notifications','수집: HA 알림 목록 · 판정: Error/Failed 알림 탐지','masakari_notification'], ['Resource','Swift containers','수집: 컨테이너 목록 · 판정: API 실패 및 비정상 응답 확인','swift_container'], ['Resource','Heat stacks','수집: 전체 프로젝트 Stack · 판정: 생성·갱신·삭제·Rollback 실패 탐지','heat_stack']
  ]},
  {title:'로그 점검', description:'주요 서비스와 시스템 로그의 오류 탐색', items:[
    ['System','Nova log','범위: 전날 00:00~오늘 00:00 · 탐지: ERROR/CRITICAL/Traceback · 직전 점검과 신규·해소 비교','nova_log'], ['System','Neutron log','범위: 전날 00:00~오늘 00:00 · 탐지: ERROR/CRITICAL/Traceback · 직전 점검과 신규·해소 비교','neutron_log'], ['System','Cinder log','범위: 전날 00:00~오늘 00:00 · 탐지: ERROR/CRITICAL/Traceback · 직전 점검과 신규·해소 비교','cinder_log'],
    ['System','Glance log','범위: 전날 00:00~오늘 00:00 · 탐지: 오류 패턴 · 직전 점검과 신규·해소 비교','glance_log'], ['System','Manila log','범위: 전날 00:00~오늘 00:00 · 탐지: 오류 패턴 · 직전 점검과 신규·해소 비교','manila_log'], ['System','Octavia log','범위: 전날 00:00~오늘 00:00 · 탐지: 오류 패턴 · 직전 점검과 신규·해소 비교','octavia_log'],
    ['System','Masakari log','범위: 전날 로그 · 오류 패턴 탐지 후 직전 점검 대비 신규·해소 비교','masakari_log'], ['System','Swift log','범위: 전날 로그 · 오류 패턴 탐지 후 직전 점검 대비 신규·해소 비교','swift_log'], ['System','Heat log','범위: 전날 로그 · 오류 패턴 탐지 후 직전 점검 대비 신규·해소 비교','heat_log'], ['System','System log','범위: 전날 syslog/messages · 오류 패턴 탐지 후 직전 점검 대비 신규·해소 비교','system_log']
  ]},
  {title:'물리·가상화 인프라 점검', description:'실행 환경을 자동 구분하여 하드웨어, 커널, 네트워크와 하이퍼바이저 상태 확인', items:[
    ['Platform','실행 환경','수집: systemd-detect-virt와 DMI Chassis · 판정: 물리/가상 환경 분류 후 적용 항목 결정','virtualization'], ['System','실패한 시스템 서비스','수집: systemctl --failed · 판정: Failed 상태 Unit 존재 시 주의','failed_units'],
    ['System','커널 오류','수집: dmesg의 err 이상 최근 100행 · 판정: 오류 메시지 존재 시 주의','kernel_errors'], ['Network','물리·가상 인터페이스','수집: ip -br link · 판정: Down/No-carrier 인터페이스 탐지','nic_state'],
    ['Network','Open vSwitch','수집: ovs-vsctl show · 판정: 구성 조회 실패 및 Error/Failed 탐지','ovs_state'], ['Virtualization','CPU 가상화 가속','수집: vmx/svm 플래그와 KVM 모듈 · 판정: Compute 가속 미지원 탐지','kvm_acceleration'],
    ['Virtualization','Libvirt 도메인','수집: virsh list --all · 판정: Shut off/Paused/Crashed 도메인 탐지','libvirt_state'], ['Storage','인스턴스 저장소','수집: nova instances 경로 용량 · 판정: 사용률 80% 이상 주의','instance_storage'],
    ['Hardware','물리 디스크 SMART','수집: 디스크별 smartctl Health · 판정: Failed/Pre-fail 탐지, 가상 환경 제외','smart_health'], ['Hardware','소프트웨어 RAID','수집: mdstat와 mdadm 구성 · 판정: Degraded 멤버 표시 탐지, 가상 환경 제외','raid_health']
  ]},
  {title:'사용자 정의', description:'공급자별로 등록한 읽기 전용 SSH 점검', items:[]}
];
let inspectionResults = {};
let currentExceptionRules = [];
let currentNodeSummary = [];
let currentFilter = 'all';
const collapsedInspectionGroups = new Set();
let allInspectionKeys = inspectionGroups.flatMap(group => group.items.map(item => item[3]));
let selectedInspectionKeys = new Set(allInspectionKeys);
let currentCustomChecks = [];
let activeSetupPanel = '';
function openSetupPanel(name, forceOpen = false) {
  activeSetupPanel = (activeSetupPanel === name && !forceOpen) ? '' : name;
  document.querySelectorAll('[data-setup-panel]').forEach(panel => { panel.hidden = panel.dataset.setupPanel !== activeSetupPanel; });
  document.querySelector('#inspectionSetupPanels').hidden = !activeSetupPanel;
  document.querySelectorAll('.setup-card').forEach(card => { const active = card.dataset.setup === activeSetupPanel; card.classList.toggle('active', active); card.setAttribute('aria-expanded', String(active)); });
}
function renderSetupCards() {
  const set = (id, value) => { const element = document.querySelector(id); if (element) element.textContent = value; };
  const controllers = Number(document.querySelector('#controllerNodeCount')?.textContent) || 0;
  const computes = Number(document.querySelector('#computeNodeCount')?.textContent) || 0;
  set('#setupInventoryValue', `${controllers + computes}대`);
  set('#setupInventoryHint', controllers + computes ? `Controller ${controllers} · Compute ${computes}` : '클러스터 탐색 필요');
  set('#setupSelectionValue', `${selectedInspectionKeys.size} / ${allInspectionKeys.length}`);
  const selectedGroups = inspectionGroups.filter(group => group.items.some(([, , , key]) => selectedInspectionKeys.has(key))).length;
  set('#setupSelectionHint', selectedInspectionKeys.size ? (selectedInspectionKeys.size === allInspectionKeys.length ? '전체 항목 선택' : `${selectedGroups}개 영역 · ${allInspectionKeys.length - selectedInspectionKeys.size}개 제외`) : '선택된 항목 없음');
  const enabledCustom = currentCustomChecks.filter(item => item.enabled).length;
  set('#setupCustomValue', `${currentCustomChecks.length}개`);
  set('#setupCustomHint', currentCustomChecks.length ? `사용 ${enabledCustom} · 중지 ${currentCustomChecks.length - enabledCustom}` : '등록된 항목 없음');
  const nodeRules = currentExceptionRules.filter(rule => rule.node_hostname).length;
  set('#setupExceptionValue', `${currentExceptionRules.length}개`);
  set('#setupExceptionHint', currentExceptionRules.length ? `전체 노드 ${currentExceptionRules.length - nodeRules} · 특정 노드 ${nodeRules}` : '등록된 예외 없음');
  set('#setupScheduleValue', currentSchedule?.enabled ? `매일 ${currentSchedule.run_time}` : '중지');
  set('#setupScheduleHint', currentSchedule?.enabled ? `${currentSchedule.selected_items ? `${currentSchedule.selected_items.length}개 항목` : '전체 항목'} · 다음 ${currentSchedule.next_run_at ? formatDateTime(currentSchedule.next_run_at) : '-'}` : (currentSchedule?.last_run_at ? `마지막 ${formatDateTime(currentSchedule.last_run_at)}` : '예약 없음'));
}
document.querySelector('#inspectionSetupCards').addEventListener('click', event => { const card = event.target.closest('.setup-card'); if (card) openSetupPanel(card.dataset.setup); });
let latestCheckId = null;
let viewingCheckId = null;
let checkHistory = [];
let currentDiff = null;
let currentDiffByKey = {};
let searchQuery = '';
let nodeFilter = '';
let currentSchedule = null;
let progressElapsedTimer = null;
let progressStartedAt = null;
const inspectionStatusLabels = {healthy:'정상', warning:'주의', pending:'수집 대기', unavailable:'확인 불가', skipped:'점검 제외', excepted:'예외 처리'};
const changeLabels = {new_issue:'신규 이상', resolved:'해소', changed:'상태 변경', added:'추가', removed:'제외'};
const dateTimeFormat = new Intl.DateTimeFormat('ko-KR', {dateStyle:'medium', timeStyle:'short'});
function formatDateTime(value) { return value ? dateTimeFormat.format(new Date(value)) : '-'; }
function formatDuration(seconds) {
  const total = Math.max(0, Math.round(Number(seconds) || 0));
  if (!total && seconds == null) return '-';
  const minutes = Math.floor(total / 60), rest = total % 60;
  return minutes ? `${minutes}분 ${rest}초` : `${rest}초`;
}
function itemNameMap() {
  const names = Object.fromEntries(inspectionGroups.flatMap(group => group.items.map(([, name,, key]) => [key, name])));
  names.ssh = 'SSH 연결';
  return names;
}
function itemGroupMap() {
  return Object.fromEntries(inspectionGroups.flatMap(group => group.items.map(([, , , key]) => [key, group.title])));
}

function renderStatusBanner() {
  const banner = document.querySelector('#inspectionStatusBanner');
  const entry = checkHistory.find(item => item.id === (viewingCheckId || latestCheckId)) || checkHistory[0];
  if (!entry) { banner.hidden = true; return; }
  banner.hidden = false;
  const summary = entry.summary || {items:{}, nodes:{}};
  const state = document.querySelector('#bannerState');
  state.className = `banner-state ${entry.status}`;
  state.textContent = entry.status === 'healthy' ? '정상' : '주의';
  const facts = [
    [viewingCheckId ? '조회 결과' : '최근 실행', formatDateTime(entry.checked_at)],
    ['실행 구분', summary.trigger === 'scheduled' ? '예약 실행' : '수동 실행'],
    ['소요 시간', summary.duration_seconds != null ? formatDuration(summary.duration_seconds) : '-'],
    ['점검 항목', `${summary.items?.total ?? 0}개`],
    ['주의', `${summary.items?.warning ?? 0}개`, 'warning'],
    ['확인 불가', `${summary.items?.unavailable ?? 0}개`, 'unavailable'],
    ['노드', `${summary.nodes?.total ?? 0}대 · 문제 ${summary.nodes?.problem ?? 0} · 접속 불가 ${summary.nodes?.unreachable ?? 0}`]
  ];
  document.querySelector('#bannerFacts').innerHTML = facts.map(([label, value, cls]) => `<span class="${cls || ''}"><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong></span>`).join('');
  document.querySelector('#bannerViewing').hidden = !viewingCheckId;
  banner.classList.toggle('viewing', Boolean(viewingCheckId));
}

async function loadCheckHistory(providerId) {
  const list = document.querySelector('#inspectionHistoryList');
  if (!providerId) { checkHistory = []; renderCheckHistory(); renderStatusBanner(); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks?limit=30`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '점검 이력을 불러오지 못했습니다.');
    checkHistory = data.checks;
    if (!latestCheckId && checkHistory.length) latestCheckId = checkHistory[0].id;
    renderCheckHistory();
    renderStatusBanner();
  } catch (error) { list.innerHTML = `<div class="empty-provider">${escapeText(error.message)}</div>`; }
}

function renderCheckHistory() {
  const list = document.querySelector('#inspectionHistoryList');
  document.querySelector('#inspectionHistoryCount').textContent = checkHistory.length;
  if (!checkHistory.length) { list.innerHTML = '<div class="empty-provider">저장된 점검 이력이 없습니다.</div>'; return; }
  const activeId = viewingCheckId || latestCheckId;
  const rows = checkHistory.map((entry, index) => {
    const summary = entry.summary || {items:{}, nodes:{}};
    return `<tr class="${entry.id === activeId ? 'active' : ''}" data-check-id="${entry.id}" tabindex="0"><td><strong>${escapeText(formatDateTime(entry.checked_at))}</strong>${index === 0 ? '<i class="history-latest">최신</i>' : ''}</td><td><span class="check-state ${entry.status}">${entry.status === 'healthy' ? '정상' : '주의'}</span></td><td>${summary.trigger === 'scheduled' ? '예약' : '수동'}</td><td>${summary.items?.total ?? 0}</td><td class="warning-text">${summary.items?.warning ?? 0}</td><td class="unavailable-text">${summary.items?.unavailable ?? 0}</td><td>${summary.nodes?.problem ?? 0} / ${summary.nodes?.total ?? 0}</td><td>${summary.duration_seconds != null ? escapeText(formatDuration(summary.duration_seconds)) : '-'}</td><td><button type="button" data-view-check="${entry.id}">${entry.id === activeId ? '조회 중' : '결과 보기'}</button></td></tr>`;
  }).join('');
  list.innerHTML = `<div class="inspection-history-table"><table><thead><tr><th>실행 시각</th><th>상태</th><th>구분</th><th>항목</th><th>주의</th><th>확인 불가</th><th>문제 노드</th><th>소요</th><th></th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

async function loadCheckDiff(providerId, checkId) {
  currentDiff = null; currentDiffByKey = {};
  if (!providerId || !checkId) { renderDiffSummary(); renderSummaryDeltas(); renderInspectionChecklist(); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks/${encodeURIComponent(checkId)}/diff`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '변화 내역을 불러오지 못했습니다.');
    currentDiff = data;
    currentDiffByKey = Object.fromEntries((data.items || []).map(item => [item.key, item]));
  } catch (error) { showToast('변화 내역을 불러오지 못했습니다.', error.message); }
  renderDiffSummary();
  renderSummaryDeltas();
  renderInspectionChecklist();
}

function renderDiffSummary() {
  const box = document.querySelector('#inspectionDiff');
  if (!currentDiff) { box.innerHTML = '<div class="empty-provider">점검을 실행하면 직전 점검과의 변화를 표시합니다.</div>'; return; }
  if (!currentDiff.previous) { box.innerHTML = '<div class="empty-provider">비교할 이전 점검이 없습니다. 다음 점검부터 변화를 표시합니다.</div>'; return; }
  const names = itemNameMap();
  const groups = [['new_issue', 'new'], ['resolved', 'resolved'], ['changed', 'changed'], ['added', 'added'], ['removed', 'removed']];
  const chips = groups.map(([type, cls]) => {
    const list = currentDiff.items.filter(item => item.change === type);
    if (!list.length) return '';
    return `<div class="diff-group ${cls}"><b>${changeLabels[type]} ${list.length}</b><div>${list.map(item => `<button type="button" data-diff-key="${escapeText(item.key)}" title="${escapeText(inspectionStatusLabels[item.before] || '없음')} → ${escapeText(inspectionStatusLabels[item.after] || '없음')}">${escapeText(names[item.key] || item.key)}<em>${escapeText(inspectionStatusLabels[item.before] || '없음')} → ${escapeText(inspectionStatusLabels[item.after] || '없음')}</em></button>`).join('')}</div></div>`;
  }).join('');
  const nodeLabels = {problem:'문제', review:'확인 필요', healthy:'정상'};
  const nodes = currentDiff.nodes.map(node => `<span class="diff-node ${escapeText(node.after || 'healthy')}"><strong>${escapeText(node.hostname)}</strong><em>${escapeText(nodeLabels[node.before] || '없음')} → ${escapeText(nodeLabels[node.after] || '없음')}</em>${node.new_items.length ? `<b class="up">+${node.new_items.length}</b>` : ''}${node.resolved_items.length ? `<b class="down">−${node.resolved_items.length}</b>` : ''}</span>`).join('');
  const counts = currentDiff.counts || {};
  const noChange = !currentDiff.items.length && !currentDiff.nodes.length;
  box.innerHTML = `<div class="diff-heading"><div><strong>직전 점검 대비 변화</strong><small>${escapeText(formatDateTime(currentDiff.previous.checked_at))} → ${escapeText(formatDateTime(currentDiff.current.checked_at))}</small></div><div class="diff-counts"><span class="new">신규 이상 ${counts.new_issue || 0}</span><span class="resolved">해소 ${counts.resolved || 0}</span><span>상태 변경 ${counts.changed || 0}</span><span>노드 변화 ${currentDiff.nodes.length}</span></div></div>${noChange ? '<div class="diff-empty">직전 점검과 동일한 결과입니다.</div>' : `<div class="diff-groups">${chips}</div>${nodes ? `<div class="diff-nodes"><b>노드별 변화</b>${nodes}</div>` : ''}`}`;
}

function renderSummaryDeltas() {
  const counts = currentDiff?.previous ? currentDiff.counts : null;
  const apply = (id, value) => {
    const element = document.querySelector(id);
    if (!element) return;
    if (counts == null || value == null) { element.hidden = true; return; }
    element.hidden = false;
    element.className = `summary-delta ${value > 0 ? 'up' : (value < 0 ? 'down' : 'same')}`;
    element.textContent = value === 0 ? '직전과 동일' : `직전 대비 ${value > 0 ? '+' : ''}${value}`;
  };
  apply('#totalDelta', counts ? (counts.added || 0) - (counts.removed || 0) : null);
  apply('#healthyDelta', counts ? counts.healthy_delta : null);
  apply('#warningDelta', counts ? counts.warning_delta : null);
  apply('#unavailableDelta', counts ? counts.unavailable_delta : null);
  apply('#pendingDelta', null);
}

async function viewCheck(providerId, checkId) {
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks/${encodeURIComponent(checkId)}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '점검 결과를 불러오지 못했습니다.');
    viewingCheckId = checkId === latestCheckId ? null : checkId;
    nodeFilter = '';
    renderInspectionResult({...data.check.result, status:data.check.status, _checked_at:data.check.checked_at});
    renderCheckHistory();
    renderStatusBanner();
    await loadCheckDiff(providerId, checkId);
    document.querySelector('#inspectionStatusBanner').scrollIntoView({behavior:'smooth', block:'start'});
  } catch (error) { showToast('점검 결과를 불러오지 못했습니다.', error.message); }
}

function focusInspectionItem(key) {
  if (!selectedInspectionKeys.has(key)) return showToast('선택되지 않은 항목입니다.', '항목 선택 패널에서 해당 항목을 선택하면 결과를 볼 수 있습니다.');
  const status = (inspectionResults[key] || {status:'pending'}).status;
  let changed = false;
  if (!inspectionStatusMatches(currentFilter, status)) { currentFilter = 'all'; changed = true; }
  if (searchQuery) { searchQuery = ''; document.querySelector('#inspectionSearch').value = ''; document.querySelector('#clearInspectionSearch').hidden = true; changed = true; }
  if (nodeFilter && !nodeFilterKeys()?.has(key)) { nodeFilter = ''; changed = true; }
  if (changed) setInspectionFilter(currentFilter); else collapsedInspectionGroups.clear(), renderInspectionChecklist();
  const row = document.querySelector(`.inspection-row[data-key="${CSS.escape(key)}"]`);
  if (!row) return;
  const detail = document.getElementById(row.dataset.detailId);
  if (detail?.hidden) toggleInspectionDetail(row);
  row.scrollIntoView({behavior:'smooth', block:'center'});
  row.classList.add('highlight');
  setTimeout(() => row.classList.remove('highlight'), 2200);
}

function nodeFilterKeys() {
  if (!nodeFilter) return null;
  const node = currentNodeSummary.find(item => item.hostname === nodeFilter);
  if (!node) return null;
  const isExcepted = key => currentExceptionRules.some(rule => rule.item_key === key && (!rule.node_hostname || rule.node_hostname === node.hostname));
  return new Set([...(node.problem_items || []), ...(node.review_items || [])].filter(key => key !== 'ssh' && !isExcepted(key)));
}

function renderNodeFilterChip() {
  const chip = document.querySelector('#nodeFilterChip');
  const keys = nodeFilterKeys();
  chip.hidden = !nodeFilter;
  if (nodeFilter) chip.innerHTML = `<b>${escapeText(nodeFilter)}</b> 관련 항목 ${keys ? keys.size : 0}개만 표시 <span aria-hidden="true">×</span>`;
  document.querySelectorAll('.node-summary-card').forEach(card => card.classList.toggle('active', card.dataset.nodeFilter === nodeFilter));
}

function setNodeFilter(hostname) {
  nodeFilter = nodeFilter === hostname ? '' : hostname;
  collapsedInspectionGroups.clear();
  renderInspectionChecklist();
  if (nodeFilter) document.querySelector('#inspectionChecklist').scrollIntoView({behavior:'smooth', block:'start'});
}

function inspectionItemMatchesSearch(category, name, method, key, result) {
  if (!searchQuery) return true;
  const query = searchQuery.toLowerCase();
  return [category, name, method, key, result.note, result.result].some(value => String(value || '').toLowerCase().includes(query));
}

function copyToClipboard(text) {
  if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
  return new Promise((resolve, reject) => {
    const area = document.createElement('textarea');
    area.value = text; area.setAttribute('readonly', ''); area.style.position = 'fixed'; area.style.opacity = '0';
    document.body.appendChild(area); area.select();
    try { document.execCommand('copy') ? resolve() : reject(new Error('복사 명령이 거부되었습니다.')); } catch (error) { reject(error); } finally { area.remove(); }
  });
}

function inspectionReportRows() {
  return inspectionGroups.flatMap(group => group.items.filter(([, , , key]) => selectedInspectionKeys.has(key)).map(([category, name, method, key]) => {
    const result = inspectionResults[key] || {status:'pending', result:'-', note:'점검 실행 필요'};
    return {group:group.title, category, name, method, key, status:result.status, note:result.note || '', result:result.result || '', change:changeLabels[currentDiffByKey[key]?.change] || ''};
  }));
}

function openInspectionReport() {
  if (!Object.keys(inspectionResults).length) return showToast('표시할 점검 내용이 없습니다.', '일일점검을 먼저 실행하세요.');
  const rows = inspectionReportRows();
  const entry = checkHistory.find(item => item.id === (viewingCheckId || latestCheckId));
  const provider = inspectionProviderSelect.options[inspectionProviderSelect.selectedIndex]?.textContent || '-';
  const counts = rows.reduce((acc, row) => { acc[row.status] = (acc[row.status] || 0) + 1; return acc; }, {});
  document.querySelector('#inspectionReportMeta').textContent = `${provider} · ${entry ? formatDateTime(entry.checked_at) : '최근 결과'}${entry?.summary?.trigger === 'scheduled' ? ' · 예약 실행' : ''}${entry?.summary?.duration_seconds != null ? ` · 소요 ${formatDuration(entry.summary.duration_seconds)}` : ''}`;
  document.querySelector('#inspectionReportSummary').innerHTML = [['전체', rows.length, ''], ['정상', (counts.healthy || 0) + (counts.excepted || 0), 'healthy'], ['주의', counts.warning || 0, 'warning'], ['확인 불가', counts.unavailable || 0, 'unavailable'], ['수집 대기·제외', (counts.pending || 0) + (counts.skipped || 0), 'pending']]
    .map(([label, value, cls]) => `<span class="${cls}"><small>${label}</small><strong>${value}</strong></span>`).join('');
  const groups = inspectionGroups.filter(group => rows.some(row => row.group === group.title));
  document.querySelector('#inspectionReportBody').innerHTML = groups.map((group, index) => {
    const groupRows = rows.filter(row => row.group === group.title);
    return `<article><h3><span>${index + 1}</span>${escapeText(group.title)}<small>${groupRows.length}개 항목</small></h3><table><thead><tr><th>점검 분류</th><th>점검 사항</th><th>상태</th><th>점검 결과</th><th>특이사항</th><th>직전 대비</th></tr></thead><tbody>${groupRows.map(row => `<tr class="${escapeText(row.status)}"><td>${escapeText(row.category)}</td><td><strong>${escapeText(row.name)}</strong><small>${escapeText(row.method)}</small></td><td><span class="check-state ${escapeText(row.status)}">${inspectionStatusLabels[row.status] || row.status}</span></td><td>${escapeText(row.result)}</td><td>${escapeText(row.note)}</td><td>${escapeText(row.change || '-')}</td></tr>`).join('')}</tbody></table></article>`;
  }).join('');
  const overlay = document.querySelector('#inspectionReportOverlay');
  overlay.hidden = false;
  document.body.classList.add('report-open');
  overlay.querySelector('.inspection-report').scrollTop = 0;
  document.querySelector('#closeInspectionReport').focus();
}

function closeInspectionReport() {
  document.querySelector('#inspectionReportOverlay').hidden = true;
  document.body.classList.remove('report-open');
}

async function downloadInspectionReportPdf() {
  const rows = inspectionReportRows();
  if (!rows.length) return showToast('PDF로 저장할 점검 내용이 없습니다.', '일일점검을 먼저 실행하세요.');
  const button = document.querySelector('#downloadInspectionReportPdf');
  const entry = checkHistory.find(item => item.id === (viewingCheckId || latestCheckId));
  const provider = inspectionProviderSelect.options[inspectionProviderSelect.selectedIndex]?.textContent || '-';
  const checkedAt = entry ? new Date(entry.checked_at) : new Date();
  const payload = {
    provider,
    checked_at: entry ? formatDateTime(entry.checked_at) : '최근 결과',
    trigger: entry?.summary?.trigger || null,
    duration_seconds: entry?.summary?.duration_seconds ?? null,
    groups: inspectionGroups.map(group => ({title:group.title, rows:rows.filter(row => row.group === group.title).map(row => ({category:row.category, name:row.name, method:row.method, status:row.status, result:row.result || '', note:row.note || '', change:row.change || ''}))})).filter(group => group.rows.length),
  };
  const stamp = `${checkedAt.getFullYear()}${String(checkedAt.getMonth() + 1).padStart(2, '0')}${String(checkedAt.getDate()).padStart(2, '0')}-${String(checkedAt.getHours()).padStart(2, '0')}${String(checkedAt.getMinutes()).padStart(2, '0')}`;
  const fileName = `일일점검_${provider.replace(/[\\/:*?"<>|\s]+/g, '_')}_${stamp}.pdf`;
  button.disabled = true; button.textContent = 'PDF 생성 중…';
  try {
    const response = await fetch('/api/reports/inspection.pdf', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    if (!response.ok) { const data = await response.json().catch(() => ({})); throw new Error(typeof data.detail === 'string' ? data.detail : `서버 오류 (${response.status})`); }
    const url = URL.createObjectURL(await response.blob());
    const link = document.createElement('a'); link.href = url; link.download = fileName; document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
    showToast('PDF를 저장했습니다.', `${fileName} · ${rows.length}개 항목`);
  } catch (error) { showToast('PDF 저장에 실패했습니다.', error.message); } finally { button.disabled = false; button.textContent = 'PDF 저장'; }
}

function applyInspectionPreset(preset) {
  const logKeys = new Set(allInspectionKeys.filter(key => key.endsWith('_log')));
  if (preset === 'quick') {
    const quickGroups = new Set(['시스템 기본 점검', 'Middleware 점검', 'OpenStack 서비스 점검', 'OpenStack 리소스 점검']);
    selectedInspectionKeys = new Set(inspectionGroups.filter(group => quickGroups.has(group.title)).flatMap(group => group.items.map(item => item[3])));
  } else if (preset === 'nologs') {
    selectedInspectionKeys = new Set(allInspectionKeys.filter(key => !logKeys.has(key)));
  } else if (preset === 'issues') {
    const issues = allInspectionKeys.filter(key => ['warning', 'unavailable'].includes(inspectionResults[key]?.status));
    if (!issues.length) return showToast('재점검할 이상 항목이 없습니다.', '최근 결과에 주의 또는 확인 불가 항목이 없습니다.');
    selectedInspectionKeys = new Set(issues);
  }
  renderInspectionSelection();
  renderInspectionChecklist();
  showToast(`${selectedInspectionKeys.size}개 항목을 선택했습니다.`, '전체 점검 실행 버튼으로 선택한 항목만 점검합니다.');
}

function updateProgressElapsed() {
  const element = document.querySelector('#inspectionProgressElapsed');
  if (!progressStartedAt) { element.hidden = true; return; }
  element.hidden = false;
  element.textContent = `경과 ${formatDuration((Date.now() - progressStartedAt) / 1000)}`;
}

async function loadCheckSchedule(providerId) {
  const info = document.querySelector('#scheduleInfo');
  currentSchedule = null;
  if (!providerId) { info.innerHTML = '<span>공급자를 선택하세요.</span>'; renderSchedule(); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/check-schedule`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '예약 정보를 불러오지 못했습니다.');
    currentSchedule = data;
  } catch (error) { info.innerHTML = `<span>${escapeText(error.message)}</span>`; }
  renderSchedule();
}

function renderSchedule() {
  const state = document.querySelector('#scheduleState');
  const select = document.querySelector('#scheduleItems');
  const schedule = currentSchedule;
  document.querySelector('#scheduleEnabled').checked = Boolean(schedule?.enabled);
  document.querySelector('#scheduleTime').value = schedule?.run_time || '09:00';
  const savedCount = schedule?.selected_items?.length;
  select.innerHTML = `${savedCount ? `<option value="saved">저장된 항목 (${savedCount}개)</option>` : ''}<option value="current">현재 선택한 항목 (${selectedInspectionKeys.size}개)</option><option value="all">전체 항목</option>`;
  select.value = savedCount ? 'saved' : (schedule && schedule.selected_items === null && schedule.updated_at ? 'all' : 'current');
  state.textContent = schedule?.enabled ? `매일 ${schedule.run_time}` : '중지';
  state.classList.toggle('enabled', Boolean(schedule?.enabled));
  if (!schedule) { renderSetupCards(); return; }
  const next = schedule.enabled && schedule.next_run_at ? schedule.next_run_at : null;
  const lastLabels = {healthy:'정상', warning:'주의', failed:'실패', running:'실행 중'};
  const facts = [
    ['다음 실행', next ? formatDateTime(next) : '예약 중지'],
    ['마지막 예약 실행', schedule.last_run_at ? `${formatDateTime(schedule.last_run_at)} · ${lastLabels[schedule.last_status] || schedule.last_status || '-'}` : '없음'],
    ['기준 시간', schedule.server_time ? `${formatDateTime(schedule.server_time)} (${schedule.timezone || '서버'})` : '-']
  ];
  document.querySelector('#scheduleInfo').innerHTML = facts.map(([label, value]) => `<span><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong></span>`).join('') + (schedule.last_error ? `<span class="schedule-error"><small>마지막 오류</small><strong>${escapeText(schedule.last_error)}</strong></span>` : '');
  renderSetupCards();
}

document.querySelector('#scheduleForm').addEventListener('submit', async event => {
  event.preventDefault();
  const providerId = inspectionProviderSelect.value;
  if (!providerId) return showToast('공급자를 먼저 선택하세요.', '예약은 공급자별로 저장됩니다.');
  const mode = document.querySelector('#scheduleItems').value;
  const selected = mode === 'all' ? null : (mode === 'saved' ? currentSchedule?.selected_items : [...selectedInspectionKeys]);
  const payload = {enabled:document.querySelector('#scheduleEnabled').checked, run_time:document.querySelector('#scheduleTime').value, selected_items:selected};
  if (payload.enabled && selected && !selected.length) return showToast('점검 항목을 선택하세요.', '예약 실행할 항목이 없습니다.');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/check-schedule`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '예약 저장에 실패했습니다.');
    currentSchedule = data; renderSchedule();
    showToast(data.enabled ? `매일 ${data.run_time}에 자동 실행합니다.` : '예약 실행을 중지했습니다.', data.enabled ? `${data.selected_items ? `${data.selected_items.length}개 항목` : '전체 항목'} · 서버 시간 기준` : '필요할 때 다시 활성화할 수 있습니다.');
  } catch (error) { showToast('예약 저장에 실패했습니다.', error.message); }
});

document.querySelector('#inspectionHistoryList').addEventListener('click', event => {
  const button = event.target.closest('[data-view-check]');
  const row = event.target.closest('tr[data-check-id]');
  const checkId = button?.dataset.viewCheck || row?.dataset.checkId;
  if (checkId && inspectionProviderSelect.value) viewCheck(inspectionProviderSelect.value, checkId);
});
document.querySelector('#inspectionHistoryList').addEventListener('keydown', event => {
  if ((event.key === 'Enter' || event.key === ' ') && event.target.matches('tr[data-check-id]')) { event.preventDefault(); viewCheck(inspectionProviderSelect.value, event.target.dataset.checkId); }
});
document.querySelector('#returnToLatest').addEventListener('click', () => { if (inspectionProviderSelect.value) loadLatestCheck(inspectionProviderSelect.value); });
document.querySelector('#inspectionDiff').addEventListener('click', event => {
  const chip = event.target.closest('[data-diff-key]');
  if (chip) focusInspectionItem(chip.dataset.diffKey);
});
document.querySelector('#nodeCheckSummary').addEventListener('click', event => {
  const chip = event.target.closest('[data-node-item]');
  if (chip) {
    event.stopPropagation();
    if (nodeFilter !== chip.dataset.nodeHost) setNodeFilter(chip.dataset.nodeHost);
    focusInspectionItem(chip.dataset.nodeItem);
    return;
  }
  const card = event.target.closest('[data-node-filter]');
  if (card) setNodeFilter(card.dataset.nodeFilter);
});
document.querySelector('#nodeCheckSummary').addEventListener('keydown', event => {
  if ((event.key === 'Enter' || event.key === ' ') && event.target.matches('[data-node-filter]')) { event.preventDefault(); setNodeFilter(event.target.dataset.nodeFilter); }
});
document.querySelector('#nodeFilterChip').addEventListener('click', () => setNodeFilter(nodeFilter));
const inspectionSearchInput = document.querySelector('#inspectionSearch');
let searchDebounce = null;
inspectionSearchInput.addEventListener('input', () => {
  window.clearTimeout(searchDebounce);
  searchDebounce = window.setTimeout(() => { searchQuery = inspectionSearchInput.value.trim(); document.querySelector('#clearInspectionSearch').hidden = !searchQuery; collapsedInspectionGroups.clear(); renderInspectionChecklist(); }, 150);
});
inspectionSearchInput.addEventListener('keydown', event => { if (event.key === 'Escape') { inspectionSearchInput.value = ''; inspectionSearchInput.dispatchEvent(new Event('input')); } });
document.querySelector('#clearInspectionSearch').addEventListener('click', () => { inspectionSearchInput.value = ''; inspectionSearchInput.dispatchEvent(new Event('input')); inspectionSearchInput.focus(); });
document.addEventListener('keydown', event => {
  if (event.key === '/' && !event.ctrlKey && !event.metaKey && !event.altKey && !document.querySelector('#inspectionPage').hidden && !['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName)) { event.preventDefault(); inspectionSearchInput.focus(); }
});
document.querySelector('#expandInspectionGroups').addEventListener('click', () => { collapsedInspectionGroups.clear(); renderInspectionChecklist(); });
document.querySelector('#collapseInspectionGroups').addEventListener('click', () => { inspectionGroups.forEach((group, index) => { if (group.items.length) collapsedInspectionGroups.add(index); }); renderInspectionChecklist(); });
document.querySelector('#openInspectionReport').addEventListener('click', openInspectionReport);
document.querySelector('#closeInspectionReport').addEventListener('click', closeInspectionReport);
document.querySelector('#downloadInspectionReportPdf').addEventListener('click', downloadInspectionReportPdf);
document.querySelector('#inspectionReportOverlay').addEventListener('click', event => { if (event.target.id === 'inspectionReportOverlay') closeInspectionReport(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape' && !document.querySelector('#inspectionReportOverlay').hidden) closeInspectionReport(); });
document.querySelector('#presetQuickInspections').addEventListener('click', () => applyInspectionPreset('quick'));
document.querySelector('#presetNoLogInspections').addEventListener('click', () => applyInspectionPreset('nologs'));
document.querySelector('#presetIssueInspections').addEventListener('click', () => applyInspectionPreset('issues'));
document.querySelector('#inspectionChecklist').addEventListener('click', async event => {
  const action = event.target.closest('[data-row-action]');
  if (!action) return;
  event.stopPropagation();
  const key = action.dataset.key;
  const names = itemNameMap();
  if (action.dataset.rowAction === 'exception') {
    exceptionItem.value = key; exceptionNode.value = nodeFilter && [...exceptionNode.options].some(option => option.value === nodeFilter) ? nodeFilter : ''; exceptionReason.value = '';
    openSetupPanel('exceptions', true);
    document.querySelector('.inspection-exceptions').scrollIntoView({behavior:'smooth', block:'start'});
    setTimeout(() => exceptionReason.focus(), 350);
    showToast(`${names[key] || key} 예외 등록`, '예외 사유를 입력한 뒤 예외 등록 버튼을 누르세요.');
  } else if (action.dataset.rowAction === 'copy') {
    const detail = document.getElementById(action.dataset.detailId);
    const text = [...detail.querySelectorAll('.inspection-raw-output article')].map(article => `## ${article.querySelector('strong')?.textContent || ''}\n${article.querySelector('pre')?.textContent || ''}`).join('\n\n');
    try { await copyToClipboard(text); showToast('상세 결과를 복사했습니다.', `${names[key] || key} 원본 출력`); } catch (error) { showToast('복사에 실패했습니다.', error.message); }
  } else if (action.dataset.rowAction === 'alerts') {
    document.querySelector('#alertSearch').value = names[key] || key;
    document.querySelector('#alertProviderFilter').value = inspectionProviderSelect.value;
    history.replaceState(null, '', '#alerts'); showPage('alerts'); loadAlerts();
  }
});
function refreshInspectionDefinitions() {
  allInspectionKeys = inspectionGroups.flatMap(group => group.items.map(item => item[3]));
  exceptionItem.innerHTML = inspectionGroups.filter(group => group.items.length).map(group => `<optgroup label="${escapeText(group.title)}">${group.items.map(([, name,, key]) => `<option value="${key}">${escapeText(name)}</option>`).join('')}</optgroup>`).join('');
}
refreshInspectionDefinitions();

const customTargetLabels = {all:'전체 노드', controller:'Controller', compute:'Compute', active_controller:'활성 Controller'};
const customRuleLabels = {exit_code:'종료 코드 0', contains:'문자열 포함 시 정상', not_contains:'문자열 포함 시 주의'};
async function loadCustomChecks(providerId) {
  const list = document.querySelector('#customCheckList');
  if (!providerId) { currentCustomChecks = []; inspectionGroups.at(-1).items = []; list.innerHTML = '<div class="empty-provider">공급자를 선택하세요.</div>'; refreshInspectionDefinitions(); renderInspectionSelection(); renderInspectionChecklist(); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/custom-checks`, {cache:'no-store'});
    const data = await response.json(); if (!response.ok) throw new Error(data.detail || '목록 조회 실패');
    const oldKeys = new Set(currentCustomChecks.map(item => item.key));
    currentCustomChecks = data.checks;
    inspectionGroups.at(-1).items = data.checks.filter(item => item.enabled).map(item => ['Custom', item.name, `대상: ${customTargetLabels[item.target_role]} · 환경: ${item.execution_context === 'openstack' ? 'OpenStack 인증' : '일반 SSH'} · 판정: ${customRuleLabels[item.rule_type]}`, item.key]);
    data.checks.filter(item => item.enabled && !oldKeys.has(item.key)).forEach(item => selectedInspectionKeys.add(item.key));
    [...selectedInspectionKeys].filter(key => key.startsWith('custom:') && !data.checks.some(item => item.key === key && item.enabled)).forEach(key => selectedInspectionKeys.delete(key));
    refreshInspectionDefinitions(); renderInspectionSelection(); renderInspectionChecklist();
    list.innerHTML = data.checks.length ? data.checks.map(item => `<article class="${item.enabled ? '' : 'disabled'}"><div><strong>${escapeText(item.name)}</strong><small>${escapeText(customTargetLabels[item.target_role])} · ${item.execution_context === 'openstack' ? 'OpenStack 인증' : '일반 SSH'} · ${escapeText(customRuleLabels[item.rule_type])}</small><code>${escapeText(item.command)}</code></div><span>${item.enabled ? '사용' : '중지'}</span><button type="button" data-custom-edit="${item.id}">수정</button><button class="danger" type="button" data-custom-delete="${item.id}">삭제</button></article>`).join('') : '<div class="empty-provider">등록된 사용자 정의 점검이 없습니다.</div>';
  } catch (error) { list.innerHTML = `<div class="empty-provider">${escapeText(error.message)}</div>`; }
  renderSetupCards();
}

menuButton.addEventListener('click', () => sidebar.classList.toggle('open'));
sidebar.addEventListener('click', event => {
  if (event.target === sidebar && sidebar.classList.contains('open')) sidebar.classList.remove('open');
});

async function executeInspection(sourceButton, selectedProvider) {
  if (!selectedProvider) return showToast('공급자를 먼저 선택하세요.', '공급자 연결 메뉴에서 환경을 등록할 수 있습니다.');
  if (!selectedInspectionKeys.size) return showToast('점검 항목을 선택하세요.', '하나 이상의 항목을 선택해야 합니다.');
  sourceButton.disabled = true;
  sourceButton.innerHTML = '<span>↻</span> 점검 실행 중';
  showInspectionProgress({running:true, stage:'preparing', message:'점검 요청을 준비하고 있습니다.', current_items:[...selectedInspectionKeys], percent:3, started_at:new Date().toISOString()});
  const progressTimer = window.setInterval(() => loadInspectionProgress(selectedProvider), 700);
  let inspectionSucceeded = false;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(selectedProvider)}/checks`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({selected_items:[...selectedInspectionKeys]})});
    const data = await response.json();
    if (!response.ok) { const error = new Error(data.detail || '점검 실행에 실패했습니다.'); error.status = response.status; throw error; }
    latestCheckId = data.check_id; viewingCheckId = null; nodeFilter = '';
    renderCheck(data);
    renderInspectionResult({...data, _checked_at:data.finished_at});
    renderInfrastructure(data);
    inspectionSucceeded = true;
    loadAlertSummary();
    loadCheckHistory(selectedProvider);
    loadCheckDiff(selectedProvider, data.check_id);
    loadCheckSchedule(selectedProvider);
    showToast('일일점검이 완료되었습니다.', data.status === 'healthy' ? '현재 확인된 경고가 없습니다.' : `${data.warnings.length}개 경고를 확인하세요.`);
  } catch (error) {
    if (error.status === 409) {
      showToast('이미 점검이 실행 중입니다.', '진행 중인 점검을 따라가며 완료되면 결과를 불러옵니다.');
      await followRunningInspection(selectedProvider);
      inspectionSucceeded = true;
    } else {
      showInspectionProgress({running:false, stage:'failed', message:`점검 실패: ${error.message}`, current_items:[], percent:0});
      showToast('일일점검에 실패했습니다.', error.message);
    }
  } finally {
    window.clearInterval(progressTimer);
    if (inspectionSucceeded) await loadInspectionProgress(selectedProvider);
    sourceButton.disabled = false;
    sourceButton.innerHTML = sourceButton === dailyRunInspection ? '<span>↻</span> 전체 점검 실행' : '<span>↻</span> 일일점검 실행';
  }
}

async function followRunningInspection(providerId) {
  for (let attempt = 0; attempt < 1800; attempt += 1) {
    await new Promise(resolve => setTimeout(resolve, 1000));
    try {
      const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks/progress`, {cache:'no-store'});
      if (!response.ok) continue;
      const progress = await response.json();
      showInspectionProgress(progress);
      if (!progress.running) { if (progress.stage === 'completed') await loadLatestCheck(providerId); return; }
    } catch (_) { /* keep polling */ }
  }
}

async function loadInspectionProgress(providerId) {
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks/progress`, {cache:'no-store'});
    if (!response.ok) return;
    showInspectionProgress(await response.json());
  } catch (_) { /* The main check request reports connection errors. */ }
}

function showInspectionProgress(progress) {
  const panel = document.querySelector('#inspectionProgress');
  const stageLabels = {idle:'대기', preparing:'준비', nodes:'노드 점검', custom:'사용자 정의', openstack:'OpenStack 점검', aggregating:'결과 집계', completed:'완료', failed:'실패'};
  const percent = Math.max(0, Math.min(100, Number(progress.percent) || 0));
  panel.hidden = false;
  panel.classList.toggle('completed', !progress.running && progress.stage === 'completed');
  panel.classList.toggle('failed', progress.stage === 'failed');
  document.querySelector('#inspectionProgressStage').textContent = stageLabels[progress.stage] || '진행 중';
  document.querySelector('#inspectionProgressMessage').textContent = progress.message || '점검 진행 상태를 확인하고 있습니다.';
  document.querySelector('#inspectionProgressPercent').textContent = `${percent}%`;
  const track = document.querySelector('.inspection-progress-track');
  track.setAttribute('aria-valuenow', String(percent));
  document.querySelector('#inspectionProgressBar').style.width = `${percent}%`;
  const items = document.querySelector('#inspectionProgressItems');
  const names = itemNameMap();
  const currentItems = progress.running ? (progress.current_items || []) : [];
  items.hidden = !currentItems.length;
  if (currentItems.length) items.innerHTML = `<b>${progress.stage === 'nodes' ? '노드에서 수집 중' : '진행 항목'} ${currentItems.length}개</b>${currentItems.slice(0, 12).map(key => `<span>${escapeText(names[key] || key)}</span>`).join('')}${currentItems.length > 12 ? `<span class="more">외 ${currentItems.length - 12}개</span>` : ''}`;
  if (progress.running) {
    progressStartedAt = progress.started_at ? new Date(progress.started_at).getTime() : (progressStartedAt || Date.now());
    if (!progressElapsedTimer) progressElapsedTimer = window.setInterval(updateProgressElapsed, 1000);
  } else {
    window.clearInterval(progressElapsedTimer); progressElapsedTimer = null;
    if (progress.stage === 'completed' && progress.started_at) { progressStartedAt = new Date(progress.started_at).getTime(); updateProgressElapsed(); document.querySelector('#inspectionProgressElapsed').textContent = `소요 ${formatDuration((new Date(progress.updated_at || Date.now()).getTime() - progressStartedAt) / 1000)}`; }
    else document.querySelector('#inspectionProgressElapsed').hidden = true;
    progressStartedAt = null;
    return;
  }
  updateProgressElapsed();
}

runInspection.addEventListener('click', () => executeInspection(runInspection, providerSelect.value));
dailyRunInspection.addEventListener('click', () => executeInspection(dailyRunInspection, inspectionProviderSelect.value));

async function loadProviders() {
  try {
    const response = await fetch('/api/providers');
    const data = await response.json();
    const requested = new URLSearchParams(location.search).get('provider');
    data.providers.forEach(provider => {
      if (providerSelect.querySelector(`option[value="${provider.id}"]`)) return;
      const option = document.createElement('option');
      option.value = provider.id;
      option.textContent = `${provider.name} (${provider.vip})`;
      providerSelect.appendChild(option);
      inspectionProviderSelect.appendChild(option.cloneNode(true));
      infrastructureProviderSelect.appendChild(option.cloneNode(true));
      if (!alertProviderFilter.querySelector(`option[value="${provider.id}"]`)) alertProviderFilter.appendChild(option.cloneNode(true));
      if (!historyProvider.querySelector(`option[value="${provider.id}"]`)) historyProvider.appendChild(option.cloneNode(true));
      if (!historyProviderFilter.querySelector(`option[value="${provider.id}"]`)) historyProviderFilter.appendChild(option.cloneNode(true));
    });
    if (requested && data.providers.some(provider => provider.id === requested)) providerSelect.value = requested;
    else if (data.providers.length) providerSelect.value = data.providers[0].id;
    inspectionProviderSelect.value = providerSelect.value;
    infrastructureProviderSelect.value = providerSelect.value;
    if (inspectionProviderSelect.value) {
      loadProviderNodes(inspectionProviderSelect.value);
      loadCheckExceptions(inspectionProviderSelect.value);
      loadCustomChecks(inspectionProviderSelect.value);
      loadLatestCheck(inspectionProviderSelect.value);
    }
  } catch (error) { showToast('공급자 목록을 불러오지 못했습니다.', error.message || '서버 연결 상태를 확인하세요.'); }
}

async function loadLatestCheck(providerId) {
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/latest-check`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '최근 점검 결과를 불러오지 못했습니다.');
    viewingCheckId = null; nodeFilter = '';
    if (data.latest_check) {
      latestCheckId = data.latest_check.id;
      const latest = {...data.latest_check.result, status:data.latest_check.status, _checked_at:data.latest_check.checked_at};
      renderCheck(latest);
      renderInspectionResult(latest);
      renderInfrastructure(latest);
      loadInfrastructureMetrics(providerId);
      loadCheckDiff(providerId, data.latest_check.id);
    } else {
      latestCheckId = null; inspectionResults = {}; currentDiff = null; currentDiffByKey = {};
      renderNodeCheckSummary([]); renderDiffSummary(); renderSummaryDeltas(); renderInspectionChecklist();
      document.querySelector('#inspectionUpdatedAt').textContent = '아직 실행된 점검이 없습니다.';
      exportInspectionPdf.disabled = true; document.querySelector('#openInspectionReport').disabled = true;
    }
    loadCheckHistory(providerId);
    loadCheckSchedule(providerId);
  } catch (error) { showToast('최근 점검 결과를 불러오지 못했습니다.', error.message); }
}

providerSelect.addEventListener('change', () => {
  inspectionProviderSelect.value = providerSelect.value;
  infrastructureProviderSelect.value = providerSelect.value;
  if (providerSelect.value) loadProviderNodes(providerSelect.value);
  loadCheckExceptions(providerSelect.value);
  loadCustomChecks(providerSelect.value);
  if (providerSelect.value) loadLatestCheck(providerSelect.value);
});
inspectionProviderSelect.addEventListener('change', () => {
  providerSelect.value = inspectionProviderSelect.value;
  infrastructureProviderSelect.value = inspectionProviderSelect.value;
  loadProviderNodes(inspectionProviderSelect.value);
  loadCheckExceptions(inspectionProviderSelect.value);
  loadCustomChecks(inspectionProviderSelect.value);
  latestCheckId = null; viewingCheckId = null; nodeFilter = '';
  if (inspectionProviderSelect.value) loadLatestCheck(inspectionProviderSelect.value);
  else { checkHistory = []; currentDiff = null; currentDiffByKey = {}; inspectionResults = {}; renderCheckHistory(); renderStatusBanner(); renderDiffSummary(); renderSummaryDeltas(); renderNodeCheckSummary([]); renderInspectionChecklist(); loadCheckSchedule(''); }
});
infrastructureProviderSelect.addEventListener('change', () => {
  providerSelect.value = infrastructureProviderSelect.value;
  inspectionProviderSelect.value = infrastructureProviderSelect.value;
  if (infrastructureProviderSelect.value) loadLatestCheck(infrastructureProviderSelect.value);
});
document.querySelector('#refreshInfrastructure').addEventListener('click', () => {
  if (infrastructureProviderSelect.value) loadLatestCheck(infrastructureProviderSelect.value);
});

function customCheckPayload() {
  return {name:document.querySelector('#customCheckName').value.trim(), description:document.querySelector('#customCheckDescription').value.trim(), target_role:document.querySelector('#customCheckTarget').value, execution_context:document.querySelector('#customCheckContext').value, command:document.querySelector('#customCheckCommand').value.trim(), rule_type:document.querySelector('#customCheckRule').value, expected_value:document.querySelector('#customCheckExpected').value, timeout_seconds:Number(document.querySelector('#customCheckTimeout').value), enabled:document.querySelector('#customCheckEnabled').checked};
}
function openCustomCheckForm(item = null) {
  const form = document.querySelector('#customCheckForm'); form.reset(); form.hidden = false;
  document.querySelector('#customCheckId').value = item?.id || ''; document.querySelector('#customCheckName').value = item?.name || ''; document.querySelector('#customCheckDescription').value = item?.description || ''; document.querySelector('#customCheckTarget').value = item?.target_role || 'all'; document.querySelector('#customCheckContext').value = item?.execution_context || 'plain'; document.querySelector('#customCheckCommand').value = item?.command || ''; document.querySelector('#customCheckRule').value = item?.rule_type || 'exit_code'; document.querySelector('#customCheckExpected').value = item?.expected_value || ''; document.querySelector('#customCheckTimeout').value = item?.timeout_seconds || 20; document.querySelector('#customCheckEnabled').checked = item?.enabled ?? true; document.querySelector('#customCheckTestOutput').hidden = true;
}
document.querySelector('#newCustomCheck').addEventListener('click', () => { if (!inspectionProviderSelect.value) return showToast('공급자를 먼저 선택하세요.', '사용자 정의 점검은 공급자별로 저장됩니다.'); openCustomCheckForm(); });
document.querySelector('#cancelCustomCheck').addEventListener('click', () => { document.querySelector('#customCheckForm').hidden = true; });
document.querySelector('#customCheckForm').addEventListener('submit', async event => {
  event.preventDefault(); const providerId = inspectionProviderSelect.value; const id = document.querySelector('#customCheckId').value; const button = event.submitter; button.disabled = true;
  try { const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/custom-checks${id ? `/${id}` : ''}`, {method:id ? 'PUT' : 'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(customCheckPayload())}); const data = await response.json(); if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '입력값을 확인하세요.'); document.querySelector('#customCheckForm').hidden = true; await loadCustomChecks(providerId); await loadCheckExceptions(providerId); showToast('사용자 정의 점검을 저장했습니다.', '일일점검 항목 선택에 반영되었습니다.'); } catch (error) { showToast('저장하지 못했습니다.', error.message); } finally { button.disabled = false; }
});
document.querySelector('#testCustomCheck').addEventListener('click', async event => {
  const providerId = inspectionProviderSelect.value; const output = document.querySelector('#customCheckTestOutput'); event.currentTarget.disabled = true; output.hidden = false; output.textContent = '시험 실행 중...';
  try { const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/custom-checks/test`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(customCheckPayload())}); const data = await response.json(); if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '입력값을 확인하세요.'); output.textContent = `[${data.status}] ${data.result}\n${(data.details || []).map(item => `\n# ${item.title}\n${item.output}`).join('')}`; } catch (error) { output.textContent = `시험 실행 실패: ${error.message}`; } finally { event.currentTarget.disabled = false; }
});
document.querySelector('#customCheckList').addEventListener('click', async event => {
  const edit = event.target.closest('[data-custom-edit]'); if (edit) return openCustomCheckForm(currentCustomChecks.find(item => item.id === edit.dataset.customEdit));
  const remove = event.target.closest('[data-custom-delete]'); if (!remove || !confirm('이 사용자 정의 점검을 삭제하시겠습니까?')) return;
  const response = await fetch(`/api/providers/${encodeURIComponent(inspectionProviderSelect.value)}/custom-checks/${remove.dataset.customDelete}`, {method:'DELETE'}); if (response.ok) { await loadCustomChecks(inspectionProviderSelect.value); await loadCheckExceptions(inspectionProviderSelect.value); showToast('사용자 정의 점검을 삭제했습니다.', '관련 예외 규칙도 함께 삭제되었습니다.'); }
});

discoverCluster.addEventListener('click', () => loadProviderNodes(inspectionProviderSelect.value, true));
document.querySelector('#clusterNodeList').addEventListener('click', event => {
  const toggle = event.target.closest('.cluster-role-heading');
  if (!toggle) return;
  const content = document.getElementById(toggle.getAttribute('aria-controls'));
  const collapsed = toggle.getAttribute('aria-expanded') === 'true';
  content.hidden = collapsed;
  toggle.setAttribute('aria-expanded', String(!collapsed));
  toggle.closest('.cluster-role-group').classList.toggle('collapsed', collapsed);
});

async function loadProviderNodes(providerId, discover = false) {
  const list = document.querySelector('#clusterNodeList');
  const warning = document.querySelector('#clusterWarning');
  if (!providerId) {
    list.innerHTML = '<div class="empty-provider">공급자를 선택한 후 클러스터를 탐색하세요.</div>';
    updateNodeCounts([]);
    updateExceptionNodeOptions([]);
    return;
  }
  discoverCluster.disabled = true;
  if (discover) {
    discoverCluster.textContent = '탐색 중...';
    list.innerHTML = '<div class="empty-provider">Controller에서 클러스터 노드를 탐색하고 있습니다.</div>';
  }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/${discover ? 'discover' : 'nodes'}`, {method:discover ? 'POST' : 'GET'});
    const data = await response.json();
    if (!response.ok) {
      const message = typeof data.detail === 'string' ? data.detail : data.detail?.message;
      const guidance = data.detail?.code === 'host_key_approval_required' ? ' 공급자 연결 화면의 SSH 키 관리에서 현재 지문을 확인하고 승인하세요.' : '';
      throw new Error(`${message || '클러스터 노드를 불러오지 못했습니다.'}${guidance}`);
    }
    updateNodeCounts(data.nodes);
    updateExceptionNodeOptions(data.nodes);
    renderClusterNodeGroups(data.nodes);
    const warnings = data.warnings || [];
    warning.hidden = !warnings.length;
    warning.textContent = warnings.join(' ');
    if (discover) showToast('클러스터 탐색이 완료되었습니다.', `Controller ${data.nodes.filter(node => node.role === 'controller').length}대 · Compute ${data.nodes.filter(node => node.role === 'compute').length}대`);
  } catch (error) {
    list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`;
    warning.hidden = true;
    updateNodeCounts([]);
    if (discover) showToast('클러스터 탐색에 실패했습니다.', error.message);
  } finally {
    discoverCluster.disabled = false;
    discoverCluster.textContent = '↻ 클러스터 탐색';
  }
}

function updateExceptionNodeOptions(nodes) {
  const selected = exceptionNode.value;
  exceptionNode.innerHTML = '<option value="">전체 노드</option>' + nodes.map(node => `<option value="${escapeText(node.hostname)}">${escapeText(node.hostname)} (${node.role === 'controller' ? 'Controller' : 'Compute'})</option>`).join('');
  if (nodes.some(node => node.hostname === selected)) exceptionNode.value = selected;
}

function updateNodeCounts(nodes) {
  document.querySelector('#controllerNodeCount').textContent = nodes.filter(node => node.role === 'controller').length;
  document.querySelector('#computeNodeCount').textContent = nodes.filter(node => node.role === 'compute').length;
  renderSetupCards();
}

function renderClusterNodeGroups(nodes) {
  const list = document.querySelector('#clusterNodeList');
  if (!nodes.length) {
    list.innerHTML = '<div class="empty-provider">저장된 노드가 없습니다. 클러스터 탐색을 실행하세요.</div>';
    return;
  }
  const roleGroups = [
    {role:'controller', title:'Controller 노드', symbol:'C'},
    {role:'compute', title:'Compute 노드', symbol:'N'}
  ];
  list.innerHTML = roleGroups.map(({role, title, symbol}) => {
    const roleNodes = nodes.filter(node => node.role === role);
    const contentId = `cluster-role-${role}`;
    const cards = roleNodes.length ? roleNodes.map(node => `<article><span class="node-role ${role}">${symbol}</span><div><strong>${escapeText(node.hostname)}</strong><small>${escapeText(node.address)}</small><small class="node-source">${escapeText(node.source)}</small></div><em>${role === 'controller' ? 'Controller' : 'Compute'}</em></article>`).join('') : `<div class="empty-role-nodes">탐색된 ${title}가 없습니다.</div>`;
    return `<section class="cluster-role-group ${role}"><button type="button" class="cluster-role-heading" aria-expanded="true" aria-controls="${contentId}"><span class="node-role ${role}">${symbol}</span><strong>${title}</strong><b>${roleNodes.length}대</b><span class="cluster-role-chevron" aria-hidden="true">⌃</span></button><div class="cluster-role-nodes" id="${contentId}">${cards}</div></section>`;
  }).join('');
}

async function loadCheckExceptions(providerId) {
  const list = document.querySelector('#exceptionList');
  if (!providerId) {
    currentExceptionRules = [];
    list.innerHTML = '<div class="empty-provider">공급자를 선택하세요.</div>';
    document.querySelector('#exceptionCount').textContent = '0';
    renderSetupCards();
    return;
  }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/check-exceptions`);
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '예외 항목을 불러오지 못했습니다.');
    const names = Object.fromEntries(inspectionGroups.flatMap(group => group.items.map(([, name,, key]) => [key, name])));
    currentExceptionRules = data.exceptions;
    document.querySelector('#exceptionCount').textContent = data.exceptions.length;
    list.innerHTML = data.exceptions.length ? data.exceptions.map(rule => `<article><strong>${escapeText(names[rule.item_key] || rule.item_key)}</strong><span class="exception-scope">${escapeText(rule.node_hostname || '전체 노드')}</span><span>${escapeText(rule.reason)}</span><button type="button" data-exception-id="${escapeText(rule.id)}">삭제</button></article>`).join('') : '<div class="empty-provider">등록된 예외 항목이 없습니다.</div>';
    if (currentNodeSummary.length) renderNodeCheckSummary(currentNodeSummary);
    renderSetupCards();
  } catch (error) {
    list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`;
  }
}

document.querySelector('#exceptionForm').addEventListener('submit', async event => {
  event.preventDefault();
  const providerId = inspectionProviderSelect.value;
  if (!providerId) return showToast('공급자를 먼저 선택하세요.', '예외 규칙은 공급자별로 저장됩니다.');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/check-exceptions`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({item_key:exceptionItem.value, node_hostname:exceptionNode.value, reason:exceptionReason.value.trim()})});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '예외 등록에 실패했습니다.');
    exceptionReason.value = '';
    await loadCheckExceptions(providerId);
    showToast('예외 항목을 등록했습니다.', '다음 점검부터 경고 판정에서 제외됩니다.');
  } catch (error) { showToast('예외 등록에 실패했습니다.', error.message); }
});

document.querySelector('#exceptionList').addEventListener('click', async event => {
  const button = event.target.closest('button[data-exception-id]');
  if (!button) return;
  const providerId = inspectionProviderSelect.value;
  const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/check-exceptions/${encodeURIComponent(button.dataset.exceptionId)}`, {method:'DELETE'});
  if (response.ok) {
    await loadCheckExceptions(providerId);
    showToast('예외 항목을 삭제했습니다.', '다음 점검부터 일반 판정 기준이 적용됩니다.');
  } else showToast('예외 삭제에 실패했습니다.', '잠시 후 다시 시도하세요.');
});

function escapeText(value) {
  const element = document.createElement('span');
  element.textContent = value ?? '';
  return element.innerHTML;
}

function groupRepeatedLogLines(output) {
  const groups = new Map();
  String(output || '').split(/\r?\n/).forEach(line => {
    const value = line.trim();
    if (!value) return;
    const iso = value.match(/^(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?)/);
    const syslog = value.match(/^([A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})/);
    const timestamp = (iso || syslog)?.[1] || '시간 정보 없음';
    let message = value.replace(/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?\s*/, '')
      .replace(/^[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s*/, '')
      .replace(/\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:[.,]\d+)?Z?\b/g, '<time>')
      .replace(/\[\d+\]/g, '[pid]')
      .replace(/\b(?:req-)?[0-9a-f]{8}-[0-9a-f-]{27,36}\b/gi, '<id>');
    if (!message) message = value;
    const group = groups.get(message) || {count:0, times:[]};
    group.count += 1;
    if (!group.times.includes(timestamp)) group.times.push(timestamp);
    groups.set(message, group);
  });
  if (!groups.size) return output || '일치하는 오류 로그 없음';
  return [...groups.entries()].map(([message, group]) => `${group.count}회 · ${message}\n발생 시각: ${group.times.join(', ')}`).join('\n\n');
}

function renderInspectionResult(data) {
  const metrics = data.metrics || {};
  if (Array.isArray(data.selected_items)) selectedInspectionKeys = new Set(data.selected_items);
  inspectionResults = data.items || {
    cpu:{status:'healthy', result:`${metrics.cpu_cores ?? '-'} Core`, note:'활성 Controller 기준'},
    memory:{status:metrics.memory_used_percent >= 80 ? 'warning' : 'healthy', result:`${metrics.memory_used_percent ?? '-'}%`, note:metrics.memory_used_percent >= 80 ? '임계치 80% 이상' : '정상 범위'},
    disk:{status:metrics.disk_used_percent >= 80 ? 'warning' : 'healthy', result:`${metrics.disk_used_percent ?? '-'}%`, note:metrics.disk_used_percent >= 80 ? '임계치 80% 이상' : '정상 범위'}
  };
  document.querySelector('#inspectionUpdatedAt').textContent = `${viewingCheckId ? '조회 결과' : '최근 실행'}: ${formatDateTime(data._checked_at || new Date())}`;
  exportInspectionPdf.disabled = !Object.keys(inspectionResults).length;
  document.querySelector('#openInspectionReport').disabled = !Object.keys(inspectionResults).length;
  renderNodeCheckSummary(data.node_summary || []);
  renderInspectionSelection();
  renderInspectionChecklist();
}

function buildPrintIssueReport() {
  const issueStatuses = new Set(['warning', 'unavailable']);
  const statusLabels = {warning:'주의', unavailable:'확인 불가'};
  const issueItems = inspectionGroups.flatMap(group => group.items
    .filter(([, , , key]) => key !== 'kernel_errors' && issueStatuses.has(inspectionResults[key]?.status))
    .map(([, name, method, key]) => ({group:group.title, name, method, key, ...inspectionResults[key]})));
  const summaryRows = issueItems.map(item => `<tr><td>${escapeText(item.group)}</td><td><strong>${escapeText(item.name)}</strong></td><td><span class="print-state ${escapeText(item.status)}">${statusLabels[item.status]}</span></td><td>${escapeText(item.note || '-')}</td><td>${escapeText(item.result || '-')}</td></tr>`).join('');
  const details = issueItems.map(item => {
    const issueHosts = new Set(currentNodeSummary.filter(node => {
      const hasIssue = [...(node.problem_items || []), ...(node.review_items || [])].includes(item.key);
      const isExcepted = currentExceptionRules.some(rule => rule.item_key === item.key && (!rule.node_hostname || rule.node_hostname === node.hostname));
      return hasIssue && !isExcepted;
    }).map(node => node.hostname));
    let outputs;
    if (item.key.endsWith('_log') && Array.isArray(item.nodes)) {
      outputs = item.nodes.filter(node => node.status !== 'healthy').map(node => {
        const groupedLogs = node.new_output ? groupRepeatedLogLines(node.new_output).split(/\n\s*\n/) : [];
        const visibleLogs = groupedLogs.slice(0, 10);
        const omitted = groupedLogs.length - visibleLogs.length;
        const output = visibleLogs.length
          ? `${visibleLogs.join('\n\n')}${omitted > 0 ? `\n\n외 ${omitted}개 신규·변경 오류 생략` : ''}`
          : (node.note || `신규·변경 오류 없음 · 전체 오류 ${Number(node.count) || 0}건`);
        return {title:`${node.hostname} (${node.role}) · 신규 ${Number(node.new_count) || 0}건`, output};
      });
    } else {
      outputs = item.details || [];
      if (issueHosts.size) outputs = outputs.filter(detail => [...issueHosts].some(host => detail.title?.includes(host)));
    }
    const outputHtml = outputs.length
      ? outputs.map(detail => `<article><strong>${escapeText(detail.title || '상세 결과')}</strong><pre>${escapeText(detail.output || '출력 없음')}</pre></article>`).join('')
      : `<article><pre>${escapeText(item.note || item.result || '상세 결과 없음')}</pre></article>`;
    return `<section class="print-issue-detail"><header><div><span>${escapeText(item.group)}</span><h2>${escapeText(item.name)}</h2></div><b class="print-state ${escapeText(item.status)}">${statusLabels[item.status]}</b></header><p><strong>점검 방법</strong> ${escapeText(item.method)}</p><p><strong>판정 결과</strong> ${escapeText(item.note || '-')} · ${escapeText(item.result || '-')}</p><div>${outputHtml}</div></section>`;
  }).join('');
  document.querySelector('#printIssueReport').innerHTML = issueItems.length
    ? `<div class="print-issue-heading"><h2>이상 항목 요약</h2><strong>${issueItems.length}개 항목</strong></div><table class="print-issue-table"><thead><tr><th>영역</th><th>점검 항목</th><th>상태</th><th>특이사항</th><th>결과</th></tr></thead><tbody>${summaryRows}</tbody></table><div class="print-detail-heading"><h2>이상 항목 상세 내용</h2><p>주의 또는 확인이 필요한 항목의 판정 근거와 원본 결과입니다.</p></div>${details}`
    : '<div class="print-no-issues"><h2>이상 항목 없음</h2><p>이번 일일점검에서 주의 또는 확인이 필요한 항목이 발견되지 않았습니다.</p></div>';
}

exportInspectionPdf.addEventListener('click', () => {
  if (!Object.keys(inspectionResults).length) return showToast('PDF로 저장할 결과가 없습니다.', '일일점검을 먼저 실행하세요.');
  const selectedProvider = inspectionProviderSelect.options[inspectionProviderSelect.selectedIndex];
  document.querySelector('#printProviderName').textContent = selectedProvider?.textContent || '-';
  document.querySelector('#printGeneratedAt').textContent = new Intl.DateTimeFormat('ko-KR', {dateStyle:'long', timeStyle:'short'}).format(new Date());
  buildPrintIssueReport();
  window.print();
});

function renderNodeCheckSummary(nodes) {
  const container = document.querySelector('#nodeCheckSummary');
  currentNodeSummary = nodes;
  const legendCounts = {problem:0, review:0, healthy:0};
  const updateLegend = () => Object.entries(legendCounts).forEach(([status, count]) => { const el = document.querySelector(`.node-summary-legend .${status} b`); if (el) el.textContent = nodes.length ? count : ''; });
  if (!nodes.length) {
    updateLegend();
    container.innerHTML = '<div class="empty-provider">노드별 요약 데이터가 없습니다. 점검을 다시 실행하세요.</div>';
    return;
  }
  const itemMeta = {};
  inspectionGroups.forEach((group, groupIndex) => group.items.forEach(([category, name,, key], itemIndex) => { itemMeta[key] = {name, category, group:group.title, order:groupIndex * 1000 + itemIndex}; }));
  itemMeta.ssh = {name:'SSH 연결', category:'Access', group:'접속', order:-1};
  const metaOf = key => itemMeta[key] || {name:key, category:'사용자 정의', group:'사용자 정의 점검', order:99999};
  const statusLabels = {problem:'문제 있음', review:'확인 필요', healthy:'정상'};
  const statusIcons = {problem:'!', review:'?', healthy:'✓'};
  const statusOrder = {problem:0, review:1, healthy:2};
  const roleLabels = {controller:'Controller', compute:'Compute'};
  const roleShort = {controller:'CTL', compute:'CMP'};
  const chipList = (keys, cls, hostname) => keys.map(key => ({key, ...metaOf(key)})).sort((a, b) => a.order - b.order)
    .map(item => `<button type="button" class="node-item-chip ${cls}" data-node-item="${escapeText(item.key)}" data-node-host="${escapeText(hostname)}" title="${escapeText(item.group)} · ${escapeText(item.category)} — 클릭하면 이 항목의 결과로 이동합니다">${escapeText(item.name)}</button>`).join('');
  const cards = [...nodes].map(node => {
    const isExcepted = key => currentExceptionRules.some(rule => rule.item_key === key && (!rule.node_hostname || rule.node_hostname === node.hostname));
    const problems = (node.problem_items || []).filter(key => !isExcepted(key));
    const reviews = (node.review_items || []).filter(key => !isExcepted(key));
    const excepted = [...new Set([...(node.excepted_items || []), ...[...(node.problem_items || []), ...(node.review_items || [])].filter(isExcepted)])];
    const effectiveStatus = problems.length ? 'problem' : (reviews.length ? 'review' : 'healthy');
    legendCounts[effectiveStatus] += 1;
    return {node, problems, reviews, excepted, effectiveStatus};
  }).sort((a, b) => statusOrder[a.effectiveStatus] - statusOrder[b.effectiveStatus] || b.problems.length - a.problems.length || a.node.hostname.localeCompare(b.node.hostname));
  updateLegend();
  container.innerHTML = cards.map(({node, problems, reviews, excepted, effectiveStatus}) => {
    const stats = `<div class="node-summary-stats"><span class="problem${problems.length ? '' : ' zero'}"><small>문제</small><b>${problems.length}</b></span><span class="review${reviews.length ? '' : ' zero'}"><small>확인</small><b>${reviews.length}</b></span><span class="excepted${excepted.length ? '' : ' zero'}"><small>예외</small><b>${excepted.length}</b></span></div>`;
    const sections = [
      problems.length ? `<div class="node-summary-detail problem"><b><i aria-hidden="true">!</i>문제</b><div class="node-item-chips">${chipList(problems, 'problem', node.hostname)}</div></div>` : '',
      reviews.length ? `<div class="node-summary-detail review"><b><i aria-hidden="true">?</i>확인</b><div class="node-item-chips">${chipList(reviews, 'review', node.hostname)}</div></div>` : '',
      excepted.length ? `<div class="node-summary-detail excepted"><b><i aria-hidden="true">–</i>예외</b><div class="node-item-chips">${chipList(excepted, 'excepted', node.hostname)}</div></div>` : ''
    ].join('');
    const body = (problems.length || reviews.length)
      ? sections
      : `${sections}<p><i aria-hidden="true">✓</i>${excepted.length ? '예외 처리를 적용한 결과 추가로 표시할 이상이 없습니다.' : '모든 점검 항목이 정상입니다.'}</p>`;
    return `<article class="node-summary-card ${effectiveStatus}${nodeFilter === node.hostname ? ' active' : ''}" data-node-filter="${escapeText(node.hostname)}" role="button" tabindex="0" title="클릭하면 이 노드와 관련된 항목만 표시합니다"><header><span class="node-role ${escapeText(node.role)}">${roleShort[node.role] || 'NODE'}</span><div><strong>${escapeText(node.hostname)}</strong><small>${escapeText(roleLabels[node.role] || node.role)} · ${escapeText(node.address)}</small></div><em><i aria-hidden="true">${statusIcons[effectiveStatus]}</i>${statusLabels[effectiveStatus]}</em></header>${stats}${body}</article>`;
  }).join('');
}

function renderInspectionSelection() {
  const panel = document.querySelector('#inspectionSelectionPanel');
  panel.innerHTML = inspectionGroups.map((group, groupIndex) => {
    const keys = group.items.map(item => item[3]);
    const checked = keys.filter(key => selectedInspectionKeys.has(key)).length;
    return `<section class="${checked ? 'has-selection' : 'no-selection'}"><label class="selection-group"><input type="checkbox" data-selection-group="${groupIndex}" ${checked === keys.length ? 'checked' : ''}><strong>${escapeText(group.title)}</strong><span>${checked}/${keys.length}</span></label><div>${group.items.map(([, name,, key]) => { const selected = selectedInspectionKeys.has(key); return `<label class="${selected ? 'selected' : 'unselected'}"><input type="checkbox" data-selection-key="${key}" ${selected ? 'checked' : ''}><span>${escapeText(name)}</span></label>`; }).join('')}</div></section>`;
  }).join('');
  document.querySelector('#selectedInspectionCount').textContent = selectedInspectionKeys.size;
  renderSetupCards();
}

function inspectionStatusMatches(filter, status) {
  return filter === 'all' || filter === status ||
    (filter === 'healthy' && status === 'excepted') ||
    (filter === 'pending' && ['pending', 'skipped'].includes(status));
}

function renderInspectionChecklist() {
  const checklist = document.querySelector('#inspectionChecklist');
  let total = 0, healthy = 0, warning = 0, unavailable = 0;
  const nodeKeys = nodeFilterKeys();
  const labels = inspectionStatusLabels;
  const changeBadge = key => {
    const change = currentDiffByKey[key];
    if (!change || !['new_issue', 'resolved', 'changed', 'added'].includes(change.change)) return '';
    const cls = {new_issue:'new', resolved:'resolved', changed:'changed', added:'added'}[change.change];
    return `<i class="change-badge ${cls}" title="직전 점검 ${escapeText(labels[change.before] || '없음')} → ${escapeText(labels[change.after] || '없음')}">${changeLabels[change.change]}</i>`;
  };
  checklist.innerHTML = inspectionGroups.map((group, groupIndex) => {
    const selectedGroupItems = group.items.filter(([, , , key]) => selectedInspectionKeys.has(key));
    if (!selectedGroupItems.length) return '';
    selectedGroupItems.forEach(([, , , key]) => {
      total += 1;
      const result = inspectionResults[key] || {status:'pending', result:'-', note:'점검 실행 필요'};
      if (result.status === 'healthy' || result.status === 'excepted') healthy += 1;
      if (result.status === 'warning') warning += 1;
      if (result.status === 'unavailable') unavailable += 1;
    });
    const visibleGroupItems = selectedGroupItems.filter(([category, name, method, key]) => {
      const result = inspectionResults[key] || {status:'pending', result:'-', note:'점검 실행 필요'};
      return inspectionStatusMatches(currentFilter, result.status) && inspectionItemMatchesSearch(category, name, method, key, result) && (!nodeKeys || nodeKeys.has(key));
    });
    if (!visibleGroupItems.length) return '';
    const rows = visibleGroupItems.map(([category, name, method, key]) => {
      const result = inspectionResults[key] || {status:'pending', result:'-', note:'점검 실행 필요'};
      const detailId = `inspection-detail-${groupIndex}-${key}`;
      const logIssueNodes = (result.nodes || []).filter(node => node.status !== 'healthy');
      const nodeDetail = logIssueNodes.length ? `<details class="node-log-detail"><summary>노드별 전전날 대비 신규·변경 오류</summary>${logIssueNodes.map(node => `<details class="node-log-entry"><summary><strong>${escapeText(node.hostname)}</strong><span>${escapeText(node.role)}</span><em class="${escapeText(node.status)}">${labels[node.status] || '확인 불가'}</em><b>신규 ${Number(node.new_count) || 0}건 · 보기</b><small>${escapeText(node.previous_log_date || '전전날')} → ${escapeText(node.log_date || '전날')} · 해소 ${Number(node.resolved_count) || 0}건${node.note ? ` · ${escapeText(node.note)}` : ''}</small></summary><pre>${escapeText(groupRepeatedLogLines(node.new_output || '전전날과 다른 신규 오류 없음'))}</pre></details>`).join('')}</details>` : '';
      const details = result.details?.length ? result.details : [{title:'조회 결과', output:result.status === 'pending' ? '아직 점검을 실행하지 않았습니다.' : `${result.note || ''}\n${result.result || '-'}`}];
      const isLogItem = key.endsWith('_log');
      const visibleDetails = isLogItem ? details.filter(detail => detail.title.includes('신규/변경 로그')) : details;
      const rawOutput = isLogItem
        ? (logIssueNodes.length ? logIssueNodes.map(node => `<article><strong>${escapeText(`${node.hostname} (${node.role}) · 전전날 대비 신규/변경 로그`)}</strong><pre>${escapeText(groupRepeatedLogLines(node.new_output || node.note || '전전날과 다른 신규 오류 없음'))}</pre></article>`).join('') : '<article><strong>신규·변경 오류</strong><pre>주의 또는 확인이 필요한 노드가 없습니다.</pre></article>')
        : (visibleDetails.length ? visibleDetails : details).map(detail => `<article><strong>${escapeText(detail.title)}</strong><pre>${escapeText(detail.output || '출력 없음')}</pre></article>`).join('');
      const hasResult = result.status !== 'pending';
      const actions = hasResult ? `<div class="inspection-detail-actions"><span>${escapeText(name)} 상세 결과</span>${result.status === 'warning' ? `<button type="button" data-row-action="exception" data-key="${escapeText(key)}">예외 등록</button>` : ''}${result.status === 'warning' || result.status === 'unavailable' ? `<button type="button" data-row-action="alerts" data-key="${escapeText(key)}">관련 알림</button>` : ''}<button type="button" data-row-action="copy" data-key="${escapeText(key)}" data-detail-id="${detailId}">출력 복사</button></div>` : '';
      const exceptionNote = result.status === 'excepted' && result.exception_reason ? `<span class="exception-inline" title="${escapeText(result.exception_reason)}">예외</span>` : '';
      return `<tr class="inspection-row" data-status="${result.status}" data-key="${escapeText(key)}" data-detail-id="${detailId}" tabindex="0" aria-expanded="false"><td><span class="category-badge">${category}</span></td><td><strong>${name}</strong><small class="detail-hint">클릭하여 상세 결과 보기</small></td><td><div class="check-method">${escapeText(method)}</div></td><td><span class="check-state ${result.status}">${labels[result.status]}</span>${changeBadge(key)}${exceptionNote}</td><td>${escapeText(result.note)}${nodeDetail}</td><td class="inspection-value">${escapeText(result.result)}</td></tr><tr class="inspection-detail-row${isLogItem ? ' log-output-row' : ''}" id="${detailId}" hidden><td colspan="6">${actions}${isLogItem ? '<div class="log-output-heading"><strong>전전날 대비 신규·변경 오류</strong><span>중복 메시지는 발생 시각으로 묶어서 표시</span></div>' : ''}<div class="inspection-raw-output">${rawOutput}</div></td></tr>`;
    }).join('');
    const collapsed = collapsedInspectionGroups.has(groupIndex);
    const contentId = `inspection-group-content-${groupIndex}`;
    const groupWarning = selectedGroupItems.filter(([, , , key]) => inspectionResults[key]?.status === 'warning').length;
    const groupUnavailable = selectedGroupItems.filter(([, , , key]) => inspectionResults[key]?.status === 'unavailable').length;
    const groupBadges = `${groupWarning ? `<i class="group-count warning">주의 ${groupWarning}</i>` : ''}${groupUnavailable ? `<i class="group-count unavailable">확인 불가 ${groupUnavailable}</i>` : ''}`;
    const filtered = currentFilter !== 'all' || searchQuery || nodeKeys;
    const countLabel = filtered ? `${visibleGroupItems.length}개 해당` : `${selectedGroupItems.length}개 선택`;
    return `<article class="inspection-group${collapsed ? ' collapsed' : ''}" data-group-index="${groupIndex}"><header><button type="button" class="inspection-group-toggle" aria-expanded="${!collapsed}" aria-controls="${contentId}"><span class="inspection-group-number">${groupIndex + 1}</span><span class="inspection-group-title"><strong>${escapeText(group.title)}</strong><small>${escapeText(group.description)}</small></span><span class="inspection-group-badges">${groupBadges}</span><b>${countLabel}</b><span class="inspection-group-chevron" aria-hidden="true">⌃</span></button></header><div class="inspection-table-wrap" id="${contentId}"${collapsed ? ' hidden' : ''}><table><thead><tr><th>점검 분류</th><th>점검 사항</th><th>점검 방법</th><th>상태</th><th>특이사항</th><th>점검 결과</th></tr></thead><tbody>${rows}</tbody></table></div></article>`;
  }).join('');
  if (!selectedInspectionKeys.size) checklist.innerHTML = '<div class="empty-provider">상단에서 일일점검 항목을 선택하세요.</div>';
  else if (!checklist.innerHTML) checklist.innerHTML = `<div class="empty-provider">${nodeKeys ? `${escapeText(nodeFilter)} 노드에 표시할 이상 항목이 없습니다.` : (searchQuery ? `'${escapeText(searchQuery)}' 검색 결과가 없습니다.` : '선택한 상태에 해당하는 점검 항목이 없습니다.')}</div>`;
  document.querySelector('#totalInspectionItems').textContent = total;
  document.querySelector('#healthyInspectionItems').textContent = healthy;
  document.querySelector('#warningInspectionItems').textContent = warning;
  document.querySelector('#unavailableInspectionItems').textContent = unavailable;
  document.querySelector('#pendingInspectionItems').textContent = total - healthy - warning - unavailable;
  document.querySelector('#inspectionCount').textContent = total;
  document.querySelector('#selectedInspectionCount').textContent = selectedInspectionKeys.size;
  renderNodeFilterChip();
  if (document.querySelector('#scheduleItems')) { const option = document.querySelector('#scheduleItems option[value="current"]'); if (option) option.textContent = `현재 선택한 항목 (${selectedInspectionKeys.size}개)`; }
}

document.querySelector('#inspectionChecklist').addEventListener('click', event => {
  const groupToggle = event.target.closest('.inspection-group-toggle');
  if (groupToggle) {
    const group = groupToggle.closest('.inspection-group');
    const groupIndex = Number(group.dataset.groupIndex);
    collapsedInspectionGroups.has(groupIndex) ? collapsedInspectionGroups.delete(groupIndex) : collapsedInspectionGroups.add(groupIndex);
    group.classList.toggle('collapsed');
    const content = document.getElementById(groupToggle.getAttribute('aria-controls'));
    const collapsed = collapsedInspectionGroups.has(groupIndex);
    content.hidden = collapsed;
    groupToggle.setAttribute('aria-expanded', String(!collapsed));
    return;
  }
  if (event.target.closest('details') || event.target.closest('[data-row-action]')) return;
  const row = event.target.closest('.inspection-row');
  if (row) toggleInspectionDetail(row);
});
document.querySelector('#inspectionSelectionPanel').addEventListener('change', event => {
  const item = event.target.closest('input[data-selection-key]');
  if (item) item.checked ? selectedInspectionKeys.add(item.dataset.selectionKey) : selectedInspectionKeys.delete(item.dataset.selectionKey);
  const group = event.target.closest('input[data-selection-group]');
  if (group) inspectionGroups[Number(group.dataset.selectionGroup)].items.forEach(([, , , key]) => group.checked ? selectedInspectionKeys.add(key) : selectedInspectionKeys.delete(key));
  renderInspectionSelection();
  renderInspectionChecklist();
});
document.querySelector('#selectAllInspections').addEventListener('click', () => { selectedInspectionKeys = new Set(allInspectionKeys); renderInspectionSelection(); renderInspectionChecklist(); });
document.querySelector('#clearAllInspections').addEventListener('click', () => { selectedInspectionKeys.clear(); renderInspectionSelection(); renderInspectionChecklist(); });
document.querySelectorAll('.collapsible-panel-heading').forEach(toggle => {
  const togglePanel = () => {
    const content = document.getElementById(toggle.getAttribute('aria-controls'));
    const collapsed = toggle.getAttribute('aria-expanded') === 'true';
    content.hidden = collapsed;
    toggle.setAttribute('aria-expanded', String(!collapsed));
    toggle.closest('.panel').classList.toggle('collapsed', collapsed);
  };
  toggle.addEventListener('click', event => {
    if (event.target.closest('button')) return;
    togglePanel();
  });
  toggle.addEventListener('keydown', event => {
    if (event.target.closest('button')) return;
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      togglePanel();
    }
  });
});
document.querySelector('#inspectionChecklist').addEventListener('keydown', event => {
  if ((event.key === 'Enter' || event.key === ' ') && event.target.classList.contains('inspection-row')) {
    event.preventDefault();
    toggleInspectionDetail(event.target);
  }
});

function toggleInspectionDetail(row) {
  const detail = document.getElementById(row.dataset.detailId);
  if (!detail) return;
  detail.hidden = !detail.hidden;
  row.setAttribute('aria-expanded', String(!detail.hidden));
  row.classList.toggle('expanded', !detail.hidden);
}

function setInspectionFilter(filter, scrollToResults = false) {
  currentFilter = filter;
  document.querySelectorAll('.inspection-filter button').forEach(item => item.classList.toggle('active', item.dataset.filter === filter));
  document.querySelectorAll('.inspection-summary-filter').forEach(item => {
    const active = item.dataset.summaryFilter === filter;
    item.classList.toggle('active', active);
    item.setAttribute('aria-pressed', String(active));
  });
  collapsedInspectionGroups.clear();
  renderInspectionChecklist();
  if (scrollToResults) document.querySelector('#inspectionChecklist').scrollIntoView({behavior:'smooth', block:'start'});
}

document.querySelectorAll('.inspection-filter button').forEach(button => button.addEventListener('click', () => setInspectionFilter(button.dataset.filter)));
document.querySelectorAll('.inspection-summary-filter').forEach(card => {
  const activate = () => setInspectionFilter(card.dataset.summaryFilter, true);
  card.addEventListener('click', activate);
  card.addEventListener('keydown', event => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      activate();
    }
  });
});

function formatCapacity(kilobytes) {
  const value = Number(kilobytes) || 0;
  if (!value) return '-';
  const gib = value / 1024 / 1024;
  return gib >= 1024 ? `${(gib / 1024).toFixed(1)} TiB` : `${gib.toFixed(gib >= 100 ? 0 : 1)} GiB`;
}

function renderInfrastructure(data) {
  const nodes = data.nodes || [];
  const summaries = new Map((data.node_summary || []).map(node => [node.hostname, node]));
  const reachable = nodes.filter(node => node.reachable);
  const nodeStatus = node => !node.reachable ? 'unreachable' : (summaries.get(node.hostname)?.status || node.status || 'healthy');
  const healthy = nodes.filter(node => nodeStatus(node) === 'healthy').length;
  const unreachable = nodes.filter(node => !node.reachable).length;
  const warning = nodes.length - healthy - unreachable;
  document.querySelector('#infraTotalNodes').textContent = nodes.length;
  document.querySelector('#infraHealthyNodes').textContent = healthy;
  document.querySelector('#infraWarningNodes').textContent = warning;
  document.querySelector('#infraUnreachableNodes').textContent = unreachable;
  document.querySelector('#infraRoleCounts').textContent = `Controller ${nodes.filter(node => node.role === 'controller').length} · Compute ${nodes.filter(node => node.role === 'compute').length}`;
  document.querySelector('#infraCpuCapacity').textContent = `${reachable.reduce((sum, node) => sum + (Number(node.metrics?.cpu_cores) || 0), 0) || '-'} Core`;
  document.querySelector('#infraMemoryCapacity').textContent = formatCapacity(reachable.reduce((sum, node) => sum + (Number(node.metrics?.memory_total_kb) || 0), 0));
  document.querySelector('#infraDiskCapacity').textContent = formatCapacity(reachable.reduce((sum, node) => sum + (Number(node.metrics?.disk_total_kb) || 0), 0));
  document.querySelector('#infraCheckedAt').textContent = data._checked_at ? new Intl.DateTimeFormat('ko-KR', {dateStyle:'short', timeStyle:'short'}).format(new Date(data._checked_at)) : '-';
  const statusLabels = {healthy:'정상', problem:'문제', review:'확인 필요', warning:'주의', unreachable:'접속 불가'};
  const nodeGrid = document.querySelector('#infrastructureNodeGrid');
  nodeGrid.innerHTML = nodes.length ? [...nodes].sort((a, b) => a.role.localeCompare(b.role) || a.hostname.localeCompare(b.hostname)).map(node => {
    const status = nodeStatus(node);
    const metrics = node.metrics || {};
    const gauges = [['CPU', metrics.cpu_used_percent], ['Memory', metrics.memory_used_percent], ['Disk', metrics.disk_used_percent]];
    return `<article class="infrastructure-node-card ${escapeText(status)}" data-infra-hostname="${escapeText(node.hostname)}"><header><span class="node-role ${escapeText(node.role)}">${node.role === 'controller' ? 'C' : 'N'}</span><div><strong>${escapeText(node.hostname)}</strong><small>${escapeText(node.address || '')} · ${node.role === 'controller' ? 'Controller' : 'Compute'}</small></div><em>${statusLabels[status] || '확인 필요'}</em></header><div class="infra-node-gauges">${gauges.map(([label, value]) => { const numeric = Number(value); const available = Number.isFinite(numeric); const percent = available ? Math.max(0, Math.min(100, numeric)) : 0; return `<div data-infra-metric="${label.toLowerCase()}"><span>${label}</span><b>${available ? `${numeric.toFixed(1)}%` : '-'}</b><i><u style="width:${percent}%"></u></i></div>`; }).join('')}</div><div class="infra-live-network" data-infra-network>Prometheus 네트워크: -</div>${node.warnings?.length ? `<p>${node.warnings.slice(0, 3).map(escapeText).join(' · ')}</p>` : ''}</article>`;
  }).join('') : '<div class="empty-provider">최근 일일점검 노드 데이터가 없습니다.</div>';
  const tableDataCount = item => {
    if (!item?.details?.length || item.status === 'unavailable') return null;
    const output = item.details.map(detail => detail.output || '').join('\n');
    const rows = output.split('\n').filter(line => /^\s*\|/.test(line));
    return rows.length ? Math.max(0, rows.length - 1) : null;
  };
  const renderStates = (containerId, definitions, showResourceCount = false) => {
    const container = document.querySelector(containerId);
    container.innerHTML = definitions.map(([key, label]) => {
      const item = data.items?.[key];
      const status = item?.status || 'pending';
      const labels = {healthy:'정상', warning:'주의', unavailable:'확인 불가', excepted:'예외', pending:'미수집'};
      const count = showResourceCount ? tableDataCount(item) : null;
      const display = showResourceCount ? (count === null ? '-' : `${count}개`) : (item ? '확인 완료' : '-');
      return `<article><span class="state-dot ${escapeText(status)}"></span><div><strong>${escapeText(label)}</strong><small>${escapeText(item?.note || '최근 점검에서 수집되지 않음')}</small></div><em class="${escapeText(status)}">${labels[status] || '확인 필요'}</em><b>${display}</b></article>`;
    }).join('');
  };
  renderStates('#infrastructureServiceList', [['endpoint','Endpoint'],['nova','Nova'],['neutron','Neutron'],['cinder','Cinder'],['manila','Manila'],['octavia','Octavia'],['masakari','Masakari'],['swift','Swift'],['heat','Heat']]);
  renderStates('#infrastructureResourceList', [['vm','VM'],['network','Network Agent'],['volume','Volume'],['snapshot','Snapshot'],['share','Share'],['lb','Load Balancer'],['amphora','Amphora'],['heat_stack','Heat Stack']], true);
}

function renderPrometheusChart(svgId, points) {
  const svg = document.querySelector(svgId);
  if (!points?.length) { svg.innerHTML = '<text x="150" y="43" text-anchor="middle">수집 데이터 없음</text>'; return; }
  const values = points.map(point => Number(point[1])).filter(Number.isFinite);
  const max = Math.max(100, ...values);
  const coordinates = values.map((value, index) => `${values.length === 1 ? 0 : index / (values.length - 1) * 300},${76 - value / max * 68}`).join(' ');
  svg.innerHTML = `<line x1="0" y1="76" x2="300" y2="76"></line><line x1="0" y1="42" x2="300" y2="42"></line><polyline points="${coordinates}"></polyline>`;
}

async function loadInfrastructureMetrics(providerId) {
  const connection = document.querySelector('#prometheusConnection');
  connection.className = 'prometheus-connection pending';
  connection.innerHTML = '<i></i>연결 중';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/infrastructure/metrics`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : 'Prometheus 조회 실패');
    connection.className = 'prometheus-connection connected';
    connection.innerHTML = `<i></i>${data.targets}개 노드 연결`;
    document.querySelector('#prometheusSource').textContent = `수집원: ${data.source}`;
    document.querySelector('#prometheusCollectedAt').textContent = `수집: ${new Intl.DateTimeFormat('ko-KR', {timeStyle:'medium'}).format(new Date(data.collected_at))}`;
    ['cpu','memory','disk'].forEach(metric => {
      const values = data.nodes.map(node => Number(node[metric])).filter(Number.isFinite);
      const average = values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : null;
      document.querySelector(`#prometheus${metric[0].toUpperCase()}${metric.slice(1)}Now`).textContent = average === null ? '-' : `${average.toFixed(1)}%`;
      renderPrometheusChart(`#prometheus${metric[0].toUpperCase()}${metric.slice(1)}Chart`, data.history?.[metric]);
    });
    data.nodes.forEach(node => {
      const card = [...document.querySelectorAll('[data-infra-hostname]')].find(item => item.dataset.infraHostname === node.hostname);
      if (!card) return;
      ['cpu','memory','disk'].forEach(metric => {
        const row = card.querySelector(`[data-infra-metric="${metric}"]`);
        const value = Number(node[metric]);
        if (!row || !Number.isFinite(value)) return;
        row.querySelector('b').textContent = `${value.toFixed(1)}%`;
        row.querySelector('u').style.width = `${Math.max(0, Math.min(100, value))}%`;
      });
      const bytes = Number(node.network);
      card.querySelector('[data-infra-network]').textContent = Number.isFinite(bytes) ? `현재 네트워크 송수신 ${bytes >= 1048576 ? `${(bytes / 1048576).toFixed(2)} MiB/s` : `${(bytes / 1024).toFixed(1)} KiB/s`}` : '현재 네트워크 송수신 -';
    });
  } catch (error) {
    connection.className = 'prometheus-connection failed';
    connection.innerHTML = '<i></i>연결 실패';
    document.querySelector('#prometheusSource').textContent = error.message;
  }
}

function showPage(page) {
  document.querySelector('#dashboardPage').hidden = page !== 'dashboard';
  document.querySelector('#inspectionPage').hidden = page !== 'daily-inspection';
  document.querySelector('#infrastructurePage').hidden = page !== 'infrastructure';
  document.querySelector('#alertsPage').hidden = page !== 'alerts';
  document.querySelector('#historyPage').hidden = page !== 'history';
  document.querySelector('#settingsPage').hidden = page !== 'settings';
  document.querySelector('#currentPageName').textContent = page === 'daily-inspection' ? '일일점검' : (page === 'infrastructure' ? '인프라 현황' : (page === 'alerts' ? '알림 및 장애' : (page === 'history' ? '작업 이력' : (page === 'settings' ? '설정' : '대시보드'))));
  document.querySelectorAll('[data-page]').forEach(link => link.classList.toggle('active', link.dataset.page === page));
  sidebar.classList.remove('open');
}

const alertSeverityLabels = {critical:'위험', warning:'주의', info:'정보'};
const alertStatusLabels = {open:'미확인', acknowledged:'확인', resolved:'해소'};

function renderAlertSummary(summary, alerts = []) {
  document.querySelector('#activeAlertCount').textContent = summary.active || 0;
  document.querySelector('#criticalAlertCount').textContent = summary.critical || 0;
  document.querySelector('#warningAlertCount').textContent = (summary.groups || []).filter(item => item.status !== 'resolved' && item.severity === 'warning').reduce((sum, item) => sum + item.count, 0);
  document.querySelector('#resolvedAlertCount').textContent = (summary.groups || []).filter(item => item.status === 'resolved').reduce((sum, item) => sum + item.count, 0);
  document.querySelectorAll('.alert-count').forEach(element => { element.textContent = summary.active || 0; element.hidden = !(summary.active || 0); });
}

async function loadAlertSummary() {
  try { const response = await fetch('/api/alerts/summary', {cache:'no-store'}); if (response.ok) renderAlertSummary(await response.json()); } catch (_) { /* Badge is non-critical. */ }
}

async function loadAlerts() {
  const params = new URLSearchParams();
  [['provider_id','#alertProviderFilter'],['severity','#alertSeverityFilter'],['status','#alertStatusFilter'],['q','#alertSearch']].forEach(([key, selector]) => { const value = document.querySelector(selector).value.trim(); if (value) params.set(key, value); });
  const list = document.querySelector('#alertManagementList'); list.innerHTML = '<div class="empty-provider">알림을 불러오는 중입니다.</div>';
  try {
    const response = await fetch(`/api/alerts?${params}`, {cache:'no-store'}); const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '알림을 불러오지 못했습니다.'); renderAlertSummary(data.summary, data.alerts);
    if (!data.alerts.length) { list.innerHTML = '<div class="empty-provider">조건에 맞는 알림이 없습니다.</div>'; return; }
    list.innerHTML = data.alerts.map(item => `<article class="managed-alert ${item.severity} ${item.status}" data-alert-id="${item.id}"><span class="managed-alert-icon">${item.severity === 'critical' ? '!' : (item.severity === 'warning' ? '△' : 'i')}</span><div><header><span class="alert-severity ${item.severity}">${alertSeverityLabels[item.severity] || escapeText(item.severity)}</span><span class="alert-state ${item.status}">${alertStatusLabels[item.status] || escapeText(item.status)}</span><h2>${escapeText(item.title)}</h2></header><p>${escapeText(item.description)}</p><small>${escapeText(item.provider_name || '공통')} · ${escapeText(item.target || '대상 미지정')} · 최근 감지 ${new Intl.DateTimeFormat('ko-KR', {dateStyle:'short', timeStyle:'short'}).format(new Date(item.last_detected_at))}</small>${item.assignee || item.work_history_title ? `<div class="alert-links">${item.assignee ? `<span>담당자 ${escapeText(item.assignee)}</span>` : ''}${item.work_history_title ? `<a href="#history">작업이력: ${escapeText(item.work_history_title)}</a>` : ''}</div>` : ''}${item.resolution_note ? `<blockquote>${escapeText(item.resolution_note)}</blockquote>` : ''}</div><button data-alert-action="manage" type="button">${item.status === 'resolved' ? '내용 보기' : '처리'}</button></article>`).join('');
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}

async function openAlertAction(id) {
  const [alertResponse, historiesResponse] = await Promise.all([fetch(`/api/alerts/${id}`), fetch('/api/work-histories')]);
  const item = await alertResponse.json(); if (!alertResponse.ok) return showToast('알림을 불러오지 못했습니다.', item.detail || '다시 시도하세요.');
  const histories = historiesResponse.ok ? (await historiesResponse.json()).histories : [];
  const select = document.querySelector('#alertWorkHistory'); select.innerHTML = '<option value="">연결하지 않음</option>' + histories.map(history => `<option value="${history.id}">${escapeText(history.title)} · ${escapeText(history.operator)}</option>`).join('');
  document.querySelector('#alertActionId').value = item.id; document.querySelector('#alertActionStatus').value = item.status; document.querySelector('#alertAssignee').value = item.assignee || ''; select.value = item.work_history_id || ''; document.querySelector('#alertResolutionNote').value = item.resolution_note || ''; document.querySelector('#alertActionTitle').textContent = item.title; document.querySelector('#alertActionEditor').hidden = false; document.querySelector('#alertActionEditor').scrollIntoView({behavior:'smooth'});
}

document.querySelector('#refreshAlerts').addEventListener('click', loadAlerts);
document.querySelector('#searchAlerts').addEventListener('click', loadAlerts);
document.querySelector('#alertSearch').addEventListener('keydown', event => { if (event.key === 'Enter') loadAlerts(); });
document.querySelector('#closeAlertAction').addEventListener('click', () => { document.querySelector('#alertActionEditor').hidden = true; });
document.querySelector('#alertManagementList').addEventListener('click', event => { const historyLink = event.target.closest('.alert-links a'); if (historyLink) { event.preventDefault(); history.replaceState(null, '', '#history'); showPage('history'); loadWorkHistories(); return; } const button = event.target.closest('[data-alert-action]'); if (button) openAlertAction(button.closest('[data-alert-id]').dataset.alertId); });
document.querySelector('#alertActionForm').addEventListener('submit', async event => {
  event.preventDefault(); const id = document.querySelector('#alertActionId').value; const payload = {status:document.querySelector('#alertActionStatus').value, assignee:document.querySelector('#alertAssignee').value, work_history_id:document.querySelector('#alertWorkHistory').value || null, resolution_note:document.querySelector('#alertResolutionNote').value}; const button = event.submitter; button.disabled = true;
  try { const response = await fetch(`/api/alerts/${id}`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)}); const data = await response.json(); if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '처리 내용을 확인하세요.'); document.querySelector('#alertActionEditor').hidden = true; showToast('알림 처리 내용을 저장했습니다.', `${alertStatusLabels[data.status]} 상태로 반영되었습니다.`); await loadAlerts(); } catch (error) { showToast('알림을 처리하지 못했습니다.', error.message); } finally { button.disabled = false; }
});

const workTypeLabels = {inspection:'점검', incident:'장애 대응', change:'설정 변경', restart:'재시작', deployment:'배포', maintenance:'유지보수', other:'기타'};
const workStatusLabels = {planned:'예정', in_progress:'진행 중', completed:'완료', failed:'실패'};
const historyFields = ['Title','Provider','Type','Status','Operator','Target','Ticket','StartedAt','CompletedAt','Description','Commands','BeforeState','AfterState','Result','FollowUp'];

function localDateTimeValue(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

function resetWorkHistoryForm() {
  document.querySelector('#workHistoryForm').reset();
  document.querySelector('#workHistoryId').value = '';
  document.querySelector('#historyStartedAt').value = localDateTimeValue();
  document.querySelector('#workHistoryFormTitle').textContent = '작업 이력 등록';
}

function workHistoryPayload() {
  const value = id => document.querySelector(`#history${id}`).value;
  return {provider_id:value('Provider') || null, title:value('Title'), work_type:value('Type'), status:value('Status'), operator:value('Operator'), target:value('Target'), ticket:value('Ticket'), description:value('Description'), commands:value('Commands'), before_state:value('BeforeState'), after_state:value('AfterState'), result:value('Result'), follow_up:value('FollowUp'), started_at:new Date(value('StartedAt')).toISOString(), completed_at:value('CompletedAt') ? new Date(value('CompletedAt')).toISOString() : null};
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
    if (!data.histories.length) { list.innerHTML = '<div class="empty-provider">조건에 맞는 작업 이력이 없습니다.</div>'; return; }
    list.innerHTML = data.histories.map(item => `<article class="work-history-card" data-history-id="${item.id}"><header><div><span class="history-type">${workTypeLabels[item.work_type] || escapeText(item.work_type)}</span><span class="history-status ${item.status}">${workStatusLabels[item.status] || escapeText(item.status)}</span><h2>${escapeText(item.title)}</h2><small>${escapeText(item.provider_name || '공통')} · ${escapeText(item.target || '대상 미지정')} · ${escapeText(item.operator)}</small></div><time>${new Intl.DateTimeFormat('ko-KR', {dateStyle:'medium', timeStyle:'short'}).format(new Date(item.started_at))}</time></header><p>${escapeText(item.description)}</p><div class="history-detail" hidden>${item.ticket ? `<section><b>티켓 / 요청 번호</b><pre>${escapeText(item.ticket)}</pre></section>` : ''}${item.commands ? `<section><b>실행 명령 / 절차</b><pre>${escapeText(item.commands)}</pre></section>` : ''}${item.before_state ? `<section><b>변경 전 상태</b><pre>${escapeText(item.before_state)}</pre></section>` : ''}${item.after_state ? `<section><b>변경 후 상태</b><pre>${escapeText(item.after_state)}</pre></section>` : ''}${item.result ? `<section><b>결과 및 검증</b><pre>${escapeText(item.result)}</pre></section>` : ''}${item.follow_up ? `<section><b>후속 조치</b><pre>${escapeText(item.follow_up)}</pre></section>` : ''}</div><footer><button data-history-action="toggle" type="button">상세 보기</button><button data-history-action="edit" type="button">수정</button><button class="danger" data-history-action="delete" type="button">삭제</button></footer></article>`).join('');
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}

document.querySelector('#newWorkHistory').addEventListener('click', () => { resetWorkHistoryForm(); document.querySelector('#workHistoryEditor').hidden = false; document.querySelector('#workHistoryEditor').scrollIntoView({behavior:'smooth'}); });
document.querySelector('#closeWorkHistory').addEventListener('click', () => { document.querySelector('#workHistoryEditor').hidden = true; });
document.querySelector('#searchWorkHistory').addEventListener('click', loadWorkHistories);
document.querySelector('#historySearch').addEventListener('keydown', event => { if (event.key === 'Enter') loadWorkHistories(); });
document.querySelector('#workHistoryForm').addEventListener('submit', async event => {
  event.preventDefault(); const id = document.querySelector('#workHistoryId').value; const button = event.submitter; button.disabled = true;
  try { const response = await fetch(id ? `/api/work-histories/${id}` : '/api/work-histories', {method:id ? 'PUT' : 'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(workHistoryPayload())}); const data = await response.json(); if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '입력값을 확인하세요.'); document.querySelector('#workHistoryEditor').hidden = true; showToast(id ? '작업 이력을 수정했습니다.' : '작업 이력을 등록했습니다.', '저장된 기록은 작업 이력에서 조회할 수 있습니다.'); await loadWorkHistories(); } catch (error) { showToast('작업 이력을 저장하지 못했습니다.', error.message); } finally { button.disabled = false; }
});
document.querySelector('#workHistoryList').addEventListener('click', async event => {
  const button = event.target.closest('[data-history-action]'); if (!button) return; const card = button.closest('[data-history-id]'); const id = card.dataset.historyId;
  if (button.dataset.historyAction === 'toggle') { const detail = card.querySelector('.history-detail'); detail.hidden = !detail.hidden; button.textContent = detail.hidden ? '상세 보기' : '상세 닫기'; return; }
  if (button.dataset.historyAction === 'delete') { if (!confirm('이 작업 이력을 삭제하시겠습니까?')) return; const response = await fetch(`/api/work-histories/${id}`, {method:'DELETE'}); if (response.ok) { showToast('작업 이력을 삭제했습니다.', '삭제한 기록은 복구할 수 없습니다.'); loadWorkHistories(); } return; }
  const response = await fetch(`/api/work-histories/${id}`); const item = await response.json(); if (!response.ok) return showToast('작업 이력을 불러오지 못했습니다.', item.detail || '다시 시도하세요.');
  const values = {Title:item.title, Provider:item.provider_id || '', Type:item.work_type, Status:item.status, Operator:item.operator, Target:item.target, Ticket:item.ticket, StartedAt:localDateTimeValue(item.started_at), CompletedAt:item.completed_at ? localDateTimeValue(item.completed_at) : '', Description:item.description, Commands:item.commands, BeforeState:item.before_state, AfterState:item.after_state, Result:item.result, FollowUp:item.follow_up};
  historyFields.forEach(name => { if (name in values) document.querySelector(`#history${name}`).value = values[name] || ''; }); document.querySelector('#workHistoryId').value = id; document.querySelector('#workHistoryFormTitle').textContent = '작업 이력 수정'; document.querySelector('#workHistoryEditor').hidden = false; document.querySelector('#workHistoryEditor').scrollIntoView({behavior:'smooth'});
});

document.querySelector('#menuSettingsList').addEventListener('change', event => {
  if (!event.target.matches('input[type="checkbox"]')) return;
  if (event.target.checked) visibleMenus.add(event.target.value); else visibleMenus.delete(event.target.value);
  saveMenuPreferences();
});
document.querySelector('#selectAllMenus').addEventListener('click', () => { visibleMenus = new Set(configurableMenus.map(menu => menu[0])); saveMenuPreferences(); });
document.querySelector('#clearAllMenus').addEventListener('click', () => { visibleMenus.clear(); saveMenuPreferences(); });
applyMenuPreferences();
renderMenuSettings();

function renderCheck(data) {
  const metrics = data.metrics || {};
  document.querySelector('#checkStatus').innerHTML = data.status === 'healthy' ? '정상 <small>/ 점검 완료</small>' : '주의 <small>/ 확인 필요</small>';
  document.querySelector('#checkMessage').textContent = data.warnings?.[0] || '확인된 경고 없음';
  document.querySelector('#cpuValue').textContent = metrics.cpu_cores ?? '-';
  document.querySelector('#memoryValue').textContent = `${metrics.memory_used_percent ?? '-'}%`;
  document.querySelector('#diskValue').textContent = `${metrics.disk_used_percent ?? '-'}%`;
  document.querySelector('#memoryMessage').textContent = metrics.hostname ? `${metrics.hostname} 기준` : '점검 완료';
  document.querySelector('#diskMessage').textContent = data.warnings?.find(value => value.includes('디스크')) || '정상 범위';
}

function showToast(title, description) {
  toast.querySelector('strong').textContent = title;
  toast.querySelector('small').textContent = description;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 3500);
}

function updateClock() {
  const now = new Date();
  clock.textContent = new Intl.DateTimeFormat('ko-KR', {
    year:'numeric', month:'2-digit', day:'2-digit', hour:'2-digit', minute:'2-digit', hour12:false
  }).format(now).replace(/\. /g, '. ');
}
updateClock();
setInterval(updateClock, 30000);
loadProviders();
renderInspectionChecklist();
renderInspectionSelection();
const initialPage = location.hash === '#daily-inspection' ? 'daily-inspection' : (location.hash === '#infrastructure' ? 'infrastructure' : (location.hash === '#alerts' ? 'alerts' : (location.hash === '#history' ? 'history' : (location.hash === '#settings' ? 'settings' : 'dashboard'))));
showPage(initialPage);
if (initialPage === 'history') loadWorkHistories();
if (initialPage === 'alerts') loadAlerts(); else loadAlertSummary();
