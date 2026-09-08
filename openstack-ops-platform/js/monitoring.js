// ===== 모니터링 =====
let monitoringRange = '6h';
let monitoringData = null;
let monitoringTimer = null;
let monitoringLoading = false;
function formatRate(bytesPerSecond) {
  const value = Number(bytesPerSecond);
  if (!Number.isFinite(value)) return '-';
  if (value >= 1073741824) return `${(value / 1073741824).toFixed(2)} GiB/s`;
  if (value >= 1048576) return `${(value / 1048576).toFixed(2)} MiB/s`;
  if (value >= 1024) return `${(value / 1024).toFixed(1)} KiB/s`;
  return `${value.toFixed(0)} B/s`;
}
function formatUptime(seconds) {
  const value = Number(seconds);
  if (!Number.isFinite(value)) return '-';
  const days = Math.floor(value / 86400), hours = Math.floor((value % 86400) / 3600);
  return days ? `${days}일 ${hours}시간` : `${hours}시간 ${Math.floor((value % 3600) / 60)}분`;
}
function stopMonitoringAutoRefresh() { if (monitoringTimer) { clearInterval(monitoringTimer); monitoringTimer = null; } }
function startMonitoringAutoRefresh() {
  stopMonitoringAutoRefresh();
  if (document.querySelector('#monitoringAutoRefresh').checked && !document.querySelector('#monitoringPage').hidden) monitoringTimer = setInterval(() => loadMonitoring(true), 30000);
}
async function loadMonitoring(silent = false) {
  const providerId = monitoringProviderSelect.value;
  const source = document.querySelector('#monitoringSource');
  if (!providerId) {
    monitoringData = null;
    resetMonitoringExtensions();
    source.innerHTML = '<span class="prometheus-connection pending"><i></i>공급자를 선택하세요</span>';
    document.querySelector('#monitoringStats').innerHTML = '';
    document.querySelector('#monitoringCharts').innerHTML = '';
    document.querySelector('#monitoringNodes').innerHTML = '<div class="empty-provider">공급자를 선택하세요.</div>';
    document.querySelector('#monitoringTargets').innerHTML = '<div class="empty-provider">Prometheus에 연결되면 수집 대상을 표시합니다.</div>';
    return;
  }
  if (monitoringLoading) return;
  monitoringLoading = true;
  const button = document.querySelector('#refreshMonitoring');
  button.disabled = true;
  if (!silent) source.innerHTML = '<span class="prometheus-connection pending"><i></i>Prometheus 연결 확인 중</span>';
  document.querySelector('#monitoringPage').classList.add('loading');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring?range=${encodeURIComponent(monitoringRange)}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '모니터링 데이터를 불러오지 못했습니다.');
    monitoringData = data;
    renderMonitoring(data);
    loadMonitoringExtensions(providerId, silent);
  } catch (error) {
    source.innerHTML = `<span class="prometheus-connection failed"><i></i>조회 실패</span><span>${escapeText(error.message)}</span>`;
  } finally {
    monitoringLoading = false;
    button.disabled = false;
    document.querySelector('#monitoringPage').classList.remove('loading');
    startMonitoringAutoRefresh();
  }
}
function renderMonitoring(data) {
  const source = document.querySelector('#monitoringSource');
  const prom = data.prometheus || {};
  const connected = prom.status === 'connected';
  const rangeLabels = {'1h':'최근 1시간', '6h':'최근 6시간', '24h':'최근 24시간', '7d':'최근 7일'};
  const inspectionPoints = data.inspection?.checks || [];
  if (connected) {
    source.innerHTML = `<span class="prometheus-connection connected"><i></i>Prometheus 연결</span><span>수집원 ${escapeText(prom.source)}</span><span>수집 대상 ${prom.targets_up}/${prom.targets_total} up</span><span>${escapeText(rangeLabels[data.range] || data.range)} · ${prom.step >= 3600 ? `${prom.step / 3600}시간` : `${prom.step / 60}분`} 간격</span><span>갱신 ${escapeText(new Intl.DateTimeFormat('ko-KR', {timeStyle:'medium'}).format(new Date(prom.collected_at)))}</span>`;
  } else {
    source.innerHTML = `<span class="prometheus-connection ${prom.status === 'error' ? 'failed' : 'fallback'}"><i></i>${prom.status === 'error' ? 'Prometheus 조회 실패' : 'Prometheus 없음'}</span><span>${escapeText(prom.error || 'Controller와 VIP의 9090 포트에서 Prometheus를 찾지 못했습니다.')}</span><span>일일점검 이력의 노드 자원 수치로 대신 표시합니다 (최근 ${inspectionPoints.length}회 점검)</span>`;
  }
  // stats
  const nodes = connected ? prom.nodes : ((data.inspection_nodes?.nodes || []).filter(node => node.reachable));
  const avg = key => { const values = nodes.map(node => Number(node[key])).filter(Number.isFinite); return values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : null; };
  const max = key => { const values = nodes.map(node => Number(node[key])).filter(Number.isFinite); return values.length ? Math.max(...values) : null; };
  const tone = value => value == null ? '' : (value >= 90 ? 'critical' : (value >= 80 ? 'high' : ''));
  const networkTotal = connected ? nodes.reduce((sum, node) => sum + (Number(node.network_rx) || 0) + (Number(node.network_tx) || 0), 0) : null;
  const stats = [
    ['CPU 사용률', avg('cpu'), `최대 ${max('cpu') != null ? `${max('cpu').toFixed(1)}%` : '-'} · ${nodes.length}대 평균`],
    ['메모리 사용률', avg('memory'), `최대 ${max('memory') != null ? `${max('memory').toFixed(1)}%` : '-'}`],
    ['루트 디스크 사용률', avg('disk'), `최대 ${max('disk') != null ? `${max('disk').toFixed(1)}%` : '-'}`],
  ].map(([label, value, hint]) => `<article class="${tone(value)}"><small>${escapeText(label)}</small><strong>${value == null ? '-' : `${value.toFixed(1)}%`}</strong><em>${escapeText(hint)}</em></article>`);
  stats.push(connected
    ? `<article><small>네트워크 송수신 합계</small><strong>${escapeText(formatRate(networkTotal))}</strong><em>물리 인터페이스 5분 평균 · ${prom.targets_up}/${prom.targets_total} 대상 up</em></article>`
    : `<article><small>기준 시각</small><strong>${data.inspection_nodes ? escapeText(relativeTime(data.inspection_nodes.checked_at)) : '-'}</strong><em>${data.inspection_nodes ? escapeText(formatDateTime(data.inspection_nodes.checked_at)) + ' 일일점검' : '점검 결과 없음'}</em></article>`);
  document.querySelector('#monitoringStats').innerHTML = stats.join('');
  // charts
  const charts = document.querySelector('#monitoringCharts');
  const chartDefinitions = connected
    ? [['cpu', 'CPU 사용률', '%', 100], ['memory', '메모리 사용률', '%', 100], ['disk', '루트 디스크 사용률', '%', 100], ['network', '네트워크 송수신', 'rate', null]]
    : [['cpu', 'CPU 사용률', '%', 100], ['memory', '메모리 사용률', '%', 100], ['disk', '루트 디스크 사용률', '%', 100]];
  charts.innerHTML = chartDefinitions.map(([key, label]) => `<article class="panel"><header><strong>${escapeText(label)}</strong><small id="monitoringChartMeta-${key}"></small></header><div class="ts-chart" id="monitoringChart-${key}" data-chart-key="${key}" tabindex="0"></div></article>`).join('');
  chartDefinitions.forEach(([key, label, unit, maxValue]) => {
    let series;
    if (connected) {
      series = key === 'network'
        ? [{cls:'rx', label:'수신', points:prom.series.network.rx}, {cls:'tx', label:'송신', points:prom.series.network.tx}]
        : [{cls:'avg', label:'평균', points:prom.series[key].avg, area:true}, {cls:'max', label:'최대', points:prom.series[key].max}];
    } else {
      const points = data.inspection?.series?.[key] || [];
      series = [{cls:'avg', label:'평균', points:points.map(point => [point[0], point[1]]), area:true}, {cls:'max', label:'최대', points:points.map(point => [point[0], point[2]])}];
    }
    const meta = document.querySelector(`#monitoringChartMeta-${key}`);
    meta.textContent = connected ? (key === 'network' ? '물리 인터페이스 합계 · 5분 평균' : '전체 노드 평균 · 최대 · 주의 기준 80%') : `일일점검 ${(data.inspection?.series?.[key] || []).length}회 기준 · 주의 기준 80%`;
    renderTimeSeriesChart(document.querySelector(`#monitoringChart-${key}`), series, {unit, max:maxValue, threshold:unit === '%' ? 80 : null, range:data.range, discrete:!connected});
  });
  // nodes table
  const nodesBox = document.querySelector('#monitoringNodes');
  const gauge = value => { const numeric = Number(value); const ok = Number.isFinite(numeric); return `<div class="resource-gauge ${gaugeClass(value)}"><i><u style="width:${ok ? Math.max(0, Math.min(100, numeric)) : 0}%"></u></i><b>${ok ? `${numeric.toFixed(1)}%` : '-'}</b></div>`; };
  const roleLabel = role => role === 'controller' ? 'Controller' : (role === 'compute' ? 'Compute' : (role || '-'));
  if (connected) {
    nodesBox.innerHTML = nodes.length ? `<table><thead><tr><th>노드</th><th>역할</th><th>CPU</th><th>메모리</th><th>루트 디스크</th><th>수신</th><th>송신</th><th>Load 1m</th><th>가동 시간</th></tr></thead><tbody>${nodes.map(node => `<tr class="node-row" data-node-host="${escapeText(node.hostname)}" tabindex="0" title="클릭하면 노드 상세 차트를 엽니다"><td><strong>${escapeText(node.hostname)}</strong><br><small style="color:#8593a6">${escapeText(node.instance || '')}</small></td><td>${escapeText(roleLabel(node.role))}</td><td>${gauge(node.cpu)}</td><td>${gauge(node.memory)}</td><td>${gauge(node.disk)}</td><td>${escapeText(formatRate(node.network_rx))}</td><td>${escapeText(formatRate(node.network_tx))}</td><td>${node.load1 != null ? `${Number(node.load1).toFixed(2)}${node.cores ? ` / ${node.cores} Core` : ''}` : '-'}</td><td>${escapeText(formatUptime(node.uptime))}</td></tr>`).join('')}</tbody></table>` : '<div class="empty-provider">node_exporter 지표가 없습니다.</div>';
    document.querySelector('#monitoringNodesMeta').textContent = `node_exporter 최신 값 · ${nodes.length}대`;
  } else {
    const allNodes = data.inspection_nodes?.nodes || [];
    nodesBox.innerHTML = allNodes.length ? `<table><thead><tr><th>노드</th><th>역할</th><th>CPU</th><th>메모리</th><th>루트 디스크</th><th>Core</th><th>메모리 용량</th><th>가동 시간</th></tr></thead><tbody>${allNodes.map(node => `<tr class="node-row" data-node-host="${escapeText(node.hostname)}" tabindex="0" title="클릭하면 노드 상세를 엽니다"><td><strong>${escapeText(node.hostname)}</strong>${node.reachable ? '' : '<br><small style="color:#c33b49">SSH 접속 실패</small>'}</td><td>${escapeText(roleLabel(node.role))}</td><td>${gauge(node.cpu)}</td><td>${gauge(node.memory)}</td><td>${gauge(node.disk)}</td><td>${node.cores ?? '-'}</td><td>${node.memory_total ? escapeText(formatBytes(node.memory_total)) : '-'}</td><td>${escapeText(formatUptime(node.uptime))}</td></tr>`).join('')}</tbody></table>` : '<div class="empty-provider">노드 점검 결과가 없습니다. 일일점검을 실행하세요.</div>';
    document.querySelector('#monitoringNodesMeta').textContent = data.inspection_nodes ? `${formatDateTime(data.inspection_nodes.checked_at)} 일일점검 기준 · 실시간이 아닙니다` : '일일점검 결과 없음';
  }
  // targets
  const targetsBox = document.querySelector('#monitoringTargets');
  const targets = connected ? prom.targets : [];
  document.querySelector('#monitoringTargetsCount').textContent = targets.length;
  const down = targets.filter(target => !target.up).length;
  document.querySelector('#monitoringTargetsMeta').textContent = connected ? (down ? `down ${down}건 · 먼저 표시` : 'job별 up 상태 · 모두 정상') : 'Prometheus 연결 시 표시';
  targetsBox.innerHTML = targets.length ? `<table><thead><tr><th>상태</th><th>Job</th><th>Instance</th><th>노드</th></tr></thead><tbody>${targets.map(target => `<tr class="${target.up ? 'up' : 'down'}"><td><span class="target-state ${target.up ? 'up' : 'down'}">${target.up ? 'UP' : 'DOWN'}</span></td><td><strong>${escapeText(target.job)}</strong></td><td>${escapeText(target.instance)}</td><td>${escapeText(target.nodename || '-')}</td></tr>`).join('')}</tbody></table>` : `<div class="empty-provider">${connected ? '수집 대상이 없습니다.' : 'Prometheus에 연결되면 수집 대상을 표시합니다.'}</div>`;
}

