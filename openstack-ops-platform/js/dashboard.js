// ===== 대시보드 =====
function relativeTime(value) {
  if (!value) return '-';
  const diff = Math.max(0, Date.now() - new Date(value).getTime());
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return '방금';
  if (minutes < 60) return `${minutes}분 전`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}시간 전`;
  const days = Math.floor(hours / 24);
  return days < 30 ? `${days}일 전` : formatDateTime(value);
}

let currentOverview = null;
async function loadOverview(providerId) {
  loadFleetOverview();
  if (!providerId) { currentOverview = null; renderDashboard(null); return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/overview`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '운영 현황을 불러오지 못했습니다.');
    currentOverview = data;
    renderDashboard(data);
    const snapshot = data.node_snapshot || {nodes:[], node_summary:[]};
    renderInfrastructure({nodes:snapshot.nodes, node_summary:snapshot.node_summary, items:data.items, _checked_at:snapshot.checked_at});
    loadInfrastructureMetrics(providerId);
  } catch (error) { showToast('운영 현황을 불러오지 못했습니다.', error.message); }
}


// --- Fleet view: every provider at a glance + today's to-do list ---------------------------------
let currentFleet = null;
let fleetTimer = null;
const fleetStatusLabels = {healthy:'정상', warning:'주의', unavailable:'확인 불가', none:'점검 전'};
async function loadFleetOverview() {
  try {
    const response = await fetch('/api/overview', {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '전체 공급자 현황을 불러오지 못했습니다.');
    currentFleet = data;
    renderFleet(data);
    renderToday(data);
  } catch (error) {
    document.querySelector('#dashboardFleetCards').innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`;
  }
}
function fleetTone(item) {
  if (item.running) return 'info';
  if (!item.latest) return 'muted';
  if (item.alerts.critical || (item.unavailable_items || 0) > 0) return 'critical';
  if (item.latest.status !== 'healthy' || item.alerts.active) return 'warning';
  return 'healthy';
}
function renderFleet(data) {
  const cards = document.querySelector('#dashboardFleetCards');
  const totals = data.totals || {};
  document.querySelector('#dashboardFleetMeta').textContent = data.providers.length
    ? `공급자 ${totals.providers}개 · 노드 ${totals.nodes}대 · 정상 ${totals.healthy} · 주의 ${totals.warning} · 점검 전 ${totals.unchecked} · 오늘 점검 완료 ${totals.checked_today}/${totals.providers} · 활성 알림 ${totals.active_alerts}건(위험 ${totals.critical_alerts})${totals.running ? ` · 실행 중 ${totals.running}` : ''}`
    : '등록된 공급자가 없습니다. 공급자 연결에서 VIP를 등록하세요.';
  if (!data.providers.length) { cards.innerHTML = '<div class="empty-provider">등록된 공급자가 없습니다.</div>'; return; }
  cards.innerHTML = data.providers.map(item => {
    const tone = fleetTone(item);
    const latest = item.latest;
    const status = item.running ? '실행 중' : (latest ? fleetStatusLabels[latest.status] || latest.status : '점검 전');
    const delta = latest && item.previous ? ((latest.summary?.items?.warning ?? 0) + (latest.summary?.items?.unavailable ?? 0)) - ((item.previous.summary?.items?.warning ?? 0) + (item.previous.summary?.items?.unavailable ?? 0)) : null;
    const schedule = item.schedule || {};
    const scheduleText = !schedule.enabled ? '예약 없음' : (schedule.today === 'done' ? `오늘 ${schedule.run_time} 예약 완료` : schedule.today === 'failed' ? `오늘 ${schedule.run_time} 예약 실패` : schedule.today === 'running' ? '예약 점검 실행 중' : `예약 ${schedule.run_time} 대기`);
    return `<button type="button" class="fleet-card ${tone}${item.id === providerSelect.value ? ' selected' : ''}" data-fleet-provider="${escapeText(item.id)}" title="클릭하면 이 공급자를 선택합니다">
      <div class="fleet-head"><strong>${escapeText(item.name)}</strong><em class="fleet-status">${escapeText(status)}</em></div>
      <small>${escapeText(item.vip)} · ${escapeText(item.controller_hostname || '-')} · 노드 ${item.nodes.total}대</small>
      <div class="fleet-facts">
        <span title="최근 점검 시각">${latest ? escapeText(relativeTime(latest.checked_at)) : '점검 기록 없음'}${latest?.summary?.trigger === 'scheduled' ? ' · 예약' : (latest ? ' · 수동' : '')}</span>
        <span class="${(item.warning_items || 0) ? 'warn' : ''}">주의 ${item.warning_items ?? '-'}</span>
        <span class="${(item.unavailable_items || 0) ? 'crit' : ''}">확인 불가 ${item.unavailable_items ?? '-'}</span>
        <span class="${item.alerts.critical ? 'crit' : (item.alerts.active ? 'warn' : '')}">알림 ${item.alerts.active}${item.alerts.critical ? ` (위험 ${item.alerts.critical})` : ''}</span>
        ${delta != null && delta !== 0 ? `<span class="${delta > 0 ? 'crit' : 'ok'}">직전 대비 ${delta > 0 ? '+' : ''}${delta}</span>` : ''}
      </div>
      <small class="fleet-schedule ${schedule.today === 'failed' ? 'crit' : ''}">${escapeText(scheduleText)}</small>
    </button>`;
  }).join('');
}
function renderToday(data) {
  const today = data.today || {schedules:[], open_critical_alerts:[], works:[]};
  const scheduleBox = document.querySelector('#dashboardTodaySchedules');
  const done = today.schedules.filter(item => item.today === 'done').length;
  const failed = today.schedules.filter(item => item.today === 'failed').length;
  document.querySelector('#dashboardTodayScheduleMeta').textContent = today.schedules.length ? `${today.schedules.length}건 예약 · 완료 ${done}${failed ? ` · 실패 ${failed}` : ''} · ${data.timezone}` : '예약된 점검이 없습니다';
  const scheduleLabel = {done:'완료', failed:'실패', running:'실행 중', pending:'대기'};
  scheduleBox.innerHTML = today.schedules.length ? today.schedules.map(item => `<button type="button" class="today-item ${item.today}" data-today-schedule="${escapeText(item.provider_id)}"><em>${escapeText(scheduleLabel[item.today] || item.today)}</em><div><strong>${escapeText(item.provider_name)}</strong><small>매일 ${escapeText(item.run_time)} · ${item.today === 'pending' ? `다음 ${escapeText(formatDateTime(item.next_run_at))}` : (item.last_run_at ? `${escapeText(formatDateTime(item.last_run_at))}${item.last_status ? ` · ${escapeText(fleetStatusLabels[item.last_status] || item.last_status)}` : ''}` : '-')}${item.last_error && item.today === 'failed' ? ` · ${escapeText(item.last_error)}` : ''}</small></div></button>`).join('') : '<div class="empty-provider">예약된 점검이 없습니다. 일일점검의 예약 실행에서 등록하세요.</div>';
  const alertBox = document.querySelector('#dashboardTodayAlerts');
  document.querySelector('#dashboardTodayAlertMeta').textContent = today.open_critical_total ? `${today.open_critical_total}건 · 담당자 확인이 필요합니다` : '모든 위험 알림이 확인되었습니다';
  alertBox.innerHTML = today.open_critical_alerts.length ? today.open_critical_alerts.map(alert => `<button type="button" class="today-item critical" data-goto="alerts" data-alert-scope="all" data-alert-id="${escapeText(alert.id)}"><em>위험</em><div><strong>${escapeText(alert.title)}</strong><small>${escapeText(alert.provider_name || '-')}${alert.target ? ` · ${escapeText(alert.target)}` : ''} · ${escapeText(relativeTime(alert.last_detected_at))}</small></div></button>`).join('') : '<div class="empty-provider">미확인 위험 알림이 없습니다.</div>';
  const workBox = document.querySelector('#dashboardTodayWorks');
  document.querySelector('#dashboardTodayWorkMeta').textContent = today.works_total ? `예정·진행 중 ${today.works_total}건${today.works.length < today.works_total ? ` 중 오늘 ${today.works.length}건` : ''}` : '예정된 작업이 없습니다';
  workBox.innerHTML = today.works.length ? today.works.map(work => `<button type="button" class="today-item ${work.status}" data-goto="history" data-history-scope="all" data-history-id="${escapeText(work.id)}"><em>${work.status === 'in_progress' ? '진행 중' : '예정'}</em><div><strong>${escapeText(work.title)}</strong><small>${escapeText(work.provider_name || '공통')} · ${escapeText(workTypeLabels[work.work_type] || work.work_type)} · ${escapeText(work.operator || '-')} · ${escapeText(formatDateTime(work.started_at))}</small></div></button>`).join('') : '<div class="empty-provider">오늘 예정된 작업이 없습니다.</div>';
}
function startFleetRefresh() {
  clearInterval(fleetTimer);
  fleetTimer = setInterval(() => { if (!document.querySelector('#dashboardPage').hidden && !document.hidden) loadFleetOverview(); }, 60000);
}
document.querySelector('#dashboardFleetCards').addEventListener('click', event => {
  const card = event.target.closest('[data-fleet-provider]');
  if (!card) return;
  selectProvider(card.dataset.fleetProvider);
  document.querySelectorAll('.fleet-card').forEach(item => item.classList.toggle('selected', item === card));
});
document.querySelector('#dashboardTodaySchedules').addEventListener('click', event => {
  const item = event.target.closest('[data-today-schedule]');
  if (!item) return;
  selectProvider(item.dataset.todaySchedule);
  history.replaceState(null, '', '#daily-inspection'); showPage('daily-inspection');
  setTimeout(() => openSetupPanel('schedule', true), 50);
});

function renderDashboardGreeting() {
  const now = new Date();
  const hour = now.getHours();
  document.querySelector('#dashboardDate').textContent = new Intl.DateTimeFormat('ko-KR', {dateStyle:'full'}).format(now);
  document.querySelector('#dashboardGreeting').textContent = hour < 6 ? '늦은 시간까지 수고 많으십니다' : (hour < 12 ? '좋은 아침입니다' : (hour < 18 ? '좋은 오후입니다' : '좋은 저녁입니다'));
}

function gaugeClass(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return 'unavailable';
  return numeric >= 90 ? 'critical' : (numeric >= 80 ? 'high' : '');
}

function renderDashboard(data) {
  renderDashboardGreeting();
  const kpis = document.querySelector('#dashboardKpis');
  const context = document.querySelector('#dashboardContext');
  const empty = (id, message) => { document.querySelector(id).innerHTML = `<div class="empty-provider">${escapeText(message)}</div>`; };
  if (!data) {
    context.textContent = '공급자를 선택하면 최근 점검, 알림, 노드와 서비스 상태를 한눈에 요약합니다.';
    kpis.innerHTML = '<div class="empty-provider">공급자를 선택하세요.</div>';
    empty('#dashboardResources', '노드 점검 결과가 없습니다.'); empty('#dashboardServices', '점검 결과가 없습니다.'); empty('#dashboardIssues', '점검 결과가 없습니다.');
    empty('#dashboardAlerts', '활성 알림이 없습니다.'); empty('#dashboardTrend', '점검이 2회 이상 쌓이면 추이를 표시합니다.'); empty('#dashboardWorkHistories', '기록된 작업이 없습니다.');
    document.querySelector('#dashboardIssueCount').textContent = '0';
    return;
  }
  const provider = data.provider;
  const inventory = provider.inventory || {};
  const sudoLabel = provider.username === 'root' ? 'root' : `${provider.username} · sudo${provider.sudo_mode === 'password' ? '(비밀번호)' : ''}`;
  context.textContent = `${provider.name} · VIP ${provider.vip} · 활성 Controller ${provider.controller_hostname || '-'} · 계정 ${sudoLabel} · 노드 ${inventory.total || 0}대 (Controller ${inventory.controller || 0} · Compute ${inventory.compute || 0})`;

  const latest = data.latest;
  const summary = latest?.summary || {items:{}, nodes:{}};
  const previous = data.history?.[1]?.summary;
  const delta = (current, before) => (previous && Number.isFinite(before)) ? (current - before === 0 ? '직전과 동일' : `직전 대비 ${current - before > 0 ? '+' : ''}${current - before}`) : '';
  const schedule = data.schedule || {};
  const snapshot = data.node_snapshot;
  const nodeCounts = snapshot ? {
    total: snapshot.nodes.length,
    problem: snapshot.node_summary.filter(node => node.status === 'problem').length,
    review: snapshot.node_summary.filter(node => node.status === 'review').length,
    unreachable: snapshot.nodes.filter(node => !node.reachable).length,
  } : null;
  const inspectionTone = data.running ? 'info' : (!latest ? 'muted' : (latest.status === 'healthy' ? 'healthy' : 'warning'));
  const cards = [
    {tone:inspectionTone, label:'일일점검', value:data.running ? '실행 중' : (latest ? (latest.status === 'healthy' ? '정상' : '주의') : '실행 전'),
     hint:latest ? `${relativeTime(latest.checked_at)} · ${summary.trigger === 'scheduled' ? '예약' : '수동'} · ${summary.items?.total ?? 0}개 항목 · ${summary.duration_seconds != null ? formatDuration(summary.duration_seconds) : '-'}` : '전체 점검을 실행하세요', goto:'daily-inspection'},
    {tone:(summary.items?.warning || 0) ? 'warning' : (latest ? 'healthy' : 'muted'), label:'주의 항목', value:summary.items?.warning ?? '-', hint:delta(summary.items?.warning ?? 0, previous?.items?.warning) || '최근 점검 기준', goto:'daily-inspection', filter:'warning'},
    {tone:(summary.items?.unavailable || 0) ? 'critical' : (latest ? 'healthy' : 'muted'), label:'확인 불가 항목', value:summary.items?.unavailable ?? '-', hint:delta(summary.items?.unavailable ?? 0, previous?.items?.unavailable) || '최근 점검 기준', goto:'daily-inspection', filter:'unavailable'},
    {tone:data.alerts.critical ? 'critical' : (data.alerts.active ? 'warning' : 'healthy'), label:'활성 알림', value:data.alerts.active, hint:`위험 ${data.alerts.critical} · 주의 ${data.alerts.warning}`, goto:'alerts'},
    {tone:nodeCounts ? (nodeCounts.unreachable || nodeCounts.problem ? 'critical' : (nodeCounts.review ? 'warning' : 'healthy')) : 'muted', label:'노드 상태', value:nodeCounts ? `${nodeCounts.total - nodeCounts.problem - nodeCounts.review - nodeCounts.unreachable}<em>/ ${nodeCounts.total} 정상</em>` : (inventory.total ? `${inventory.total}<em>대 미점검</em>` : '미탐색'), hint:nodeCounts ? `문제 ${nodeCounts.problem} · 확인 필요 ${nodeCounts.review} · 접속 불가 ${nodeCounts.unreachable}` : (inventory.total ? '점검을 실행하면 상태가 표시됩니다' : '클러스터 노드 탐색이 필요합니다'), goto:'infrastructure', raw:true},
    {tone:schedule.enabled ? 'info' : 'muted', label:'예약 실행', value:schedule.enabled ? `매일 ${schedule.run_time}` : '중지', hint:schedule.enabled ? `다음 ${schedule.next_run_at ? formatDateTime(schedule.next_run_at) : '-'}` : (schedule.last_run_at ? `마지막 ${relativeTime(schedule.last_run_at)}` : '예약 없음'), goto:'daily-inspection', setup:'schedule'},
  ];
  kpis.innerHTML = cards.map(card => `<button type="button" class="kpi-card ${card.tone}" data-goto="${card.goto}"${card.filter ? ` data-filter="${card.filter}"` : ''}${card.setup ? ` data-setup-open="${card.setup}"` : ''}><small>${escapeText(card.label)}</small><strong>${card.raw ? card.value : escapeText(String(card.value))}</strong><span title="${escapeText(card.hint)}">${escapeText(card.hint)}</span></button>`).join('');

  // resources
  const resources = document.querySelector('#dashboardResources');
  if (snapshot && snapshot.nodes.length) {
    const reachable = snapshot.nodes.filter(node => node.reachable);
    const cores = reachable.reduce((sum, node) => sum + (Number(node.metrics?.cpu_cores) || 0), 0);
    const memoryTotal = reachable.reduce((sum, node) => sum + (Number(node.metrics?.memory_total_kb) || 0), 0);
    const memoryUsed = reachable.reduce((sum, node) => sum + (Number(node.metrics?.memory_used_kb) || 0), 0);
    const diskTotal = reachable.reduce((sum, node) => sum + (Number(node.metrics?.disk_total_kb) || 0), 0);
    const diskUsed = reachable.reduce((sum, node) => sum + (Number(node.metrics?.disk_used_kb) || 0), 0);
    const cpuValues = reachable.map(node => Number(node.metrics?.cpu_used_percent)).filter(Number.isFinite);
    const cpuAverage = cpuValues.length ? cpuValues.reduce((sum, value) => sum + value, 0) / cpuValues.length : null;
    const percent = (used, total) => total ? Math.round(used / total * 1000) / 10 : null;
    const totals = [
      ['CPU', cpuAverage != null ? `평균 ${cpuAverage.toFixed(1)}%` : '-', `${cores} Core · 최대 ${cpuValues.length ? Math.max(...cpuValues).toFixed(1) : '-'}%`],
      ['메모리', percent(memoryUsed, memoryTotal) != null ? `${percent(memoryUsed, memoryTotal)}% 사용` : '-', `${formatCapacity(memoryUsed)} / ${formatCapacity(memoryTotal)}`],
      ['루트 디스크', percent(diskUsed, diskTotal) != null ? `${percent(diskUsed, diskTotal)}% 사용` : '-', `${formatCapacity(diskUsed)} / ${formatCapacity(diskTotal)}`],
    ];
    const statusOf = node => !node.reachable ? 'unreachable' : (snapshot.node_summary.find(entry => entry.hostname === node.hostname)?.status || 'healthy');
    const order = {unreachable:0, problem:1, review:2, healthy:3};
    const rows = [...snapshot.nodes].sort((a, b) => order[statusOf(a)] - order[statusOf(b)] || a.role.localeCompare(b.role) || a.hostname.localeCompare(b.hostname)).map(node => {
      const status = statusOf(node);
      const statusLabel = {unreachable:'접속 불가', problem:'문제', review:'확인 필요', healthy:'정상'}[status];
      const gauge = (label, value) => { const numeric = Number(value); const ok = Number.isFinite(numeric); return `<div class="resource-gauge ${gaugeClass(value)}"><i><u style="width:${ok ? Math.max(0, Math.min(100, numeric)) : 0}%"></u></i><b>${ok ? `${numeric.toFixed(0)}%` : '-'}</b></div>`; };
      return `<div class="resource-node-row ${status}"><div><span class="node-role ${escapeText(node.role)}">${node.role === 'controller' ? 'CTL' : 'CMP'}</span><div><strong>${escapeText(node.hostname)}</strong><small>${escapeText(statusLabel)}${node.metrics?.cpu_cores ? ` · ${node.metrics.cpu_cores} Core` : ''}${node.metrics?.uptime_seconds ? ` · 가동 ${Math.floor(node.metrics.uptime_seconds / 86400)}일` : ''}</small></div></div>${gauge('CPU', node.metrics?.cpu_used_percent)}${gauge('메모리', node.metrics?.memory_used_percent)}${gauge('디스크', node.metrics?.disk_used_percent)}</div>`;
    }).join('');
    resources.innerHTML = `<div class="resource-totals">${totals.map(([label, value, hint]) => `<article><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong><em>${escapeText(hint)}</em></article>`).join('')}</div><div class="resource-node-row" style="border-top:0;padding:2px 0 4px;color:#8593a6;font-size:8.5px"><div>노드</div><div>CPU</div><div>메모리</div><div>루트 디스크</div></div>${rows}`;
    document.querySelector('#dashboardResourceMeta').textContent = `${relativeTime(snapshot.checked_at)} 노드 점검 기준 · ${reachable.length}/${snapshot.nodes.length}대 수집`;
  } else {
    resources.innerHTML = `<div class="empty-provider">${inventory.total ? '아직 노드 점검 결과가 없습니다. 일일점검을 실행하세요.' : '클러스터 노드 탐색 후 일일점검을 실행하면 노드별 자원 사용률이 표시됩니다.'}</div>`;
    document.querySelector('#dashboardResourceMeta').textContent = '최근 노드 점검 기준';
  }

  // services
  const services = document.querySelector('#dashboardServices');
  const serviceDefinitions = [['pcs','PCS','Pacemaker'],['vip','VIP','통신'],['rabbitmq','RabbitMQ','Messaging'],['mysql','MySQL','Galera'],['endpoint','Endpoint','Keystone'],['nova','Nova','Compute'],['neutron','Neutron','Network'],['cinder','Cinder','Block Storage'],['manila','Manila','Shared FS'],['octavia','Octavia','Load Balancer'],['masakari','Masakari','Instance HA'],['swift','Swift','Object Storage'],['heat','Heat','Orchestration'],['nova_compute','nova-compute','Compute 노드']];
  const stateLabels = {healthy:'정상', warning:'주의', unavailable:'확인 불가', excepted:'예외', pending:'미점검'};
  const symbols = {pcs:'P', vip:'V', rabbitmq:'R', mysql:'M', endpoint:'K', nova:'N', neutron:'Ne', cinder:'C', manila:'Ma', octavia:'O', masakari:'Mk', swift:'S', heat:'H', nova_compute:'Nc'};
  const checkedTimes = Object.values(data.items || {}).map(item => item.checked_at).filter(Boolean).sort();
  services.innerHTML = serviceDefinitions.map(([key, label, kind]) => {
    const item = data.items?.[key];
    const status = item?.status || 'pending';
    const detail = item ? (item.problems?.length ? item.problems[0] : (item.result && item.result !== '-' ? item.result : item.note)) : '아직 점검되지 않음';
    return `<button type="button" data-goto="daily-inspection" data-item-key="${escapeText(key)}" title="${escapeText(item?.note || '')}"><span class="service-symbol">${symbols[key]}</span><p><strong>${escapeText(label)} <small style="display:inline;color:#8593a6">${escapeText(kind)}</small></strong><small>${escapeText(detail || '-')}${item?.checked_at ? ` · ${escapeText(relativeTime(item.checked_at))}` : ''}</small></p><span class="state-pill ${escapeText(status)}">${stateLabels[status] || status}</span></button>`;
  }).join('');
  document.querySelector('#dashboardServiceMeta').textContent = checkedTimes.length ? `항목별 가장 최근 점검 결과 · ${relativeTime(checkedTimes[0])} ~ ${relativeTime(checkedTimes[checkedTimes.length - 1])}` : '항목별 가장 최근 점검 결과';

  // issues
  const issues = document.querySelector('#dashboardIssues');
  const names = itemNameMap();
  const groups = itemGroupMap();
  const issueItems = data.issue_items || [];
  document.querySelector('#dashboardIssueCount').textContent = issueItems.length;
  issues.innerHTML = issueItems.length ? issueItems.slice(0, 8).map(item => `<button type="button" data-goto="daily-inspection" data-item-key="${escapeText(item.key)}"><span class="state-pill ${escapeText(item.status)}">${stateLabels[item.status] || item.status}</span><div><strong>${escapeText(names[item.key] || item.key)} <small style="display:inline;color:#8593a6">${escapeText(groups[item.key] || '')}</small></strong><small>${escapeText(item.problems?.length ? item.problems.join('; ') : (item.note || item.result || ''))}</small></div><em>${escapeText(relativeTime(item.checked_at))}</em></button>`).join('') + (issueItems.length > 8 ? `<div class="more">외 ${issueItems.length - 8}개 항목 · 일일점검에서 전체 보기</div>` : '') : '<div class="empty-provider">최근 점검에서 주의·확인 불가 항목이 없습니다.</div>';
  document.querySelector('#dashboardIssueMeta').textContent = issueItems.length ? `주의 ${issueItems.filter(item => item.status === 'warning').length} · 확인 불가 ${issueItems.filter(item => item.status === 'unavailable').length} · 항목을 클릭하면 상세로 이동합니다` : '항목을 클릭하면 일일점검 상세로 이동합니다';

  // alerts
  const alerts = document.querySelector('#dashboardAlerts');
  const recent = data.alerts.recent || [];
  const severityIcons = {critical:'!', warning:'△', info:'i'};
  alerts.innerHTML = recent.length ? recent.map(alert => `<button type="button" data-goto="alerts" data-alert-id="${escapeText(alert.id)}"><span class="severity ${alert.severity === 'critical' ? 'critical' : (alert.severity === 'warning' ? 'warn' : 'info')}">${severityIcons[alert.severity] || 'i'}</span><div><strong>${escapeText(alert.title)}</strong><small>${escapeText(alert.description || '')}${alert.target ? ` · ${escapeText(alert.target)}` : ''}${alert.assignee ? ` · 담당 ${escapeText(alert.assignee)}` : ''}</small></div><time>${escapeText(relativeTime(alert.last_detected_at))}</time></button>`).join('') : '<div class="empty-provider">활성 알림이 없습니다.</div>';
  document.querySelector('#dashboardAlertMeta').textContent = data.alerts.active ? `미해소 ${data.alerts.active}건 중 최근 ${recent.length}건 · 위험 ${data.alerts.critical}` : '미해소 알림 없음';

  // trend + work histories
  renderDashboardTrend(data);
  const histories = document.querySelector('#dashboardWorkHistories');
  const typeLabels = {inspection:'점검', incident:'장애 대응', change:'설정 변경', restart:'재시작', deployment:'배포', maintenance:'유지보수', other:'기타'};
  const historyStates = {planned:['pending', '예정'], in_progress:['warning', '진행 중'], completed:['healthy', '완료'], failed:['unavailable', '실패']};
  histories.innerHTML = (data.work_histories || []).length ? data.work_histories.map(history => { const [cls, label] = historyStates[history.status] || ['pending', history.status]; return `<article><strong>${escapeText(history.title)}</strong><span class="state-pill ${cls}">${escapeText(label)}</span><small>${escapeText(typeLabels[history.work_type] || history.work_type)} · ${escapeText(history.operator || '-')}${history.target ? ` · ${escapeText(history.target)}` : ''} · ${escapeText(relativeTime(history.started_at))}</small></article>`; }).join('') : '<div class="empty-provider">기록된 작업이 없습니다. 작업 이력에서 점검·변경 작업을 등록하세요.</div>';
}

function renderDashboardTrend(data) {
  const box = document.querySelector('#dashboardTrend');
  const points = [...(data.history || [])].reverse();
  renderTrendChart(box, points, {activeIndex:points.length - 1, heading:false, minWidth:360});
  document.querySelector('#dashboardTrendMeta').textContent = points.length >= 2 ? `최근 ${points.length}회 점검 · 점을 클릭하면 해당 결과를 조회합니다` : '최근 점검의 주의·확인 불가 건수';
}

document.querySelector('#dashboardPage').addEventListener('click', event => {
  const trendHit = event.target.closest('#dashboardTrend [data-trend-index]');
  if (trendHit && currentOverview && providerSelect.value) {
    const entry = [...(currentOverview.history || [])].reverse()[Number(trendHit.dataset.trendIndex)];
    history.replaceState(null, '', '#daily-inspection'); showPage('daily-inspection');
    if (entry) viewCheck(providerSelect.value, entry.id);
    return;
  }
  const target = event.target.closest('[data-goto]');
  if (!target) return;
  const page = target.dataset.goto;
  history.replaceState(null, '', `#${page}`);
  showPage(page);
  if (page === 'alerts') {
    document.querySelector('#alertProviderFilter').value = target.dataset.alertScope === 'all' ? '' : providerSelect.value;
    document.querySelector('#alertSearch').value = '';
    loadAlerts().then(() => { if (target.dataset.alertId) openAlertAction(target.dataset.alertId); });
  } else if (page === 'history') {
    document.querySelector('#historyProviderFilter').value = target.dataset.historyScope === 'all' ? '' : providerSelect.value;
    loadWorkHistories().then(() => { if (target.dataset.historyId) { const card = document.querySelector(`[data-history-id="${target.dataset.historyId}"]`); if (card) { card.querySelector('[data-history-action="toggle"]')?.click(); card.scrollIntoView({behavior:'smooth', block:'center'}); } } });
  } else if (page === 'daily-inspection') {
    if (target.dataset.itemKey) setTimeout(() => focusInspectionItem(target.dataset.itemKey), 50);
    else if (target.dataset.filter) setInspectionFilter(target.dataset.filter, true);
    else if (target.dataset.setupOpen) { openSetupPanel(target.dataset.setupOpen, true); document.querySelector('.inspection-setup').scrollIntoView({behavior:'smooth', block:'start'}); }
  }
});
