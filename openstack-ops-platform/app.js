const menuButton = document.querySelector('#menuButton');
const sidebar = document.querySelector('#sidebar');
const runInspection = document.querySelector('#runInspection');
const toast = document.querySelector('#toast');
const clock = document.querySelector('#clock');
const providerSelect = document.querySelector('#providerSelect');
const inspectionProviderSelect = document.querySelector('#inspectionProviderSelect');
const dailyRunInspection = document.querySelector('#dailyRunInspection');
const discoverCluster = document.querySelector('#discoverCluster');

const inspectionGroups = [
  {title:'시스템 기본 점검', description:'Controller의 운영체제와 기본 자원 상태', items:[
    ['Resource','CPU 사용률','top','cpu'], ['Resource','Memory 사용률','free -h','memory'], ['Resource','Disk 사용률','df -h','disk'],
    ['System','Chrony 동기화','chronyc sources','chrony'], ['System','물리 인터페이스','cat /proc/net/bonding/* | egrep "MII Status"','bonding'], ['System','Mount 상태','Glance/Cinder 이미지 및 볼륨 경로 확인','mount']
  ]},
  {title:'Middleware 점검', description:'고가용성 및 데이터베이스 클러스터 상태', items:[
    ['Clustering','PCS cluster','pcs status','pcs'], ['Clustering','VIP 통신','ping ${VIP}','vip'], ['Clustering','RabbitMQ cluster','rabbitmqctl cluster_status','rabbitmq'], ['Clustering','MySQL cluster','wsrep_cluster_weight 상태 확인','mysql']
  ]},
  {title:'OpenStack 서비스 점검', description:'서비스 및 에이전트 가용 상태', items:[
    ['Service','Endpoint','openstack endpoint list','endpoint'], ['Service','Nova','openstack compute service list','nova'], ['Service','Neutron','openstack network agent list','neutron'],
    ['Service','Cinder','openstack volume service list','cinder'], ['Service','Manila','manila service-list','manila'], ['Service','Octavia','systemctl status octavia-*','octavia'], ['Service','Nova-compute','nova-compute API 포트 확인','nova_compute']
    ,['Service','Masakari','openstack segment list','masakari'], ['Service','Swift','openstack object store account show','swift'], ['Service','Heat','openstack orchestration service list','heat']
  ]},
  {title:'OpenStack 리소스 점검', description:'사용자 리소스의 비정상 상태 확인', items:[
    ['Resource','VM state','openstack server list --all','vm'], ['Resource','Network state','OVS 및 네트워크 상태 확인','network'], ['Resource','Volume state','openstack volume list --all','volume'],
    ['Resource','Snapshot state','openstack volume snapshot list --all','snapshot'], ['Resource','Share state','openstack share list --all','share'], ['Resource','LB state','openstack loadbalancer list','lb'], ['Resource','Amphora state','openstack loadbalancer amphora list --long','amphora'],
    ['Resource','Masakari notifications','openstack notification list','masakari_notification'], ['Resource','Swift containers','openstack container list','swift_container'], ['Resource','Heat stacks','openstack stack list --all-projects','heat_stack']
  ]},
  {title:'로그 점검', description:'주요 서비스와 시스템 로그의 오류 탐색', items:[
    ['System','Nova log','/var/log/nova/*.log에서 ERROR 확인','nova_log'], ['System','Neutron log','/var/log/neutron/*.log에서 ERROR 확인','neutron_log'], ['System','Cinder log','/var/log/cinder/*.log에서 ERROR 확인','cinder_log'],
    ['System','Glance log','/var/log/glance/*.log에서 ERROR 확인','glance_log'], ['System','Manila log','/var/log/manila/*.log에서 ERROR 확인','manila_log'], ['System','Octavia log','/var/log/octavia/*.log에서 ERROR 확인','octavia_log'],
    ['System','Masakari log','/var/log/masakari/*.log 오류 확인','masakari_log'], ['System','Swift log','/var/log/swift/*.log 오류 확인','swift_log'], ['System','Heat log','/var/log/heat/*.log 오류 확인','heat_log'], ['System','System log','syslog/messages에서 ERROR 확인','system_log']
  ]},
  {title:'물리·가상화 인프라 점검', description:'실행 환경을 자동 구분하여 하드웨어, 커널, 네트워크와 하이퍼바이저 상태 확인', items:[
    ['Platform','실행 환경','systemd-detect-virt 및 DMI chassis type','virtualization'], ['System','실패한 시스템 서비스','systemctl --failed','failed_units'],
    ['System','커널 오류','dmesg --level=err,crit,alert,emerg','kernel_errors'], ['Network','물리·가상 인터페이스','ip -br link','nic_state'],
    ['Network','Open vSwitch','ovs-vsctl show','ovs_state'], ['Virtualization','CPU 가상화 가속','vmx/svm 및 KVM 모듈 확인','kvm_acceleration'],
    ['Virtualization','Libvirt 도메인','virsh list --all','libvirt_state'], ['Storage','인스턴스 저장소','df -h /var/lib/nova/instances','instance_storage'],
    ['Hardware','물리 디스크 SMART','smartctl --scan 및 smartctl -H','smart_health'], ['Hardware','소프트웨어 RAID','/proc/mdstat 및 mdadm --detail --scan','raid_health']
  ]}
];
let inspectionResults = {};
let currentFilter = 'all';
const allInspectionKeys = inspectionGroups.flatMap(group => group.items.map(item => item[3]));
let selectedInspectionKeys = new Set(allInspectionKeys);