function renderTimeSeriesChart(box, series, {unit = '%', max = null, threshold = null, range = '6h', discrete = false} = {}) {
  if (!box) return;
  const all = series.flatMap(item => item.points || []);
  if (all.length < 2) { box.innerHTML = '<div class="empty-provider">표시할 데이터가 없습니다.</div>'; return; }
  const width = Math.max(360, Math.min(1400, (box.clientWidth || 600) - 4)), height = 190, left = 44, right = 84, top = 12, bottom = 26;
  const plotWidth = width - left - right, plotHeight = height - top - bottom;
  const times = all.map(point => point[0]);
  const tMin = Math.min(...times), tMax = Math.max(...times);
  const values = all.map(point => point[1]).filter(Number.isFinite);
  const dataMax = Math.max(...values, 0);
  const yMax = max != null ? max : (dataMax <= 0 ? 1 : dataMax * 1.15);
  const x = time => left + (tMax === tMin ? plotWidth / 2 : (time - tMin) / (tMax - tMin) * plotWidth);
  const y = value => top + plotHeight - Math.max(0, Math.min(yMax, value)) / yMax * plotHeight;
  const formatValue = value => unit === '%' ? `${Number(value).toFixed(1)}%` : (unit === 'rate' ? formatRate(value) : (Math.abs(Number(value)) >= 1000 ? Number(value).toLocaleString('ko-KR', {maximumFractionDigits:0}) : Number(value).toFixed(2)));
  const ticks = 4;
  const gridlines = Array.from({length: ticks + 1}, (_, index) => yMax / ticks * index).map(value => `<line class="grid" x1="${left}" y1="${y(value)}" x2="${left + plotWidth}" y2="${y(value)}"></line><text class="axis-label" x="${left - 6}" y="${y(value) + 3}" text-anchor="end">${unit === '%' ? `${Math.round(value)}%` : (unit === 'rate' ? escapeText(formatRate(value).replace(/\.\d+/, '')) : escapeText(formatValue(value)))}</text>`).join('');
  const labelCount = Math.min(6, Math.max(2, Math.floor(plotWidth / 110)));
  const timeFormat = new Intl.DateTimeFormat('ko-KR', range === '7d' ? {month:'2-digit', day:'2-digit', hour:'2-digit', hour12:false} : {hour:'2-digit', minute:'2-digit', hour12:false});
  const xLabels = Array.from({length: labelCount}, (_, index) => tMin + (tMax - tMin) * index / (labelCount - 1)).map((time, index) => `<text class="axis-label" x="${x(time)}" y="${height - 8}" text-anchor="${index === 0 ? 'start' : (index === labelCount - 1 ? 'end' : 'middle')}">${escapeText(timeFormat.format(new Date(time * 1000)))}</text>`).join('');
  const thresholdLine = threshold != null && threshold < yMax ? `<line class="threshold" x1="${left}" y1="${y(threshold)}" x2="${left + plotWidth}" y2="${y(threshold)}"></line>` : '';
  const paths = series.map(item => {
    const points = (item.points || []).filter(point => Number.isFinite(point[1]));
    if (!points.length) return '';
    const coordinates = points.map(point => `${x(point[0]).toFixed(1)},${y(point[1]).toFixed(1)}`).join(' ');
    const area = item.area ? `<polygon class="area ${item.cls}" points="${x(points[0][0]).toFixed(1)},${(top + plotHeight).toFixed(1)} ${coordinates} ${x(points[points.length - 1][0]).toFixed(1)},${(top + plotHeight).toFixed(1)}"></polygon>` : '';
    const markers = discrete ? points.map(point => `<circle class="marker ${item.cls}" cx="${x(point[0]).toFixed(1)}" cy="${y(point[1]).toFixed(1)}" r="3.5"></circle>`).join('') : '';
    return `${area}<polyline class="series ${item.cls}" points="${coordinates}"></polyline>${markers}`;
  }).join('');
  const ends = series.map(item => { const points = (item.points || []).filter(point => Number.isFinite(point[1])); return points.length ? {cls:item.cls, label:item.label, value:points[points.length - 1][1], yPos:y(points[points.length - 1][1])} : null; }).filter(Boolean).sort((a, b) => a.yPos - b.yPos);
  for (let index = 1; index < ends.length; index += 1) if (ends[index].yPos - ends[index - 1].yPos < 13) ends[index].yPos = ends[index - 1].yPos + 13;
  const endLabels = ends.map(item => `<line class="end-key ${item.cls}" x1="${left + plotWidth + 6}" y1="${item.yPos}" x2="${left + plotWidth + 16}" y2="${item.yPos}"></line><text class="end-label" x="${left + plotWidth + 20}" y="${item.yPos + 3.5}">${escapeText(item.label)} ${escapeText(formatValue(item.value))}</text>`).join('');
  const legend = `<div class="ts-legend">${series.map(item => { const points = (item.points || []).filter(point => Number.isFinite(point[1])); const latest = points.length ? points[points.length - 1][1] : null; return `<span class="${item.cls}"><i aria-hidden="true"></i>${escapeText(item.label)} <b>${latest == null ? '-' : escapeText(formatValue(latest))}</b></span>`; }).join('')}</div>`;
  box.innerHTML = `${legend}<svg viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" preserveAspectRatio="xMinYMin meet" role="img" aria-label="${escapeText(series.map(item => item.label).join('·'))} 추이">${gridlines}${xLabels}${thresholdLine}${paths}${endLabels}<line class="crosshair" x1="-10" y1="${top}" x2="-10" y2="${top + plotHeight}" data-crosshair></line><rect class="hit" x="${left}" y="${top}" width="${plotWidth}" height="${plotHeight}" data-hit></rect></svg><div class="ts-tooltip" hidden></div>`;
  const tooltip = box.querySelector('.ts-tooltip');
  const crosshair = box.querySelector('[data-crosshair]');
  const hit = box.querySelector('[data-hit]');
  const show = clientX => {
    const rect = hit.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    const time = tMin + ratio * (tMax - tMin);
    const rows = series.map(item => { const points = (item.points || []).filter(point => Number.isFinite(point[1])); if (!points.length) return null; let best = points[0]; points.forEach(point => { if (Math.abs(point[0] - time) < Math.abs(best[0] - time)) best = point; }); return {cls:item.cls, label:item.label, point:best}; }).filter(Boolean);
    if (!rows.length) return;
    const anchorTime = rows[0].point[0];
    crosshair.setAttribute('x1', x(anchorTime)); crosshair.setAttribute('x2', x(anchorTime));
    tooltip.innerHTML = '';
    const title = document.createElement('strong'); title.textContent = new Intl.DateTimeFormat('ko-KR', {dateStyle:'short', timeStyle:'short'}).format(new Date(anchorTime * 1000)); tooltip.appendChild(title);
    rows.forEach(row => { const line = document.createElement('div'); line.className = row.cls; const key = document.createElement('i'); const value = document.createElement('b'); value.textContent = formatValue(row.point[1]); const name = document.createElement('span'); name.textContent = row.label; line.append(key, value, name); tooltip.appendChild(line); });
    tooltip.hidden = false;
    const boxWidth = box.getBoundingClientRect().width;
    const anchor = x(anchorTime) / width * Math.min(boxWidth, width);
    tooltip.style.left = `${Math.max(0, Math.min(boxWidth - tooltip.offsetWidth, anchor + (ratio > 0.6 ? -tooltip.offsetWidth - 12 : 12)))}px`;
  };
  hit.addEventListener('pointermove', event => show(event.clientX));
  box.addEventListener('pointerleave', () => { tooltip.hidden = true; crosshair.setAttribute('x1', -10); crosshair.setAttribute('x2', -10); });
}

