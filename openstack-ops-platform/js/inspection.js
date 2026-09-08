// ===== 일일점검 =====
const inspectionGroups = [
  {title:'시스템 기본 점검', description:'Controller의 운영체제와 기본 자원 상태', items:[
    ['Resource','CPU 사용률','수집: top으로 노드별 사용률 확인 · 판정: 80% 이상 주의','cpu'], ['Resource','Memory 사용률','수집: MemTotal/Available 기반 실사용률 계산 · 판정: 80% 이상 주의','memory'], ['Resource','Disk 사용률','수집: df로 루트 파일시스템 용량 확인 · 판정: 80% 이상 주의','disk'],
    ['System','Chrony 동기화','수집: chronyc sources/tracking · 판정: 시간원 연결 및 동기화 실패 시 주의','chrony'], ['System','Bonding 인터페이스','대상: 전체 노드 중 /proc/net/bonding이 있는 노드 · 판정: Bond 또는 Slave MII 상태 Down이면 주의, 미구성 노드는 판정 제외','bonding'], ['System','Mount 상태','대상: Controller · 수집: findmnt로 /var/lib/{glance,cinder,nova} 마운트·fstab · 판정: fstab 등록 경로 미마운트 또는 NFS 등 네트워크 마운트 5초 무응답이면 주의 (Compute는 인스턴스 저장소 항목)','mount']
  ]},
  {title:'Middleware 점검', description:'고가용성 및 데이터베이스 클러스터 상태', items:[
    ['Clustering','PCS cluster','수집: pcs status · 판정: Offline/Stopped/Failed/Unclean 리소스 탐지','pcs'], ['Clustering','VIP 통신','수집: VIP ICMP 응답 · 판정: 패킷 손실 및 접근 실패 확인','vip'], ['Clustering','RabbitMQ cluster','수집: rabbitmqctl cluster_status · 판정: 노드·파티션·알람 이상 확인','rabbitmq'], ['Clustering','MySQL cluster','수집: wsrep_cluster_weight · 판정: Galera 구성원 수와 쿼럼 이상 확인','mysql'],
    ['Database','MySQL Host Blocked Errors','수집: performance_schema.host_cache의 COUNT_HOST_BLOCKED_ERRORS · 판정: 출력값이 모두 0이면 정상, 1 이상이면 주의, 행이 없으면 확인 불가','mysql_host_blocked_errors'],
    ['Database','WSREP Local Cert Failures','수집: wsrep_local_cert_failures Global Status · 판정: 0이면 정상, 1 이상이면 주의','wsrep_local_cert_failures']
  ]},
  {title:'OpenStack 서비스 점검', description:'서비스 및 에이전트 가용 상태', items:[
    ['Service','Endpoint','수집: openstack endpoint list · 판정: 서비스별 Endpoint 존재 여부 확인','endpoint'], ['Service','Nova','수집: compute service list · 판정: 서비스 Down/Disabled 탐지','nova'], ['Service','Neutron','수집: network agent list · 판정: 에이전트 Down 탐지','neutron'],
    ['Service','Cinder','수집: volume service list 표 분석 · 판정: State down 또는 Status disabled 서비스를 호스트·마지막 갱신 시각과 함께 표시, 서비스 없음·CLI 미설치는 확인 불가','cinder'], ['Service','Manila','수집: share service list 표 분석 · 판정: down/disabled 서비스를 호스트·마지막 갱신 시각과 함께 표시, 플러그인 미설치·서비스 미배포는 확인 불가','manila'], ['Service','Octavia','수집: loadbalancer API 조회 · 판정: 명령 실패와 오류 상태 탐지','octavia'], ['Service','Nova-compute','수집: 프로세스·systemd 상태 · 판정: Compute 노드의 nova-compute 비활성 탐지','nova_compute'],
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
let currentLogExclusions = [];
const logServiceLabels = {'':'전체 로그', nova:'Nova', neutron:'Neutron', cinder:'Cinder', glance:'Glance', manila:'Manila', octavia:'Octavia', masakari:'Masakari', swift:'Swift', heat:'Heat', system:'System'};
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
  set('#setupExceptionValue', `${currentExceptionRules.length}개`);
  set('#setupExceptionHint', `${currentExceptionRules.length ? `전체 노드 ${currentExceptionRules.length - nodeRules} · 특정 노드 ${nodeRules}` : '등록된 예외 없음'} · 로그 제외 ${currentLogExclusions.length}`);
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
  const againstSelect = document.querySelector('#diffAgainstSelect');
  if (againstSelect) {
    const previous = againstSelect.value;
    againstSelect.innerHTML = '<option value="">직전 점검</option>' + checkHistory.filter(entry => entry.id !== activeId).map(entry => `<option value="${escapeText(entry.id)}">${escapeText(formatDateTime(entry.checked_at))} · ${entry.status === 'healthy' ? '정상' : '주의'}</option>`).join('');
    againstSelect.value = checkHistory.some(entry => entry.id === previous) ? previous : '';
    diffAgainstId = againstSelect.value;
  }
  renderInspectionTrend();
}

const trendSeries = [['warning', '주의', entry => entry.summary?.items?.warning ?? 0], ['unavailable', '확인 불가', entry => entry.summary?.items?.unavailable ?? 0]];
let trendActiveIndex = -1;
let trendGeometry = {width:720, left:34, plotWidth:590};
// 건수 추이 표시 여부는 브라우저에 남긴다(알림 화면의 '원인별 묶어 보기'와 같은 방식).
const trendVisibleKey = 'okestro-inspection-trend';
function trendVisible() { try { return localStorage.getItem(trendVisibleKey) !== '0'; } catch (_) { return true; } }
function applyTrendVisibility() {
  const box = document.querySelector('#inspectionTrend');
  const toggle = document.querySelector('#trendToggle');
  const visible = trendVisible();
  if (toggle) toggle.checked = visible;
  if (box) box.hidden = !visible;
  return visible;
}
function renderInspectionTrend() {
  const box = document.querySelector('#inspectionTrend');
  if (!box) return;
  if (!applyTrendVisibility()) { trendActiveIndex = -1; return; }
  const points = [...checkHistory].reverse();
  const hovering = trendActiveIndex >= 0 && trendActiveIndex < points.length;
  const activeIndex = hovering ? trendActiveIndex : points.findIndex(entry => entry.id === (viewingCheckId || latestCheckId));
  trendGeometry = renderTrendChart(box, points, {activeIndex, heading:true});
  if (hovering && trendGeometry) showTrendTooltip(points, activeIndex);
}
function renderTrendChart(box, points, {activeIndex = -1, heading = true, minWidth = 480} = {}) {
  if (!box) return null;
  if (points.length < 2) { box.innerHTML = '<div class="empty-provider">점검이 2회 이상 쌓이면 주의·확인 불가 건수 추이를 표시합니다.</div>'; return null; }
  // Draw at the container's pixel width so axis text is never stretched.
  const width = Math.max(minWidth, Math.min(1400, (box.clientWidth || 760) - 40)), height = 170, left = 34, right = 96, top = 14, bottom = 26;
  const plotWidth = width - left - right, plotHeight = height - top - bottom;
  const maxValue = Math.max(1, ...points.flatMap(entry => trendSeries.map(series => series[2](entry))));
  const ticks = maxValue <= 4 ? maxValue : 4;
  const stepValue = Math.ceil(maxValue / ticks);
  const yMax = stepValue * ticks;
  const x = index => left + (points.length === 1 ? plotWidth / 2 : index / (points.length - 1) * plotWidth);
  const y = value => top + plotHeight - value / yMax * plotHeight;
  const shortDate = value => { const date = new Date(value); return `${String(date.getMonth() + 1).padStart(2, '0')}.${String(date.getDate()).padStart(2, '0')}`; };
  const gridlines = Array.from({length: ticks + 1}, (_, index) => index * stepValue).map(value => `<line class="grid" x1="${left}" y1="${y(value)}" x2="${left + plotWidth}" y2="${y(value)}"></line><text class="axis-label" x="${left - 6}" y="${y(value) + 3}" text-anchor="end">${value}</text>`).join('');
  const labelEvery = Math.max(1, Math.ceil(points.length / 6));
  const xLabels = points.map((entry, index) => (index % labelEvery === 0 || index === points.length - 1) ? `<text class="axis-label" x="${x(index)}" y="${height - 8}" text-anchor="${index === 0 ? 'start' : (index === points.length - 1 ? 'end' : 'middle')}">${shortDate(entry.checked_at)}</text>` : '').join('');
  const lines = trendSeries.map(([cls, , valueOf]) => `<polyline class="series ${cls}" points="${points.map((entry, index) => `${x(index)},${y(valueOf(entry))}`).join(' ')}"></polyline>`).join('');
  const markers = trendSeries.map(([cls, , valueOf]) => points.map((entry, index) => `<circle class="marker ${cls}${index === activeIndex ? ' active' : ''}" cx="${x(index)}" cy="${y(valueOf(entry))}" r="4"></circle>`).join('')).join('');
  const last = points[points.length - 1];
  const endLabels = (() => {
    const placed = trendSeries.map(([cls, label, valueOf]) => ({cls, label, value: valueOf(last), yPos: y(valueOf(last))}));
    placed.sort((a, b) => a.yPos - b.yPos);
    for (let index = 1; index < placed.length; index += 1) if (placed[index].yPos - placed[index - 1].yPos < 13) placed[index].yPos = placed[index - 1].yPos + 13;
    return placed.map(item => `<line class="end-key ${item.cls}" x1="${left + plotWidth + 6}" y1="${item.yPos}" x2="${left + plotWidth + 16}" y2="${item.yPos}"></line><text class="end-label" x="${left + plotWidth + 21}" y="${item.yPos + 3.5}">${item.label} ${item.value}</text>`).join('');
  })();
  const crosshair = activeIndex >= 0 ? `<line class="crosshair" x1="${x(activeIndex)}" y1="${top}" x2="${x(activeIndex)}" y2="${top + plotHeight}"></line>` : '';
  const columnWidth = points.length > 1 ? plotWidth / (points.length - 1) : plotWidth;
  const hits = points.map((entry, index) => `<rect class="hit" data-trend-index="${index}" x="${x(index) - columnWidth / 2}" y="${top}" width="${columnWidth}" height="${plotHeight}"><title>${escapeText(formatDateTime(entry.checked_at))} · 주의 ${entry.summary?.items?.warning ?? 0} · 확인 불가 ${entry.summary?.items?.unavailable ?? 0}</title></rect>`).join('');
  const previous = points[points.length - 2];
  const deltaText = trendSeries.map(([cls, label, valueOf]) => { const delta = valueOf(last) - valueOf(previous); return `<span class="${cls}"><i aria-hidden="true"></i>${label} <b>${valueOf(last)}</b> (직전 ${delta > 0 ? '+' : ''}${delta})</span>`; }).join('');
  const headingHtml = heading
    ? `<div class="trend-heading"><div><strong>주의·확인 불가 건수 추이</strong><small>최근 ${points.length}회 · ${escapeText(shortDate(points[0].checked_at))} ~ ${escapeText(shortDate(last.checked_at))} · 점을 클릭하면 해당 결과를 조회합니다</small></div><div class="trend-legend">${deltaText}</div></div>`
    : `<div class="trend-heading"><div class="trend-legend">${deltaText}</div></div>`;
  box.innerHTML = `${headingHtml}<div class="trend-plot"><svg viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" preserveAspectRatio="xMinYMin meet" role="img" aria-label="최근 ${points.length}회 점검의 주의·확인 불가 건수">${gridlines}${xLabels}${crosshair}${lines}${markers}${endLabels}${hits}</svg>${box.id === 'inspectionTrend' ? '<div class="trend-tooltip" id="trendTooltip" hidden></div>' : ''}</div>`;
  return {width, left, plotWidth};
}
let trendResizeTimer = null;
window.addEventListener('resize', () => { clearTimeout(trendResizeTimer); trendResizeTimer = setTimeout(() => { renderInspectionTrend(); if (currentOverview) renderDashboardTrend(currentOverview); }, 150); });
function showTrendTooltip(points, index) {
  const tooltip = document.querySelector('#trendTooltip');
  const plot = tooltip?.parentElement;
  if (!tooltip || !plot) return;
  const entry = points[index];
  const summary = entry.summary || {items:{}, nodes:{}};
  tooltip.innerHTML = '';
  const title = document.createElement('strong'); title.textContent = formatDateTime(entry.checked_at); tooltip.appendChild(title);
  trendSeries.forEach(([cls, label, valueOf]) => { const row = document.createElement('div'); row.className = cls; const key = document.createElement('i'); const value = document.createElement('b'); value.textContent = valueOf(entry); const name = document.createElement('span'); name.textContent = label; row.append(key, value, name); tooltip.appendChild(row); });
  const meta = document.createElement('small');
  meta.textContent = `${summary.trigger === 'scheduled' ? '예약' : '수동'} · 항목 ${summary.items?.total ?? 0} · 문제 노드 ${summary.nodes?.problem ?? 0}/${summary.nodes?.total ?? 0}${summary.duration_seconds != null ? ` · ${formatDuration(summary.duration_seconds)}` : ''}`;
  tooltip.appendChild(meta);
  tooltip.hidden = false;
  const ratio = points.length === 1 ? 0.5 : index / (points.length - 1);
  const plotBox = plot.getBoundingClientRect();
  const anchor = trendGeometry.left + ratio * trendGeometry.plotWidth;
  tooltip.style.left = `${Math.max(0, Math.min(plotBox.width - tooltip.offsetWidth, anchor + (ratio > 0.6 ? -tooltip.offsetWidth - 12 : 12)))}px`;
}
document.querySelector('#inspectionTrend').addEventListener('pointermove', event => {
  const hit = event.target.closest('[data-trend-index]');
  if (!hit) return;
  const index = Number(hit.dataset.trendIndex);
  if (index === trendActiveIndex) return;
  trendActiveIndex = index; renderInspectionTrend();
});
document.querySelector('#inspectionTrend').addEventListener('pointerleave', () => { trendActiveIndex = -1; renderInspectionTrend(); });
document.querySelector('#inspectionTrend').addEventListener('click', event => {
  const hit = event.target.closest('[data-trend-index]');
  if (!hit || !inspectionProviderSelect.value) return;
  const entry = [...checkHistory].reverse()[Number(hit.dataset.trendIndex)];
  if (entry) viewCheck(inspectionProviderSelect.value, entry.id);
});
document.querySelector('#inspectionTrend').addEventListener('keydown', event => {
  const count = checkHistory.length;
  if (count < 2) return;
  if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
    event.preventDefault();
    const current = trendActiveIndex >= 0 ? trendActiveIndex : count - 1;
    trendActiveIndex = Math.max(0, Math.min(count - 1, current + (event.key === 'ArrowRight' ? 1 : -1)));
    renderInspectionTrend();
  } else if (event.key === 'Enter' && trendActiveIndex >= 0 && inspectionProviderSelect.value) {
    const entry = [...checkHistory].reverse()[trendActiveIndex];
    if (entry) viewCheck(inspectionProviderSelect.value, entry.id);
  }
});

let diffAgainstId = '';
async function loadCheckDiff(providerId, checkId, against = diffAgainstId) {
  currentDiff = null; currentDiffByKey = {};
  if (!providerId || !checkId) { renderDiffSummary(); renderSummaryDeltas(); renderInspectionChecklist(); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks/${encodeURIComponent(checkId)}/diff${against && against !== checkId ? `?against=${encodeURIComponent(against)}` : ''}`, {cache:'no-store'});
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

const summaryDeltaLabels = {all:'전체 항목', healthy:'정상', warning:'주의', unavailable:'확인 불가', pending:'수집 대기'};

function summaryDeltaItems(filter) {
  if (!currentDiff?.previous) return {entered:[], left:[]};
  const items = currentDiff.items || [];
  if (filter === 'all') return {entered:items.filter(item => item.change === 'added'), left:items.filter(item => item.change === 'removed')};
  const matches = status => status != null && inspectionStatusMatches(filter, status);
  return {entered:items.filter(item => matches(item.after) && !matches(item.before)), left:items.filter(item => matches(item.before) && !matches(item.after))};
}

function renderSummaryDeltas() {
  closeSummaryDeltaPopover();
  const counts = currentDiff?.previous ? currentDiff.counts : null;
  const apply = (id, filter, value) => {
    const element = document.querySelector(id);
    if (!element) return;
    if (counts == null || value == null) { element.hidden = true; return; }
    element.hidden = false;
    element.className = `summary-delta ${value > 0 ? 'up' : (value < 0 ? 'down' : 'same')}`;
    const {entered, left} = summaryDeltaItems(filter);
    const moved = entered.length + left.length;
    let text = value === 0 ? '직전과 동일' : `직전 대비 ${value > 0 ? '+' : ''}${value}`;
    if (value === 0 && moved) text += ` · 변동 ${moved}건`;
    element.textContent = text;
    element.dataset.deltaFilter = filter;
    if (moved) {
      element.classList.add('clickable');
      element.setAttribute('role', 'button'); element.setAttribute('tabindex', '0'); element.setAttribute('aria-expanded', 'false');
      element.title = `클릭하면 직전 점검 대비 늘거나 줄어든 항목을 표시합니다 (+${entered.length} / −${left.length})`;
      element.insertAdjacentHTML('beforeend', '<i aria-hidden="true">▾</i>');
    } else { element.removeAttribute('role'); element.removeAttribute('tabindex'); element.removeAttribute('aria-expanded'); element.removeAttribute('title'); }
  };
  apply('#totalDelta', 'all', counts ? (counts.added || 0) - (counts.removed || 0) : null);
  apply('#healthyDelta', 'healthy', counts ? counts.healthy_delta : null);
  apply('#warningDelta', 'warning', counts ? counts.warning_delta : null);
  apply('#unavailableDelta', 'unavailable', counts ? counts.unavailable_delta : null);
  apply('#pendingDelta', 'pending', null);
}

function closeSummaryDeltaPopover() {
  document.querySelector('#summaryDeltaPopover')?.remove();
  document.querySelectorAll('.summary-delta.open').forEach(element => { element.classList.remove('open'); element.setAttribute('aria-expanded', 'false'); });
}

function toggleSummaryDeltaPopover(element) {
  const wasOpen = element.classList.contains('open');
  closeSummaryDeltaPopover();
  if (wasOpen || !currentDiff?.previous) return;
  const filter = element.dataset.deltaFilter;
  const {entered, left} = summaryDeltaItems(filter);
  const names = itemNameMap();
  const labels = inspectionStatusLabels;
  const label = summaryDeltaLabels[filter] || filter;
  const list = (items, cls) => items.map(item => `<button type="button" data-delta-key="${escapeText(item.key)}"><b class="${cls}">${cls === 'up' ? '+' : '−'}</b><span>${escapeText(names[item.key] || item.key)}</span><em>${escapeText(labels[item.before] || '없음')} → ${escapeText(labels[item.after] || '없음')}</em></button>`).join('');
  const enteredTitle = filter === 'all' ? '이번 점검에 추가된 항목' : `새로 ${label}(으)로 바뀐 항목`;
  const leftTitle = filter === 'all' ? '이번 점검에서 제외된 항목' : `${label}에서 벗어난 항목`;
  const popover = document.createElement('div');
  popover.id = 'summaryDeltaPopover';
  popover.className = 'summary-delta-popover';
  popover.setAttribute('role', 'dialog');
  popover.setAttribute('aria-label', `${label} 직전 대비 변화`);
  popover.innerHTML = `<header><strong>${escapeText(label)} 직전 대비 변화</strong><small>${escapeText(formatDateTime(currentDiff.previous.checked_at))} → ${escapeText(formatDateTime(currentDiff.current.checked_at))}</small></header>${entered.length ? `<section><b class="up">${enteredTitle} ${entered.length}</b>${list(entered, 'up')}</section>` : ''}${left.length ? `<section><b class="down">${leftTitle} ${left.length}</b>${list(left, 'down')}</section>` : ''}<p>항목을 클릭하면 결과 목록에서 해당 행을 표시합니다.</p>`;
  element.closest('article').appendChild(popover);
  element.classList.add('open');
  element.setAttribute('aria-expanded', 'true');
  popover.querySelector('[data-delta-key]')?.focus();
}

const inspectionSummarySection = document.querySelector('.inspection-summary');
inspectionSummarySection.addEventListener('click', event => {
  const item = event.target.closest('[data-delta-key]');
  if (item) { event.stopPropagation(); const key = item.dataset.deltaKey; closeSummaryDeltaPopover(); focusInspectionItem(key); return; }
  if (event.target.closest('#summaryDeltaPopover')) { event.stopPropagation(); return; }
  const delta = event.target.closest('.summary-delta.clickable');
  if (delta) { event.stopPropagation(); toggleSummaryDeltaPopover(delta); }
}, true);
inspectionSummarySection.addEventListener('keydown', event => {
  if (event.key !== 'Enter' && event.key !== ' ') { if (event.key === 'Escape' && document.querySelector('#summaryDeltaPopover')) { event.stopPropagation(); closeSummaryDeltaPopover(); } return; }
  const item = event.target.closest('[data-delta-key]');
  if (item) { event.preventDefault(); event.stopPropagation(); const key = item.dataset.deltaKey; closeSummaryDeltaPopover(); focusInspectionItem(key); return; }
  if (event.target.closest('#summaryDeltaPopover')) { event.stopPropagation(); return; }
  const delta = event.target.closest('.summary-delta.clickable');
  if (delta) { event.preventDefault(); event.stopPropagation(); toggleSummaryDeltaPopover(delta); }
}, true);
document.addEventListener('click', event => { if (document.querySelector('#summaryDeltaPopover') && !event.target.closest('#summaryDeltaPopover') && !event.target.closest('.summary-delta')) closeSummaryDeltaPopover(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape') closeSummaryDeltaPopover(); });

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
  const names = itemNameMap();
  if (!inspectionGroups.some(group => group.items.some(item => item[3] === key))) return showToast('표시할 수 없는 항목입니다.', `${names[key] || key} 항목은 현재 점검 항목 목록에 없습니다.`);
  const status = (inspectionResults[key] || {status:'pending'}).status;
  let changed = false;
  if (!selectedInspectionKeys.has(key)) {
    selectedInspectionKeys.add(key);
    renderInspectionSelection();
    changed = true;
    showToast('항목을 결과 목록에 표시했습니다.', `${names[key] || key} 항목을 점검 항목 선택에 추가했습니다.${status === 'pending' ? ' 이번 결과에는 점검되지 않은 항목입니다.' : ''}`);
  }
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

const reportFormats = {pdf: {label:'PDF', endpoint:'/api/reports/inspection.pdf', extension:'pdf'}, xlsx: {label:'Excel', endpoint:'/api/reports/inspection.xlsx', extension:'xlsx'}};
async function downloadInspectionReport(format = 'pdf') {
  const spec = reportFormats[format] || reportFormats.pdf;
  const rows = inspectionReportRows();
  if (!rows.length) return showToast(`${spec.label}로 저장할 점검 내용이 없습니다.`, '일일점검을 먼저 실행하세요.');
  const button = document.querySelector(format === 'xlsx' ? '#downloadInspectionReportXlsx' : '#downloadInspectionReportPdf');
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
  const fileName = `일일점검_${provider.replace(/[\\/:*?"<>|\s]+/g, '_')}_${stamp}.${spec.extension}`;
  const idleLabel = button.textContent;
  button.disabled = true; button.textContent = `${spec.label} 생성 중…`;
  try {
    const response = await fetch(spec.endpoint, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    if (!response.ok) { const data = await response.json().catch(() => ({})); throw new Error(typeof data.detail === 'string' ? data.detail : `서버 오류 (${response.status})`); }
    const url = URL.createObjectURL(await response.blob());
    const link = document.createElement('a'); link.href = url; link.download = fileName; document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
    showToast(`${spec.label}을 저장했습니다.`, `${fileName} · ${rows.length}개 항목`);
  } catch (error) { showToast(`${spec.label} 저장에 실패했습니다.`, error.message); } finally { button.disabled = false; button.textContent = idleLabel; }
}
const downloadInspectionReportPdf = () => downloadInspectionReport('pdf');

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
document.querySelector('#downloadInspectionReportXlsx').addEventListener('click', () => downloadInspectionReport('xlsx'));
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
  if (action.dataset.rowAction === 'rerun') {
    if (!viewingCheckId) executeInspection(action, inspectionProviderSelect.value, [key]);
    else showToast('과거 결과를 조회 중입니다.', '최신 결과 보기로 돌아간 뒤 재점검하세요.');
  } else if (action.dataset.rowAction === 'exclude-message') {
    const service = (action.dataset.service || '').replace(/_log$/, '');
    const select = document.querySelector('#logExclusionService');
    select.value = [...select.options].some(option => option.value === service) ? service : '';
    document.querySelector('#logExclusionPattern').value = messageToPattern(action.dataset.message || '');
    openSetupPanel('exceptions', true);
    document.querySelector('.log-exclusion-section').scrollIntoView({behavior:'smooth', block:'start'});
    setTimeout(() => document.querySelector('#logExclusionPattern').focus(), 350);
    showToast('제외 패턴을 채웠습니다.', '메시지의 가변 부분은 .* 로 바꿨습니다. 사유를 입력하고 등록하세요.');
  } else if (action.dataset.rowAction === 'exception') {
    exceptionItem.value = key; exceptionNode.value = nodeFilter && [...exceptionNode.options].some(option => option.value === nodeFilter) ? nodeFilter : ''; exceptionReason.value = '';
    openSetupPanel('exceptions', true);
    document.querySelector('.inspection-exceptions').scrollIntoView({behavior:'smooth', block:'start'});
    setTimeout(() => exceptionReason.focus(), 350);
    showToast(`${names[key] || key} 예외 등록`, '예외 사유를 입력한 뒤 예외 등록 버튼을 누르세요.');
  } else if (action.dataset.rowAction === 'log-exclusion') {
    const service = key.replace(/_log$/, '');
    const select = document.querySelector('#logExclusionService');
    select.value = [...select.options].some(option => option.value === service) ? service : '';
    document.querySelector('#logExclusionPattern').value = '';
    openSetupPanel('exceptions', true);
    document.querySelector('.log-exclusion-section').scrollIntoView({behavior:'smooth', block:'start'});
    setTimeout(() => document.querySelector('#logExclusionPattern').focus(), 350);
    showToast(`${names[key] || key} 제외 패턴 등록`, '상세 결과의 오류 메시지 중 무시할 부분을 정규식으로 입력하세요.');
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
  // Provider-scoped inspection settings ride along with the custom checks, which every provider change reloads.
  loadProviderInspectionSettings(providerId);
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

async function executeInspection(sourceButton, selectedProvider, keys = null) {
  if (!selectedProvider) return showToast('공급자를 먼저 선택하세요.', '공급자 연결 메뉴에서 환경을 등록할 수 있습니다.');
  const runKeys = keys ? new Set(keys) : selectedInspectionKeys;
  const partial = Boolean(keys);
  if (!runKeys.size) return showToast('점검 항목을 선택하세요.', '하나 이상의 항목을 선택해야 합니다.');
  const idleHtml = sourceButton.innerHTML;
  sourceButton.disabled = true;
  sourceButton.innerHTML = '<span>↻</span> 점검 실행 중';
  showInspectionProgress({running:true, stage:'preparing', message:partial ? `${runKeys.size}개 항목만 다시 점검합니다.` : '점검 요청을 준비하고 있습니다.', current_items:[...runKeys], percent:3, started_at:new Date().toISOString()});
  const progressTimer = window.setInterval(() => loadInspectionProgress(selectedProvider), 700);
  let inspectionSucceeded = false;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(selectedProvider)}/checks`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({selected_items:[...runKeys]})});
    const data = await response.json();
    if (!response.ok) { const error = new Error(data.detail || '점검 실행에 실패했습니다.'); error.status = response.status; throw error; }
    latestCheckId = data.check_id; viewingCheckId = null; nodeFilter = '';
    renderInspectionResult({...data, _checked_at:data.finished_at}, partial);
    loadOverview(selectedProvider);
    inspectionSucceeded = true;
    loadAlertSummary();
    loadCheckHistory(selectedProvider);
    loadCheckDiff(selectedProvider, data.check_id);
    loadCheckSchedule(selectedProvider);
    showToast('일일점검이 완료되었습니다.', data.status === 'healthy' ? '현재 확인된 경고가 없습니다.' : `${data.warnings.length}개 경고를 확인하세요.`);
  } catch (error) {
    if (error.status === 409 && /취소/.test(error.message)) {
      showToast('점검을 취소했습니다.', '취소 전까지의 결과는 저장되지 않았습니다.');
      await loadInspectionProgress(selectedProvider);
    } else if (error.status === 409) {
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
    sourceButton.innerHTML = sourceButton === dailyRunInspection ? '<span>↻</span> 전체 점검 실행' : (sourceButton === runInspection ? '<span>↻</span> 일일점검 실행' : idleHtml);
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
  const stageLabels = {idle:'대기', preparing:'준비', nodes:'노드 점검', custom:'사용자 정의', openstack:'OpenStack 점검', aggregating:'결과 집계', completed:'완료', failed:'실패', cancelling:'취소 중', cancelled:'취소됨'};
  const percent = Math.max(0, Math.min(100, Number(progress.percent) || 0));
  panel.hidden = false;
  panel.classList.toggle('completed', !progress.running && progress.stage === 'completed');
  panel.classList.toggle('failed', progress.stage === 'failed' || progress.stage === 'cancelled');
  const cancelButton = document.querySelector('#cancelInspection');
  cancelButton.hidden = !progress.running || progress.stage === 'cancelling';
  cancelButton.disabled = progress.stage === 'cancelling';
  const nodeBox = document.querySelector('#inspectionProgressNodes');
  const nodeStates = progress.nodes && Object.keys(progress.nodes).length ? progress.nodes : null;
  nodeBox.hidden = !nodeStates || !progress.running;
  if (nodeStates && progress.running) {
    const stateLabels = {pending:'대기', running:'점검 중', done:'완료', failed:'실패'};
    const order = {running:0, pending:1, failed:2, done:3};
    nodeBox.innerHTML = `<b>노드 ${progress.node_done ?? 0}/${progress.node_total ?? Object.keys(nodeStates).length}대 완료</b>` + Object.entries(nodeStates).sort((a, b) => (order[a[1].state] ?? 9) - (order[b[1].state] ?? 9) || a[0].localeCompare(b[0])).map(([hostname, state]) => `<span class="node-progress ${escapeText(state.state)}" title="${escapeText(state.role || '')}${state.seconds != null ? ` · ${state.seconds}초` : ''}"><i></i>${escapeText(hostname)}<small>${stateLabels[state.state] || state.state}${state.state === 'done' && state.seconds != null ? ` ${Math.round(state.seconds)}초` : ''}</small></span>`).join('');
  }
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
document.querySelector('#cancelInspection').addEventListener('click', async event => {
  const providerId = inspectionProviderSelect.value || providerSelect.value;
  if (!providerId || !window.confirm('실행 중인 점검을 취소할까요? 지금까지 수집한 결과는 저장되지 않습니다.')) return;
  event.currentTarget.disabled = true;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/checks/cancel`, {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '취소하지 못했습니다.');
    showToast('점검 취소를 요청했습니다.', '실행 중인 SSH 명령이 끝나는 대로 멈춥니다.');
  } catch (error) { showToast('취소하지 못했습니다.', error.message); event.currentTarget.disabled = false; }
});
dailyRunInspection.addEventListener('click', () => executeInspection(dailyRunInspection, inspectionProviderSelect.value));

async function loadLatestCheck(providerId) {
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/latest-check`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '최근 점검 결과를 불러오지 못했습니다.');
    viewingCheckId = null; nodeFilter = '';
    if (data.latest_check) {
      latestCheckId = data.latest_check.id;
      const latest = {...data.latest_check.result, status:data.latest_check.status, _checked_at:data.latest_check.checked_at};
      renderInspectionResult(latest);
      loadCheckDiff(providerId, data.latest_check.id);
    } else {
      latestCheckId = null; inspectionResults = {}; currentDiff = null; currentDiffByKey = {};
      renderNodeCheckSummary([]); renderDiffSummary(); renderSummaryDeltas(); renderInspectionChecklist();
      document.querySelector('#inspectionUpdatedAt').textContent = '아직 실행된 점검이 없습니다.';
      exportInspectionPdf.disabled = true; document.querySelector('#openInspectionReport').disabled = true;
    }
    loadCheckHistory(providerId);
    loadCheckSchedule(providerId);
    loadOverview(providerId);
  } catch (error) { showToast('최근 점검 결과를 불러오지 못했습니다.', error.message); }
}

providerSelect.addEventListener('change', () => {
  inspectionProviderSelect.value = providerSelect.value;
  infrastructureProviderSelect.value = providerSelect.value;
  monitoringProviderSelect.value = providerSelect.value;
  if (!providerSelect.value) loadOverview('');
  if (providerSelect.value) loadProviderNodes(providerSelect.value);
  loadCheckExceptions(providerSelect.value);
  loadCustomChecks(providerSelect.value);
  if (providerSelect.value) loadLatestCheck(providerSelect.value);
});
inspectionProviderSelect.addEventListener('change', () => {
  providerSelect.value = inspectionProviderSelect.value;
  infrastructureProviderSelect.value = inspectionProviderSelect.value;
  monitoringProviderSelect.value = inspectionProviderSelect.value;
  loadProviderNodes(inspectionProviderSelect.value);
  loadCheckExceptions(inspectionProviderSelect.value);
  loadCustomChecks(inspectionProviderSelect.value);
  latestCheckId = null; viewingCheckId = null; nodeFilter = '';
  if (inspectionProviderSelect.value) loadLatestCheck(inspectionProviderSelect.value);
  else { checkHistory = []; currentDiff = null; currentDiffByKey = {}; inspectionResults = {}; renderCheckHistory(); renderStatusBanner(); renderDiffSummary(); renderSummaryDeltas(); renderNodeCheckSummary([]); renderInspectionChecklist(); loadCheckSchedule(''); loadOverview(''); }
});
infrastructureProviderSelect.addEventListener('change', () => {
  providerSelect.value = infrastructureProviderSelect.value;
  inspectionProviderSelect.value = infrastructureProviderSelect.value;
  monitoringProviderSelect.value = infrastructureProviderSelect.value;
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
dashboardDiscoverCluster.addEventListener('click', () => {
  if (!providerSelect.value) return showToast('공급자를 먼저 선택하세요.', '탐색할 OpenStack 환경을 선택한 뒤 다시 누르세요.');
  loadProviderNodes(providerSelect.value, true);
});
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
    dashboardNodeCount.hidden = true;
    return;
  }
  discoverCluster.disabled = true;
  dashboardDiscoverCluster.disabled = true;
  if (discover) {
    discoverCluster.textContent = '탐색 중...';
    dashboardNodeCount.hidden = false; dashboardNodeCount.className = ''; dashboardNodeCount.textContent = '탐색 중';
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
    dashboardNodeCount.hidden = false;
    dashboardNodeCount.className = data.nodes.length ? '' : 'empty';
    dashboardNodeCount.textContent = data.nodes.length ? `${data.nodes.length}대` : '미탐색';
    const warnings = data.warnings || [];
    warning.hidden = !warnings.length;
    warning.textContent = warnings.join(' ');
    if (discover) showToast('클러스터 탐색이 완료되었습니다.', `Controller ${data.nodes.filter(node => node.role === 'controller').length}대 · Compute ${data.nodes.filter(node => node.role === 'compute').length}대`);
  } catch (error) {
    list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`;
    warning.hidden = true;
    updateNodeCounts([]);
    dashboardNodeCount.hidden = false; dashboardNodeCount.className = 'empty'; dashboardNodeCount.textContent = discover ? '탐색 실패' : '미탐색';
    if (discover) showToast('클러스터 탐색에 실패했습니다.', error.message);
  } finally {
    discoverCluster.disabled = false;
    dashboardDiscoverCluster.disabled = false;
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

async function loadLogExclusions(providerId) {
  const list = document.querySelector('#logExclusionList');
  const count = document.querySelector('#logExclusionCount');
  if (!providerId) { currentLogExclusions = []; count.textContent = '0'; list.innerHTML = '<div class="empty-provider">공급자를 선택하세요.</div>'; renderSetupCards(); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/log-exclusions`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '제외 패턴을 불러오지 못했습니다.');
    currentLogExclusions = data.exclusions;
    count.textContent = data.exclusions.length;
    list.innerHTML = data.exclusions.length ? data.exclusions.map(rule => `<article><span class="exception-scope">${escapeText(logServiceLabels[rule.service] || rule.service)}</span><code title="${escapeText(rule.pattern)}">${escapeText(rule.pattern)}</code><span>${escapeText(rule.reason)}</span><button type="button" data-exclusion-id="${escapeText(rule.id)}">삭제</button></article>`).join('') : '<div class="empty-provider">등록된 제외 패턴이 없습니다. 반복되는 무해한 오류 메시지를 정규식으로 등록하면 다음 점검부터 건수에서 제외됩니다.</div>';
    renderSetupCards();
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
document.querySelector('#logExclusionForm').addEventListener('submit', async event => {
  event.preventDefault();
  const providerId = inspectionProviderSelect.value;
  if (!providerId) return showToast('공급자를 먼저 선택하세요.', '제외 패턴은 공급자별로 저장됩니다.');
  const payload = {service:document.querySelector('#logExclusionService').value, pattern:document.querySelector('#logExclusionPattern').value.trim(), reason:document.querySelector('#logExclusionReason').value.trim()};
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/log-exclusions`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '입력값을 확인하세요.');
    document.querySelector('#logExclusionPattern').value = ''; document.querySelector('#logExclusionReason').value = '';
    await loadLogExclusions(providerId);
    showToast('로그 제외 패턴을 등록했습니다.', '다음 점검부터 일치하는 로그 줄이 오류 건수에서 제외됩니다.');
  } catch (error) { showToast('제외 패턴을 등록하지 못했습니다.', error.message); }
});
document.querySelector('#logExclusionList').addEventListener('click', async event => {
  const button = event.target.closest('button[data-exclusion-id]');
  if (!button) return;
  const providerId = inspectionProviderSelect.value;
  const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/log-exclusions/${encodeURIComponent(button.dataset.exclusionId)}`, {method:'DELETE'});
  if (response.ok) { await loadLogExclusions(providerId); showToast('제외 패턴을 삭제했습니다.', '다음 점검부터 해당 로그 줄이 다시 집계됩니다.'); }
  else showToast('제외 패턴 삭제에 실패했습니다.', '잠시 후 다시 시도하세요.');
});

async function loadCheckExceptions(providerId) {
  const list = document.querySelector('#exceptionList');
  loadLogExclusions(providerId);
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

// Turns one log line into a permissive regex: timestamps, ids and numbers become wildcards so one rule covers the recurring message.
function messageToPattern(message) {
  let text = String(message).replace(/^\s*\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}[.,]?\d*\s*/, '').replace(/^\s*\d+\s+(DEBUG|INFO|WARNING|ERROR|CRITICAL)\s+/, '').trim();
  text = text.slice(0, 220);
  text = text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  text = text.replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, '.*').replace(/req-[0-9a-f-]+/gi, 'req-.*').replace(/\b\d{3,}\b/g, '\\d+').replace(/(\.\*\s*){2,}/g, '.*');
  return text;
}
function logNodeSections(node, key = '') {
  const sections = [];
  if (node.new_output) sections.push(`<div class="log-section new"><b>신규·변경 오류 ${Number(node.new_count) || 0}건</b><pre>${escapeText(groupRepeatedLogLines(node.new_output))}</pre></div>`);
  if (node.persistent_output) {
    const top = (node.top_messages || []).map(entry => `${entry.count}회 · ${entry.message}`).join('\n');
    const quick = (node.top_messages || []).slice(0, 5).map(entry => `<li><button type="button" data-row-action="exclude-message" data-key="${escapeText(key)}" data-service="${escapeText(key)}" data-message="${escapeText(entry.message)}" title="이 메시지를 제외 패턴으로 등록합니다">제외 패턴</button><span>${entry.count}회 · ${escapeText(entry.message)}</span></li>`).join('');
    sections.push(`<div class="log-section persistent"><b>지속 오류 ${Number(node.persistent_count) || 0}건 <small>전전날에도 발생 · 표본 기준 · 상위 메시지</small></b>${quick ? `<ul class="log-quick-exclude">${quick}</ul>` : `<pre>${escapeText(top || groupRepeatedLogLines(node.persistent_output))}</pre>`}<details class="log-section-all"><summary>지속 오류 표본 전체 보기</summary><pre>${escapeText(groupRepeatedLogLines(node.persistent_output))}</pre></details></div>`);
  }
  if (!sections.length) sections.push(`<pre>${escapeText(node.note || (node.compacted ? '보관 정책에 따라 원본 출력이 정리되었습니다.' : '일치하는 오류 로그 없음'))}</pre>`);
  return sections.join('');
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

function renderInspectionResult(data, merge = false) {
  const metrics = data.metrics || {};
  if (merge && data.items) {
    // A single-item re-run: keep everything else on screen and only replace the re-checked items.
    inspectionResults = {...inspectionResults, ...data.items};
    Object.keys(data.items).forEach(key => selectedInspectionKeys.add(key));
    document.querySelector('#inspectionUpdatedAt').textContent = `부분 재점검: ${formatDateTime(data._checked_at || new Date())}`;
    renderInspectionSelection();
    renderInspectionChecklist();
    return;
  }
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

function collectIssueReportItems() {
  const issueStatuses = new Set(['warning', 'unavailable']);
  const issueItems = inspectionGroups.flatMap(group => group.items
    .filter(([, , , key]) => key !== 'kernel_errors' && issueStatuses.has(inspectionResults[key]?.status))
    .map(([, name, method, key]) => ({group:group.title, name, method, key, ...inspectionResults[key]})));
  return issueItems.map(item => {
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
        const entries = [{title:`${node.hostname} (${node.role}) · 전체 ${Number(node.count) || 0}건 · 신규 ${Number(node.new_count) || 0}건`, output}];
        if (node.persistent_output) {
          const top = (node.top_messages || []).map(entry => `${entry.count}회 · ${entry.message}`).join('\n');
          entries.push({title:`${node.hostname} (${node.role}) · 지속 오류 ${Number(node.persistent_count) || 0}건 (전전날에도 발생, 표본 기준 상위 메시지)`, output:top || groupRepeatedLogLines(node.persistent_output).split(/\n\s*\n/).slice(0, 10).join('\n\n')});
        }
        return entries;
      }).flat();
    } else {
      outputs = item.details || [];
      if (issueHosts.size) outputs = outputs.filter(detail => [...issueHosts].some(host => detail.title?.includes(host)));
    }
    return {group:item.group, name:item.name, method:item.method, status:item.status, note:item.note || '', result:item.result || '', outputs:outputs.map(detail => ({title:detail.title || '', output:detail.output || ''}))};
  });
}

exportInspectionPdf.addEventListener('click', async () => {
  if (!Object.keys(inspectionResults).length) return showToast('PDF로 저장할 결과가 없습니다.', '일일점검을 먼저 실행하세요.');
  const items = collectIssueReportItems();
  const entry = checkHistory.find(item => item.id === (viewingCheckId || latestCheckId));
  const provider = inspectionProviderSelect.options[inspectionProviderSelect.selectedIndex]?.textContent || '-';
  const checkedAt = entry ? new Date(entry.checked_at) : new Date();
  const payload = {provider, checked_at: entry ? formatDateTime(entry.checked_at) : '최근 결과', trigger: entry?.summary?.trigger || null, duration_seconds: entry?.summary?.duration_seconds ?? null, items};
  const stamp = `${checkedAt.getFullYear()}${String(checkedAt.getMonth() + 1).padStart(2, '0')}${String(checkedAt.getDate()).padStart(2, '0')}-${String(checkedAt.getHours()).padStart(2, '0')}${String(checkedAt.getMinutes()).padStart(2, '0')}`;
  const fileName = `일일점검_이상항목_${provider.replace(/[\\/:*?"<>|\s]+/g, '_')}_${stamp}.pdf`;
  const label = exportInspectionPdf.innerHTML;
  exportInspectionPdf.disabled = true; exportInspectionPdf.textContent = 'PDF 생성 중…';
  try {
    const response = await fetch('/api/reports/issues.pdf', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    if (!response.ok) { const data = await response.json().catch(() => ({})); throw new Error(typeof data.detail === 'string' ? data.detail : `서버 오류 (${response.status})`); }
    const url = URL.createObjectURL(await response.blob());
    const link = document.createElement('a'); link.href = url; link.download = fileName; document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
    showToast('PDF를 저장했습니다.', `${fileName} · 이상 항목 ${items.length}개`);
  } catch (error) { showToast('PDF 저장에 실패했습니다.', error.message); } finally { exportInspectionPdf.disabled = false; exportInspectionPdf.innerHTML = label; }
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

const trendStatusOrder = {healthy:'healthy', excepted:'healthy', warning:'warning', unavailable:'unavailable', skipped:'skipped'};
function itemTrendMarkup(key) {
  // 점검 사항 칸에서 항목 이름과 상세 보기 안내 사이에 항상 같은 줄을 차지한다.
  // 이력이 2회 미만이면 그릴 점이 없지만 빈 줄은 남겨 행마다 위치가 흔들리지 않게 한다.
  if (checkHistory.length < 2) return '<span class="item-trend empty" aria-hidden="true"></span>';
  const points = [...checkHistory].slice(0, 14).reverse();
  const dots = points.map(entry => {
    const status = entry.summary?.item_status?.[key];
    const cls = status ? (trendStatusOrder[status] || 'unavailable') : 'none';
    return `<i class="${cls}${entry.id === (viewingCheckId || latestCheckId) ? ' current' : ''}" data-trend-check="${escapeText(entry.id)}" title="${escapeText(formatDateTime(entry.checked_at))} · ${escapeText(status ? (inspectionStatusLabels[status] || status) : '미점검')}"></i>`;
  }).join('');
  return `<span class="item-trend" title="최근 ${points.length}회 결과 · 점을 클릭하면 그 결과를 조회합니다">${dots}</span>`;
}
document.querySelector('#inspectionChecklist').addEventListener('click', event => {
  const dot = event.target.closest('[data-trend-check]');
  if (!dot) return;
  event.stopPropagation();
  if (inspectionProviderSelect.value) viewCheck(inspectionProviderSelect.value, dot.dataset.trendCheck);
});

// --- Provider inspection settings: thresholds and the default item set ---------------------------
let currentThresholds = null;
let currentDefaultItems = null;
const thresholdFields = [['cpu_warning', 'CPU 사용률 주의', '%', 50, 100], ['memory_warning', '메모리 사용률 주의', '%', 50, 100], ['disk_warning', '루트 디스크 사용률 주의', '%', 50, 100], ['log_error_warning', '로그 오류 주의 기준', '건 이상', 0, 100000]];
function renderThresholdPanel() {
  const form = document.querySelector('#thresholdsForm');
  if (!form) return;
  const entry = currentThresholds;
  const value = entry?.value || {};
  const defaults = entry?.default || {};
  form.innerHTML = thresholdFields.map(([key, label, unit, min, max]) => `<label><span>${label}</span><div class="settings-input"><input name="${key}" type="number" min="${min}" max="${max}" step="1" value="${value[key] ?? defaults[key] ?? ''}" required><b>${unit}</b></div><small>기본 ${defaults[key] ?? '-'}${unit}${key === 'log_error_warning' ? ' · 0이면 로그 건수로 주의 판정하지 않음' : ' · 이상이면 주의'}</small></label>`).join('')
    + `<div class="settings-form-actions"><span class="settings-form-note">${entry?.source === 'stored' ? `서버 저장값 · ${escapeText(entry.updated_by || '')} · ${escapeText(formatDateTime(entry.updated_at))}` : '기본값 사용 중'} · 다음 점검부터 적용</span><button type="button" id="resetThresholds" class="secondary">기본값</button><button class="primary-button" type="submit">저장</button></div>`;
  const set = (id, text) => { const element = document.querySelector(id); if (element) element.textContent = text; };
  const cpu = value.cpu_warning ?? defaults.cpu_warning ?? 80;
  const memory = value.memory_warning ?? defaults.memory_warning ?? 80;
  const disk = value.disk_warning ?? defaults.disk_warning ?? 80;
  const sameThreshold = cpu === memory && memory === disk;
  set('#setupThresholdValue', sameThreshold ? `CPU/MEM/DISK ${cpu}%` : `${cpu}/${memory}/${disk}%`);
  set('#setupThresholdHint', `${sameThreshold ? '' : 'CPU/MEM/DISK · '}로그 오류 ${value.log_error_warning ?? defaults.log_error_warning ?? 1}건 이상 주의 · ${entry?.source === 'stored' ? '공급자 설정값' : '기본값'}`);
}
async function loadProviderInspectionSettings(providerId) {
  currentThresholds = null; currentDefaultItems = null;
  if (!providerId) { renderThresholdPanel(); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/settings`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '공급자 설정을 불러오지 못했습니다.');
    currentThresholds = data.settings.thresholds;
    currentDefaultItems = data.settings.default_items;
    if (Array.isArray(currentDefaultItems?.value?.selected) && !inspectionResultsLoadedFor(providerId)) {
      selectedInspectionKeys = new Set(currentDefaultItems.value.selected.filter(key => allInspectionKeys.includes(key)));
      renderInspectionSelection(); renderInspectionChecklist();
    }
  } catch (error) { showToast('공급자 설정을 불러오지 못했습니다.', error.message); }
  renderThresholdPanel();
}
function inspectionResultsLoadedFor() { return Object.keys(inspectionResults).length > 0; }
document.querySelector('#thresholdsForm').addEventListener('submit', async event => {
  event.preventDefault();
  const providerId = inspectionProviderSelect.value;
  if (!providerId) return;
  const value = {};
  thresholdFields.forEach(([key]) => { value[key] = Number(event.currentTarget.elements[key].value); });
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/settings/thresholds`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({value})});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '임계치를 저장하지 못했습니다.');
    currentThresholds = data; renderThresholdPanel();
    showToast('판정 임계치를 저장했습니다.', '다음 일일점검부터 적용됩니다.');
  } catch (error) { showToast('임계치를 저장하지 못했습니다.', error.message); }
});
document.querySelector('#thresholdsForm').addEventListener('click', async event => {
  if (!event.target.closest('#resetThresholds')) return;
  const providerId = inspectionProviderSelect.value;
  if (!providerId || !window.confirm('판정 임계치를 기본값(80% · 로그 1건)으로 되돌릴까요?')) return;
  const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/settings/thresholds`, {method:'DELETE'});
  if (response.ok) { currentThresholds = await response.json(); renderThresholdPanel(); showToast('판정 임계치를 기본값으로 되돌렸습니다.', '다음 점검부터 적용됩니다.'); }
});
document.querySelector('#saveDefaultInspections').addEventListener('click', async () => {
  const providerId = inspectionProviderSelect.value;
  if (!providerId) return showToast('공급자를 먼저 선택하세요.', '');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/settings/default_items`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({value:{selected:[...selectedInspectionKeys]}})});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '기본 항목을 저장하지 못했습니다.');
    currentDefaultItems = data;
    showToast('기본 점검 항목을 저장했습니다.', `${selectedInspectionKeys.size}개 항목 · 이 공급자를 열 때 자동으로 선택됩니다.`);
  } catch (error) { showToast('기본 항목을 저장하지 못했습니다.', error.message); }
});
document.querySelector('#applyDefaultInspections').addEventListener('click', () => {
  const saved = currentDefaultItems?.value?.selected;
  if (!Array.isArray(saved)) return showToast('저장된 기본 항목이 없습니다.', '원하는 항목을 고른 뒤 "기본으로 저장"을 누르세요.');
  selectedInspectionKeys = new Set(saved.filter(key => allInspectionKeys.includes(key)));
  renderInspectionSelection(); renderInspectionChecklist();
  showToast('기본 점검 항목을 적용했습니다.', `${selectedInspectionKeys.size}개 항목`);
});

// --- Timing statistics ---------------------------------------------------------------------------
async function loadTimingStats() {
  const providerId = inspectionProviderSelect.value;
  const box = document.querySelector('#inspectionTiming');
  if (!providerId) return;
  box.hidden = !box.hidden;
  if (box.hidden) return;
  box.innerHTML = '<div class="empty-provider">소요 시간을 집계하고 있습니다.</div>';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/check-timing?limit=10`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '소요 시간 통계를 불러오지 못했습니다.');
    const names = itemNameMap();
    const timeoutLabels = {command:'노드 명령 1개', log_scan:'로그 검색 1개', openstack:'OpenStack·클러스터 명령 1개', node_script:'노드 스크립트 전체', controller_script:'Controller 스크립트 전체'};
    const suggestions = Object.entries(data.suggested_timeouts || {}).filter(([, value]) => value != null).map(([key, value]) => { const current = data.current_timeouts?.[key]; const tone = value > current ? 'warn' : ''; return `<tr class="${tone}"><td>${timeoutLabels[key] || key}</td><td>${current ?? '-'}초</td><td><strong>${value}초</strong></td><td>${value > current ? '관측 최대의 1.5배가 현재 값보다 큽니다. 설정에서 늘리는 것을 검토하세요.' : '현재 값으로 충분합니다.'}</td></tr>`; }).join('');
    box.innerHTML = `<div class="timing-grid">
      <section><h3>가장 오래 걸린 항목 <small>최근 ${data.sampled_checks}회 · 최대 기준</small></h3><table><thead><tr><th>항목</th><th>평균</th><th>P90</th><th>최대</th><th>표본</th></tr></thead><tbody>${(data.items || []).slice(0, 12).map(item => `<tr><td>${escapeText(names[item.key] || item.key)}</td><td>${item.avg}초</td><td>${item.p90}초</td><td><strong>${item.max}초</strong></td><td>${item.samples}</td></tr>`).join('') || '<tr><td colspan="5">집계할 결과가 없습니다.</td></tr>'}</tbody></table></section>
      <section><h3>노드별 소요 <small>노드 스크립트 전체</small></h3><table><thead><tr><th>노드</th><th>평균</th><th>P90</th><th>최대</th></tr></thead><tbody>${(data.nodes || []).map(node => `<tr><td>${escapeText(node.hostname)}</td><td>${node.avg}초</td><td>${node.p90}초</td><td><strong>${node.max}초</strong></td></tr>`).join('') || '<tr><td colspan="4">-</td></tr>'}</tbody></table>
      <h3>단계별 소요</h3><table><thead><tr><th>단계</th><th>평균</th><th>최대</th></tr></thead><tbody>${[['nodes', '노드 점검'], ['controller', 'Controller 점검'], ['total', '전체']].map(([key, label]) => { const stat = data.phases?.[key]; return `<tr><td>${label}</td><td>${stat ? `${stat.avg}초` : '-'}</td><td>${stat ? `${stat.max}초` : '-'}</td></tr>`; }).join('')}</tbody></table></section>
      <section class="timing-suggest"><h3>제한 시간 권장값 <small>관측 최대 × 1.5</small></h3><table><thead><tr><th>제한 시간</th><th>현재</th><th>권장</th><th>판단</th></tr></thead><tbody>${suggestions || '<tr><td colspan="4">집계할 결과가 없습니다.</td></tr>'}</tbody></table><p>제한 시간은 <a href="#settings" data-page="settings">설정 › 점검 실행 제한 시간</a>에서 바꿉니다.</p></section>
    </div>`;
  } catch (error) { box.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
document.querySelector('#openTimingStats').addEventListener('click', loadTimingStats);
if (document.querySelector('#trendToggle')) {
  applyTrendVisibility();
  document.querySelector('#trendToggle').addEventListener('change', event => {
    try { localStorage.setItem(trendVisibleKey, event.target.checked ? '1' : '0'); } catch (_) { /* private mode: this session only */ }
    // 숨은 동안에는 컨테이너 폭을 잴 수 없으므로 다시 켤 때 실제 폭으로 그린다.
    renderInspectionTrend();
  });
}
document.querySelector('#diffAgainstSelect').addEventListener('change', event => {
  diffAgainstId = event.target.value;
  const checkId = viewingCheckId || latestCheckId;
  if (inspectionProviderSelect.value && checkId) loadCheckDiff(inspectionProviderSelect.value, checkId, diffAgainstId);
});

function inspectionStatusMatches(filter, status) {
  return filter === 'all' || filter === status ||
    (filter === 'healthy' && status === 'excepted') ||
    (filter === 'pending' && ['pending', 'skipped'].includes(status));
}

const RESULT_STATUSES = ['healthy', 'excepted', 'warning', 'unavailable'];
// 결과가 없는 선택 항목 수. 0이면 요약 카드와 상태 필터에서 '수집 대기'를 감춘다.
function pendingInspectionCount() {
  return inspectionGroups.reduce((count, group) => count + group.items.filter(([, , , key]) =>
    selectedInspectionKeys.has(key) && !RESULT_STATUSES.includes(inspectionResults[key]?.status)).length, 0);
}

function renderInspectionChecklist() {
  const checklist = document.querySelector('#inspectionChecklist');
  const pending = pendingInspectionCount();
  if (!pending && currentFilter === 'pending') { setInspectionFilter('all'); return; }
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
      const nodeDetail = logIssueNodes.length ? `<details class="node-log-detail"><summary>노드별 전전날 대비 신규·변경 오류</summary>${logIssueNodes.map(node => `<details class="node-log-entry"><summary><strong>${escapeText(node.hostname)}</strong><span>${escapeText(node.role)}</span><em class="${escapeText(node.status)}">${labels[node.status] || '확인 불가'}</em><b>신규 ${Number(node.new_count) || 0}건 · 지속 ${Number(node.persistent_count) || 0}건 · 보기</b><small>${escapeText(node.previous_log_date || '전전날')} → ${escapeText(node.log_date || '전날')} · 전체 ${Number(node.count) || 0}건 · 해소 ${Number(node.resolved_count) || 0}건${Number(node.excluded_count) ? ` · 제외 ${Number(node.excluded_count)}건` : ''}${node.note ? ` · ${escapeText(node.note)}` : ''}</small></summary>${logNodeSections(node, key)}</details>`).join('')}</details>` : '';
      const isLogItem = key.endsWith('_log');
      const details = result.details?.length ? result.details : [{title:'조회 결과', output:result.status === 'pending' ? '아직 점검을 실행하지 않았습니다.' : `${result.note || ''}\n${result.result || '-'}`}];
      const visibleDetails = isLogItem ? details.filter(detail => detail.title.includes('신규/변경 로그')) : details;
      const rawOutput = isLogItem
        ? (logIssueNodes.length ? logIssueNodes.map(node => `<article><strong>${escapeText(`${node.hostname} (${node.role}) · 전체 ${Number(node.count) || 0}건 · 신규 ${Number(node.new_count) || 0}건 · 지속 ${Number(node.persistent_count) || 0}건`)}</strong>${logNodeSections(node, key)}</article>`).join('') : '<article><strong>신규·변경 오류</strong><pre>주의 또는 확인이 필요한 노드가 없습니다.</pre></article>')
        : (visibleDetails.length ? visibleDetails : details).map(detail => `<article><strong>${escapeText(detail.title)}</strong><pre>${escapeText(detail.output || '출력 없음')}</pre></article>`).join('');
      const hasResult = result.status !== 'pending';
      const durationBadge = Number.isFinite(Number(result.duration_seconds)) && result.duration_seconds !== null ? `<em class="detail-duration" title="가장 오래 걸린 노드 또는 명령 기준">소요 ${escapeText(formatDuration(result.duration_seconds))}</em>` : '';
      const actions = hasResult ? `<div class="inspection-detail-actions"><span>${escapeText(name)} 상세 결과${durationBadge}</span><button type="button" data-row-action="rerun" data-key="${escapeText(key)}" title="이 항목만 다시 점검합니다">이 항목만 재점검</button>${result.status === 'warning' ? `<button type="button" data-row-action="exception" data-key="${escapeText(key)}">예외 등록</button>` : ''}${isLogItem && result.status === 'warning' ? `<button type="button" data-row-action="log-exclusion" data-key="${escapeText(key)}">제외 패턴 등록</button>` : ''}${result.status === 'warning' || result.status === 'unavailable' ? `<button type="button" data-row-action="alerts" data-key="${escapeText(key)}">관련 알림</button>` : ''}<button type="button" data-row-action="copy" data-key="${escapeText(key)}" data-detail-id="${detailId}">출력 복사</button></div>${result.compacted ? '<p class="compacted-note">보관 정책에 따라 이 결과의 원본 출력은 정리되었습니다. 상태와 판정 결과만 표시됩니다.</p>' : ''}` : '';
      const exceptionNote = result.status === 'excepted' && result.exception_reason ? `<span class="exception-inline" title="${escapeText(result.exception_reason)}">예외</span>` : '';
      return `<tr class="inspection-row" data-status="${result.status}" data-key="${escapeText(key)}" data-detail-id="${detailId}" tabindex="0" aria-expanded="false"><td><span class="category-badge">${category}</span></td><td><strong>${name}</strong>${itemTrendMarkup(key)}<small class="detail-hint">클릭하여 상세 결과 보기</small></td><td><div class="check-method">${escapeText(method)}</div></td><td><span class="check-state ${result.status}">${labels[result.status]}</span>${changeBadge(key)}${exceptionNote}</td><td>${escapeText(result.note)}${nodeDetail}</td><td class="inspection-value">${escapeText(result.result)}</td></tr><tr class="inspection-detail-row${isLogItem ? ' log-output-row' : ''}" id="${detailId}" hidden><td colspan="6">${actions}${isLogItem ? '<div class="log-output-heading"><strong>신규·변경 오류와 지속 오류</strong><span>전전날에도 발생한 오류는 지속 오류로 분리 · 중복 메시지는 발생 시각으로 묶어서 표시 · 표본은 전날 마지막 100줄</span></div>' : ''}<div class="inspection-raw-output">${rawOutput}</div></td></tr>`;
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
  document.querySelector('#pendingInspectionItems').textContent = pending;
  const pendingCard = document.querySelector('.inspection-summary-filter[data-summary-filter="pending"]');
  if (pendingCard) pendingCard.hidden = !pending;
  const pendingFilterButton = document.querySelector('.inspection-filter button[data-filter="pending"]');
  if (pendingFilterButton) pendingFilterButton.hidden = !pending;
  document.querySelector('.inspection-summary')?.classList.toggle('no-pending', !pending);
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
