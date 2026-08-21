const menuButton = document.querySelector('#menuButton');
const sidebar = document.querySelector('#sidebar');
const runInspection = document.querySelector('#runInspection');
const toast = document.querySelector('#toast');
const clock = document.querySelector('#clock');
const providerSelect = document.querySelector('#providerSelect');

menuButton.addEventListener('click', () => sidebar.classList.toggle('open'));
sidebar.addEventListener('click', event => {
  if (event.target === sidebar && sidebar.classList.contains('open')) sidebar.classList.remove('open');
});

runInspection.addEventListener('click', async () => {
  if (!providerSelect.value) return showToast('공급자를 먼저 선택하세요.', '공급자 연결 메뉴에서 환경을 등록할 수 있습니다.');
  runInspection.disabled = true;
  runInspection.innerHTML = '<span>↻</span> 점검 실행 중';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(providerSelect.value)}/checks`, {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '점검 실행에 실패했습니다.');
    renderCheck(data);
    showToast('일일점검이 완료되었습니다.', data.status === 'healthy' ? '현재 확인된 경고가 없습니다.' : `${data.warnings.length}개 경고를 확인하세요.`);
  } catch (error) {
    showToast('일일점검에 실패했습니다.', error.message);
  } finally {
    runInspection.disabled = false;
    runInspection.innerHTML = '<span>↻</span> 일일점검 실행';
  }
});

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
    });
    if (requested && data.providers.some(provider => provider.id === requested)) providerSelect.value = requested;
    else if (data.providers.length === 1) providerSelect.value = data.providers[0].id;
    const selected = data.providers.find(provider => provider.id === providerSelect.value);
    if (selected?.latest_check) renderCheck({...selected.latest_check.result, status:selected.latest_check.status});
  } catch (_) { showToast('공급자 목록을 불러오지 못했습니다.', '서버 연결 상태를 확인하세요.'); }
}

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