monitoringProviderSelect.addEventListener('change', () => {
  providerSelect.value = monitoringProviderSelect.value;
  inspectionProviderSelect.value = monitoringProviderSelect.value;
  infrastructureProviderSelect.value = monitoringProviderSelect.value;
  if (monitoringProviderSelect.value) { loadProviderNodes(monitoringProviderSelect.value); loadCheckExceptions(monitoringProviderSelect.value); loadCustomChecks(monitoringProviderSelect.value); loadLatestCheck(monitoringProviderSelect.value); }
  loadMonitoring();
});
document.querySelector('#monitoringRange').addEventListener('click', event => {
  const button = event.target.closest('[data-range]');
  if (!button) return;
  monitoringRange = button.dataset.range;
  document.querySelectorAll('#monitoringRange button').forEach(item => item.classList.toggle('active', item === button));
  loadMonitoring();
});
document.querySelector('#refreshMonitoring').addEventListener('click', () => loadMonitoring());
document.querySelector('#monitoringAutoRefresh').addEventListener('change', startMonitoringAutoRefresh);
window.addEventListener('resize', () => { if (monitoringData && !document.querySelector('#monitoringPage').hidden) { clearTimeout(window.__monitoringResize); window.__monitoringResize = setTimeout(() => renderMonitoring(monitoringData), 200); } });


