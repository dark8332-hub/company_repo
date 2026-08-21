const form = document.querySelector('#connectionForm');
const keyInput = document.querySelector('#privateKey');
const connectButton = document.querySelector('#connectButton');
const confirmButton = document.querySelector('#confirmFingerprint');
const errorBox = document.querySelector('#formError');
const successBox = document.querySelector('#formSuccess');
const fingerprintBox = document.querySelector('#fingerprintBox');
const fingerprintText = document.querySelector('#fingerprint');
const deleteSelectedButton = document.querySelector('#deleteSelected');
let pendingPayload = null;

document.querySelector('#menuButton').addEventListener('click', () => document.querySelector('#sidebar').classList.toggle('open'));
loadSavedProviders();
deleteSelectedButton.addEventListener('click', deleteSelectedProviders);
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
      return `<article><label class="provider-check"><input type="checkbox" class="provider-selector" value="${escapeHtml(provider.id)}" aria-label="${escapeHtml(provider.name)} 선택"></label><span class="provider-avatar">OS</span><div><b>${escapeHtml(provider.name)}</b><small>${escapeHtml(provider.vip)}:${provider.port} · ${escapeHtml(provider.controller_hostname)}</small></div><em class="provider-status ${statusClass}">${status}</em><a href="/?provider=${encodeURIComponent(provider.id)}">대시보드</a></article>`;
    }).join('');
    list.querySelectorAll('.provider-selector').forEach(checkbox => checkbox.addEventListener('change', updateDeleteButton));
  } catch (_) {
    list.innerHTML = '<div class="empty-provider error">공급자 목록을 불러오지 못했습니다.</div>';
  }
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
