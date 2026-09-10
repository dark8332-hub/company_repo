// ===== 공급자 연결: 등록 폼, 등록된 공급자 목록, SSH 호스트 키·MySQL·sudo 인증 관리 =====
const connectionForm = document.querySelector('#connectionForm');
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
const sudoCredentialManager = document.querySelector('#sudoCredentialManager');
const sudoCredentialForm = document.querySelector('#sudoCredentialForm');
const deleteSudoCredentialButton = document.querySelector('#deleteSudoCredential');
// The MySQL and sudo forms also carry a `username` field, so look the SSH account up on the form itself.
const usernameInput = connectionForm.elements.username;
let pendingPayload = null;
let managedProviderId = null;
let managedDatabaseProviderId = null;
let managedSudoProviderId = null;
let pendingHostFingerprint = null;
let savedProvidersLoaded = false;
let savedProviders = [];
let editingProviderId = null;
let editPendingFingerprint = null;
let diagnosingProviderId = null;
let managedNodesProviderId = null;
let profileProviderId = null;

deleteSelectedButton.addEventListener('click', deleteSelectedProviders);
document.querySelector('#closeHostKeyManager').addEventListener('click', () => { hostKeyManager.hidden = true; });
document.querySelector('#closeDatabaseCredentialManager').addEventListener('click', () => { databaseCredentialManager.hidden = true; });
databaseCredentialForm.addEventListener('submit', saveDatabaseCredential);
deleteDatabaseCredentialButton.addEventListener('click', deleteDatabaseCredential);
document.querySelector('#closeSudoCredentialManager').addEventListener('click', () => { sudoCredentialManager.hidden = true; });
sudoCredentialForm.addEventListener('submit', saveSudoCredential);
deleteSudoCredentialButton.addEventListener('click', deleteSudoCredential);
usernameInput.addEventListener('input', updateSudoFields);
probeHostKeyButton.addEventListener('click', probeManagedHostKey);
approveHostKeyButton.addEventListener('click', approveManagedHostKey);
document.querySelector('#savedProviderList').addEventListener('click', event => {
  const button = event.target.closest('[data-manage-host-keys]');
  if (button) openHostKeyManager(button.dataset.manageHostKeys, button.dataset.providerName);
  const databaseButton = event.target.closest('[data-manage-database]');
  if (databaseButton) openDatabaseCredentialManager(databaseButton.dataset.manageDatabase, databaseButton.dataset.providerName);
  const sudoButton = event.target.closest('[data-manage-sudo]');
  if (sudoButton) openSudoCredentialManager(sudoButton.dataset.manageSudo, sudoButton.dataset.providerName, sudoButton.dataset.username);
  const editButton = event.target.closest('[data-edit-provider]');
  if (editButton) openProviderEditor(editButton.dataset.editProvider);
  const diagnoseButton = event.target.closest('[data-diagnose-provider]');
  if (diagnoseButton) openProviderDiagnosis(diagnoseButton.dataset.diagnoseProvider, diagnoseButton.dataset.providerName);
  const nodesButton = event.target.closest('[data-manage-nodes]');
  if (nodesButton) openNodeManager(nodesButton.dataset.manageNodes, nodesButton.dataset.providerName);
  const profileButton = event.target.closest('[data-edit-profile]');
  if (profileButton) openProviderProfile(profileButton.dataset.editProfile, profileButton.dataset.providerName);
});

