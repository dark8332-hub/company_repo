// ===== 인프라 현황 =====
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
  const renderStates = (containerId, definitions) => {
    const container = document.querySelector(containerId);
    container.innerHTML = definitions.map(([key, label]) => {
      const item = data.items?.[key];
      const status = item?.status || 'pending';
      const labels = {healthy:'정상', warning:'주의', unavailable:'확인 불가', excepted:'예외', pending:'미수집'};
      const when = item?.checked_at ? ` · ${relativeTime(item.checked_at)} 점검` : '';
      return `<article><span class="state-dot ${escapeText(status)}"></span><div><strong>${escapeText(label)}</strong><small>${escapeText((item?.note || '아직 점검되지 않은 항목') + when)}</small></div><em class="${escapeText(status)}">${labels[status] || '확인 필요'}</em><b>${escapeText(item?.result || '-')}</b></article>`;
    }).join('');
  };
  renderStates('#infrastructureServiceList', [['endpoint','Endpoint'],['nova','Nova'],['neutron','Neutron'],['cinder','Cinder'],['manila','Manila'],['octavia','Octavia'],['masakari','Masakari'],['swift','Swift'],['heat','Heat']]);
  renderStates('#infrastructureResourceList', [['vm','VM'],['network','Network Agent'],['volume','Volume'],['snapshot','Snapshot'],['share','Share'],['lb','Load Balancer'],['amphora','Amphora'],['heat_stack','Heat Stack']]);
  lastInfrastructureData = data;
  ensureInventoryLoaded(infrastructureProviderSelect.value);
  if (nodeDetailHostname && !nodes.some(node => node.hostname === nodeDetailHostname)) closeNodeDetail();
}

// ---------- Monitoring page ----------

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

// ---------- Inventory: node detail, hypervisor capacity, storage backend ----------
let lastInfrastructureData = null;
let currentInventory = null;
let inventoryProviderId = '';
let inventoryPollTimer = null;
let nodeDetailHostname = '';

function formatBytesShort(bytes) {
  const value = Number(bytes) || 0;
  if (!value) return '-';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  let index = 0; let amount = value;
  while (amount >= 1024 && index < units.length - 1) { amount /= 1024; index += 1; }
  return `${amount.toFixed(amount >= 100 || index === 0 ? 0 : 1)} ${units[index]}`;
}
function formatMiB(megabytes) { return formatBytesShort((Number(megabytes) || 0) * 1048576); }
function formatGiB(gigabytes) { return formatBytesShort((Number(gigabytes) || 0) * 1073741824); }
function formatUptimeShort(seconds) {
  const value = Number(seconds);
  if (!Number.isFinite(value)) return '-';
  const days = Math.floor(value / 86400); const hours = Math.floor((value % 86400) / 3600); const minutes = Math.floor((value % 3600) / 60);
  return days ? `${days}일 ${hours}시간` : (hours ? `${hours}시간 ${minutes}분` : `${minutes}분`);
}
function usageBar(percent) {
  const value = Number(percent);
  if (!Number.isFinite(value)) return '<span class="inventory-bar"><i><u style="width:0"></u></i><b>-</b></span>';
  const tone = value >= 90 ? 'crit' : (value >= 80 ? 'warn' : '');
  return `<span class="inventory-bar ${tone}"><i><u style="width:${Math.max(0, Math.min(100, value))}%"></u></i><b>${value.toFixed(value >= 10 ? 0 : 1)}%</b></span>`;
}
function stopInventoryPolling() { if (inventoryPollTimer) { clearInterval(inventoryPollTimer); inventoryPollTimer = null; } }

function ensureInventoryLoaded(providerId) {
  // Called on every infrastructure render; only fetch when the provider actually changed.
  if (providerId === inventoryProviderId) return;
  loadInventory(providerId);
}

async function loadInventory(providerId) {
  inventoryProviderId = providerId || '';
  const collectButton = document.querySelector('#collectInventory');
  collectButton.disabled = !providerId;
  document.querySelector('#inventoryHistory').hidden = true;
  if (!providerId) { currentInventory = null; renderInventory(null); document.querySelector('#inventoryMeta').textContent = '공급자를 선택하세요.'; return; }
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/inventory`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '인벤토리를 불러오지 못했습니다.');
    if (inventoryProviderId !== providerId) return;
    currentInventory = data.inventory;
    renderInventory(data.inventory);
    if (data.running) followInventoryCollection(providerId);
  } catch (error) {
    document.querySelector('#inventorySummary').innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`;
  }
}

