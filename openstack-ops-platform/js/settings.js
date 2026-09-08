// ===== 설정: 점검 제한 시간·보관 정책, 메뉴 표시, 관리자 계정 =====
function formatBytes(bytes) {
  const value = Number(bytes) || 0;
  if (value >= 1073741824) return `${(value / 1073741824).toFixed(2)} GB`;
  if (value >= 1048576) return `${(value / 1048576).toFixed(1)} MB`;
  if (value >= 1024) return `${Math.round(value / 1024)} KB`;
  return `${value} B`;
}
// --- Server-side settings ---------------------------------------------------------------------
const timeoutFields = [
  ['command', '노드 명령 1개', 'INSPECTION_COMMAND_TIMEOUT', '초', 5, 600, '시스템 명령(smartctl, virsh 등)'],
  ['log_scan', '로그 검색 1개 서비스', 'INSPECTION_LOG_TIMEOUT', '초', 10, 600, '전날 로그 파일 검색'],
  ['openstack', 'OpenStack·클러스터 명령 1개', 'INSPECTION_OPENSTACK_TIMEOUT', '초', 10, 600, 'openstack CLI, pcs, rabbitmqctl, mysql'],
  ['node_script', '노드 스크립트 전체', 'INSPECTION_NODE_TIMEOUT', '초', 60, 3600, 'SSH 세션이 멈춘 경우의 최종 보호선'],
  ['controller_script', '활성 Controller 스크립트 전체', 'INSPECTION_CONTROLLER_TIMEOUT', '초', 60, 3600, 'OpenStack 명령 묶음의 최종 보호선'],
  ['node_concurrency', '노드 동시 점검 수', 'INSPECTION_NODE_CONCURRENCY', '대', 1, 64, '동시에 SSH 점검하는 노드 수']
];
const retentionFields = [
  ['keep_latest', '항상 보존하는 최신 결과', 'INSPECTION_RETENTION_KEEP', '건', 1, 1000, '기간·개수와 관계없이 원본 유지'],
  ['raw_age_days', '원본 출력 보관 기간', 'INSPECTION_RAW_RETENTION_DAYS', '일', 0, 3650, '지나면 상태·판정만 남기고 원본 출력 정리 · 0이면 정리하지 않음'],
  ['max_age_days', '결과 보관 기간', 'INSPECTION_RETENTION_DAYS', '일', 0, 3650, '지나면 결과 삭제 · 0이면 삭제하지 않음'],
  ['max_per_provider', '공급자별 최대 보관 수', 'INSPECTION_RETENTION_MAX', '건', 0, 100000, '초과분은 오래된 순으로 삭제 · 0이면 무제한']
];
let currentSettings = null;

