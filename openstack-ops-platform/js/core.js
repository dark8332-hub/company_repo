// ===== 공통: 세션 가드, DOM 참조, 메뉴 설정, 화면 전환, 공급자 목록, 알림 토스트 =====
// Session guard: a 401 from any API call means the login session is gone, so return to the login page.
const nativeFetch = window.fetch.bind(window);
function redirectToLogin() {
  location.replace(`/login?next=${encodeURIComponent(location.pathname + location.search)}${location.hash}`);
}
window.fetch = async (...args) => {
  const response = await nativeFetch(...args);
  if (response.status === 401 && !String(args[0]).startsWith('/api/auth/')) redirectToLogin();
  return response;
};

const menuButton = document.querySelector('#menuButton');
const sidebar = document.querySelector('#sidebar');
const runInspection = document.querySelector('#runInspection');
const toast = document.querySelector('#toast');
const clock = document.querySelector('#clock');
const providerSelect = document.querySelector('#providerSelect');
const inspectionProviderSelect = document.querySelector('#inspectionProviderSelect');
const infrastructureProviderSelect = document.querySelector('#infrastructureProviderSelect');
const monitoringProviderSelect = document.querySelector('#monitoringProviderSelect');
const historyProvider = document.querySelector('#historyProvider');
const historyProviderFilter = document.querySelector('#historyProviderFilter');
const alertProviderFilter = document.querySelector('#alertProviderFilter');
const dailyRunInspection = document.querySelector('#dailyRunInspection');
const exportInspectionPdf = document.querySelector('#exportInspectionPdf');
const discoverCluster = document.querySelector('#discoverCluster');
const dashboardDiscoverCluster = document.querySelector('#dashboardDiscoverCluster');
const dashboardNodeCount = document.querySelector('#dashboardNodeCount');
const exceptionItem = document.querySelector('#exceptionItem');
const exceptionNode = document.querySelector('#exceptionNode');
const exceptionReason = document.querySelector('#exceptionReason');

const menuPreferenceKey = 'okestro-visible-menus';
const configurableMenus = [
  ['dashboard', '대시보드', '운영 현황 요약'], ['providers', '공급자 연결', 'OpenStack 환경 연결 관리'],
  ['infrastructure', '인프라 현황', '노드와 자원 상태'], ['daily-inspection', '일일점검', '클러스터 일일 점검'],
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
}

function renderMenuSettings() {
  const list = document.querySelector('#menuSettingsList');
  if (!list) return;
  list.innerHTML = configurableMenus.map(([key, name, description]) => `<label class="menu-setting-item${visibleMenus.has(key) ? ' selected' : ''}"><input type="checkbox" value="${key}" ${visibleMenus.has(key) ? 'checked' : ''}><span><strong>${name}</strong><small>${description}</small></span><em>${visibleMenus.has(key) ? '사용' : '숨김'}</em></label>`).join('');
}

let menuSyncTimer = null;
function saveMenuPreferences() {
  try { localStorage.setItem(menuPreferenceKey, JSON.stringify([...visibleMenus])); } catch (_) { /* private mode: the server copy still applies */ }
  applyMenuPreferences();
  renderMenuSettings();
  // The server copy makes the choice follow the account to other browsers; localStorage only covers the first paint.
  clearTimeout(menuSyncTimer);
  menuSyncTimer = setTimeout(() => {
    fetch('/api/settings/ui.menus', {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({value:{visible:[...visibleMenus]}})}).catch(() => {});
  }, 300);
}
function applyServerMenus(value) {
  if (!value || !Array.isArray(value.visible)) return;
  visibleMenus = new Set(value.visible.filter(key => configurableMenus.some(menu => menu[0] === key)));
  try { localStorage.setItem(menuPreferenceKey, JSON.stringify([...visibleMenus])); } catch (_) { /* ignore */ }
  applyMenuPreferences();
  renderMenuSettings();
}
async function loadMenuPreferences() {
  try {
    const response = await fetch('/api/settings/ui.menus', {cache:'no-store'});
    if (!response.ok) return;
    const entry = await response.json();
    if (entry.source === 'stored') applyServerMenus(entry.value);
  } catch (_) { /* offline: keep the local copy */ }
}