function followInventoryCollection(providerId) {
  stopInventoryPolling();
  const progress = document.querySelector('#inventoryProgress');
  const button = document.querySelector('#collectInventory');
  button.disabled = true;
  progress.hidden = false; progress.className = 'inventory-progress'; progress.textContent = '수집 중…';
  const poll = async () => {
    try {
      const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/inventory/progress`, {cache:'no-store'});
      const state = await response.json();
      progress.textContent = `${state.percent ?? 0}% · ${state.message || ''}`;
      if (!state.running) {
        stopInventoryPolling();
        button.disabled = false;
        if (state.stage === 'failed') { progress.className = 'inventory-progress failed'; showToast('인벤토리 수집에 실패했습니다.', state.message || ''); }
        else { progress.hidden = true; }
        if (inventoryProviderId === providerId) { currentInventory = null; loadInventory(providerId); }
      }
    } catch (_) { /* transient */ }
  };
  poll();
  inventoryPollTimer = setInterval(poll, 2000);
}

async function collectInventory() {
  const providerId = infrastructureProviderSelect.value;
  if (!providerId) return showToast('공급자를 선택하세요.', '인벤토리를 수집할 공급자가 필요합니다.');
  followInventoryCollection(providerId);
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/inventory/collect`, {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : `서버 오류 (${response.status})`);
    showToast('인벤토리 수집을 완료했습니다.', `노드 ${data.summary?.reachable ?? 0}/${data.summary?.nodes ?? 0}대 · 하이퍼바이저 ${data.summary?.hypervisors ?? 0} · 인스턴스 ${data.summary?.instances ?? 0} · ${data.duration_seconds}초`);
  } catch (error) {
    showToast('인벤토리 수집에 실패했습니다.', error.message);
  }
}

async function toggleInventoryHistory() {
  const box = document.querySelector('#inventoryHistory');
  if (!box.hidden) { box.hidden = true; return; }
  const providerId = inventoryProviderId;
  if (!providerId) return;
  const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/inventory?history=1`, {cache:'no-store'});
  const data = await response.json();
  const rows = (data.history || []).map(item => `<tr><td>${escapeText(formatDateTime(item.collected_at))}</td><td><span class="state-pill ${item.status === 'healthy' ? 'ok' : (item.status === 'warning' ? 'warn' : 'bad')}">${item.status === 'healthy' ? '정상' : (item.status === 'warning' ? '일부 실패' : '실패')}</span></td><td>${item.reachable_nodes}/${item.node_count}대</td><td>${item.hypervisors}</td><td>${item.instances}</td><td>${escapeText(item.storage_backend)}</td><td>${item.duration_seconds ?? '-'}초</td><td><button type="button" data-inventory-id="${escapeText(item.id)}">보기</button></td></tr>`).join('');
  box.innerHTML = `<table><thead><tr><th>수집 시각</th><th>결과</th><th>노드</th><th>하이퍼바이저</th><th>인스턴스</th><th>스토리지</th><th>소요</th><th></th></tr></thead><tbody>${rows || '<tr><td colspan="8">수집 이력이 없습니다.</td></tr>'}</tbody></table>`;
  box.hidden = false;
}

async function viewInventory(inventoryId) {
  const response = await fetch(`/api/providers/${encodeURIComponent(inventoryProviderId)}/inventory?inventory_id=${encodeURIComponent(inventoryId)}`, {cache:'no-store'});
  const data = await response.json();
  if (!response.ok) return showToast('인벤토리를 불러오지 못했습니다.', data.detail || '');
  currentInventory = data.inventory;
  renderInventory(data.inventory);
}

function renderInventory(inventory) {
  const summary = document.querySelector('#inventorySummary');
  const meta = document.querySelector('#inventoryMeta');
  const historyButton = document.querySelector('#inventoryHistoryButton');
  document.querySelector('#inventoryGrid').hidden = !inventory;
  document.querySelector('#inventoryGrid2').hidden = !inventory;
  historyButton.hidden = !inventoryProviderId;
  if (!inventory) {
    meta.textContent = inventoryProviderId ? '아직 수집한 인벤토리가 없습니다.' : '공급자를 선택하세요.';
    summary.innerHTML = '<div class="empty-provider">아직 수집한 인벤토리가 없습니다. 인벤토리 수집을 실행하면 노드 하드웨어, 하이퍼바이저 용량, 인스턴스·볼륨·네트워크 목록과 스토리지 백엔드를 읽기 전용 명령으로 수집합니다.</div>';
    if (nodeDetailHostname) renderNodeDetail(nodeDetailHostname);
    return;
  }
  const payload = inventory.payload || {};
  const s = payload.summary || {};
  const statusLabel = inventory.status === 'healthy' ? '정상 수집' : (inventory.status === 'warning' ? '일부 실패' : '수집 실패');
  meta.textContent = `${formatDateTime(inventory.collected_at)} 수집 · ${statusLabel} · ${inventory.duration_seconds ?? '-'}초 · 활성 Controller ${payload.controller?.hostname || '-'}${payload.controller?.error ? ` · ${payload.controller.error}` : ''}`;
  const controllerTone = payload.controller?.error ? 'critical' : (s.openstack_available ? 'healthy' : 'warning');
  const facts = [
    {tone: s.reachable === s.nodes ? 'healthy' : (s.reachable ? 'warning' : 'critical'), label:'노드 수집', value:`${s.reachable ?? 0}/${s.nodes ?? 0}대`, hint: s.reachable === s.nodes ? '전체 노드 접속 성공' : '접속 실패 노드는 카드에서 확인'},
    {tone: controllerTone, label:'OpenStack 인벤토리', value: s.openstack_available ? '수집됨' : '수집 실패', hint: payload.openstack?.openrc ? `OpenRC ${payload.openstack.openrc}` : (payload.openstack?.errors?.openrc || payload.controller?.error || 'OpenRC 확인 필요')},
    {tone:'info', label:'하이퍼바이저', value:`${s.hypervisors ?? 0}대`, hint:`인스턴스 ${s.instances ?? 0}개`},
    {tone:'info', label:'볼륨 · 네트워크', value:`${s.volumes ?? 0} · ${s.networks ?? 0}`, hint:'전체 프로젝트 기준'},
    {tone: s.storage_backend === 'none' ? 'warning' : 'healthy', label:'스토리지 백엔드', value: s.storage_backend === 'ceph' ? 'Ceph' : (s.storage_backend === 'nfs' ? 'NFS' : '미감지'), hint: s.storage_backend === 'ceph' ? `상태 ${payload.storage?.ceph?.health || '-'}` : (s.storage_backend === 'nfs' ? `NFS 마운트 ${payload.storage?.nfs?.mounts?.length || 0}개` : 'Ceph·NFS 모두 감지되지 않음')},
  ];
  summary.innerHTML = `<div class="inventory-facts">${facts.map(fact => `<article class="${fact.tone}"><small>${escapeText(fact.label)}</small><strong>${escapeText(fact.value)}</strong><em>${escapeText(fact.hint)}</em></article>`).join('')}</div>`;
  renderHypervisorCapacity(payload);
  renderProjectUsage(payload);
  renderStorageBackend(payload);
  renderOpenstackInventory(payload);
  document.querySelectorAll('[data-infra-hostname]').forEach(card => {
    const node = (payload.nodes || []).find(item => item.hostname === card.dataset.infraHostname);
    if (node && !node.reachable) card.title = `인벤토리 수집 실패: ${node.error}`;
  });
  if (nodeDetailHostname) renderNodeDetail(nodeDetailHostname);
}

function renderHypervisorCapacity(payload) {
  const box = document.querySelector('#hypervisorCapacity');
  const capacity = payload.capacity || {};
  const totals = capacity.totals || {};
  const hypervisors = capacity.hypervisors || [];
  document.querySelector('#hypervisorCapacityMeta').textContent = hypervisors.length ? `하이퍼바이저 ${totals.hypervisors_up ?? 0}/${totals.hypervisors ?? 0}대 up · 실행 중 VM ${totals.running_vms ?? 0}개` : 'nova hypervisor 정보가 없습니다';
  if (!hypervisors.length) { box.innerHTML = `<div class="empty-provider">${escapeText(payload.openstack?.errors?.hypervisors || payload.controller?.error || '하이퍼바이저 정보를 수집하지 못했습니다.')}</div>`; return; }
  const totalCards = [
    ['vCPU 할당', `${totals.vcpus_used ?? 0} / ${totals.vcpus ?? 0}`, totals.vcpu_percent],
    ['메모리 할당', `${formatMiB(totals.memory_mb_used)} / ${formatMiB(totals.memory_mb)}`, totals.memory_percent],
    ['로컬 디스크 할당', `${formatGiB(totals.local_gb_used)} / ${formatGiB(totals.local_gb)}`, totals.disk_percent],
  ];
  const rows = [...hypervisors].sort((a, b) => (b.vcpu_percent ?? 0) - (a.vcpu_percent ?? 0)).map(h => {
    const worst = Math.max(h.vcpu_percent ?? 0, h.memory_percent ?? 0, h.disk_percent ?? 0);
    return `<tr class="${worst >= 90 ? 'crit' : (worst >= 80 ? 'warn' : '')}"><td><strong>${escapeText(h.hostname)}</strong><small>${escapeText(h.type || '-')}${h.host_ip ? ` · ${escapeText(h.host_ip)}` : ''}</small></td><td><span class="state-pill ${String(h.state).toLowerCase() === 'up' ? 'up' : 'down'}">${escapeText(h.state || '-')}</span></td><td class="num">${h.instances ?? h.running_vms ?? 0}</td><td>${usageBar(h.vcpu_percent)}<small>${h.vcpus_used} / ${h.vcpus}</small></td><td>${usageBar(h.memory_percent)}<small>${escapeText(formatMiB(h.memory_mb_used))} / ${escapeText(formatMiB(h.memory_mb))}</small></td><td>${h.local_gb ? `${usageBar(h.disk_percent)}<small>${escapeText(formatGiB(h.local_gb_used))} / ${escapeText(formatGiB(h.local_gb))}</small>` : '<small>정보 없음</small>'}</td></tr>`;
  }).join('');
  box.innerHTML = `<div class="capacity-totals">${totalCards.map(([label, value, percent]) => `<article><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong>${usageBar(percent)}</article>`).join('')}</div>
    <table class="inventory-table"><thead><tr><th>하이퍼바이저</th><th>상태</th><th class="num">VM</th><th>vCPU</th><th>메모리</th><th>로컬 디스크</th></tr></thead><tbody>${rows}</tbody></table>
    <p class="capacity-note">할당량은 nova가 보고한 원시 값(vcpus_used / vcpus)입니다. nova.conf의 오버커밋 비율(cpu_allocation_ratio 등)은 수집하지 않으므로 100%를 넘을 수 있으며, 실제 여유는 오버커밋 비율을 곱해 판단하세요.</p>`;
}

function renderProjectUsage(payload) {
  const box = document.querySelector('#projectUsage');
  const capacity = payload.capacity || {};
  const projects = capacity.projects || [];
  const instances = capacity.instances || {total:0, by_status:{}};
  const statusText = Object.entries(instances.by_status || {}).sort((a, b) => b[1] - a[1]).map(([status, count]) => `${status} ${count}`).join(' · ');
  document.querySelector('#projectUsageMeta').textContent = instances.total ? `인스턴스 ${instances.total}개 · ${statusText}` : '인스턴스 정보가 없습니다';
  if (!projects.length) { box.innerHTML = `<div class="empty-provider">${escapeText(payload.openstack?.errors?.servers || '인스턴스 목록을 수집하지 못했거나 인스턴스가 없습니다.')}</div>`; return; }
  const totalVcpus = projects.reduce((sum, item) => sum + (item.vcpus || 0), 0) || 1;
  box.innerHTML = `<table class="inventory-table"><thead><tr><th>프로젝트</th><th class="num">인스턴스</th><th class="num">ACTIVE</th><th class="num">vCPU</th><th class="num">메모리</th><th class="num">디스크</th><th>vCPU 비중</th></tr></thead><tbody>${projects.map(item => `<tr><td><strong>${escapeText(item.name)}</strong><small>${escapeText(item.id || '-')}</small></td><td class="num">${item.instances}</td><td class="num">${item.active}</td><td class="num">${item.vcpus}</td><td class="num">${escapeText(formatMiB(item.ram_mb))}</td><td class="num">${escapeText(formatGiB(item.disk_gb))}</td><td>${usageBar(item.vcpus / totalVcpus * 100)}</td></tr>`).join('')}</tbody></table>`;
}

function renderStorageBackend(payload) {
  const box = document.querySelector('#storageBackend');
  const storage = payload.storage || {backend:'none'};
  if (storage.backend === 'ceph' && storage.ceph) {
    const ceph = storage.ceph;
    const health = String(ceph.health || '').toUpperCase();
    const tone = health === 'HEALTH_OK' ? 'ok' : (health === 'HEALTH_WARN' ? 'warn' : 'bad');
    const usedPercent = ceph.bytes_total ? ceph.bytes_used / ceph.bytes_total * 100 : null;
    document.querySelector('#storageBackendMeta').textContent = `Ceph 클러스터 ${ceph.fsid || ''}`;
    box.innerHTML = `<div class="storage-card ${tone}"><strong>Ceph · <span class="state-pill ${tone}">${escapeText(ceph.health || '-')}</span></strong><small>OSD ${ceph.osds_up}/${ceph.osds} up · ${ceph.osds_in} in · PG ${ceph.pgs} · Pool ${ceph.pools}</small><div>${usageBar(usedPercent)}</div><small>사용 ${escapeText(formatBytesShort(ceph.bytes_used))} / 전체 ${escapeText(formatBytesShort(ceph.bytes_total))} · 여유 ${escapeText(formatBytesShort(ceph.bytes_avail))}</small>${ceph.warnings?.length ? `<small>${ceph.warnings.map(escapeText).join('<br>')}</small>` : ''}</div>`;
    return;
  }
  const nfs = storage.nfs || {mounts:[]};
  if (nfs.mounts.length) {
    document.querySelector('#storageBackendMeta').textContent = `NFS 마운트 ${nfs.mounts.length}개 · Glance ${nfs.glance_on_nfs ? 'NFS' : '로컬'} · Cinder ${nfs.cinder_on_nfs || nfs.cinder_mount_dirs?.length ? 'NFS' : '로컬'}`;
    box.innerHTML = `<table class="inventory-table"><thead><tr><th>마운트</th><th>내보내기</th><th>용도</th><th>사용률</th></tr></thead><tbody>${nfs.mounts.map(mount => `<tr class="${(mount.use_percent ?? 0) >= 90 ? 'crit' : ((mount.use_percent ?? 0) >= 80 ? 'warn' : '')}"><td><strong>${escapeText(mount.mountpoint)}</strong><small>${escapeText(mount.type)}${mount.options ? ` · ${escapeText(mount.options.slice(0, 60))}` : ''}</small></td><td>${escapeText(mount.export)}</td><td>${mount.serves?.length ? mount.serves.map(item => `<span class="state-pill ok">${escapeText(item)}</span>`).join(' ') : '-'}</td><td>${mount.size_bytes ? `${usageBar(mount.use_percent)}<small>${escapeText(formatBytesShort(mount.used_bytes))} / ${escapeText(formatBytesShort(mount.size_bytes))}</small>` : '<small>-</small>'}</td></tr>`).join('')}</tbody></table>${nfs.cinder_mount_dirs?.length ? `<p class="capacity-note">Cinder NFS 마운트 디렉터리 ${nfs.cinder_mount_dirs.length}개: ${nfs.cinder_mount_dirs.slice(0, 5).map(escapeText).join(', ')}</p>` : ''}`;
    return;
  }
  document.querySelector('#storageBackendMeta').textContent = 'Ceph 또는 NFS 감지 결과';
  box.innerHTML = `<div class="empty-provider">감지된 백엔드 없음 · 활성 Controller에 ceph 명령이 없고 NFS 마운트도 없습니다.${payload.controller?.error ? ` (${escapeText(payload.controller.error)})` : ''}</div>`;
}

function renderOpenstackInventory(payload) {
  const box = document.querySelector('#openstackInventory');
  const os = payload.openstack || {};
  if (!os.available) { box.innerHTML = `<div class="empty-provider">${escapeText(Object.values(os.errors || {}).filter(Boolean).join(' · ') || payload.controller?.error || 'OpenStack 인벤토리를 수집하지 못했습니다.')}</div>`; document.querySelector('#openstackInventoryMeta').textContent = 'OpenStack CLI 수집 실패'; return; }
  const volumeStatus = {}; (os.volumes || []).forEach(volume => { volumeStatus[volume.status || '-'] = (volumeStatus[volume.status || '-'] || 0) + 1; });
  const volumeGb = (os.volumes || []).reduce((sum, volume) => sum + (volume.size_gb || 0), 0);
  const external = (os.networks || []).filter(network => network.external).length;
  document.querySelector('#openstackInventoryMeta').textContent = `프로젝트 ${(os.projects || []).length} · Flavor ${(os.flavors || []).length} · 볼륨 ${(os.volumes || []).length}개 ${escapeText(formatGiB(volumeGb))} · 네트워크 ${(os.networks || []).length}개(외부 ${external})`;
  const servers = [...(os.servers || [])].sort((a, b) => a.host.localeCompare(b.host) || a.name.localeCompare(b.name));
  const serverRows = servers.slice(0, 200).map(server => `<tr class="${String(server.status).toUpperCase() === 'ERROR' ? 'crit' : (String(server.status).toUpperCase() !== 'ACTIVE' ? 'warn' : '')}"><td><strong>${escapeText(server.name)}</strong><small>${escapeText(server.id)}</small></td><td><span class="state-pill ${String(server.status).toUpperCase() === 'ACTIVE' ? 'ok' : (String(server.status).toUpperCase() === 'ERROR' ? 'bad' : 'warn')}">${escapeText(server.status)}</span></td><td>${escapeText(server.host || '-')}</td><td>${escapeText(server.flavor || '-')}<small>${server.vcpus || 0} vCPU · ${escapeText(formatMiB(server.ram_mb))}</small></td><td><small>${escapeText(server.networks || '-')}</small></td></tr>`).join('');
  box.innerHTML = `<div class="capacity-totals">${Object.entries(volumeStatus).slice(0, 4).map(([status, count]) => `<article><small>볼륨 ${escapeText(status)}</small><strong>${count}</strong></article>`).join('')}<article><small>인스턴스</small><strong>${servers.length}</strong></article></div>
    <table class="inventory-table"><thead><tr><th>인스턴스</th><th>상태</th><th>호스트</th><th>Flavor</th><th>네트워크</th></tr></thead><tbody>${serverRows || '<tr><td colspan="5">인스턴스가 없습니다.</td></tr>'}</tbody></table>${servers.length > 200 ? `<p class="capacity-note">인스턴스 ${servers.length}개 중 200개만 표시합니다.</p>` : ''}`;
}

function openNodeDetail(hostname) {
  nodeDetailHostname = hostname;
  document.querySelectorAll('[data-infra-hostname]').forEach(card => card.classList.toggle('selected', card.dataset.infraHostname === hostname));
  renderNodeDetail(hostname);
  const panel = document.querySelector('#nodeDetailPanel');
  panel.hidden = false;
  panel.scrollIntoView({behavior:'smooth', block:'start'});
}
function closeNodeDetail() {
  nodeDetailHostname = '';
  document.querySelector('#nodeDetailPanel').hidden = true;
  document.querySelectorAll('[data-infra-hostname]').forEach(card => card.classList.remove('selected'));
}

function renderNodeDetail(hostname) {
  const body = document.querySelector('#nodeDetailBody');
  const checkNode = (lastInfrastructureData?.nodes || []).find(node => node.hostname === hostname) || null;
  const payload = currentInventory?.payload || {};
  const node = (payload.nodes || []).find(item => item.hostname === hostname) || null;
  const role = (node || checkNode)?.role === 'controller' ? 'Controller' : 'Compute';
  document.querySelector('#nodeDetailTitle').textContent = `${hostname} · ${role}`;
  document.querySelector('#nodeDetailMeta').textContent = node ? (node.reachable ? `인벤토리 ${formatDateTime(currentInventory.collected_at)} 수집 · ${node.address || ''}` : `인벤토리 수집 실패: ${node.error}`) : '이 노드의 인벤토리가 없습니다. 인벤토리 수집을 실행하세요.';
  const metrics = checkNode?.metrics || {};
  const checkFacts = checkNode ? [
    ['최근 점검 CPU', Number.isFinite(Number(metrics.cpu_used_percent)) ? `${Number(metrics.cpu_used_percent).toFixed(1)}%` : '-', `${metrics.cpu_cores || '-'} Core`],
    ['최근 점검 메모리', Number.isFinite(Number(metrics.memory_used_percent)) ? `${Number(metrics.memory_used_percent).toFixed(1)}%` : '-', `${formatCapacity(metrics.memory_used_kb)} / ${formatCapacity(metrics.memory_total_kb)}`],
    ['최근 점검 루트 디스크', Number.isFinite(Number(metrics.disk_used_percent)) ? `${metrics.disk_used_percent}%` : '-', `${formatCapacity(metrics.disk_used_kb)} / ${formatCapacity(metrics.disk_total_kb)}`],
  ] : [];
  if (!node || !node.reachable) {
    body.innerHTML = `${checkFacts.length ? `<div class="node-detail-facts">${checkFacts.map(([label, value, hint]) => `<article><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong><em>${escapeText(hint)}</em></article>`).join('')}</div>` : ''}<div class="empty-provider">${node ? escapeText(`인벤토리 수집 실패: ${node.error}`) : '하드웨어·네트워크·서비스 상세는 인벤토리 수집 후 표시됩니다.'}</div>${checkNode?.warnings?.length ? `<p class="capacity-note">최근 점검 경고: ${checkNode.warnings.map(escapeText).join(' · ')}</p>` : ''}`;
    return;
  }
  const cpu = node.cpu || {};
  const facts = [
    ['운영체제', node.os?.name || '-', `커널 ${node.kernel || '-'}`],
    ['CPU', cpu.model || '-', `${cpu.cpus || '-'} CPU · 소켓 ${cpu.sockets || '-'} · 코어/소켓 ${cpu.cores_per_socket || '-'} · 스레드/코어 ${cpu.threads_per_core || '-'}${cpu.hypervisor_vendor ? ` · VM(${cpu.hypervisor_vendor})` : ''}`],
    ['메모리', formatCapacity(node.memory_total_kb), `Swap ${formatCapacity(node.swap_total_kb)}`],
    ['가동 시간', formatUptimeShort(node.uptime_seconds), `주소 ${node.address || '-'}`],
    ['디스크', `${(node.disks || []).length}개`, formatBytesShort((node.disks || []).reduce((sum, disk) => sum + (disk.size_bytes || 0), 0))],
    ['인터페이스', `${(node.interfaces || []).length}개`, `Bond ${(node.bonds || []).length}개 · UP ${(node.interfaces || []).filter(item => item.state === 'UP').length}`],
    ...checkFacts,
  ];
  const hostShort = hostname.split('.')[0];
  const hostedServers = (payload.openstack?.servers || []).filter(server => server.host && server.host.split('.')[0] === hostShort);
  const vmRows = hostedServers.length ? hostedServers.map(server => `<tr><td><strong>${escapeText(server.name)}</strong><small>${escapeText(server.id)}</small></td><td><span class="state-pill ${String(server.status).toUpperCase() === 'ACTIVE' ? 'ok' : (String(server.status).toUpperCase() === 'ERROR' ? 'bad' : 'warn')}">${escapeText(server.status)}</span></td><td>${escapeText(server.flavor || '-')}<small>${server.vcpus || 0} vCPU · ${escapeText(formatMiB(server.ram_mb))}</small></td><td><small>${escapeText(server.networks || '-')}</small></td></tr>`).join('')
    : (node.vms || []).map(vm => `<tr><td><strong>${escapeText(vm.name)}</strong></td><td><span class="state-pill ${vm.state === 'running' ? 'ok' : 'warn'}">${escapeText(vm.state)}</span></td><td colspan="2"><small>virsh 기준</small></td></tr>`).join('');
  const diskRows = (node.disks || []).map(disk => `<tr><td><strong>${escapeText(disk.name)}</strong><small>${escapeText(disk.model || '-')}</small></td><td>${escapeText(disk.type)}</td><td class="num">${escapeText(formatBytesShort(disk.size_bytes))}</td><td>${disk.rotational ? 'HDD' : 'SSD/가상'}</td></tr>`).join('');
  const fsRows = (node.filesystems || []).map(fs => `<tr class="${fs.use_percent >= 90 ? 'crit' : (fs.use_percent >= 80 ? 'warn' : '')}"><td><strong>${escapeText(fs.mountpoint)}</strong><small>${escapeText(fs.filesystem)}</small></td><td>${usageBar(fs.use_percent)}</td><td class="num">${escapeText(formatBytesShort(fs.used_bytes))} / ${escapeText(formatBytesShort(fs.size_bytes))}</td></tr>`).join('');
  const nicRows = (node.interfaces || []).map(nic => `<tr><td><strong>${escapeText(nic.name)}</strong><small>${escapeText(nic.mac || '')}</small></td><td><span class="state-pill ${nic.state === 'UP' ? 'up' : (nic.state === 'DOWN' ? 'down' : '')}">${escapeText(nic.state)}</span></td><td><small>${escapeText((nic.addresses || []).join(', ') || '-')}</small></td></tr>`).join('');
  const bondRows = (node.bonds || []).map(bond => `<tr class="${bond.mii_status && bond.mii_status !== 'up' ? 'crit' : ''}"><td><strong>${escapeText(bond.name)}</strong><small>${escapeText(bond.mode || '-')}</small></td><td><span class="state-pill ${bond.mii_status === 'up' ? 'up' : 'down'}">${escapeText(bond.mii_status || '-')}</span></td><td><small>${(bond.slaves || []).map(slave => `${escapeText(slave.name)} ${escapeText(slave.mii_status)}${slave.speed ? ` ${escapeText(slave.speed)}` : ''}`).join(' · ') || '-'}${bond.active_slave ? ` · 활성 ${escapeText(bond.active_slave)}` : ''}</small></td></tr>`).join('');
  const isOpenstackService = name => /nova|neutron|cinder|glance|keystone|placement|heat|octavia|manila|masakari|swift/.test(name);
  body.innerHTML = `<div class="node-detail-facts">${facts.map(([label, value, hint]) => `<article><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong><em>${escapeText(hint)}</em></article>`).join('')}</div>
    ${checkNode?.warnings?.length ? `<p class="capacity-note">최근 점검 경고: ${checkNode.warnings.map(escapeText).join(' · ')}</p>` : ''}
    <div class="node-detail-grid">
      <section><h3>파일시스템<span>${(node.filesystems || []).length}개</span></h3><table class="inventory-table"><thead><tr><th>마운트</th><th>사용률</th><th class="num">사용 / 전체</th></tr></thead><tbody>${fsRows || '<tr><td colspan="3">정보 없음</td></tr>'}</tbody></table></section>
      <section><h3>디스크<span>${(node.disks || []).length}개</span></h3><table class="inventory-table"><thead><tr><th>장치</th><th>유형</th><th class="num">용량</th><th>매체</th></tr></thead><tbody>${diskRows || '<tr><td colspan="4">정보 없음</td></tr>'}</tbody></table></section>
      <section><h3>네트워크 인터페이스<span>${(node.interfaces || []).length}개</span></h3><table class="inventory-table"><thead><tr><th>인터페이스</th><th>상태</th><th>주소</th></tr></thead><tbody>${nicRows || '<tr><td colspan="3">정보 없음</td></tr>'}</tbody></table></section>
      <section><h3>Bonding<span>${(node.bonds || []).length}개</span></h3><table class="inventory-table"><thead><tr><th>Bond</th><th>MII</th><th>슬레이브</th></tr></thead><tbody>${bondRows || '<tr><td colspan="3">Bond 미구성</td></tr>'}</tbody></table></section>
      <section><h3>실행 중 서비스<span>${(node.services || []).length}개</span></h3><div class="service-chips">${(node.services || []).map(name => `<span class="${isOpenstackService(name) ? 'openstack' : ''}">${escapeText(name.replace(/\.service$/, ''))}</span>`).join('') || '<span>정보 없음</span>'}</div></section>
      <section><h3>호스팅 중인 VM<span>${hostedServers.length || (node.vms || []).length}개${node.virsh_available && !hostedServers.length ? ' · virsh' : ''}</span></h3><table class="inventory-table"><thead><tr><th>인스턴스</th><th>상태</th><th>Flavor</th><th>네트워크</th></tr></thead><tbody>${vmRows || '<tr><td colspan="4">이 노드에서 실행 중인 VM이 없습니다.</td></tr>'}</tbody></table></section>
    </div>`;
}

document.querySelector('#infrastructureNodeGrid').addEventListener('click', event => {
  const card = event.target.closest('[data-infra-hostname]');
  if (!card) return;
  if (nodeDetailHostname === card.dataset.infraHostname) { closeNodeDetail(); return; }
  openNodeDetail(card.dataset.infraHostname);
});
document.querySelector('#closeNodeDetail').addEventListener('click', closeNodeDetail);
document.querySelector('#collectInventory').addEventListener('click', collectInventory);
document.querySelector('#inventoryHistoryButton').addEventListener('click', toggleInventoryHistory);
document.querySelector('#inventoryHistory').addEventListener('click', event => { const button = event.target.closest('[data-inventory-id]'); if (button) viewInventory(button.dataset.inventoryId); });
document.querySelector('#refreshInfrastructure').addEventListener('click', () => { currentInventory = null; loadInventory(infrastructureProviderSelect.value); });
infrastructureProviderSelect.addEventListener('change', () => { closeNodeDetail(); currentInventory = null; loadInventory(infrastructureProviderSelect.value); });
