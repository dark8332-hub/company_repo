const form = document.querySelector('#connectionForm');
const keyInput = document.querySelector('#privateKey');
const connectButton = document.querySelector('#connectButton');
const confirmButton = document.querySelector('#confirmFingerprint');
const errorBox = document.querySelector('#formError');
const successBox = document.querySelector('#formSuccess');
const fingerprintBox = document.querySelector('#fingerprintBox');
const fingerprintText = document.querySelector('#fingerprint');
const deleteSelectedButton = document.querySelector('#deleteSelected');
const hostKeyManager = document.querySelector('#hostKeyManager');
const probeHostKeyButton = document.querySelector('#probeHostKey');
const approveHostKeyButton = document.querySelector('#approveHostKey');
const databaseCredentialManager = document.querySelector('#databaseCredentialManager');
const databaseCredentialForm = document.querySelector('#databaseCredentialForm');
const deleteDatabaseCredentialButton = document.querySelector('#deleteDatabaseCredential');
let pendingPayload = null;
let managedProviderId = null;
let managedDatabaseProviderId = null;
let pendingHostFingerprint = null;

function applyMenuPreferences() {
  const allKeys = ['dashboard', 'daily-inspection', 'providers', 'infrastructure', 'monitoring', 'alerts', 'history'];
  let visible = allKeys;
  try { const saved = JSON.parse(localStorage.getItem('okestro-visible-menus')); if (Array.isArray(saved)) visible = saved; } catch (_) { /* Use all menus. */ }
  document.querySelectorAll('[data-menu-key]').forEach(link => { link.hidden = !visible.includes(link.dataset.menuKey); });
  document.querySelectorAll('.navigation>p').forEach(heading => {
    let item = heading.nextElementSibling;
    let hasVisibleItem = false;
    while (item && item.tagName !== 'P') { if (item.tagName === 'A' && !item.hidden) hasVisibleItem = true; item = item.nextElementSibling; }
    heading.hidden = !hasVisibleItem;
  });
}

document.querySelector('#menuButton').addEventListener('click', () => document.querySelector('#sidebar').classList.toggle('open'));
applyMenuPreferences();
loadSavedProviders();
deleteSelectedButton.addEventListener('click', deleteSelectedProviders);
document.querySelector('#closeHostKeyManager').addEventListener('click', () => { hostKeyManager.hidden = true; });
document.querySelector('#closeDatabaseCredentialManager').addEventListener('click', () => { databaseCredentialManager.hidden = true; });
databaseCredentialForm.addEventListener('submit', saveDatabaseCredential);
deleteDatabaseCredentialButton.addEventListener('click', deleteDatabaseCredential);
probeHostKeyButton.addEventListener('click', probeManagedHostKey);
approveHostKeyButton.addEventListener('click', approveManagedHostKey);
document.querySelector('#savedProviderList').addEventListener('click', event => {
  const button = event.target.closest('[data-manage-host-keys]');
  if (button) openHostKeyManager(button.dataset.manageHostKeys, button.dataset.providerName);
  const databaseButton = event.target.closest('[data-manage-database]');
  if (databaseButton) openDatabaseCredentialManager(databaseButton.dataset.manageDatabase, databaseButton.dataset.providerName);
});
document.querySelector('#trustedHostKeyList').addEventListener('click', event => {
  const button = event.target.closest('[data-remove-host-key]');
  if (button) removeManagedHostKey(button.dataset.removeHostKey);
});
document.querySelectorAll('[name=auth_method]').forEach(radio => radio.addEventListener('change', () => {
  const useKey = radio.value === 'private_key' && radio.checked;
  document.querySelector('#keyFields').hidden = !useKey;
  document.querySelector('#passwordFields').hidden = useKey;
  keyInput.required = useKey;
  document.querySelector('[name=password]').required = !useKey;
  resetFingerprint();
}));

form.addEventListener('input', () => { if (pendingPayload) resetFingerprint(); });
form.addEventListener('submit', async event => {
  event.preventDefault();
  errorBox.hidden = true;
  successBox.hidden = true;
  const values = new FormData(form);
  const authMethod = values.get('auth_method');
  const keyFile = keyInput.files[0];
  if (authMethod === 'private_key' && !keyFile) return showError('SSH 개인키 파일을 선택하세요.');
  pendingPayload = {
    provider_name: values.get('name'), vip: values.get('vip'), port: Number(values.get('port')),
    username: values.get('username'), auth_method: authMethod,
    private_key: keyFile ? await keyFile.text() : null,
    passphrase: values.get('passphrase') || null, password: values.get('password') || null,
    trusted_fingerprint: null
  };
  await connectProvider(false);
});