// --- Provider editing ------------------------------------------------------------------------------
const providerEditor = document.querySelector('#providerEditor');
const providerEditForm = document.querySelector('#providerEditForm');
function closePanelsExcept(keep) {
  [providerEditor, document.querySelector('#providerDiagnosis'), document.querySelector('#nodeManager'), document.querySelector('#providerProfile')].forEach(panel => { if (panel !== keep) panel.hidden = true; });
}
function openProviderEditor(providerId) {
  const provider = savedProviders.find(item => item.id === providerId);
  if (!provider) return;
  editingProviderId = providerId; editPendingFingerprint = null;
  closePanelsExcept(providerEditor);
  providerEditor.hidden = false;
  document.querySelector('#providerEditorName').textContent = `${provider.name} · 현재 ${provider.vip}:${provider.port} · ${provider.username} · ${provider.auth_method === 'private_key' ? '개인키' : '비밀번호'} 인증`;
  providerEditForm.reset();
  providerEditForm.elements.provider_id.value = providerId;
  providerEditForm.elements.name.value = provider.name;
  providerEditForm.elements.vip.value = provider.vip;
  providerEditForm.elements.port.value = provider.port;
  providerEditForm.elements.username.value = provider.username;
  document.querySelector('#providerEditFingerprint').hidden = true;
  document.querySelector('#providerEditStatus').textContent = '변경할 항목만 입력하세요. 인증정보 칸을 비우면 저장된 값을 그대로 씁니다.';
  providerEditor.scrollIntoView({behavior:'smooth', block:'start'});
}
async function submitProviderEdit(trustedFingerprint = null) {
  if (!editingProviderId) return;
  const values = new FormData(providerEditForm);
  const keyFile = document.querySelector('#providerEditKey').files[0];
  const payload = {
    name: values.get('name'), vip: values.get('vip').trim(), port: Number(values.get('port')), username: values.get('username').trim(),
    auth_method: values.get('auth_method') || null, private_key: keyFile ? await keyFile.text() : null, passphrase: values.get('passphrase') || null,
    password: values.get('password') || null, sudo_password: values.get('sudo_password') || null, trusted_fingerprint: trustedFingerprint,
  };
  const button = document.querySelector('#saveProviderEdit');
  const status = document.querySelector('#providerEditStatus');
  button.disabled = true; status.textContent = '변경 내용을 확인하고 있습니다…';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(editingProviderId)}`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) throw new Error(apiError(data, '공급자를 수정하지 못했습니다.'));
    if (data.status === 'confirmation_required') {
      editPendingFingerprint = data.fingerprint;
      document.querySelector('#providerEditFingerprintText').textContent = data.fingerprint;
      document.querySelector('#providerEditFingerprint').hidden = false;
      status.textContent = '새 주소의 SSH 호스트 키를 확인한 뒤 승인하세요.';
      return;
    }
    document.querySelector('#providerEditFingerprint').hidden = true;
    status.textContent = `저장했습니다. ${data.controller_hostname ? `활성 Controller ${data.controller_hostname} · sudo ${data.sudo_mode}` : ''}`;
    showToast('공급자를 수정했습니다.', data.provider?.name || '');
    ['passphrase', 'password', 'sudo_password'].forEach(name => { providerEditForm.elements[name].value = ''; });
    document.querySelector('#providerEditKey').value = '';
    await loadSavedProviders();
    await loadProviders(editingProviderId);
  } catch (error) { status.textContent = error.message; showError(error.message); }
  finally { button.disabled = false; }
}
providerEditForm.addEventListener('submit', event => { event.preventDefault(); submitProviderEdit(null); });
document.querySelector('#confirmProviderEditFingerprint').addEventListener('click', () => { if (editPendingFingerprint) submitProviderEdit(editPendingFingerprint); });
document.querySelector('#closeProviderEditor').addEventListener('click', () => { providerEditor.hidden = true; });

// --- Connection diagnosis ----------------------------------------------------------------------------
const diagnosisPanel = document.querySelector('#providerDiagnosis');
function openProviderDiagnosis(providerId, providerName) {
  diagnosingProviderId = providerId;
  closePanelsExcept(diagnosisPanel);
  diagnosisPanel.hidden = false;
  document.querySelector('#providerDiagnosisName').textContent = `${providerName} · 연결 준비 상태`;
  document.querySelector('#providerDiagnosisResult').innerHTML = '<div class="empty-provider">진단 실행을 누르면 결과가 표시됩니다.</div>';
  diagnosisPanel.scrollIntoView({behavior:'smooth', block:'start'});
  runProviderDiagnosis();
}
async function runProviderDiagnosis() {
  if (!diagnosingProviderId) return;
  const button = document.querySelector('#runProviderDiagnosis');
  const box = document.querySelector('#providerDiagnosisResult');
  button.disabled = true; button.textContent = '진단 중…';
  box.innerHTML = '<div class="empty-provider">VIP, SSH, root 권한, OpenStack CLI, 노드, Prometheus를 확인하고 있습니다. 최대 1~2분 걸립니다.</div>';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(diagnosingProviderId)}/diagnose`, {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(apiError(data, '진단을 실행하지 못했습니다.'));
    const icons = {ok:'✓', warn:'!', fail:'✕', skip:'–'};
    const labels = {ok:'정상', warn:'주의', fail:'실패', skip:'건너뜀'};
    box.innerHTML = `<div class="diagnosis-summary ${escapeHtml(data.overall)}"><strong>${data.overall === 'ok' ? '연결 준비 완료' : (data.overall === 'warn' ? '주의 항목이 있습니다' : '실패한 단계가 있습니다')}</strong><span>정상 ${data.summary.ok} · 주의 ${data.summary.warn} · 실패 ${data.summary.fail} · 건너뜀 ${data.summary.skip} · ${data.duration_seconds}초 · ${escapeHtml(formatDate(data.diagnosed_at))}</span></div>` +
      `<ol class="diagnosis-steps">${data.steps.map(step => `<li class="${escapeHtml(step.status)}"><i>${icons[step.status] || '?'}</i><div><strong>${escapeHtml(step.label)}</strong><span>${escapeHtml(step.detail)}</span>${step.nodes ? `<ul class="diagnosis-nodes">${step.nodes.map(node => `<li class="${escapeHtml(node.status)}"><b>${escapeHtml(node.hostname)}</b><span>${escapeHtml(node.detail)}</span></li>`).join('')}</ul>` : ''}</div><em>${labels[step.status] || step.status}${step.seconds != null ? ` · ${step.seconds}초` : ''}</em></li>`).join('')}</ol>`;
    await loadSavedProviders();
  } catch (error) { box.innerHTML = `<div class="empty-provider error">${escapeHtml(error.message)}</div>`; }
  finally { button.disabled = false; button.textContent = '진단 실행'; }
}
document.querySelector('#runProviderDiagnosis').addEventListener('click', runProviderDiagnosis);
document.querySelector('#closeProviderDiagnosis').addEventListener('click', () => { diagnosisPanel.hidden = true; });

