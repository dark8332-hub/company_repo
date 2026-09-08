const loginForm = document.querySelector('#loginForm');
const passwordForm = document.querySelector('#passwordForm');
const loginError = document.querySelector('#loginError');
const passwordError = document.querySelector('#passwordError');
const loginButton = document.querySelector('#loginButton');
const passwordButton = document.querySelector('#passwordButton');

function nextLocation() {
  // Only same-origin paths are honoured so the login page cannot be used as an open redirect.
  const raw = new URLSearchParams(location.search).get('next') || '/';
  const target = raw.startsWith('/') && !raw.startsWith('//') && !raw.startsWith('/login') ? raw : '/';
  return location.hash && !target.includes('#') ? target + location.hash : target;
}

function showError(box, message) {
  box.textContent = message;
  box.hidden = !message;
}

async function postJson(url, body) {
  const response = await fetch(url, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)});
  let data = {};
  try { data = await response.json(); } catch (error) { data = {}; }
  if (!response.ok) throw new Error(data.detail || `요청에 실패했습니다. (HTTP ${response.status})`);
  return data;
}

loginForm.addEventListener('submit', async event => {
  event.preventDefault();
  const username = document.querySelector('#loginUsername').value.trim();
  const password = document.querySelector('#loginPassword').value;
  if (!username || !password) { showError(loginError, '아이디와 비밀번호를 입력하세요.'); return; }
  loginButton.disabled = true;
  showError(loginError, '');
  try {
    const data = await postJson('/api/auth/login', {username, password});
    if (data.must_change_password) {
      document.querySelector('#passwordUsername').value = data.username;
      document.querySelector('#currentPassword').value = password;
      loginForm.hidden = true;
      passwordForm.hidden = false;
      document.querySelector('#newPassword').focus();
      return;
    }
    location.replace(nextLocation());
  } catch (error) {
    showError(loginError, error.message);
    document.querySelector('#loginPassword').select();
  } finally {
    loginButton.disabled = false;
  }
});

passwordForm.addEventListener('submit', async event => {
  event.preventDefault();
  const current = document.querySelector('#currentPassword').value;
  const next = document.querySelector('#newPassword').value;
  const confirm = document.querySelector('#confirmPassword').value;
  if (next !== confirm) { showError(passwordError, '새 비밀번호 확인이 일치하지 않습니다.'); return; }
  passwordButton.disabled = true;
  showError(passwordError, '');
  try {
    await postJson('/api/auth/password', {current_password: current, new_password: next});
    location.replace(nextLocation());
  } catch (error) {
    showError(passwordError, error.message);
  } finally {
    passwordButton.disabled = false;
  }
});