confirmButton.addEventListener('click', async () => {
  if (!pendingPayload?.trusted_fingerprint) return showError('확인할 SSH 지문 정보가 없습니다. 다시 연결해 주세요.');
  await connectProvider(true);
});

async function connectProvider(confirmed) {
  errorBox.hidden = true;
  connectButton.disabled = true;
  confirmButton.disabled = true;
  const activeButton = confirmed ? confirmButton : connectButton;
  activeButton.textContent = confirmed ? '지문 확인 후 연결 중...' : 'SSH 연결 확인 중...';
  try {
    const response = await fetch('/api/providers/connect', {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(pendingPayload)
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '연결에 실패했습니다.');
    if (data.status === 'confirmation_required') {
      pendingPayload.trusted_fingerprint = data.fingerprint;
      fingerprintText.textContent = data.fingerprint;
      fingerprintBox.hidden = false;
      connectButton.hidden = true;
      return;
    }
    const sudoText = data.sudo_mode === 'passwordless' ? '비밀번호 없이 sudo 사용 가능' : 'sudo 인증 필요';
    const tools = data.available_tools.length ? data.available_tools.map(escapeHtml).join(', ') : '탐지된 관리 도구 없음';
    successBox.innerHTML = `<b>공급자 등록 완료</b><span>노드: ${escapeHtml(data.controller_hostname)} · 계정: ${escapeHtml(data.ssh_user)}</span><span>${sudoText} · 도구: ${tools}</span><a class="result-link" href="/?provider=${encodeURIComponent(data.provider_id)}">대시보드에서 점검하기 →</a>`;
    successBox.hidden = false;
    fingerprintBox.hidden = true;
    connectButton.hidden = false;
    connectButton.disabled = true;
    connectButton.textContent = '공급자 등록 완료';
    pendingPayload = null;
    await loadSavedProviders();
  } catch (error) {
    showError(error.message);
    if (confirmed) confirmButton.textContent = '다시 연결';
  } finally {
    confirmButton.disabled = false;
    if (!confirmed) {
      connectButton.disabled = false;
      if (!connectButton.hidden) connectButton.textContent = 'VIP 연결 확인';
    }
  }
}

function resetFingerprint() {
  pendingPayload = null;
  fingerprintBox.hidden = true;
  connectButton.hidden = false;
  connectButton.disabled = false;
  connectButton.textContent = 'VIP 연결 확인';
}
function showError(message) { errorBox.textContent = message; errorBox.hidden = false; }
function escapeHtml(value) { const node = document.createElement('span'); node.textContent = value; return node.innerHTML; }

async function loadSavedProviders() {
  const list = document.querySelector('#savedProviderList');
  try {
    const response = await fetch('/api/providers');
    const data = await response.json();
    document.querySelector('#providerCount').textContent = data.providers.length;
    if (!data.providers.length) {
      list.innerHTML = '<div class="empty-provider">등록된 공급자가 없습니다.</div>';
      return;
    }
    list.innerHTML = data.providers.map(provider => {
      const check = provider.latest_check;
      const status = check ? (check.status === 'healthy' ? '정상' : '주의') : '점검 전';
      const statusClass = check ? check.status : 'pending';
      const databaseState = provider.database_credentials_configured ? 'DB 인증 완료' : 'DB 인증 등록';
      return `<article><label class="provider-check"><input type="checkbox" class="provider-selector" value="${escapeHtml(provider.id)}" aria-label="${escapeHtml(provider.name)} 선택"></label><span class="provider-avatar">OS</span><div><b>${escapeHtml(provider.name)}</b><small>${escapeHtml(provider.vip)}:${provider.port} · ${escapeHtml(provider.controller_hostname)}</small></div><em class="provider-status ${statusClass}">${status}</em><button class="manage-host-keys" type="button" data-manage-host-keys="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}">SSH 키 관리</button><button class="manage-database ${provider.database_credentials_configured ? 'configured' : ''}" type="button" data-manage-database="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}">${databaseState}</button><a href="/?provider=${encodeURIComponent(provider.id)}">대시보드</a></article>`;
    }).join('');
    list.querySelectorAll('.provider-selector').forEach(checkbox => checkbox.addEventListener('change', updateDeleteButton));
  } catch (_) {
    list.innerHTML = '<div class="empty-provider error">공급자 목록을 불러오지 못했습니다.</div>';
  }
}

async function openDatabaseCredentialManager(providerId, providerName) {
  managedDatabaseProviderId = providerId;
  databaseCredentialManager.hidden = false;
  document.querySelector('#databaseCredentialProviderName').textContent = `${providerName} · Middleware MySQL 점검 인증`;
  databaseCredentialForm.reset();
  databaseCredentialForm.elements.host.value = 'localhost';
  databaseCredentialForm.elements.port.value = '3306';
  const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/database-credentials`, {cache:'no-store'});
  const data = await response.json();
  if (!response.ok) return showError(apiError(data, 'DB 인증정보를 불러오지 못했습니다.'));
  if (data.configured) {
    databaseCredentialForm.elements.username.value = data.username;
    databaseCredentialForm.elements.host.value = data.host;
    databaseCredentialForm.elements.port.value = data.port;
    document.querySelector('#databaseCredentialStatus').textContent = '암호화된 DB 인증정보가 등록되어 있습니다. 비밀번호는 화면에 표시되지 않습니다.';
  } else {
    document.querySelector('#databaseCredentialStatus').textContent = '인증정보를 등록하면 Middleware MySQL 점검에 사용됩니다.';
  }
  deleteDatabaseCredentialButton.hidden = !data.configured;
  databaseCredentialManager.scrollIntoView({behavior:'smooth', block:'start'});
}

async function saveDatabaseCredential(event) {
  event.preventDefault();
  if (!managedDatabaseProviderId) return;
  const values = new FormData(databaseCredentialForm);
  const response = await fetch(`/api/providers/${encodeURIComponent(managedDatabaseProviderId)}/database-credentials`, {
    method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({username:values.get('username'), password:values.get('password'), host:values.get('host'), port:Number(values.get('port'))})
  });
  const data = await response.json();
  if (!response.ok) return showError(apiError(data, 'DB 인증정보를 저장하지 못했습니다.'));
  databaseCredentialForm.elements.password.value = '';
  document.querySelector('#databaseCredentialStatus').textContent = '암호화 저장을 완료했습니다. 다음 일일점검부터 사용됩니다.';
  deleteDatabaseCredentialButton.hidden = false;
  await loadSavedProviders();
}

async function deleteDatabaseCredential() {
  if (!managedDatabaseProviderId || !window.confirm('등록된 DB 인증정보를 삭제할까요?')) return;
  const response = await fetch(`/api/providers/${encodeURIComponent(managedDatabaseProviderId)}/database-credentials`, {method:'DELETE'});
  const data = await response.json();
  if (!response.ok) return showError(apiError(data, 'DB 인증정보를 삭제하지 못했습니다.'));
  databaseCredentialForm.reset();
  databaseCredentialForm.elements.host.value = 'localhost';
  databaseCredentialForm.elements.port.value = '3306';
  document.querySelector('#databaseCredentialStatus').textContent = 'DB 인증정보가 삭제되었습니다.';
  deleteDatabaseCredentialButton.hidden = true;
  await loadSavedProviders();
}

function apiError(data, fallback) {
  return typeof data?.detail === 'string' ? data.detail : (data?.detail?.message || fallback);
}

async function openHostKeyManager(providerId, providerName) {
  managedProviderId = providerId;
  pendingHostFingerprint = null;
  hostKeyManager.hidden = false;
  document.querySelector('#hostKeyProviderName').textContent = `${providerName} · 승인된 Controller 지문`;
  document.querySelector('#currentHostFingerprint').textContent = '조회 전';
  const status = document.querySelector('#currentHostKeyStatus');
  status.className = 'pending';
  status.textContent = '조회 전';
  approveHostKeyButton.hidden = true;
  await loadManagedHostKeys();
  hostKeyManager.scrollIntoView({behavior:'smooth', block:'start'});
}

async function loadManagedHostKeys() {
  if (!managedProviderId) return;
  const keyList = document.querySelector('#trustedHostKeyList');
  const eventList = document.querySelector('#hostKeyEventList');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(managedProviderId)}/host-keys`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(apiError(data, 'SSH 지문 목록을 불러오지 못했습니다.'));
    keyList.innerHTML = data.keys.length ? data.keys.map(key => `<article><div><strong>${escapeHtml(key.hostname || 'Controller')}</strong><code>${escapeHtml(key.fingerprint)}</code><small>승인 ${formatDate(key.approved_at)} · 최근 확인 ${formatDate(key.last_seen_at)}</small></div><button type="button" data-remove-host-key="${escapeHtml(key.id)}" ${data.keys.length === 1 ? 'disabled title="마지막 신뢰 지문은 삭제할 수 없습니다."' : ''}>폐기</button></article>`).join('') : '<div class="empty-provider">신뢰 중인 지문이 없습니다.</div>';
    eventList.innerHTML = data.events.length ? data.events.map(item => `<article><span class="${escapeHtml(item.action)}">${item.action === 'approved' ? '승인' : '폐기'}</span><div><code>${escapeHtml(item.fingerprint)}</code><small>${escapeHtml(item.hostname || 'Controller')} · ${formatDate(item.created_at)}</small></div></article>`).join('') : '<div class="empty-provider">변경 이력이 없습니다.</div>';
  } catch (error) {
    keyList.innerHTML = `<div class="empty-provider error">${escapeHtml(error.message)}</div>`;
  }
}