function settingSourceText(entry) {
  if (!entry) return '-';
  return entry.source === 'stored' ? `서버 저장값 · ${escapeText(entry.updated_by || '관리자')} · ${escapeText(formatDateTime(entry.updated_at))}` : '환경 변수 기본값 사용 중';
}
function renderSettingSource(id, entry) {
  const badge = document.querySelector(`#${id}`);
  if (!badge) return;
  badge.className = `setting-source ${entry?.source === 'stored' ? 'stored' : 'default'}`;
  badge.innerHTML = settingSourceText(entry);
}
function renderSettingForm(form, fields, entry) {
  const value = entry?.value || {};
  const defaults = entry?.default || {};
  form.innerHTML = fields.map(([key, label, env, unit, min, max, hint]) => `<label><span>${escapeText(label)}</span><div class="settings-input"><input name="${key}" type="number" min="${min}" max="${max}" step="1" value="${value[key] ?? defaults[key] ?? ''}" required><b>${unit}</b></div><small>${escapeText(env)} 기본 ${defaults[key] ?? '-'}${unit} · ${escapeText(hint)}</small></label>`).join('')
    + '<div class="settings-form-actions"><span class="settings-form-note">저장하면 즉시 적용됩니다.</span><button class="primary-button" type="submit">저장</button></div>';
}
function collectSettingForm(form, fields) {
  const value = {};
  fields.forEach(([key]) => { value[key] = Number(form.elements[key].value); });
  return value;
}
function renderTimezoneSetting(entry, timezones) {
  const select = document.querySelector('#timezoneSelect');
  const current = entry?.value?.timezone || 'Asia/Seoul';
  const names = [...new Set([...(timezones || []), current])];
  select.innerHTML = names.map(name => `<option value="${escapeText(name)}" ${name === current ? 'selected' : ''}>${escapeText(name)}</option>`).join('');
  document.querySelector('#timezoneCustom').value = '';
  try {
    document.querySelector('#timezoneNow').textContent = `현재 ${current} 시각 ${new Intl.DateTimeFormat('ko-KR', {timeZone: current, dateStyle:'medium', timeStyle:'short'}).format(new Date())}`;
  } catch (_) { document.querySelector('#timezoneNow').textContent = ''; }
}
function renderRetentionStorage(storage) {
  storage = storage || {providers:[]};
  const rows = storage.providers.map(row => `<tr><td><strong>${escapeText(row.provider_name)}</strong></td><td>${row.count}건</td><td>${row.compacted || 0}건</td><td>${escapeText(formatBytes(row.bytes))}</td><td>${row.oldest ? escapeText(formatDateTime(row.oldest)) : '-'}</td><td>${row.newest ? escapeText(formatDateTime(row.newest)) : '-'}</td></tr>`).join('');
  const last = storage.last_prune;
  document.querySelector('#retentionStorage').innerHTML = `<table><thead><tr><th>공급자</th><th>보관 결과</th><th>원본 정리됨</th><th>결과 용량</th><th>가장 오래된 결과</th><th>최신 결과</th></tr></thead><tbody>${rows || '<tr><td colspan="6">등록된 공급자가 없습니다.</td></tr>'}</tbody></table><p class="retention-last">전체 ${storage.total_count ?? 0}건 · 결과 ${escapeText(formatBytes(storage.total_bytes))} · 데이터베이스 파일 ${escapeText(formatBytes(storage.db_bytes))}${last ? ` · 마지막 정리 ${escapeText(formatDateTime(last.ran_at))} (${escapeText(last.detail || '')})` : ' · 아직 정리 실행 전'}</p>`;
}
function renderSettingsPage(data) {
  currentSettings = data;
  const settings = data.settings || {};
  renderSettingForm(document.querySelector('#timeoutSettingsForm'), timeoutFields, settings['inspection.timeouts']);
  renderSettingSource('timeoutSettingSource', settings['inspection.timeouts']);
  renderSettingForm(document.querySelector('#retentionSettingsForm'), retentionFields, settings['inspection.retention']);
  renderSettingSource('retentionSettingSource', settings['inspection.retention']);
  renderRetentionStorage(data.storage);
  renderTimezoneSetting(settings['inspection.timezone'], data.timezones);
  renderSettingSource('timezoneSettingSource', settings['inspection.timezone']);
  document.querySelector('#auditRetentionDays').value = settings['audit.retention']?.value?.max_age_days ?? 365;
  if (settings['ui.menus']?.source === 'stored') applyServerMenus(settings['ui.menus'].value);
}
async function loadInspectionSettings() {
  loadSession();
  try {
    const response = await fetch('/api/settings', {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '설정을 불러오지 못했습니다.');
    renderSettingsPage(data);
  } catch (error) {
    document.querySelector('#timeoutSettingsForm').innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`;
  }
  loadAuditFacets();
  loadAuditLogs(0);
}
async function saveSetting(key, value, successTitle) {
  const response = await fetch(`/api/settings/${encodeURIComponent(key)}`, {method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify({value})});
  const data = await response.json();
  if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '설정을 저장하지 못했습니다.');
  if (successTitle) showToast(successTitle, '서버에 저장되어 즉시 적용됩니다.');
  return data;
}
async function resetSetting(key, title) {
  if (!window.confirm(`${title}을(를) 환경 변수 기본값으로 되돌릴까요?`)) return;
  try {
    const response = await fetch(`/api/settings/${encodeURIComponent(key)}`, {method:'DELETE'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '초기화하지 못했습니다.');
    showToast(`${title}을(를) 기본값으로 되돌렸습니다.`, '환경 변수 값이 다시 적용됩니다.');
    await loadInspectionSettings();
  } catch (error) { showToast('초기화하지 못했습니다.', error.message); }
}
document.querySelector('#timeoutSettingsForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const button = form.querySelector('button[type="submit"]');
  button.disabled = true;
  try { await saveSetting('inspection.timeouts', collectSettingForm(form, timeoutFields), '점검 제한 시간을 저장했습니다.'); await loadInspectionSettings(); }
  catch (error) { showToast('제한 시간을 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
document.querySelector('#retentionSettingsForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const button = form.querySelector('button[type="submit"]');
  button.disabled = true;
  try { await saveSetting('inspection.retention', collectSettingForm(form, retentionFields), '보관 정책을 저장했습니다.'); await loadInspectionSettings(); }
  catch (error) { showToast('보관 정책을 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
document.querySelector('#timezoneSettingsForm').addEventListener('submit', async event => {
  event.preventDefault();
  const custom = document.querySelector('#timezoneCustom').value.trim();
  const timezone = custom || document.querySelector('#timezoneSelect').value;
  try { await saveSetting('inspection.timezone', {timezone}, `예약 실행 시간대를 ${timezone}(으)로 저장했습니다.`); await loadInspectionSettings(); if (inspectionProviderSelect.value) loadCheckSchedule(inspectionProviderSelect.value); }
  catch (error) { showToast('시간대를 저장하지 못했습니다.', error.message); }
});
document.querySelector('#saveAuditRetention').addEventListener('click', async () => {
  const days = Number(document.querySelector('#auditRetentionDays').value);
  try { await saveSetting('audit.retention', {max_age_days: days}, days ? `감사 로그를 ${days}일 동안 보관합니다.` : '감사 로그를 삭제하지 않고 보관합니다.'); loadAuditFacets(); }
  catch (error) { showToast('보관 기간을 저장하지 못했습니다.', error.message); }
});
document.querySelector('#resetTimeoutSettings').addEventListener('click', () => resetSetting('inspection.timeouts', '점검 제한 시간'));
document.querySelector('#resetRetentionSettings').addEventListener('click', () => resetSetting('inspection.retention', '보관 정책'));
document.querySelector('#resetTimezoneSettings').addEventListener('click', () => resetSetting('inspection.timezone', '예약 실행 시간대'));
document.querySelector('#refreshInspectionSettings').addEventListener('click', loadInspectionSettings);

// --- Audit log ------------------------------------------------------------------------------------
const auditPage = {offset: 0, limit: 50, total: 0};
function auditDateBoundary(value, endOfDay) {
  if (!value) return '';
  const date = new Date(`${value}T${endOfDay ? '23:59:59.999' : '00:00:00'}`);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
}
function auditQuery(offset) {
  const params = new URLSearchParams();
  params.set('limit', String(auditPage.limit));
  params.set('offset', String(offset));
  const action = document.querySelector('#auditActionFilter').value;
  const outcome = document.querySelector('#auditOutcomeFilter').value;
  const actor = document.querySelector('#auditActorFilter').value.trim();
  const search = document.querySelector('#auditSearch').value.trim();
  const since = auditDateBoundary(document.querySelector('#auditSince').value, false);
  const until = auditDateBoundary(document.querySelector('#auditUntil').value, true);
  if (action) params.set('action', action);
  if (outcome) params.set('outcome', outcome);
  if (actor) params.set('actor', actor);
  if (search) params.set('search', search);
  if (since) params.set('since', since);
  if (until) params.set('until', until);
  return params.toString();
}
async function loadAuditFacets() {
  try {
    const response = await fetch('/api/audit-logs/facets?days=30', {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) return;
    const select = document.querySelector('#auditActionFilter');
    const current = select.value;
    const groups = {};
    Object.entries(data.labels || {}).forEach(([action, label]) => { const prefix = action.split('.')[0]; (groups[prefix] = groups[prefix] || []).push([action, label]); });
    const counts = Object.fromEntries((data.actions || []).map(item => [item.action, item.count]));
    const groupLabels = {auth:'로그인·계정', provider:'공급자', check:'일일점검', alert:'알림', work_history:'작업 이력', settings:'설정', retention:'보관 정리', report:'보고서'};
    select.innerHTML = '<option value="">전체 작업</option>' + Object.entries(groups).map(([prefix, items]) => `<optgroup label="${escapeText(groupLabels[prefix] || prefix)}"><option value="${prefix}.">${escapeText(groupLabels[prefix] || prefix)} 전체</option>${items.map(([action, label]) => `<option value="${action}">${escapeText(label)}${counts[action] ? ` (${counts[action]})` : ''}</option>`).join('')}</optgroup>`).join('');
    select.value = current;
    const failures = (data.outcomes || []).find(item => item.outcome === 'failure')?.count || 0;
    document.querySelector('#auditSummary').textContent = `전체 ${data.total ?? 0}건 보관${data.oldest ? ` · 가장 오래된 기록 ${formatDateTime(data.oldest)}` : ''} · 최근 30일 ${(data.actions || []).reduce((sum, item) => sum + item.count, 0)}건, 실패 ${failures}건 · ${data.retention_days ? `${data.retention_days}일 후 자동 삭제` : '자동 삭제 없음'}`;
  } catch (_) { /* facets are decorative; the list still loads */ }
}
async function loadAuditLogs(offset = 0) {
  const list = document.querySelector('#auditLogList');
  try {
    const response = await fetch(`/api/audit-logs?${auditQuery(offset)}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '감사 로그를 불러오지 못했습니다.');
    auditPage.offset = data.offset; auditPage.total = data.total;
    if (!data.items.length) {
      list.innerHTML = '<div class="empty-provider">조건에 맞는 기록이 없습니다.</div>';
    } else {
      list.innerHTML = `<table><thead><tr><th>시각</th><th>작업자</th><th>작업</th><th>대상</th><th>내용</th><th>결과</th><th>접속 주소</th></tr></thead><tbody>${data.items.map(item => `<tr class="${item.outcome === 'failure' ? 'failure' : ''}"><td>${escapeText(formatDateTime(item.created_at))}</td><td><strong>${escapeText(item.actor)}</strong></td><td><span class="audit-action">${escapeText(item.action_label || item.action)}</span><small>${escapeText(item.action)}</small></td><td>${escapeText(item.target_name || item.target_id || '-')}${item.target_type ? `<small>${escapeText(item.target_type)}${item.target_id && item.target_name ? ` · ${escapeText(item.target_id.slice(0, 8))}` : ''}</small>` : ''}</td><td class="audit-detail">${escapeText(item.detail || '-')}</td><td><em class="audit-outcome ${escapeText(item.outcome)}">${item.outcome === 'failure' ? '실패' : '성공'}</em></td><td>${escapeText(item.remote_addr || '-')}</td></tr>`).join('')}</tbody></table>`;
    }
    const from = data.total ? data.offset + 1 : 0;
    const to = Math.min(data.offset + data.items.length, data.total);
    document.querySelector('#auditPageInfo').textContent = `${from}–${to} / ${data.total}건`;
    document.querySelector('#auditPrevPage').disabled = data.offset === 0;
    document.querySelector('#auditNextPage').disabled = to >= data.total;
  } catch (error) { list.innerHTML = `<div class="empty-provider error">${escapeText(error.message)}</div>`; }
}
document.querySelector('#refreshAuditLogs').addEventListener('click', () => { loadAuditFacets(); loadAuditLogs(auditPage.offset); });
document.querySelector('#searchAuditLogs').addEventListener('click', () => loadAuditLogs(0));
document.querySelector('#auditSearch').addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); loadAuditLogs(0); } });
document.querySelector('#auditActorFilter').addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); loadAuditLogs(0); } });
['#auditActionFilter', '#auditOutcomeFilter', '#auditSince', '#auditUntil'].forEach(selector => document.querySelector(selector).addEventListener('change', () => loadAuditLogs(0)));
document.querySelector('#auditPrevPage').addEventListener('click', () => loadAuditLogs(Math.max(0, auditPage.offset - auditPage.limit)));
document.querySelector('#auditNextPage').addEventListener('click', () => loadAuditLogs(auditPage.offset + auditPage.limit));