// --- Node inventory management -----------------------------------------------------------------------
const nodeManager = document.querySelector('#nodeManager');
const roleNames = {controller:'Controller', compute:'Compute', storage:'Storage', network:'Network'};
function openNodeManager(providerId, providerName) {
  managedNodesProviderId = providerId;
  closePanelsExcept(nodeManager);
  nodeManager.hidden = false;
  document.querySelector('#nodeManagerName').textContent = `${providerName} · 노드 인벤토리`;
  loadManagedNodes();
  nodeManager.scrollIntoView({behavior:'smooth', block:'start'});
}
async function loadManagedNodes() {
  const list = document.querySelector('#nodeManagerList');
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(managedNodesProviderId)}/nodes`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(apiError(data, '노드 목록을 불러오지 못했습니다.'));
    if (!data.nodes.length) { list.innerHTML = '<div class="empty-provider">탐색된 노드가 없습니다. 대시보드의 클러스터 노드 탐색을 실행하거나 아래에서 직접 추가하세요.</div>'; return; }
    list.innerHTML = `<table><thead><tr><th>호스트명</th><th>역할</th><th>주소</th><th>출처</th><th>정비 중</th><th>메모</th><th></th></tr></thead><tbody>${data.nodes.map(node => `<tr class="${node.maintenance ? 'maintenance' : ''}" data-node-host="${escapeHtml(node.hostname)}"><td><strong>${escapeHtml(node.hostname)}</strong></td><td><select data-node-field="role">${Object.entries(roleNames).map(([value, label]) => `<option value="${value}" ${node.role === value ? 'selected' : ''}>${label}</option>`).join('')}</select></td><td><input data-node-field="address" value="${escapeHtml(node.address || '')}" maxlength="253"></td><td>${node.source === 'manual' ? '직접 추가' : escapeHtml(node.source || '탐색')}</td><td><label class="node-maintenance"><input type="checkbox" data-node-field="maintenance" ${node.maintenance ? 'checked' : ''}> 점검 제외</label></td><td><input data-node-field="note" value="${escapeHtml(node.note || '')}" maxlength="300" placeholder="메모"></td><td><button type="button" data-node-save>저장</button><button type="button" class="danger" data-node-delete>삭제</button></td></tr>`).join('')}</tbody></table><p class="retention-last">정비 중으로 표시한 노드는 다음 점검부터 제외되고 결과에 '정비 중 제외'로 남습니다. 직접 추가한 노드는 클러스터 탐색 후에도 유지됩니다.</p>`;
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeHtml(error.message)}</div>`; }
}
document.querySelector('#nodeManagerList').addEventListener('click', async event => {
  const row = event.target.closest('[data-node-host]');
  if (!row) return;
  const hostname = row.dataset.nodeHost;
  if (event.target.closest('[data-node-save]')) {
    const payload = {role: row.querySelector('[data-node-field="role"]').value, address: row.querySelector('[data-node-field="address"]').value.trim(), maintenance: row.querySelector('[data-node-field="maintenance"]').checked, note: row.querySelector('[data-node-field="note"]').value.trim()};
    const response = await fetch(`/api/providers/${encodeURIComponent(managedNodesProviderId)}/nodes/${encodeURIComponent(hostname)}`, {method:'PATCH', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) return showError(apiError(data, '노드를 저장하지 못했습니다.'));
    showToast('노드를 저장했습니다.', `${hostname} · ${roleNames[payload.role] || payload.role}${payload.maintenance ? ' · 점검 제외' : ''}`);
    await loadManagedNodes(); await loadSavedProviders();
    if (inspectionProviderSelect.value === managedNodesProviderId) loadProviderNodes(managedNodesProviderId);
  } else if (event.target.closest('[data-node-delete]')) {
    if (!window.confirm(`${hostname} 노드를 인벤토리에서 삭제할까요? 다시 탐색하면 자동 탐색 노드는 복구됩니다.`)) return;
    const response = await fetch(`/api/providers/${encodeURIComponent(managedNodesProviderId)}/nodes/${encodeURIComponent(hostname)}`, {method:'DELETE'});
    const data = await response.json();
    if (!response.ok) return showError(apiError(data, '노드를 삭제하지 못했습니다.'));
    await loadManagedNodes(); await loadSavedProviders();
    if (inspectionProviderSelect.value === managedNodesProviderId) loadProviderNodes(managedNodesProviderId);
  }
});
document.querySelector('#nodeAddForm').addEventListener('submit', async event => {
  event.preventDefault();
  if (!managedNodesProviderId) return;
  const form = event.currentTarget;
  const payload = {hostname: form.elements.hostname.value.trim(), role: form.elements.role.value, address: form.elements.address.value.trim(), note: form.elements.note.value.trim()};
  const response = await fetch(`/api/providers/${encodeURIComponent(managedNodesProviderId)}/nodes`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
  const data = await response.json();
  if (!response.ok) return showError(apiError(data, '노드를 추가하지 못했습니다.'));
  form.reset();
  showToast('노드를 추가했습니다.', `${payload.hostname} · 점검 전에 known_hosts 등록(ssh-keyscan)을 확인하세요.`);
  await loadManagedNodes(); await loadSavedProviders();
  if (inspectionProviderSelect.value === managedNodesProviderId) loadProviderNodes(managedNodesProviderId);
});
document.querySelector('#closeNodeManager').addEventListener('click', () => { nodeManager.hidden = true; });

// --- Provider profile ------------------------------------------------------------------------------
const profilePanel = document.querySelector('#providerProfile');
const profileForm = document.querySelector('#providerProfileForm');
async function openProviderProfile(providerId, providerName) {
  profileProviderId = providerId;
  closePanelsExcept(profilePanel);
  profilePanel.hidden = false;
  document.querySelector('#providerProfileName').textContent = `${providerName} · 사이트 정보와 상태`;
  profileForm.reset();
  try {
    const [settingResponse, statusResponse] = await Promise.all([
      fetch(`/api/providers/${encodeURIComponent(providerId)}/settings/profile`, {cache:'no-store'}),
      fetch(`/api/providers/${encodeURIComponent(providerId)}/status`, {cache:'no-store'})]);
    const setting = await settingResponse.json();
    const status = await statusResponse.json();
    if (settingResponse.ok) {
      const value = setting.value || {};
      profileForm.elements.site.value = value.site || ''; profileForm.elements.environment.value = value.environment || '';
      profileForm.elements.tags.value = (value.tags || []).join(', '); profileForm.elements.contact.value = value.contact || ''; profileForm.elements.memo.value = value.memo || '';
    }
    if (statusResponse.ok) {
      const summary = status.last_diagnosis;
      document.querySelector('#providerProfileStatus').innerHTML = [
        ['최근 점검', status.last_check_at ? formatDate(status.last_check_at) : '-', status.last_check_status === 'healthy' ? '정상' : (status.last_check_status ? '주의' : '기록 없음')],
        ['마지막 연결 진단', status.last_diagnosed_at ? formatDate(status.last_diagnosed_at) : '-', summary ? `정상 ${summary.ok} · 주의 ${summary.warn} · 실패 ${summary.fail}` : '진단 전'],
        ['마지막 SSH 성공', status.ssh_ok_at ? formatDate(status.ssh_ok_at) : '-', '연결 진단 기준'],
        ['공급자 정보 수정', status.updated_at ? formatDate(status.updated_at) : '-', '이름·주소·계정·인증정보 변경 시각']
      ].map(([label, value, hint]) => `<article><small>${escapeHtml(label)}</small><strong>${escapeHtml(value)}</strong><em>${escapeHtml(hint)}</em></article>`).join('');
    }
  } catch (_) { /* the form still works */ }
  profilePanel.scrollIntoView({behavior:'smooth', block:'start'});
}
profileForm.addEventListener('submit', async event => {
  event.preventDefault();
  if (!profileProviderId) return;
  const value = {site: profileForm.elements.site.value, environment: profileForm.elements.environment.value, contact: profileForm.elements.contact.value, memo: profileForm.elements.memo.value, tags: profileForm.elements.tags.value.split(',').map(tag => tag.trim()).filter(Boolean)};
  const response = await fetch(`/api/providers/${encodeURIComponent(profileProviderId)}/settings/profile`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({value})});
  const data = await response.json();
  if (!response.ok) return showError(apiError(data, '프로필을 저장하지 못했습니다.'));
  showToast('프로필을 저장했습니다.', [value.site, value.environment, ...value.tags].filter(Boolean).join(' · ') || '태그 없음');
  await loadSavedProviders();
});
document.querySelector('#closeProviderProfile').addEventListener('click', () => { profilePanel.hidden = true; });
document.querySelector('#providersPage').addEventListener('click', event => {
  const link = event.target.closest('[data-open-provider]');
  if (!link) return;
  event.preventDefault();
  selectProvider(link.dataset.openProvider);
  history.replaceState(null, '', '#dashboard');
  showPage('dashboard');
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
  connectionForm.elements.password.required = !useKey;
  updateSudoFields();
  resetFingerprint();
}));