document.querySelectorAll('[data-page]').forEach(link => link.addEventListener('click', event => {
  event.preventDefault();
  history.replaceState(null, '', link.getAttribute('href'));
  showPage(link.dataset.page);
  if (link.dataset.page === 'history') loadWorkHistories();
  if (link.dataset.page === 'alerts') loadAlerts();
  if (link.dataset.page === 'settings') loadInspectionSettings();
}));

// Every provider <select> on the page. The first option of each is its placeholder ("공급자를 선택하세요" / "전체 공급자")
// and is kept; provider options are rebuilt on every load so registrations and deletions show up without a reload.
const providerSelects = () => [providerSelect, inspectionProviderSelect, infrastructureProviderSelect, monitoringProviderSelect, alertProviderFilter, historyProvider, historyProviderFilter];
let knownProviders = [];
function fillProviderOptions(select, providers) {
  const previous = select.value;
  [...select.options].filter(option => option.dataset.provider === '1').forEach(option => option.remove());
  providers.forEach(provider => {
    const option = document.createElement('option');
    option.value = provider.id;
    option.dataset.provider = '1';
    option.textContent = `${provider.name} (${provider.vip})`;
    select.appendChild(option);
  });
  if (previous && providers.some(provider => provider.id === previous)) select.value = previous;
}
function syncProviderSelects(providerId) {
  [providerSelect, inspectionProviderSelect, infrastructureProviderSelect, monitoringProviderSelect].forEach(select => { select.value = providerId || ''; });
}
// Switches every screen to the given provider and reloads the provider-scoped data of the current screen.
function selectProvider(providerId) {
  if (!knownProviders.some(provider => provider.id === providerId)) return;
  syncProviderSelects(providerId);
  providerSelect.dispatchEvent(new Event('change'));
}
async function loadProviders(preferredId = null) {
  try {
    const response = await fetch('/api/providers', {cache:'no-store'});
    const data = await response.json();
    knownProviders = data.providers;
    const requested = preferredId || new URLSearchParams(location.search).get('provider');
    providerSelects().forEach(select => fillProviderOptions(select, data.providers));
    if (requested && data.providers.some(provider => provider.id === requested)) providerSelect.value = requested;
    else if (!data.providers.some(provider => provider.id === providerSelect.value)) providerSelect.value = data.providers.length ? data.providers[0].id : '';
    syncProviderSelects(providerSelect.value);
    if (location.hash === '#monitoring') loadMonitoring();
    if (inspectionProviderSelect.value) {
      loadProviderNodes(inspectionProviderSelect.value);
      loadCheckExceptions(inspectionProviderSelect.value);
      loadCustomChecks(inspectionProviderSelect.value);
      loadLatestCheck(inspectionProviderSelect.value);
    } else {
      loadOverview('');
    }
  } catch (error) { showToast('공급자 목록을 불러오지 못했습니다.', error.message || '서버 연결 상태를 확인하세요.'); }
}

// page key → [container id, breadcrumb label]. Add a page here and it takes part in navigation, the initial hash and the breadcrumb.
const pageRegistry = {
  dashboard: ['dashboardPage', '대시보드'], 'daily-inspection': ['inspectionPage', '일일점검'], providers: ['providersPage', '공급자 연결'],
  infrastructure: ['infrastructurePage', '인프라 현황'], monitoring: ['monitoringPage', '모니터링'], alerts: ['alertsPage', '알림 및 장애'],
  history: ['historyPage', '작업 이력'], settings: ['settingsPage', '설정']
};
let currentPage = 'dashboard';
function showPage(page) {
  if (!pageRegistry[page]) page = 'dashboard';
  currentPage = page;
  Object.entries(pageRegistry).forEach(([key, [id]]) => { document.querySelector(`#${id}`).hidden = key !== page; });
  if (page === 'monitoring') loadMonitoring(); else stopMonitoringAutoRefresh();
  if (page === 'providers') openProvidersPage();
  document.querySelector('#currentPageName').textContent = pageRegistry[page][1];
  document.querySelectorAll('[data-page]').forEach(link => link.classList.toggle('active', link.dataset.page === page));
  sidebar.classList.remove('open');
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