async function probeManagedHostKey() {
  if (!managedProviderId) return;
  probeHostKeyButton.disabled = true;
  probeHostKeyButton.textContent = '조회 중...';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(managedProviderId)}/host-keys/probe`, {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(apiError(data, '현재 SSH 지문을 조회하지 못했습니다.'));
    pendingHostFingerprint = data.fingerprint;
    document.querySelector('#currentHostFingerprint').textContent = data.fingerprint;
    const status = document.querySelector('#currentHostKeyStatus');
    status.className = data.trusted ? 'trusted' : 'untrusted';
    status.textContent = data.trusted ? '신뢰됨' : '승인 필요';
    approveHostKeyButton.hidden = data.trusted;
    if (data.trusted) await loadManagedHostKeys();
  } catch (error) { showError(error.message); }
  finally { probeHostKeyButton.disabled = false; probeHostKeyButton.textContent = '현재 지문 조회'; }
}

async function approveManagedHostKey() {
  if (!managedProviderId || !pendingHostFingerprint) return;
  if (!window.confirm(`대상 Controller에서 직접 확인한 지문과 아래 값이 일치합니까?\n\n${pendingHostFingerprint}\n\n일치할 때만 승인하세요.`)) return;
  approveHostKeyButton.disabled = true;
  approveHostKeyButton.textContent = '승인 확인 중...';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(managedProviderId)}/host-keys/approve`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({fingerprint:pendingHostFingerprint})});
    const data = await response.json();
    if (!response.ok) throw new Error(apiError(data, 'SSH 지문을 승인하지 못했습니다.'));
    approveHostKeyButton.hidden = true;
    const status = document.querySelector('#currentHostKeyStatus');
    status.className = 'trusted';
    status.textContent = '신뢰됨';
    await loadManagedHostKeys();
  } catch (error) { showError(error.message); }
  finally { approveHostKeyButton.disabled = false; approveHostKeyButton.textContent = '확인 후 신뢰 추가'; }
}