document.querySelector('#runRetentionPrune').addEventListener('click', async event => {
  const button = event.currentTarget;
  button.disabled = true;
  try {
    const response = await fetch('/api/settings/retention/prune', {method:'POST'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '정리를 실행하지 못했습니다.');
    showToast('점검 이력을 정리했습니다.', `삭제 ${data.deleted}건 · 원본 정리 ${data.compacted}건 · ${formatBytes(data.freed_bytes)} 확보`);
    await loadInspectionSettings();
    if (inspectionProviderSelect.value) loadCheckHistory(inspectionProviderSelect.value);
  } catch (error) { showToast('정리를 실행하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});

document.querySelector('#menuSettingsList').addEventListener('change', event => {
  if (!event.target.matches('input[type="checkbox"]')) return;
  if (event.target.checked) visibleMenus.add(event.target.value); else visibleMenus.delete(event.target.value);
  saveMenuPreferences();
});
document.querySelector('#selectAllMenus').addEventListener('click', () => { visibleMenus = new Set(configurableMenus.map(menu => menu[0])); saveMenuPreferences(); });
document.querySelector('#clearAllMenus').addEventListener('click', () => { visibleMenus.clear(); saveMenuPreferences(); });
applyMenuPreferences();
renderMenuSettings();


// --- Administrator session ---------------------------------------------------------------------
function renderSession(data) {
  const name = data.username || '관리자';
  const avatar = document.querySelector('#operatorAvatar');
  if (avatar) avatar.textContent = name.slice(0, 2).toUpperCase();
  const label = document.querySelector('#operatorName');
  if (label) label.textContent = `${name} · 관리자`;
  const facts = document.querySelector('#accountFacts');
  if (!facts) return;
  facts.innerHTML = [
    ['로그인 계정', name, '단일 관리자 계정 · ADMIN_USERNAME'],
    ['이번 로그인', formatDateTime(data.login_at), `세션 만료 ${formatDateTime(data.expires_at)} · SESSION_TTL_HOURS ${data.session_ttl_hours}시간`],
    ['마지막 비밀번호 변경', formatDateTime(data.password_changed_at), data.must_change_password ? '초기 비밀번호 사용 중 · 변경이 필요합니다' : '아래에서 변경할 수 있습니다'],
    ['활성 로그인 세션', `${data.active_sessions ?? 1}개`, '비밀번호를 변경하면 다른 세션은 모두 해제됩니다']
  ].map(([label, value, hint]) => `<article><small>${escapeText(label)}</small><strong>${escapeText(value)}</strong><em>${escapeText(hint)}</em></article>`).join('');
}
async function loadSession() {
  try {
    const response = await fetch('/api/auth/session', {cache:'no-store'});
    if (!response.ok) return;
    renderSession(await response.json());
  } catch (error) { /* offline: the health poll already reports the connection state */ }
}
async function logout() {
  try { await fetch('/api/auth/logout', {method:'POST'}); } catch (error) { /* cookie is cleared server-side; fall through */ }
  location.replace('/login');
}
document.querySelectorAll('#logoutButton, #logoutSettingsButton').forEach(button => button.addEventListener('click', logout));
document.querySelector('#passwordChangeForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const current = form.elements.current_password.value;
  const next = form.elements.new_password.value;
  if (next !== form.elements.confirm_password.value) { showToast('비밀번호를 변경하지 못했습니다.', '새 비밀번호 확인이 일치하지 않습니다.'); return; }
  const button = form.querySelector('button[type="submit"]');
  button.disabled = true;
  try {
    const response = await fetch('/api/auth/password', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({current_password: current, new_password: next})});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '비밀번호를 변경하지 못했습니다.');
    form.reset();
    showToast('비밀번호를 변경했습니다.', data.revoked_sessions ? `다른 로그인 세션 ${data.revoked_sessions}개를 해제했습니다.` : '이 브라우저의 로그인은 유지됩니다.');
    if (data.session) renderSession(data.session);
  } catch (error) { showToast('비밀번호를 변경하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