// ===== 모니터링 확장: 수집원 설정, 임계치 알림 규칙, 노드 상세, OpenStack API·HAProxy, Alertmanager, PromQL =====
let monitoringSettingsData = null;
let monitoringRulesData = null;
let monitoringNodeDetail = null;
let monitoringQueryMode = 'instant';
let monitoringExtensionsProvider = '';
const monitoringQueryHistoryKey = 'okestro-promql-history';

function monitoringApiError(data, fallback) { return typeof data?.detail === 'string' ? data.detail : (data?.detail?.message || fallback); }
function monitoringRoleLabel(role) { return role === 'controller' ? 'Controller' : (role === 'compute' ? 'Compute' : (role || '-')); }

function resetMonitoringExtensions() {
  monitoringExtensionsProvider = '';
  monitoringSettingsData = null; monitoringRulesData = null; monitoringNodeDetail = null;
  document.querySelector('#monitoringNodeDetailPanel').hidden = true;
  document.querySelector('#monitoringGrafanaLink').hidden = true;
  document.querySelector('#monitoringApiProbes').innerHTML = '<div class="empty-provider">공급자를 선택하세요.</div>';
  document.querySelector('#monitoringHaproxy').innerHTML = '<div class="empty-provider">-</div>';
  document.querySelector('#monitoringMiddleware').innerHTML = '';
  document.querySelector('#monitoringAlertmanager').innerHTML = '<div class="empty-provider">공급자를 선택하세요.</div>';
  document.querySelector('#monitoringAlertmanagerCount').textContent = '0';
  document.querySelector('#monitoringQueryResult').innerHTML = '<div class="empty-provider">조회식을 입력하세요.</div>';
}

function loadMonitoringExtensions(providerId, silent) {
  const changed = providerId !== monitoringExtensionsProvider;
  monitoringExtensionsProvider = providerId;
  if (changed) { document.querySelector('#monitoringNodeDetailPanel').hidden = true; monitoringNodeDetail = null; }
  if (changed || !silent) { loadMonitoringSettings(providerId); loadMonitoringRules(providerId); }
  loadMonitoringOpenstack(providerId);
  loadMonitoringAlertmanager(providerId);
  if (monitoringNodeDetail && !document.querySelector('#monitoringNodeDetailPanel').hidden) loadMonitoringNodeDetail(monitoringNodeDetail.hostname, true);
}