function updateSudoFields() {
  // The sudo password only matters for non-root logins; hide it otherwise to keep the root flow unchanged.
  const isRoot = usernameInput.value.trim() === 'root' || usernameInput.value.trim() === '';
  document.querySelector('#sudoFields').hidden = isRoot;
}
updateSudoFields();

function openProvidersPage() {
  // Called by showPage: the list is fetched on first open and refreshed on every visit afterwards.
  loadSavedProviders();
  savedProvidersLoaded = true;
}

connectionForm.addEventListener('input', () => { if (pendingPayload) resetFingerprint(); });
connectionForm.addEventListener('submit', async event => {
  event.preventDefault();
  errorBox.hidden = true;
  successBox.hidden = true;
  const values = new FormData(connectionForm);
  const authMethod = values.get('auth_method');
  const keyFile = keyInput.files[0];
  if (authMethod === 'private_key' && !keyFile) return showError('SSH 개인키 파일을 선택하세요.');
  pendingPayload = {
    provider_name: values.get('name'), vip: values.get('vip'), port: Number(values.get('port')),
    username: values.get('username'), auth_method: authMethod,
    private_key: keyFile ? await keyFile.text() : null,
    passphrase: values.get('passphrase') || null, password: values.get('password') || null,
    sudo_password: values.get('sudo_password') || null,
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
    if (!response.ok) throw new Error(apiError(data, '연결에 실패했습니다.'));
    if (data.status === 'confirmation_required') {
      pendingPayload.trusted_fingerprint = data.fingerprint;
      fingerprintText.textContent = data.fingerprint;
      fingerprintBox.hidden = false;
      connectButton.hidden = true;
      return;
    }
    const sudoText = sudoModeText(data.sudo_mode);
    const tools = data.available_tools.length ? data.available_tools.map(escapeHtml).join(', ') : '탐지된 관리 도구 없음';
    successBox.innerHTML = `<b>공급자 등록 완료</b><span>노드: ${escapeHtml(data.controller_hostname)} · 계정: ${escapeHtml(data.ssh_user)}</span><span>${sudoText} · 도구: ${tools}</span><a class="result-link" href="#dashboard" data-open-provider="${escapeHtml(data.provider_id)}">대시보드에서 점검하기 →</a>`;
    successBox.hidden = false;
    fingerprintBox.hidden = true;
    connectButton.hidden = false;
    connectButton.disabled = true;
    connectButton.textContent = '공급자 등록 완료';
    pendingPayload = null;
    await loadSavedProviders();
    await loadProviders(data.provider_id);
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
function showError(message) { errorBox.textContent = message; errorBox.hidden = false; errorBox.scrollIntoView({behavior:'smooth', block:'nearest'}); }
function sudoModeText(mode) {
  if (mode === 'root') return 'root 계정으로 직접 실행';
  if (mode === 'password') return 'sudo 비밀번호 인증 확인됨';
  return 'sudo 인증 필요';
}
function escapeHtml(value) { return escapeText(value); }

async function loadSavedProviders() {
  const list = document.querySelector('#savedProviderList');
  try {
    const response = await fetch('/api/providers', {cache:'no-store'});
    const data = await response.json();
    document.querySelector('#providerCount').textContent = data.providers.length;
    if (!data.providers.length) {
      list.innerHTML = '<div class="empty-provider">등록된 공급자가 없습니다.</div>';
      updateDeleteButton();
      return;
    }
    savedProviders = data.providers;
    list.innerHTML = data.providers.map(provider => {
      const check = provider.latest_check;
      const status = check ? (check.status === 'healthy' ? '정상' : '주의') : '점검 전';
      const statusClass = check ? check.status : 'pending';
      const databaseState = provider.database_credentials_configured ? 'DB 인증 완료' : 'DB 인증 등록';
      let sudoControl;
      if (provider.username === 'root') {
        sudoControl = '<span class="manage-database is-root" title="root 계정으로 등록되어 sudo가 필요하지 않습니다.">root 계정</span>';
      } else {
        const sudoState = provider.sudo_password_configured ? 'sudo 인증 완료' : 'sudo 비밀번호 등록';
        const sudoClass = provider.sudo_password_configured ? 'configured' : 'attention';
        sudoControl = `<button class="manage-database manage-sudo ${sudoClass}" type="button" data-manage-sudo="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}" data-username="${escapeHtml(provider.username)}">${sudoState}</button>`;
      }
      const profile = provider.profile || {};
      const tags = [profile.environment, profile.site, ...(profile.tags || [])].filter(Boolean).map(tag => `<i class="provider-tag">${escapeHtml(tag)}</i>`).join('');
      const diagnosis = provider.last_diagnosis ? `<span class="provider-fact ${provider.last_diagnosis.fail ? 'crit' : (provider.last_diagnosis.warn ? 'warn' : 'ok')}" title="마지막 연결 진단 ${escapeHtml(formatDate(provider.last_diagnosed_at))}">진단 ${provider.last_diagnosis.fail ? `실패 ${provider.last_diagnosis.fail}` : (provider.last_diagnosis.warn ? `주의 ${provider.last_diagnosis.warn}` : '정상')}</span>` : '<span class="provider-fact">진단 전</span>';
      return `<article class="provider-card" data-provider-card="${escapeHtml(provider.id)}">
        <div class="provider-card-main"><label class="provider-check"><input type="checkbox" class="provider-selector" value="${escapeHtml(provider.id)}" aria-label="${escapeHtml(provider.name)} 선택"></label><span class="provider-avatar">OS</span><div class="provider-card-title"><b>${escapeHtml(provider.name)}</b>${tags}<small>${escapeHtml(provider.vip)}:${provider.port} · ${escapeHtml(provider.controller_hostname)} · ${escapeHtml(provider.username)} · 노드 ${provider.node_count ?? 0}대${provider.maintenance_count ? ` (정비 중 ${provider.maintenance_count})` : ''}${profile.contact ? ` · ${escapeHtml(profile.contact)}` : ''}</small></div><em class="provider-status ${statusClass}" title="${check ? `최근 점검 ${escapeHtml(formatDate(check.checked_at))}` : '아직 점검 전'}">${status}</em></div>
        <div class="provider-card-facts"><span class="provider-fact">${check ? `점검 ${escapeHtml(formatDate(check.checked_at))}` : '점검 기록 없음'}</span>${diagnosis}<span class="provider-fact">${provider.ssh_ok_at ? `SSH 확인 ${escapeHtml(formatDate(provider.ssh_ok_at))}` : 'SSH 미확인'}</span>${provider.updated_at ? `<span class="provider-fact">수정 ${escapeHtml(formatDate(provider.updated_at))}</span>` : ''}</div>
        <div class="provider-card-actions"><button type="button" data-open-provider="${escapeHtml(provider.id)}">대시보드</button><button type="button" data-edit-provider="${escapeHtml(provider.id)}">수정</button><button type="button" data-diagnose-provider="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}">연결 진단</button><button type="button" data-manage-nodes="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}">노드 관리</button><button type="button" data-edit-profile="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}">프로필</button><button class="manage-host-keys" type="button" data-manage-host-keys="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}">SSH 키 관리</button><button class="manage-database ${provider.database_credentials_configured ? 'configured' : ''}" type="button" data-manage-database="${escapeHtml(provider.id)}" data-provider-name="${escapeHtml(provider.name)}">${databaseState}</button>${sudoControl}</div>
      </article>`;
    }).join('');
    list.querySelectorAll('.provider-selector').forEach(checkbox => checkbox.addEventListener('change', updateDeleteButton));
    updateDeleteButton();
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

async function openSudoCredentialManager(providerId, providerName, username) {
  managedSudoProviderId = providerId;
  sudoCredentialManager.hidden = false;
  document.querySelector('#sudoCredentialProviderName').textContent = `${providerName} · ${username} 계정의 sudo 인증`;
  sudoCredentialForm.reset();
  sudoCredentialForm.elements.username.value = username;
  const response = await fetch(`/api/providers/${encodeURIComponent(providerId)}/sudo-credentials`, {cache:'no-store'});
  const data = await response.json();
  if (!response.ok) return showError(apiError(data, 'sudo 인증 상태를 불러오지 못했습니다.'));
  const status = document.querySelector('#sudoCredentialStatus');
  if (data.sudo_password_configured) {
    status.textContent = '암호화된 sudo 비밀번호가 등록되어 있습니다. 비밀번호는 화면에 표시되지 않으며, 새로 저장하면 교체됩니다.';
  } else {
    status.textContent = 'sudo 비밀번호가 없어 일일점검이 root 권한을 얻지 못합니다. 비밀번호를 등록하면 저장 전에 VIP의 Controller에서 검증합니다.';
  }
  deleteSudoCredentialButton.hidden = !data.sudo_password_configured;
  sudoCredentialManager.scrollIntoView({behavior:'smooth', block:'start'});
}

async function saveSudoCredential(event) {
  event.preventDefault();
  if (!managedSudoProviderId) return;
  const submitButton = sudoCredentialForm.querySelector('button[type=submit]');
  submitButton.disabled = true;
  submitButton.textContent = 'Controller에서 확인 중...';
  try {
    const response = await fetch(`/api/providers/${encodeURIComponent(managedSudoProviderId)}/sudo-credentials`, {
      method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({sudo_password:sudoCredentialForm.elements.sudo_password.value})
    });
    const data = await response.json();
    if (!response.ok) return showError(apiError(data, 'sudo 비밀번호를 저장하지 못했습니다.'));
    sudoCredentialForm.elements.sudo_password.value = '';
    document.querySelector('#sudoCredentialStatus').textContent = 'sudo 인증을 확인하고 암호화 저장을 완료했습니다. 다음 일일점검부터 root 권한으로 실행됩니다.';
    deleteSudoCredentialButton.hidden = false;
    await loadSavedProviders();
  } finally {
    submitButton.disabled = false;
    submitButton.textContent = '확인 후 암호화 저장';
  }
}

async function deleteSudoCredential() {
  if (!managedSudoProviderId || !window.confirm('등록된 sudo 비밀번호를 삭제할까요? 삭제하면 이 공급자의 일일점검이 root 권한을 얻지 못할 수 있습니다.')) return;
  const response = await fetch(`/api/providers/${encodeURIComponent(managedSudoProviderId)}/sudo-credentials`, {method:'DELETE'});
  const data = await response.json();
  if (!response.ok) return showError(apiError(data, 'sudo 비밀번호를 삭제하지 못했습니다.'));
  sudoCredentialForm.elements.sudo_password.value = '';
  document.querySelector('#sudoCredentialStatus').textContent = 'sudo 비밀번호가 삭제되었습니다.';
  deleteSudoCredentialButton.hidden = true;
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
    await loadProviders();
  } catch (error) {
    showError(error.message);
  } finally {
    updateDeleteButton();
  }
}