menuButton.addEventListener('click', () => sidebar.classList.toggle('open'));
sidebar.addEventListener('click', event => {
  if (event.target === sidebar && sidebar.classList.contains('open')) sidebar.classList.remove('open');
});

async function executeInspection(sourceButton, selectedProvider) {
  if (!selectedProvider) return showToast('공급자를 먼저 선택하세요.', '공급자 연결 메뉴에서 환경을 등록할 수 있습니다.');
  if (!selectedInspectionKeys.size) return showToast('점검 항목을 선택하세요.', '하나 이상의 항목을 선택해야 합니다.');
  sourceButton.disabled = true;
  sourceButton.innerHTML = '<span>↻</span> 점검 실행 중';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(selectedProvider)}/checks`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({selected_items:[...selectedInspectionKeys]})});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '점검 실행에 실패했습니다.');
    renderCheck(data);
    renderInspectionResult(data);
    showToast('일일점검이 완료되었습니다.', data.status === 'healthy' ? '현재 확인된 경고가 없습니다.' : `${data.warnings.length}개 경고를 확인하세요.`);
  } catch (error) {
    showToast('일일점검에 실패했습니다.', error.message);
  } finally {
    sourceButton.disabled = false;
    sourceButton.innerHTML = sourceButton === dailyRunInspection ? '<span>↻</span> 전체 점검 실행' : '<span>↻</span> 일일점검 실행';
  }
}

runInspection.addEventListener('click', () => executeInspection(runInspection, providerSelect.value));
dailyRunInspection.addEventListener('click', () => executeInspection(dailyRunInspection, inspectionProviderSelect.value));

async function loadProviders() {
  try {
    const response = await fetch('/api/providers');
    const data = await response.json();
    const requested = new URLSearchParams(location.search).get('provider');
    data.providers.forEach(provider => {
      const option = document.createElement('option');
      option.value = provider.id;
      option.textContent = `${provider.name} (${provider.vip})`;
      providerSelect.appendChild(option);
      inspectionProviderSelect.appendChild(option.cloneNode(true));
    });
    if (requested && data.providers.some(provider => provider.id === requested)) providerSelect.value = requested;
    else if (data.providers.length === 1) providerSelect.value = data.providers[0].id;
    inspectionProviderSelect.value = providerSelect.value;
    if (inspectionProviderSelect.value) loadProviderNodes(inspectionProviderSelect.value);
    const selected = data.providers.find(provider => provider.id === providerSelect.value);
    if (selected?.latest_check) {
      const latest = {...selected.latest_check.result, status:selected.latest_check.status};
      renderCheck(latest);
      renderInspectionResult(latest);
    }
  } catch (_) { showToast('공급자 목록을 불러오지 못했습니다.', '서버 연결 상태를 확인하세요.'); }
}

providerSelect.addEventListener('change', () => {
  inspectionProviderSelect.value = providerSelect.value;
  if (providerSelect.value) loadProviderNodes(providerSelect.value);
});
inspectionProviderSelect.addEventListener('change', () => {
  providerSelect.value = inspectionProviderSelect.value;
  loadProviderNodes(inspectionProviderSelect.value);
});

discoverCluster.addEventListener('click', () => loadProviderNodes(inspectionProviderSelect.value, true));

async function loadProviderNodes(providerId, discover = false) {
  const list = document.querySelector('#clusterNodeList');
  const warning = document.querySelector('#clusterWarning');
  if (!providerId) {
    list.innerHTML = '<div class="empty-provider">공급자를 선택한 후 클러스터를 탐색하세요.</div>';
    updateNodeCounts([]);
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
    if (!response.ok) throw new Error(data.detail || '클러스터 노드를 불러오지 못했습니다.');
    updateNodeCounts(data.nodes);
    list.innerHTML = data.nodes.length ? data.nodes.map(node => `<article><span class="node-role ${node.role}">${node.role === 'controller' ? 'C' : 'N'}</span><div><strong>${escapeText(node.hostname)}</strong><small>${escapeText(node.address)} · ${escapeText(node.source)}</small></div><em>${node.role === 'controller' ? 'Controller' : 'Compute'}</em></article>`).join('') : '<div class="empty-provider">저장된 노드가 없습니다. 클러스터 탐색을 실행하세요.</div>';
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

function updateNodeCounts(nodes) {
  document.querySelector('#controllerNodeCount').textContent = nodes.filter(node => node.role === 'controller').length;
  document.querySelector('#computeNodeCount').textContent = nodes.filter(node => node.role === 'compute').length;
}

function escapeText(value) {
  const element = document.createElement('span');
  element.textContent = value ?? '';
  return element.innerHTML;
}

function renderInspectionResult(data) {
  const metrics = data.metrics || {};
  if (Array.isArray(data.selected_items)) selectedInspectionKeys = new Set(data.selected_items);
  inspectionResults = data.items || {
    cpu:{status:'healthy', result:`${metrics.cpu_cores ?? '-'} Core`, note:'활성 Controller 기준'},
    memory:{status:metrics.memory_used_percent >= 80 ? 'warning' : 'healthy', result:`${metrics.memory_used_percent ?? '-'}%`, note:metrics.memory_used_percent >= 80 ? '임계치 80% 이상' : '정상 범위'},
    disk:{status:metrics.disk_used_percent >= 80 ? 'warning' : 'healthy', result:`${metrics.disk_used_percent ?? '-'}%`, note:metrics.disk_used_percent >= 80 ? '임계치 80% 이상' : '정상 범위'}
  };
  document.querySelector('#inspectionUpdatedAt').textContent = `최근 실행: ${new Intl.DateTimeFormat('ko-KR', {dateStyle:'medium', timeStyle:'short'}).format(new Date())}`;
  renderInspectionSelection();
  renderInspectionChecklist();
}

function renderInspectionSelection() {
  const panel = document.querySelector('#inspectionSelectionPanel');
  panel.innerHTML = inspectionGroups.map((group, groupIndex) => {
    const keys = group.items.map(item => item[3]);
    const checked = keys.filter(key => selectedInspectionKeys.has(key)).length;
    return `<section><label class="selection-group"><input type="checkbox" data-selection-group="${groupIndex}" ${checked === keys.length ? 'checked' : ''}><strong>${escapeText(group.title)}</strong><span>${checked}/${keys.length}</span></label><div>${group.items.map(([, name,, key]) => `<label><input type="checkbox" data-selection-key="${key}" ${selectedInspectionKeys.has(key) ? 'checked' : ''}><span>${escapeText(name)}</span></label>`).join('')}</div></section>`;
  }).join('');
  document.querySelector('#selectedInspectionCount').textContent = selectedInspectionKeys.size;
}

function renderInspectionChecklist() {
  const checklist = document.querySelector('#inspectionChecklist');
  let total = 0, healthy = 0, warning = 0;
  checklist.innerHTML = inspectionGroups.map((group, groupIndex) => {
    const rows = group.items.map(([category, name, method, key]) => {
      total += 1;
      const isSelected = selectedInspectionKeys.has(key);
      const result = inspectionResults[key] || (isSelected ? {status:'pending', result:'-', note:'점검 실행 필요'} : {status:'skipped', result:'-', note:'점검 제외'});
      if (result.status === 'healthy') healthy += 1;
      if (result.status === 'warning') warning += 1;
      const filterMatches = currentFilter === result.status || (currentFilter === 'pending' && ['unavailable','skipped'].includes(result.status));
      const hidden = currentFilter !== 'all' && !filterMatches ? ' hidden' : '';
      const labels = {healthy:'정상', warning:'주의', pending:'수집 대기', unavailable:'확인 불가', skipped:'점검 제외'};
      const nodeDetail = result.nodes?.length ? `<details class="node-log-detail"><summary>노드별 상태</summary>${result.nodes.map(node => `<div><strong>${escapeText(node.hostname)}</strong><span>${escapeText(node.role)}</span><em class="${escapeText(node.status)}">${labels[node.status] || '확인 불가'}</em><b>${Number(node.count) || 0}건</b>${node.note ? `<small>${escapeText(node.note)}</small>` : ''}</div>`).join('')}</details>` : '';
      const detailId = `inspection-detail-${groupIndex}-${key}`;
      const details = result.details?.length ? result.details : [{title:'조회 결과', output:result.status === 'pending' ? '아직 점검을 실행하지 않았습니다.' : `${result.note || ''}\n${result.result || '-'}`}];
      const rawOutput = details.map(detail => `<article><strong>${escapeText(detail.title)}</strong><pre>${escapeText(detail.output || '출력 없음')}</pre></article>`).join('');
      return `<tr class="inspection-row" data-status="${result.status}" data-detail-id="${detailId}" tabindex="0" aria-expanded="false"${hidden}><td><span class="category-badge">${category}</span></td><td><strong>${name}</strong><small class="detail-hint">클릭하여 명령 원문 보기</small></td><td><code>${method}</code></td><td><span class="check-state ${result.status}">${labels[result.status]}</span></td><td>${escapeText(result.note)}${nodeDetail}</td><td class="inspection-value">${escapeText(result.result)}</td></tr><tr class="inspection-detail-row" id="${detailId}" hidden><td colspan="6"><div class="inspection-raw-output">${rawOutput}</div></td></tr>`;
    }).join('');
    return `<article class="inspection-group"><header><span>${groupIndex + 1}</span><div><h2>${group.title}</h2><p>${group.description}</p></div><b>${group.items.length}개 항목</b></header><div class="inspection-table-wrap"><table><thead><tr><th>점검 분류</th><th>점검 사항</th><th>점검 방법</th><th>상태</th><th>특이사항</th><th>점검 결과</th></tr></thead><tbody>${rows}</tbody></table></div></article>`;
  }).join('');
  document.querySelector('#totalInspectionItems').textContent = total;
  document.querySelector('#healthyInspectionItems').textContent = healthy;
  document.querySelector('#warningInspectionItems').textContent = warning;
  document.querySelector('#pendingInspectionItems').textContent = total - healthy - warning;
  document.querySelector('#inspectionCount').textContent = total;
  document.querySelector('#selectedInspectionCount').textContent = selectedInspectionKeys.size;
}

document.querySelector('#inspectionChecklist').addEventListener('click', event => {
  if (event.target.closest('details')) return;
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

document.querySelectorAll('.inspection-filter button').forEach(button => button.addEventListener('click', () => {
  currentFilter = button.dataset.filter;
  document.querySelectorAll('.inspection-filter button').forEach(item => item.classList.toggle('active', item === button));
  renderInspectionChecklist();
}));

function showPage(page) {
  const inspection = page === 'daily-inspection';
  document.querySelector('#dashboardPage').hidden = inspection;
  document.querySelector('#inspectionPage').hidden = !inspection;
  document.querySelector('#currentPageName').textContent = inspection ? '일일점검' : '대시보드';
  document.querySelectorAll('[data-page]').forEach(link => link.classList.toggle('active', link.dataset.page === page));
  sidebar.classList.remove('open');
}

document.querySelectorAll('[data-page]').forEach(link => link.addEventListener('click', event => {
  event.preventDefault();
  history.replaceState(null, '', link.getAttribute('href'));
  showPage(link.dataset.page);
}));

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
showPage(location.hash === '#daily-inspection' ? 'daily-inspection' : 'dashboard');