// --- 수집원 설정 -------------------------------------------------------------------------------
async function loadMonitoringSettings(providerId) {
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/settings`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '수집원 설정을 불러오지 못했습니다.'));
    monitoringSettingsData = data;
    renderMonitoringSettings(data);
  } catch (error) { document.querySelector('#monitoringSettingsMeta').textContent = error.message; }
}
function renderMonitoringSettings(data) {
  const form = document.querySelector('#monitoringSettingsForm');
  form.elements.prometheus_url.value = data.prometheus_url || '';
  form.elements.auth_type.value = data.auth_type || 'none';
  form.elements.username.value = data.username || '';
  form.elements.secret.value = '';
  form.elements.verify_tls.checked = data.verify_tls !== false;
  form.elements.grafana_url.value = data.grafana_url || '';
  form.elements.alertmanager_url.value = data.alertmanager_url || '';
  document.querySelector('#monitoringSecretHint').textContent = data.secret_configured ? '암호화된 비밀이 저장되어 있습니다. 비워두면 유지되고, 입력하면 교체됩니다.' : '저장된 비밀 없음';
  const badge = document.querySelector('#monitoringSettingsSource');
  badge.className = `setting-source ${data.source === 'stored' ? 'stored' : 'default'}`;
  badge.textContent = data.source === 'stored' ? `저장값 · ${data.updated_by || '관리자'} · ${formatDateTime(data.updated_at)}` : '자동 탐색(9090) 사용 중';
  const grafana = document.querySelector('#monitoringGrafanaLink');
  if (data.grafana_url) { grafana.href = data.grafana_url; grafana.hidden = false; } else { grafana.hidden = true; grafana.removeAttribute('href'); }
  updateMonitoringAuthFields();
}
function updateMonitoringAuthFields() {
  const form = document.querySelector('#monitoringSettingsForm');
  const type = form.elements.auth_type.value;
  form.elements.username.disabled = type !== 'basic';
  form.elements.secret.disabled = type === 'none';
  form.elements.secret.placeholder = type === 'bearer' ? '토큰 · 변경할 때만 입력' : (type === 'basic' ? '비밀번호 · 변경할 때만 입력' : '인증 없음');
}
document.querySelector('#monitoringSettingsForm').elements.auth_type.addEventListener('change', updateMonitoringAuthFields);
document.querySelector('#toggleMonitoringSettings').addEventListener('click', () => {
  const panel = document.querySelector('#monitoringSettingsPanel');
  panel.hidden = !panel.hidden;
  if (!panel.hidden) { if (monitoringProviderSelect.value && !monitoringSettingsData) loadMonitoringSettings(monitoringProviderSelect.value); panel.scrollIntoView({behavior:'smooth', block:'start'}); }
});
document.querySelector('#closeMonitoringSettings').addEventListener('click', () => { document.querySelector('#monitoringSettingsPanel').hidden = true; });
document.querySelector('#monitoringSettingsForm').addEventListener('submit', async event => {
  event.preventDefault();
  const providerId = monitoringProviderSelect.value;
  if (!providerId) return showToast('공급자를 선택하세요.', '수집원 설정은 공급자별로 저장됩니다.');
  const form = event.currentTarget;
  const button = form.querySelector('button[type="submit"]');
  const payload = {
    prometheus_url: form.elements.prometheus_url.value.trim(), auth_type: form.elements.auth_type.value, username: form.elements.username.value.trim(),
    secret: form.elements.secret.value ? form.elements.secret.value : (form.elements.auth_type.value === 'none' ? '' : null),
    verify_tls: form.elements.verify_tls.checked, grafana_url: form.elements.grafana_url.value.trim(), alertmanager_url: form.elements.alertmanager_url.value.trim(),
  };
  button.disabled = true;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/settings`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '수집원 설정을 저장하지 못했습니다.'));
    monitoringSettingsData = data;
    renderMonitoringSettings(data);
    showToast('수집원 설정을 저장했습니다.', data.prometheus_url ? `${data.prometheus_url} · 인증 ${data.auth_type}` : '9090 자동 탐색을 사용합니다.');
    loadMonitoring();
  } catch (error) { showToast('수집원 설정을 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
document.querySelector('#testMonitoringConnection').addEventListener('click', async event => {
  const providerId = monitoringProviderSelect.value;
  if (!providerId) return showToast('공급자를 선택하세요.', '연결 테스트는 저장된 설정으로 실행됩니다.');
  const button = event.currentTarget;
  const result = document.querySelector('#monitoringTestResult');
  button.disabled = true; result.textContent = '연결 확인 중…';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/test`, {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '연결 테스트에 실패했습니다.'));
    if (data.status === 'connected') result.innerHTML = `<b class="ok">연결 성공</b> ${escapeText(data.source)}${data.fallback ? ' <em>(설정 주소 응답 없음 · 자동 탐색으로 대체)</em>' : ''} · ${data.version ? `v${escapeText(data.version)} · ` : ''}${data.latency_ms}ms · 수집 대상 ${data.targets_up}/${data.targets_total} up`;
    else result.innerHTML = `<b class="fail">${data.status === 'error' ? '조회 실패' : '연결 실패'}</b> ${escapeText(data.error || '-')}`;
  } catch (error) { result.innerHTML = `<b class="fail">실패</b> ${escapeText(error.message)}`; }
  finally { button.disabled = false; }
});

// --- 임계치 알림 규칙 ----------------------------------------------------------------------------
async function loadMonitoringRules(providerId) {
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/rules`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '임계치 규칙을 불러오지 못했습니다.'));
    monitoringRulesData = data;
    renderMonitoringRules(data);
  } catch (error) { document.querySelector('#monitoringRulesStatus').textContent = error.message; }
}
function renderMonitoringRules(data) {
  const form = document.querySelector('#monitoringRulesForm');
  const rules = data.value || {};
  form.elements.enabled.checked = rules.enabled !== false;
  form.elements.sustained_minutes.value = rules.sustained_minutes ?? 5;
  [['cpu', 'cpu'], ['memory', 'memory'], ['disk', 'disk'], ['load_per_core', 'load']].forEach(([key, prefix]) => {
    form.elements[`${prefix}_warning`].value = rules[key]?.warning ?? '';
    form.elements[`${prefix}_critical`].value = rules[key]?.critical ?? '';
  });
  form.elements.node_down.checked = rules.node_down !== false;
  form.elements.target_down.checked = rules.target_down !== false;
  const badge = document.querySelector('#monitoringRulesSource');
  badge.className = `setting-source ${data.source === 'stored' ? 'stored' : 'default'}`;
  badge.textContent = data.source === 'stored' ? `저장값 · ${data.updated_by || '관리자'} · ${formatDateTime(data.updated_at)}` : '기본 임계치 사용 중';
  const last = data.last_evaluation;
  const statusLabels = {ok:'평가 완료', disabled:'규칙 사용 안 함', no_prometheus:'Prometheus 없음 · 평가 건너뜀', error:'평가 실패', skipped:'-'};
  document.querySelector('#monitoringRulesStatus').textContent = last
    ? `마지막 평가 ${formatDateTime(last.evaluated_at)} · ${statusLabels[last.status] || last.status} · 활성 ${last.active}건 · 신규 ${last.created} · 해소 ${last.resolved}${last.suppressed ? ` · 정비 창 억제 ${last.suppressed}` : ''}${last.error ? ` · ${last.error}` : ''} · ${data.interval_seconds}초 주기`
    : `서버 시작 후 아직 평가 전 · ${data.interval_seconds}초 주기로 평가합니다`;
}
function monitoringRulesPayload(form) {
  const number = name => { const value = form.elements[name].value; return value === '' ? null : Number(value); };
  const pair = prefix => { const warning = number(`${prefix}_warning`), critical = number(`${prefix}_critical`); return warning == null && critical == null ? null : {warning: warning ?? critical, critical: critical ?? warning}; };
  return {enabled: form.elements.enabled.checked, sustained_minutes: Number(form.elements.sustained_minutes.value) || 5, cpu: pair('cpu'), memory: pair('memory'), disk: pair('disk'), load_per_core: pair('load'), node_down: form.elements.node_down.checked, target_down: form.elements.target_down.checked};
}
document.querySelector('#monitoringRulesForm').addEventListener('submit', async event => {
  event.preventDefault();
  const providerId = monitoringProviderSelect.value;
  if (!providerId) return showToast('공급자를 선택하세요.', '임계치 규칙은 공급자별로 저장됩니다.');
  const form = event.currentTarget;
  const button = form.querySelector('button[type="submit"]');
  button.disabled = true;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/rules`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({value: monitoringRulesPayload(form)})});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '임계치 규칙을 저장하지 못했습니다.'));
    monitoringRulesData = data; renderMonitoringRules(data);
    showToast('임계치 알림 규칙을 저장했습니다.', '다음 평가 주기부터 적용됩니다. 알림은 알림 및 장애에서 확인합니다.');
  } catch (error) { showToast('임계치 규칙을 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
document.querySelector('#resetMonitoringRules').addEventListener('click', async () => {
  const providerId = monitoringProviderSelect.value;
  if (!providerId || !window.confirm('임계치 알림 규칙을 기본값으로 되돌릴까요?')) return;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/rules`, {method:'DELETE'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '초기화하지 못했습니다.'));
    monitoringRulesData = data; renderMonitoringRules(data);
    showToast('임계치 규칙을 기본값으로 되돌렸습니다.', 'CPU·메모리·디스크 85/95%, Core당 Load 2/4.');
  } catch (error) { showToast('초기화하지 못했습니다.', error.message); }
});
document.querySelector('#evaluateMonitoringRules').addEventListener('click', async event => {
  const providerId = monitoringProviderSelect.value;
  if (!providerId) return;
  const button = event.currentTarget;
  button.disabled = true;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/evaluate`, {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '평가에 실패했습니다.'));
    const labels = {ok:'평가 완료', disabled:'규칙 사용 안 함', no_prometheus:'Prometheus를 찾지 못했습니다', error:'평가 실패'};
    showToast(labels[data.status] || data.status, data.status === 'ok' ? `활성 ${data.active}건 · 신규 ${data.created}건 · 해소 ${data.resolved}건${data.suppressed ? ` · 정비 창 억제 ${data.suppressed}건` : ''}` : (data.error || '수집원 설정을 확인하세요.'));
    await loadMonitoringRules(providerId);
    if (typeof loadAlertSummary === 'function') loadAlertSummary();
  } catch (error) { showToast('평가에 실패했습니다.', error.message); }
  finally { button.disabled = false; }
});

// --- 노드 상세 -----------------------------------------------------------------------------------
async function loadMonitoringNodeDetail(hostname, silent = false) {
  const providerId = monitoringProviderSelect.value;
  if (!providerId || !hostname) return;
  const panel = document.querySelector('#monitoringNodeDetailPanel');
  panel.hidden = false;
  document.querySelector('#monitoringNodeDetailTitle').textContent = `${hostname} 상세`;
  if (!silent) { document.querySelector('#monitoringNodeDetailMeta').textContent = '불러오는 중…'; panel.scrollIntoView({behavior:'smooth', block:'start'}); }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/nodes/${encodeURIComponent(hostname)}?range=${encodeURIComponent(monitoringRange)}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '노드 상세를 불러오지 못했습니다.'));
    monitoringNodeDetail = data;
    renderMonitoringNodeDetail(data);
  } catch (error) { document.querySelector('#monitoringNodeDetailMeta').textContent = error.message; }
}
function renderMonitoringNodeDetail(data) {
  const prom = data.prometheus || {};
  const connected = prom.status === 'connected';
  const inventory = data.inventory;
  const meta = document.querySelector('#monitoringNodeDetailMeta');
  const facts = document.querySelector('#monitoringNodeFacts');
  const charts = document.querySelector('#monitoringNodeCharts');
  const fsBox = document.querySelector('#monitoringNodeFilesystems');
  const ifBox = document.querySelector('#monitoringNodeInterfaces');
  const percent = value => (value == null || !Number.isFinite(Number(value))) ? '-' : `${Number(value).toFixed(1)}%`;
  if (connected) {
    const f = prom.facts || {};
    meta.textContent = `${inventory ? `${monitoringRoleLabel(inventory.role)} · ${inventory.address || ''} · ` : ''}instance ${prom.instance} · ${new Intl.DateTimeFormat('ko-KR', {timeStyle:'medium'}).format(new Date(prom.collected_at))} 기준 · Prometheus 실시간`;
    const swapUsed = f.swap_total ? (1 - (f.swap_free || 0) / f.swap_total) * 100 : null;
    const fdPercent = f.fd_maximum ? (f.fd_allocated || 0) / f.fd_maximum * 100 : null;
    const cards = [
      ['CPU 사용률', percent(f.cpu), `${f.cores ?? '-'} Core`, gaugeClass(f.cpu)],
      ['메모리 사용률', percent(f.memory), f.memory_total ? formatBytes(f.memory_total) : '-', gaugeClass(f.memory)],
      ['I/O 대기(iowait)', percent(f.iowait), f.steal != null ? `steal ${Number(f.steal).toFixed(1)}%` : '', f.iowait >= 20 ? 'critical' : (f.iowait >= 10 ? 'high' : '')],
      ['Swap 사용', f.swap_total ? percent(swapUsed) : '없음', f.swap_total ? `${formatBytes(f.swap_total - (f.swap_free || 0))} / ${formatBytes(f.swap_total)}` : 'swap 미구성', swapUsed != null ? gaugeClass(swapUsed) : ''],
      ['열린 파일 디스크립터', f.fd_allocated != null ? Math.round(f.fd_allocated).toLocaleString() : '-', f.fd_maximum ? `최대 ${Math.round(f.fd_maximum).toLocaleString()} · ${percent(fdPercent)}` : '', fdPercent != null ? gaugeClass(fdPercent) : ''],
      ['Load 1m / 5m / 15m', [f.load1, f.load5, f.load15].map(value => value == null ? '-' : Number(value).toFixed(2)).join(' / '), f.cores && f.load1 != null ? `Core당 ${(f.load1 / f.cores).toFixed(2)}` : '', f.cores && f.load1 / f.cores >= 4 ? 'critical' : (f.cores && f.load1 / f.cores >= 2 ? 'high' : '')],
      ['conntrack', f.conntrack != null ? Math.round(f.conntrack).toLocaleString() : '-', f.conntrack_limit ? `한도 ${Math.round(f.conntrack_limit).toLocaleString()}` : '', f.conntrack_limit && f.conntrack / f.conntrack_limit >= 0.8 ? 'high' : ''],
      ['프로세스', `실행 ${f.procs_running ?? '-'} · 대기 ${f.procs_blocked ?? '-'}`, f.uptime != null ? `가동 ${formatUptime(f.uptime)}` : '', f.procs_blocked >= 5 ? 'high' : ''],
    ];
    facts.innerHTML = cards.map(([label, value, hint, cls]) => `<article class="${escapeText(cls || '')}"><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong><em>${escapeText(hint || '')}</em></article>`).join('');
    const definitions = [['cpu', 'CPU 사용률', '%', 100, [{cls:'avg', label:'CPU', points:prom.series.cpu, area:true}]], ['memory', '메모리 사용률', '%', 100, [{cls:'avg', label:'메모리', points:prom.series.memory, area:true}]],
      ['iowait', 'I/O 대기', '%', null, [{cls:'max', label:'iowait', points:prom.series.iowait, area:true}]], ['diskio', '디스크 I/O', 'rate', null, [{cls:'rx', label:'읽기', points:prom.series.disk_read}, {cls:'tx', label:'쓰기', points:prom.series.disk_write}]],
      ['network', '네트워크', 'rate', null, [{cls:'rx', label:'수신', points:prom.series.net_rx}, {cls:'tx', label:'송신', points:prom.series.net_tx}]], ['load', 'Load 1m', 'load', null, [{cls:'max', label:'Load 1m', points:prom.series.load1, area:true}]]];
    charts.innerHTML = definitions.map(([key, label]) => `<article class="panel"><header><strong>${escapeText(label)}</strong><small>${escapeText(data.hostname)}</small></header><div class="ts-chart" id="monitoringNodeChart-${key}" tabindex="0"></div></article>`).join('');
    definitions.forEach(([key, , unit, maxValue, series]) => renderTimeSeriesChart(document.querySelector(`#monitoringNodeChart-${key}`), series, {unit: unit === 'load' ? '' : unit, max:maxValue, threshold: unit === '%' && maxValue ? 80 : null, range:data.range}));
    fsBox.innerHTML = prom.filesystems.length ? `<table><thead><tr><th>마운트</th><th>장치</th><th>형식</th><th>사용률</th><th>여유 / 전체</th></tr></thead><tbody>${prom.filesystems.map(fs => `<tr><td><strong>${escapeText(fs.mountpoint)}</strong></td><td>${escapeText(fs.device)}</td><td>${escapeText(fs.fstype)}</td><td><div class="resource-gauge ${gaugeClass(fs.used_percent)}"><i><u style="width:${Math.max(0, Math.min(100, fs.used_percent || 0))}%"></u></i><b>${percent(fs.used_percent)}</b></div></td><td>${fs.avail != null ? escapeText(formatBytes(fs.avail)) : '-'} / ${fs.size != null ? escapeText(formatBytes(fs.size)) : '-'}</td></tr>`).join('')}</tbody></table>` : '<div class="empty-provider">파일시스템 지표가 없습니다.</div>';
    const speed = value => (value == null || value <= 0) ? '-' : `${(value * 8 / 1e9).toFixed(value * 8 >= 1e9 ? 0 : 1)} Gbps`;
    ifBox.innerHTML = prom.interfaces.length ? `<table><thead><tr><th>인터페이스</th><th>링크</th><th>수신</th><th>송신</th><th>속도</th></tr></thead><tbody>${prom.interfaces.map(item => `<tr class="${item.up === 0 ? 'down' : ''}"><td><strong>${escapeText(item.device)}</strong></td><td><span class="target-state ${item.up === 0 ? 'down' : 'up'}">${item.up == null ? '-' : (item.up ? 'UP' : 'DOWN')}</span></td><td>${escapeText(formatRate(item.rx))}</td><td>${escapeText(formatRate(item.tx))}</td><td>${escapeText(speed(item.speed))}</td></tr>`).join('')}</tbody></table>` : '<div class="empty-provider">인터페이스 지표가 없습니다.</div>';
    return;
  }
  const latest = data.inspection?.latest;
  meta.textContent = `${prom.error || 'Prometheus 없음'} · 일일점검 이력 값만 표시합니다${latest ? ` (${formatDateTime(latest.checked_at)} 기준)` : ''}`;
  if (latest) {
    const m = latest.metrics || {};
    facts.innerHTML = [['CPU 사용률', percent(m.cpu_used_percent), `${m.cpu_cores ?? '-'} Core`, gaugeClass(m.cpu_used_percent)], ['메모리 사용률', percent(m.memory_used_percent), m.memory_total_kb ? formatBytes(m.memory_total_kb * 1024) : '', gaugeClass(m.memory_used_percent)], ['루트 디스크', percent(m.disk_used_percent), m.disk_total_kb ? formatBytes(m.disk_total_kb * 1024) : '', gaugeClass(m.disk_used_percent)], ['가동 시간', formatUptime(m.uptime_seconds), latest.warnings?.length ? `주의 ${latest.warnings.length}건` : '이상 없음', latest.warnings?.length ? 'high' : '']]
      .map(([label, value, hint, cls]) => `<article class="${escapeText(cls || '')}"><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong><em>${escapeText(hint || '')}</em></article>`).join('');
  } else facts.innerHTML = '<div class="empty-provider">이 노드의 점검 결과가 없습니다.</div>';
  const series = data.inspection?.series || {cpu:[], memory:[], disk:[]};
  charts.innerHTML = [['cpu', 'CPU 사용률'], ['memory', '메모리 사용률'], ['disk', '루트 디스크 사용률']].map(([key, label]) => `<article class="panel"><header><strong>${escapeText(label)}</strong><small>일일점검 ${series[key].length}회</small></header><div class="ts-chart" id="monitoringNodeChart-${key}" tabindex="0"></div></article>`).join('');
  ['cpu', 'memory', 'disk'].forEach(key => renderTimeSeriesChart(document.querySelector(`#monitoringNodeChart-${key}`), [{cls:'avg', label:key.toUpperCase(), points:series[key], area:true}], {unit:'%', max:100, threshold:80, range:data.range, discrete:true}));
  fsBox.innerHTML = '<div class="empty-provider">Prometheus에 연결되면 파티션별 사용률을 표시합니다.</div>';
  ifBox.innerHTML = '<div class="empty-provider">Prometheus에 연결되면 인터페이스 트래픽을 표시합니다.</div>';
}
document.querySelector('#monitoringNodes').addEventListener('click', event => { const row = event.target.closest('[data-node-host]'); if (row) loadMonitoringNodeDetail(row.dataset.nodeHost); });
document.querySelector('#monitoringNodes').addEventListener('keydown', event => { if (event.key !== 'Enter' && event.key !== ' ') return; const row = event.target.closest('[data-node-host]'); if (row) { event.preventDefault(); loadMonitoringNodeDetail(row.dataset.nodeHost); } });
document.querySelector('#closeMonitoringNodeDetail').addEventListener('click', () => { document.querySelector('#monitoringNodeDetailPanel').hidden = true; monitoringNodeDetail = null; });