async function removeManagedHostKey(keyId) {
  if (!window.confirm('이 SSH 지문을 신뢰 목록에서 폐기하시겠습니까?')) return;
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(managedProviderId)}/host-keys/${encodeURIComponent(keyId)}`, {method:'DELETE'});
    const data = await response.json();
    if (!response.ok) throw new Error(apiError(data, 'SSH 지문을 폐기하지 못했습니다.'));
    await loadManagedHostKeys();
  } catch (error) { showError(error.message); }
}

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '-' : new Intl.DateTimeFormat('ko-KR', {dateStyle:'short', timeStyle:'short'}).format(date);
}

function updateDeleteButton() {
  const count = document.querySelectorAll('.provider-selector:checked').length;
  deleteSelectedButton.disabled = count === 0;
  deleteSelectedButton.textContent = count ? `${count}개 선택 삭제` : '선택 삭제';
}

async function deleteSelectedProviders() {
  const selected = [...document.querySelectorAll('.provider-selector:checked')];
  if (!selected.length) return;
  if (!window.confirm(`선택한 공급자 ${selected.length}개와 점검 이력을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.`)) return;
  deleteSelectedButton.disabled = true;
  deleteSelectedButton.textContent = '삭제 중...';
  try {
    const responses = await Promise.all(selected.map(item => fetch(`/api/providers/${encodeURIComponent(item.value)}`, {method:'DELETE'})));
    if (responses.some(response => !response.ok)) throw new Error('일부 공급자를 삭제하지 못했습니다.');
    await loadSavedProviders();
  } catch (error) {
    showError(error.message);
  } finally {
    updateDeleteButton();
  }
}