// --- OpenStack API · HAProxy · Middleware -----------------------------------------------------------
async function loadMonitoringOpenstack(providerId) {
  const probes = document.querySelector('#monitoringApiProbes');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/openstack`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, 'OpenStack 상태를 불러오지 못했습니다.'));
    renderMonitoringOpenstack(data);
  } catch (error) { probes.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
function renderMonitoringOpenstack(data) {
  document.querySelector('#monitoringOpenstackMeta').textContent = `VIP ${data.provider.vip} · ${new Intl.DateTimeFormat('ko-KR', {timeStyle:'medium'}).format(new Date(data.collected_at))} 기준${data.source ? ` · exporter 지표 ${data.source}` : ' · Prometheus 없음(API 응답만 확인)'}`;
  document.querySelector('#monitoringApiSummary').textContent = `${data.api_reachable}/${data.api.length} 응답`;
  document.querySelector('#monitoringApiProbes').innerHTML = `<table><thead><tr><th>서비스</th><th>포트</th><th>응답</th><th>HTTP</th><th>지연</th></tr></thead><tbody>${data.api.map(item => `<tr class="${item.reachable ? 'up' : 'down'}"><td><strong>${escapeText(item.label)}</strong></td><td>${item.port}</td><td><span class="target-state ${item.reachable ? 'up' : 'down'}">${item.reachable ? '응답' : '응답 없음'}</span></td><td>${item.status_code ?? '-'}${item.scheme === 'https' ? ' (https)' : ''}</td><td>${item.latency_ms != null ? `${item.latency_ms}ms` : escapeText(item.error || '-')}</td></tr>`).join('')}</tbody></table><p class="monitoring-note">응답 없음은 해당 서비스가 이 사이트에 없거나 VIP에서 열리지 않은 포트일 수 있습니다. 300·401 응답도 API가 살아 있다는 뜻입니다.</p>`;
  const haproxy = data.haproxy || {};
  const haBox = document.querySelector('#monitoringHaproxy');
  if (haproxy.status === 'ok' && haproxy.backends.length) {
    haBox.innerHTML = `<table><thead><tr><th>백엔드</th><th>상태</th><th>서버</th></tr></thead><tbody>${haproxy.backends.map(item => `<tr class="${item.up === false ? 'down' : 'up'}"><td><strong>${escapeText(item.backend)}</strong></td><td><span class="target-state ${item.up === false ? 'down' : 'up'}">${item.up == null ? '-' : (item.up ? 'UP' : 'DOWN')}</span></td><td>${item.servers_total ? `${item.servers_up}/${item.servers_total} up · ${item.servers.map(server => `<span class="server-chip ${server.up ? 'up' : 'down'}">${escapeText(server.server)}</span>`).join(' ')}` : '-'}</td></tr>`).join('')}</tbody></table>`;
  } else haBox.innerHTML = `<div class="empty-provider">${escapeText(haproxy.note || 'haproxy_exporter 수집원 없음')}</div>`;
  const mw = document.querySelector('#monitoringMiddleware');
  const rabbit = data.rabbitmq || {}; const galera = data.galera || {};
  const cards = [];
  if (rabbit.status === 'ok') cards.push(`<article class="${rabbit.messages_ready > 1000 ? 'high' : ''}"><small>RabbitMQ</small><strong>대기 ${Math.round(rabbit.messages_ready || 0).toLocaleString()} · 미확인 ${Math.round(rabbit.messages_unacked || 0).toLocaleString()}</strong><em>큐 ${Math.round(rabbit.queues || 0).toLocaleString()}개 · 노드 ${(rabbit.nodes || []).filter(node => node.up).length}/${(rabbit.nodes || []).length} up</em></article>`);
  else cards.push(`<article class="muted"><small>RabbitMQ</small><strong>-</strong><em>${escapeText(rabbit.note || '수집원 없음')}</em></article>`);
  if (galera.status === 'ok') { const synced = (galera.nodes || []).filter(node => node.state === 'Synced').length; cards.push(`<article class="${galera.nodes?.length && synced < galera.nodes.length ? 'critical' : ''}"><small>MySQL Galera</small><strong>클러스터 ${galera.cluster_size ?? '-'} · Synced ${synced}/${(galera.nodes || []).length}</strong><em>${(galera.nodes || []).map(node => `${escapeText(node.instance.split(':')[0])} ${escapeText(node.state)}${node.recv_queue ? ` · 수신 큐 ${node.recv_queue}` : ''}${node.flow_control_paused ? ` · flow control ${(node.flow_control_paused * 100).toFixed(0)}%` : ''}`).join(' / ') || '-'}</em></article>`); }
  else cards.push(`<article class="muted"><small>MySQL Galera</small><strong>-</strong><em>${escapeText(galera.note || '수집원 없음')}</em></article>`);
  mw.innerHTML = cards.join('');
}

// --- Alertmanager --------------------------------------------------------------------------------
async function loadMonitoringAlertmanager(providerId) {
  const box = document.querySelector('#monitoringAlertmanager');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/alertmanager`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, 'Alertmanager 알림을 불러오지 못했습니다.'));
    document.querySelector('#monitoringAlertmanagerCount').textContent = data.total ?? 0;
    document.querySelector('#monitoringAlertmanagerMeta').textContent = data.status === 'connected' ? `${data.source} · 발화 중 ${data.total}건` : (data.note || 'Alertmanager 없음');
    if (data.status !== 'connected') { box.innerHTML = `<div class="empty-provider">${escapeText(data.note || 'Alertmanager를 찾지 못했습니다.')}</div>`; return; }
    box.innerHTML = data.alerts.length ? `<table><thead><tr><th>심각도</th><th>알림</th><th>대상</th><th>시작</th><th>내용</th></tr></thead><tbody>${data.alerts.map(alert => `<tr class="${alert.severity === 'critical' ? 'down' : ''}"><td><span class="target-state ${alert.severity === 'critical' ? 'down' : (alert.severity === 'warning' ? 'warn' : 'up')}">${escapeText(alert.severity || '-')}</span></td><td><strong>${escapeText(alert.name)}</strong>${alert.job ? `<br><small style="color:#8593a6">${escapeText(alert.job)}</small>` : ''}</td><td>${escapeText(alert.instance || '-')}</td><td>${alert.starts_at ? escapeText(relativeTime(alert.starts_at)) : '-'}</td><td class="alert-summary-cell">${escapeText(alert.summary || Object.entries(alert.labels || {}).map(([key, value]) => `${key}=${value}`).join(' '))}</td></tr>`).join('')}</tbody></table>` : '<div class="empty-provider">발화 중인 알림이 없습니다.</div>';
  } catch (error) { box.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}

// --- PromQL ---------------------------------------------------------------------------------------
function loadQueryHistory() { try { const saved = JSON.parse(localStorage.getItem(monitoringQueryHistoryKey)); return Array.isArray(saved) ? saved : []; } catch (_) { return []; } }
function rememberQuery(expr) {
  const history = [expr, ...loadQueryHistory().filter(item => item !== expr)].slice(0, 10);
  try { localStorage.setItem(monitoringQueryHistoryKey, JSON.stringify(history)); } catch (_) { /* private mode */ }
  renderQueryHistory();
}
function renderQueryHistory() {
  const box = document.querySelector('#monitoringQueryHistory');
  const history = loadQueryHistory();
  box.innerHTML = history.length ? history.map(expr => `<button type="button" class="promql-chip" data-query="${escapeText(expr)}" title="${escapeText(expr)}">${escapeText(expr.length > 60 ? `${expr.slice(0, 60)}…` : expr)}</button>`).join('') : '';
}
renderQueryHistory();
document.querySelector('#monitoringQueryHistory').addEventListener('click', event => { const chip = event.target.closest('[data-query]'); if (chip) { document.querySelector('#monitoringQueryExpr').value = chip.dataset.query; document.querySelector('#monitoringQueryForm').requestSubmit(); } });
document.querySelector('#monitoringQueryMode').addEventListener('click', event => {
  const button = event.target.closest('[data-mode]');
  if (!button) return;
  monitoringQueryMode = button.dataset.mode;
  document.querySelectorAll('#monitoringQueryMode button').forEach(item => item.classList.toggle('active', item === button));
});
document.querySelector('#monitoringQueryForm').addEventListener('submit', async event => {
  event.preventDefault();
  const providerId = monitoringProviderSelect.value;
  const expr = document.querySelector('#monitoringQueryExpr').value.trim();
  const result = document.querySelector('#monitoringQueryResult');
  if (!providerId) return showToast('공급자를 선택하세요.', 'PromQL은 선택한 공급자의 Prometheus에 질의합니다.');
  if (!expr) return;
  const button = document.querySelector('#runMonitoringQuery');
  button.disabled = true; result.innerHTML = '<div class="empty-provider">조회 중…</div>';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/monitoring/query?expr=${encodeURIComponent(expr)}&mode=${monitoringQueryMode}&range=${encodeURIComponent(monitoringRange)}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(monitoringApiError(data, '조회에 실패했습니다.'));
    rememberQuery(expr);
    renderQueryResult(data);
  } catch (error) { result.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
  finally { button.disabled = false; }
});
function labelText(metric) { const name = metric.__name__ ? `${metric.__name__}` : ''; const rest = Object.entries(metric).filter(([key]) => key !== '__name__').map(([key, value]) => `${key}="${value}"`).join(', '); return `${name}{${rest}}`; }
function renderQueryResult(data) {
  const box = document.querySelector('#monitoringQueryResult');
  const note = `<p class="monitoring-note">${escapeText(data.source)} · ${data.latency_ms}ms · ${data.result.length}개 시계열${data.truncated ? ' (50개까지만 표시)' : ''}</p>`;
  if (!data.result.length) { box.innerHTML = `${note}<div class="empty-provider">결과가 없습니다.</div>`; return; }
  if (data.mode === 'instant') {
    if (data.result_type === 'scalar' || data.result_type === 'string') { box.innerHTML = `${note}<table><tbody><tr><td>${escapeText(String(data.result[1] ?? data.result))}</td></tr></tbody></table>`; return; }
    box.innerHTML = `${note}<table><thead><tr><th>시계열</th><th>값</th></tr></thead><tbody>${data.result.map(item => `<tr><td><code>${escapeText(labelText(item.metric || {}))}</code></td><td>${escapeText(String(item.value ? item.value[1] : '-'))}</td></tr>`).join('')}</tbody></table>`;
    return;
  }
  const palette = ['avg', 'max', 'rx', 'tx'];
  const series = data.result.slice(0, 8).map((item, index) => ({cls: palette[index % palette.length], label: labelText(item.metric || {}).slice(0, 48), points: item.values.map(([ts, value]) => [ts, Number(value)]).filter(point => Number.isFinite(point[1]))}));
  box.innerHTML = `${note}<article class="panel"><header><strong>${escapeText(document.querySelector('#monitoringQueryExpr').value.trim().slice(0, 80))}</strong><small>${data.result.length > 8 ? '앞 8개 시계열만 차트에 표시' : ''}</small></header><div class="ts-chart" id="monitoringQueryChart" tabindex="0"></div></article>`;
  renderTimeSeriesChart(document.querySelector('#monitoringQueryChart'), series, {unit:'', range:data.range});
}
