// ===== 이슈 노트: 목록·요약, 편집기, 상세(본문·코드 스니펫·타임라인), 알림·작업 이력 연결 =====
const issueMeta = {statuses:[], severities:[], categories:[], languages:['text'], transitions:{}};
const issueStatusLabels = {open:'열림', in_progress:'진행 중', on_hold:'보류', resolved:'해결'};
const issueSeverityLabels = {critical:'치명', high:'높음', medium:'보통', low:'낮음'};
const issueCategoryLabels = {incident:'장애', bug:'결함', config:'설정', performance:'성능', capacity:'용량', question:'확인 요청', improvement:'개선', other:'기타'};
const issueEventLabels = {created:'등록', edited:'수정', status:'상태', comment:'코멘트', snippet:'코드'};
const issueTransitionLabels = {open:'다시 열기', in_progress:'진행 시작', on_hold:'보류', resolved:'해결 처리'};
const issueLanguageLabels = {text:'텍스트', bash:'Bash / Shell', python:'Python', yaml:'YAML', json:'JSON', ini:'INI / conf', log:'로그', sql:'SQL', diff:'diff', javascript:'JavaScript', html:'HTML', css:'CSS', dockerfile:'Dockerfile'};
let currentIssues = [];
let currentIssue = null;
let issueScope = '';
let issueTagScope = '';
let issueMetaLoaded = false;

function issueShortDate(value) {
  return value ? new Intl.DateTimeFormat('ko-KR', {month:'2-digit', day:'2-digit', hour:'2-digit', minute:'2-digit', hour12:false}).format(new Date(value)) : '-';
}

// --- Code highlighting -----------------------------------------------------------------------
// No external library (closed-network sites): a small tokenizer per language. Text is escaped token by token,
// so the only HTML that reaches innerHTML is the spans this function writes.
const issueHighlightRules = {
  bash: [['comment', /#[^\n]*/], ['string', /"(?:[^"\\]|\\.)*"|'[^']*'/], ['keyword', /\b(?:if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|exit|export|local|sudo|systemctl|journalctl|openstack|nova|neutron|cinder|virsh|docker|kubectl|grep|awk|sed|cat|tail|head|ls|cd|echo|set|source)\b/], ['variable', /\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|\$[0-9@#?*]/], ['number', /\b\d+(?:\.\d+)?\b/], ['operator', /\|\||&&|[|;&><]/]],
  python: [['comment', /#[^\n]*/], ['string', /"""[\s\S]*?"""|'''[\s\S]*?'''|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/], ['keyword', /\b(?:def|class|return|if|elif|else|for|while|in|not|and|or|is|None|True|False|import|from|as|try|except|finally|raise|with|yield|lambda|pass|break|continue|async|await|global|del)\b/], ['builtin', /\b(?:print|len|range|dict|list|set|str|int|float|open|isinstance|self)\b/], ['number', /\b\d+(?:\.\d+)?\b/], ['decorator', /@[A-Za-z_][\w.]*/]],
  yaml: [['comment', /#[^\n]*/], ['key', /^[ \t-]*[A-Za-z0-9_.\-"']+(?=\s*:(?:\s|$))/m], ['string', /"(?:[^"\\]|\\.)*"|'[^']*'/], ['keyword', /\b(?:true|false|null|yes|no|on|off)\b/], ['number', /\b\d+(?:\.\d+)?\b/]],
  json: [['key', /"(?:[^"\\]|\\.)*"(?=\s*:)/], ['string', /"(?:[^"\\]|\\.)*"/], ['keyword', /\b(?:true|false|null)\b/], ['number', /-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/]],
  ini: [['comment', /[#;][^\n]*/], ['section', /^\s*\[[^\]\n]+\]/m], ['key', /^[ \t]*[A-Za-z0-9_.\-]+(?=\s*=)/m], ['number', /\b\d+(?:\.\d+)?\b/]],
  log: [['error', /\b(?:ERROR|CRITICAL|FATAL|Traceback|Exception|failed|FAILED|denied|Denied|refused|timeout|Timeout)\b/], ['warning', /\b(?:WARNING|WARN|deprecated|retry|Retry)\b/], ['info', /\b(?:INFO|DEBUG|NOTICE)\b/], ['timestamp', /\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?\b|\b[A-Z][a-z]{2} +\d{1,2} \d{2}:\d{2}:\d{2}\b/], ['ip', /\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b/], ['uuid', /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/]],
  sql: [['comment', /--[^\n]*|\/\*[\s\S]*?\*\//], ['string', /'(?:[^']|'')*'/], ['keyword', /\b(?:SELECT|FROM|WHERE|AND|OR|NOT|IN|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|INDEX|DROP|ALTER|JOIN|LEFT|RIGHT|INNER|ON|GROUP|BY|ORDER|LIMIT|OFFSET|AS|COUNT|SUM|MAX|MIN|DISTINCT|NULL|IS|LIKE|BETWEEN|SHOW|STATUS|VARIABLES|PRIMARY|KEY)\b/i], ['number', /\b\d+(?:\.\d+)?\b/]],
  diff: [['meta', /^(?:diff|index|---|\+\+\+|@@)[^\n]*/m], ['inserted', /^\+[^\n]*/m], ['deleted', /^-[^\n]*/m]],
  javascript: [['comment', /\/\/[^\n]*|\/\*[\s\S]*?\*\//], ['string', /`(?:[^`\\]|\\.)*`|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/], ['keyword', /\b(?:const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|new|class|extends|this|async|await|try|catch|finally|throw|import|export|default|typeof|instanceof|in|of|null|undefined|true|false)\b/], ['number', /\b\d+(?:\.\d+)?\b/]],
  html: [['comment', /<!--[\s\S]*?-->/], ['tag', /<\/?[A-Za-z][A-Za-z0-9-]*|\/?>/], ['attr', /\b[A-Za-z-]+(?==)/], ['string', /"[^"]*"|'[^']*'/]],
  css: [['comment', /\/\*[\s\S]*?\*\//], ['selector', /^[^{}\n]+(?=\s*\{)/m], ['key', /[A-Za-z-]+(?=\s*:)/], ['string', /"[^"]*"|'[^']*'/], ['number', /#[0-9a-fA-F]{3,8}\b|\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|s|ms)?\b/]],
  dockerfile: [['comment', /#[^\n]*/], ['keyword', /^\s*(?:FROM|RUN|COPY|ADD|CMD|ENTRYPOINT|ENV|ARG|EXPOSE|WORKDIR|USER|VOLUME|LABEL|HEALTHCHECK|SHELL|STOPSIGNAL)\b/m], ['string', /"(?:[^"\\]|\\.)*"|'[^']*'/]]
};
function highlightCode(code, language) {
  const rules = issueHighlightRules[language];
  if (!rules) return escapeText(code);
  const source = rules.map(([name, pattern]) => `(${pattern.source})`).join('|');
  const flags = 'g' + (rules.some(([, pattern]) => pattern.flags.includes('m')) ? 'm' : '') + (rules.some(([, pattern]) => pattern.flags.includes('i')) ? 'i' : '');
  const matcher = new RegExp(source, flags);
  let output = '', last = 0, match;
  while ((match = matcher.exec(code)) !== null) {
    if (match.index === last && match[0] === '') { matcher.lastIndex += 1; continue; }
    output += escapeText(code.slice(last, match.index));
    const index = match.slice(1).findIndex(group => group !== undefined);
    output += `<span class="tok-${rules[index][0]}">${escapeText(match[0])}</span>`;
    last = match.index + match[0].length;
    if (!match[0]) matcher.lastIndex += 1;
  }
  return output + escapeText(code.slice(last));
}
function renderCodeBlock(code, language, options = {}) {
  const lines = code.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n');
  const body = highlightCode(lines.join('\n'), language).split('\n').map(line => `<span class="code-line">${line || ' '}</span>`).join('\n');
  return `<div class="code-block${options.compact ? ' compact' : ''}" data-language="${escapeText(language)}"><div class="code-block-bar"><span>${escapeText(issueLanguageLabels[language] || language)}${options.label ? ` · ${escapeText(options.label)}` : ''}</span><small>${lines.length}줄</small><button type="button" data-copy-code title="클립보드에 복사">복사</button></div><pre class="code-body"><code>${body}</code></pre></div>`;
}
async function copyCodeFrom(button) {
  const code = button.closest('.code-block')?.querySelector('code');
  if (!code) return;
  try { await navigator.clipboard.writeText(code.textContent); button.textContent = '복사됨'; setTimeout(() => { button.textContent = '복사'; }, 1500); }
  catch (_) { showToast('복사하지 못했습니다.', '브라우저가 클립보드 접근을 막았습니다. 직접 드래그해 복사하세요.'); }
}
document.addEventListener('click', event => { const button = event.target.closest('[data-copy-code]'); if (button) copyCodeFrom(button); });

// --- Meta, summary, menu badge ------------------------------------------------------------------
async function loadIssueMeta() {
  if (issueMetaLoaded) return;
  try {
    const response = await fetch('/api/issues/meta', {cache:'no-store'});
    if (!response.ok) return;
    Object.assign(issueMeta, await response.json());
    issueMetaLoaded = true;
    const option = (key, label) => `<option value="${key}">${escapeText(label)}</option>`;
    document.querySelector('#issueStatus').innerHTML = issueMeta.statuses.map(item => option(item.key, item.label)).join('');
    document.querySelector('#issueSeverity').innerHTML = issueMeta.severities.map(item => option(item.key, item.label)).join('');
    document.querySelector('#issueCategory').innerHTML = issueMeta.categories.map(item => option(item.key, item.label)).join('');
    document.querySelector('#issueStatusFilter').innerHTML = '<option value="">전체 상태</option>' + issueMeta.statuses.map(item => option(item.key, item.label)).join('');
    document.querySelector('#issueSeverityFilter').innerHTML = '<option value="">전체 심각도</option>' + issueMeta.severities.map(item => option(item.key, item.label)).join('');
    document.querySelector('#issueCategoryFilter').innerHTML = '<option value="">전체 분류</option>' + issueMeta.categories.map(item => option(item.key, item.label)).join('');
    document.querySelector('#issueSnippetLanguage').innerHTML = issueMeta.languages.map(key => option(key, issueLanguageLabels[key] || key)).join('');
    document.querySelector('#issueSeverity').value = 'medium';
  } catch (_) { /* the page still works with the built-in labels */ }
}

function renderIssueSummary(summary) {
  const set = (id, value) => { const node = document.querySelector(id); if (node) node.textContent = value; };
  set('#issueActiveCount', summary.active || 0); set('#issueCriticalCount', summary.by_severity?.critical || 0); set('#issueHighCount', summary.by_severity?.high || 0);
  set('#issueOnHoldCount', summary.by_status?.on_hold || 0); set('#issueResolvedCount', summary.by_status?.resolved || 0);
  document.querySelectorAll('[data-issue-scope]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.issueScope === issueScope)));
  const badge = document.querySelector('#issueMenuCount');
  if (badge) { badge.textContent = summary.active || 0; badge.hidden = !(summary.active > 0); }
  const cloud = document.querySelector('#issueTagCloud');
  const tags = summary.tags || [];
  cloud.hidden = !tags.length;
  cloud.innerHTML = tags.map(item => `<button type="button" data-issue-tag="${escapeText(item.tag)}" class="${issueTagScope === item.tag ? 'active' : ''}">#${escapeText(item.tag)} <em>${item.count}</em></button>`).join('');
}
async function loadIssueSummary() {
  try {
    const response = await fetch('/api/issues/summary', {cache:'no-store'});
    if (response.ok) renderIssueSummary(await response.json());
  } catch (_) { /* summary is decorative */ }
}
async function loadIssueMenuCount() {
  try {
    const response = await fetch('/api/issues/summary', {cache:'no-store'});
    if (!response.ok) return;
    const summary = await response.json();
    const badge = document.querySelector('#issueMenuCount');
    if (badge) { badge.textContent = summary.active || 0; badge.hidden = !(summary.active > 0); }
  } catch (_) { /* badge only */ }
}

// --- List ---------------------------------------------------------------------------------------
function issueCard(item) {
  const tags = (item.tags || []).map(tag => `<button type="button" class="issue-tag" data-issue-tag="${escapeText(tag)}">#${escapeText(tag)}</button>`).join('');
  return `<article class="issue-card status-${item.status} severity-${item.severity}" data-issue-id="${item.id}">
    <header><div class="issue-card-head"><span class="issue-key">${escapeText(item.key)}</span><span class="issue-severity ${item.severity}">${issueSeverityLabels[item.severity] || escapeText(item.severity)}</span><span class="history-status issue-status ${item.status}">${issueStatusLabels[item.status] || escapeText(item.status)}</span><span class="issue-category">${issueCategoryLabels[item.category] || escapeText(item.category)}</span></div>
    <h2><button type="button" data-open-issue="${item.id}">${escapeText(item.title)}</button></h2>
    <small>${escapeText(item.provider_name || '공통')} · ${escapeText(item.target || '대상 미지정')} · 담당 ${escapeText(item.assignee || '-')} · 등록 ${escapeText(item.reporter || '-')}</small></header>
    <div class="issue-card-side"><time>수정 ${escapeText(issueShortDate(item.updated_at))}</time><span class="issue-counts">${item.snippet_count ? `<em title="코드 스니펫">⌘ ${item.snippet_count}</em>` : ''}${item.comment_count ? `<em title="코멘트">✉ ${item.comment_count}</em>` : ''}</span></div>
    ${tags ? `<div class="issue-tags">${tags}</div>` : ''}
  </article>`;
}
function renderIssueList() {
  const list = document.querySelector('#issueList');
  list.innerHTML = currentIssues.length ? currentIssues.map(issueCard).join('') : '<div class="empty-provider">조건에 맞는 이슈가 없습니다.</div>';
  const filter = document.querySelector('#issueTagFilter');
  filter.hidden = !issueTagScope;
  filter.innerHTML = issueTagScope ? `태그 #${escapeText(issueTagScope)} <button type="button" id="clearIssueTag">해제</button>` : '';
}
function issueListParams() {
  const params = new URLSearchParams();
  [['provider_id', '#issueProviderFilter'], ['status', '#issueStatusFilter'], ['severity', '#issueSeverityFilter'], ['category', '#issueCategoryFilter'], ['q', '#issueSearch']].forEach(([key, selector]) => {
    const value = document.querySelector(selector).value.trim(); if (value) params.set(key, value);
  });
  if (issueTagScope) params.set('tag', issueTagScope);
  return params;
}
async function loadIssues() {
  await loadIssueMeta();
  const list = document.querySelector('#issueList');
  list.innerHTML = '<div class="empty-provider">이슈를 불러오는 중입니다.</div>';
  try {
    const response = await fetch(`/api/issues?${issueListParams()}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '이슈 목록을 불러오지 못했습니다.');
    currentIssues = data.issues || [];
    renderIssueList();
  } catch (error) { list.innerHTML = `<div class="empty-provider">${escapeText(error.message)}</div>`; }
  loadIssueSummary();
  const requested = new URLSearchParams(location.search).get('issue');
  if (requested && !currentIssue) { history.replaceState(null, '', location.pathname + location.hash); openIssue(requested); }
}
function applyIssueScope(scope) {
  issueScope = issueScope === scope ? '' : scope;
  const status = document.querySelector('#issueStatusFilter'), severity = document.querySelector('#issueSeverityFilter');
  status.value = ''; severity.value = '';
  if (issueScope === 'critical' || issueScope === 'high') severity.value = issueScope;
  else if (issueScope === 'on_hold' || issueScope === 'resolved') status.value = issueScope;
  loadIssues();
}

// --- Editor -------------------------------------------------------------------------------------
function issueFormValue(id) { return document.querySelector(`#issue${id}`).value; }
function renderIssueLinkRow(links) {
  const row = document.querySelector('#issueLinkRow');
  const parts = [];
  if (links.alert_id) parts.push(`<span>알림 연결 <code>${escapeText(links.alert_title || links.alert_id)}</code></span>`);
  if (links.work_history_id) parts.push(`<span>작업 이력 연결 <code>${escapeText(links.work_history_title || links.work_history_id)}</code></span>`);
  if (links.check_id) parts.push(`<span>점검 결과 연결 <code>${escapeText(links.check_id)}</code></span>`);
  row.hidden = !parts.length;
  row.innerHTML = parts.length ? `<b>연결</b>${parts.join('')}<button type="button" id="clearIssueLinks">연결 해제</button>` : '';
}
async function openIssueEditor(item = null, prefill = {}) {
  await loadIssueMeta();
  const form = document.querySelector('#issueForm');
  form.reset();
  const values = item ? {Id:item.id, Title:item.title, Provider:item.provider_id || '', Category:item.category, Severity:item.severity, Status:item.status, Assignee:item.assignee || '', Target:item.target || '', Tags:(item.tags || []).join(', '), Body:item.body || '', Resolution:item.resolution || '', AlertId:item.alert_id || '', WorkHistoryId:item.work_history_id || '', CheckId:item.check_id || ''}
    : {Id:'', Title:prefill.title || '', Provider:prefill.provider_id || document.querySelector('#issueProviderFilter').value || '', Category:prefill.category || 'other', Severity:prefill.severity || 'medium', Status:'open', Assignee:'', Target:prefill.target || '', Tags:(prefill.tags || []).join(', '), Body:prefill.body || '', Resolution:'', AlertId:prefill.alert_id || '', WorkHistoryId:prefill.work_history_id || '', CheckId:prefill.check_id || ''};
  Object.entries(values).forEach(([key, value]) => { const node = document.querySelector(`#issue${key}`); if (node) node.value = value; });
  renderIssueLinkRow({alert_id:values.AlertId, alert_title:item?.alert_title || prefill.alert_title, work_history_id:values.WorkHistoryId, work_history_title:item?.work_history_title || prefill.work_history_title, check_id:values.CheckId});
  document.querySelector('#issueFormTitle').textContent = item ? `${item.key} 수정` : '이슈 등록';
  document.querySelector('#issueDetail').hidden = true;
  const editor = document.querySelector('#issueEditor');
  editor.hidden = false;
  editor.scrollIntoView({behavior:'smooth', block:'start'});
  document.querySelector('#issueTitle').focus();
}
// Entry point for the 알림/작업 이력 screens: switch to this page with the link and a scaffolded body.
function openIssueEditorFrom(prefill) {
  history.replaceState(null, '', '#issues');
  showPage('issues');
  openIssueEditor(null, prefill);
}
function issuePayload() {
  return {provider_id:issueFormValue('Provider') || null, title:issueFormValue('Title'), status:issueFormValue('Status'), severity:issueFormValue('Severity'), category:issueFormValue('Category'),
    tags:issueFormValue('Tags').split(/[,\n]/).map(tag => tag.trim()).filter(Boolean), body:issueFormValue('Body'), assignee:issueFormValue('Assignee'), target:issueFormValue('Target'), resolution:issueFormValue('Resolution'),
    alert_id:issueFormValue('AlertId') || null, work_history_id:issueFormValue('WorkHistoryId') || null, check_id:issueFormValue('CheckId') || null};
}
document.querySelector('#issueForm').addEventListener('submit', async event => {
  event.preventDefault();
  const id = issueFormValue('Id');
  const button = event.submitter || event.target.querySelector('button[type="submit"]');
  button.disabled = true;
  try {
    const response = await fetch(id ? `/api/issues/${id}` : '/api/issues', {method:id ? 'PUT' : 'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(issuePayload())});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : (data.detail?.[0]?.msg || '저장하지 못했습니다.'));
    showToast(id ? '이슈를 수정했습니다.' : '이슈를 등록했습니다.', `${data.key} ${data.title}`);
    document.querySelector('#issueEditor').hidden = true;
    await loadIssues();
    renderIssueDetail(data);
  } catch (error) { showToast('이슈를 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});
document.querySelector('#issueLinkRow').addEventListener('click', event => {
  if (!event.target.closest('#clearIssueLinks')) return;
  ['AlertId', 'WorkHistoryId', 'CheckId'].forEach(key => { document.querySelector(`#issue${key}`).value = ''; });
  renderIssueLinkRow({});
});

// --- Detail -------------------------------------------------------------------------------------
function renderIssueLinks(detail) {
  const box = document.querySelector('#issueDetailLinks');
  const links = detail.links || {};
  const parts = [];
  if (detail.alert_id) parts.push(links.alert ? `<a href="#alerts" data-page="alerts" data-issue-link="alert" data-link-id="${escapeText(links.alert.id)}"><em>알림</em>${escapeText(links.alert.title)} <small>${escapeText(alertStatusLabels?.[links.alert.status] || links.alert.status)}</small></a>` : '<span><em>알림</em>삭제된 알림</span>');
  if (detail.work_history_id) parts.push(links.work_history ? `<a href="#history" data-page="history" data-issue-link="history" data-link-id="${escapeText(links.work_history.id)}"><em>작업 이력</em>${escapeText(links.work_history.title)} <small>${escapeText(workStatusLabels?.[links.work_history.status] || links.work_history.status)}</small></a>` : '<span><em>작업 이력</em>삭제된 작업</span>');
  if (detail.check_id) parts.push(links.check ? `<a href="#daily-inspection" data-page="daily-inspection" data-issue-link="check" data-link-id="${escapeText(links.check.id)}" data-provider-id="${escapeText(detail.provider_id || '')}"><em>점검 결과</em>${escapeText(issueShortDate(links.check.created_at))} <small>${escapeText(links.check.status || '-')}</small></a>` : '<span><em>점검 결과</em>정리된 점검</span>');
  box.hidden = !parts.length;
  box.innerHTML = parts.join('');
}
function renderIssueSnippets(snippets) {
  const list = document.querySelector('#issueSnippetList');
  document.querySelector('#issueSnippetMeta').textContent = snippets.length ? `${snippets.length}개` : '파일 경로와 언어를 붙여 코드를 보관합니다';
  list.innerHTML = snippets.length ? snippets.map(snippet => `<section class="issue-snippet" data-snippet-id="${snippet.id}"><header><div><b>${escapeText(snippet.title || snippet.path || issueLanguageLabels[snippet.language] || snippet.language)}</b>${snippet.path ? `<code>${escapeText(snippet.path)}</code>` : ''}<small>${escapeText(snippet.created_by || '-')} · ${escapeText(issueShortDate(snippet.updated_at))}</small></div><span><button type="button" data-snippet-action="edit">수정</button><button type="button" class="danger" data-snippet-action="delete">삭제</button></span></header>${renderCodeBlock(snippet.code, snippet.language)}</section>`).join('') : '<div class="empty-provider">등록된 코드가 없습니다. 「코드 추가」로 설정 파일, 명령, 로그 발췌를 붙이세요.</div>';
}
function renderIssueTimeline(events) {
  const box = document.querySelector('#issueTimeline');
  document.querySelector('#issueTimelineMeta').textContent = events.length ? `${events.length}건` : '등록·상태 변경·코멘트 기록';
  box.innerHTML = events.length ? events.map(event => `<div class="timeline-item ${escapeText(event.kind)}"><em>${escapeText(issueEventLabels[event.kind] || event.kind)}</em><div><p>${escapeText(event.text || '-')}</p><small>${escapeText(issueShortDate(event.created_at))} · ${escapeText(event.actor || 'system')}</small></div></div>`).join('') : '<div class="empty-provider">기록이 없습니다.</div>';
}
function renderIssueDetail(detail) {
  currentIssue = detail;
  document.querySelector('#issueDetailKey').textContent = detail.key;
  document.querySelector('#issueDetailTitle').textContent = detail.title;
  document.querySelector('#issueDetailMeta').innerHTML = `<span class="issue-severity ${detail.severity}">${issueSeverityLabels[detail.severity] || escapeText(detail.severity)}</span><span class="history-status issue-status ${detail.status}">${issueStatusLabels[detail.status] || escapeText(detail.status)}</span><span class="issue-category">${issueCategoryLabels[detail.category] || escapeText(detail.category)}</span> ${escapeText(detail.provider_name || '공통')} · ${escapeText(detail.target || '대상 미지정')} · 담당 ${escapeText(detail.assignee || '-')} · 등록 ${escapeText(detail.reporter || '-')} ${escapeText(issueShortDate(detail.created_at))}${detail.resolved_at ? ` · 해결 ${escapeText(issueShortDate(detail.resolved_at))}` : ''}`;
  document.querySelector('#issueDetailTags').innerHTML = (detail.tags || []).map(tag => `<button type="button" class="issue-tag" data-issue-tag="${escapeText(tag)}">#${escapeText(tag)}</button>`).join('');
  document.querySelector('#issueDetailTransitions').innerHTML = (issueMeta.transitions[detail.status] || []).map(status => `<button type="button" data-issue-transition="${status}" class="transition ${status}">${issueTransitionLabels[status] || issueStatusLabels[status] || status}</button>`).join('');
  document.querySelector('#issueDetailBody').innerHTML = detail.body ? renderMarkdown(detail.body) : '<div class="empty-provider">내용이 없습니다.</div>';
  document.querySelector('#issueBodyMeta').textContent = `수정 ${issueShortDate(detail.updated_at)}`;
  document.querySelector('#issueResolutionSection').hidden = !detail.resolution;
  document.querySelector('#issueDetailResolution').innerHTML = detail.resolution ? renderMarkdown(detail.resolution) : '';
  renderIssueLinks(detail);
  renderIssueSnippets(detail.snippets || []);
  renderIssueTimeline(detail.events || []);
  document.querySelector('#issueSnippetForm').hidden = true;
  document.querySelector('#issueCommentText').value = '';
  document.querySelector('#issueEditor').hidden = true;
  const panel = document.querySelector('#issueDetail');
  panel.hidden = false;
  panel.scrollIntoView({behavior:'smooth', block:'start'});
}
async function openIssue(id) {
  try {
    const response = await fetch(`/api/issues/${encodeURIComponent(id)}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || '이슈를 불러오지 못했습니다.');
    renderIssueDetail(data);
  } catch (error) { showToast('이슈를 불러오지 못했습니다.', error.message); }
}
async function refreshCurrentIssue() {
  if (currentIssue) await openIssue(currentIssue.id);
  loadIssues();
}
async function transitionCurrentIssue(status) {
  if (!currentIssue) return;
  let note = '';
  if (status === 'resolved') {
    note = (window.prompt(`${currentIssue.key} ${currentIssue.title}\n해결 처리합니다. 근본 원인과 최종 조치를 입력하세요.`, currentIssue.resolution || '') || '').trim();
    if (!note) return;
  }
  try {
    const response = await fetch(`/api/issues/${currentIssue.id}/transition`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({status, note})});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : '상태를 바꾸지 못했습니다.');
    showToast('이슈 상태를 바꿨습니다.', `${data.key} → ${issueStatusLabels[status] || status}`);
    renderIssueDetail(data);
    loadIssues();
  } catch (error) { showToast('상태를 바꾸지 못했습니다.', error.message); }
}
async function deleteCurrentIssue() {
  if (!currentIssue || !window.confirm(`${currentIssue.key} ${currentIssue.title}\n이 이슈와 코드 스니펫, 타임라인을 모두 삭제할까요?`)) return;
  try {
    const response = await fetch(`/api/issues/${currentIssue.id}`, {method:'DELETE'});
    if (!response.ok) throw new Error((await response.json()).detail || '삭제하지 못했습니다.');
    showToast('이슈를 삭제했습니다.', currentIssue.key);
    currentIssue = null;
    document.querySelector('#issueDetail').hidden = true;
    loadIssues();
  } catch (error) { showToast('이슈를 삭제하지 못했습니다.', error.message); }
}
function exportCurrentIssue() {
  if (!currentIssue) return;
  const link = document.createElement('a');
  link.href = `/api/issues/${currentIssue.id}/export`;
  link.download = `${currentIssue.key}.md`;
  document.body.appendChild(link); link.click(); link.remove();
}

// --- Snippets and comments ------------------------------------------------------------------------
function openSnippetForm(snippet = null) {
  const form = document.querySelector('#issueSnippetForm');
  form.reset();
  document.querySelector('#issueSnippetId').value = snippet ? snippet.id : '';
  document.querySelector('#issueSnippetTitle').value = snippet ? snippet.title || '' : '';
  document.querySelector('#issueSnippetPath').value = snippet ? snippet.path || '' : '';
  document.querySelector('#issueSnippetLanguage').value = snippet ? snippet.language : 'bash';
  document.querySelector('#issueSnippetCode').value = snippet ? snippet.code : '';
  form.hidden = false;
  document.querySelector('#issueSnippetCode').focus();
}
document.querySelector('#issueSnippetForm').addEventListener('submit', async event => {
  event.preventDefault();
  if (!currentIssue) return;
  const snippetId = document.querySelector('#issueSnippetId').value;
  const payload = {title:document.querySelector('#issueSnippetTitle').value, path:document.querySelector('#issueSnippetPath').value, language:document.querySelector('#issueSnippetLanguage').value, code:document.querySelector('#issueSnippetCode').value};
  if (!payload.code.trim()) return showToast('코드를 입력하세요.', '빈 스니펫은 저장하지 않습니다.');
  try {
    const response = await fetch(snippetId ? `/api/issues/${currentIssue.id}/snippets/${snippetId}` : `/api/issues/${currentIssue.id}/snippets`, {method:snippetId ? 'PUT' : 'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : (data.detail?.[0]?.msg || '저장하지 못했습니다.'));
    showToast(snippetId ? '코드를 수정했습니다.' : '코드를 추가했습니다.', payload.path || payload.title || issueLanguageLabels[payload.language] || payload.language);
    await refreshCurrentIssue();
  } catch (error) { showToast('코드를 저장하지 못했습니다.', error.message); }
});
document.querySelector('#issueSnippetList').addEventListener('click', async event => {
  const button = event.target.closest('[data-snippet-action]'); if (!button || !currentIssue) return;
  const section = button.closest('[data-snippet-id]');
  const snippet = (currentIssue.snippets || []).find(item => item.id === section.dataset.snippetId);
  if (!snippet) return;
  if (button.dataset.snippetAction === 'edit') { openSnippetForm(snippet); document.querySelector('#issueSnippetForm').scrollIntoView({behavior:'smooth', block:'center'}); return; }
  if (!window.confirm(`코드 「${snippet.title || snippet.path || snippet.language}」를 삭제할까요?`)) return;
  try {
    const response = await fetch(`/api/issues/${currentIssue.id}/snippets/${snippet.id}`, {method:'DELETE'});
    if (!response.ok) throw new Error((await response.json()).detail || '삭제하지 못했습니다.');
    await refreshCurrentIssue();
  } catch (error) { showToast('코드를 삭제하지 못했습니다.', error.message); }
});
document.querySelector('#issueCommentForm').addEventListener('submit', async event => {
  event.preventDefault();
  if (!currentIssue) return;
  const input = document.querySelector('#issueCommentText');
  if (!input.value.trim()) return;
  const button = event.target.querySelector('button'); button.disabled = true;
  try {
    const response = await fetch(`/api/issues/${currentIssue.id}/comments`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({text:input.value.trim()})});
    if (!response.ok) throw new Error((await response.json()).detail || '저장하지 못했습니다.');
    input.value = '';
    await refreshCurrentIssue();
  } catch (error) { showToast('코멘트를 저장하지 못했습니다.', error.message); }
  finally { button.disabled = false; }
});

// --- Page wiring ----------------------------------------------------------------------------------
document.querySelector('#newIssue').addEventListener('click', () => openIssueEditor(null, {}));
document.querySelector('#closeIssueEditor').addEventListener('click', () => { document.querySelector('#issueEditor').hidden = true; });
document.querySelector('#closeIssueDetail').addEventListener('click', () => { document.querySelector('#issueDetail').hidden = true; currentIssue = null; });
document.querySelector('#editIssue').addEventListener('click', () => { if (currentIssue) openIssueEditor(currentIssue); });
document.querySelector('#deleteIssue').addEventListener('click', deleteCurrentIssue);
document.querySelector('#exportIssue').addEventListener('click', exportCurrentIssue);
document.querySelector('#addIssueSnippet').addEventListener('click', () => openSnippetForm());
document.querySelector('#cancelIssueSnippet').addEventListener('click', () => { document.querySelector('#issueSnippetForm').hidden = true; });
document.querySelector('#issueDetailTransitions').addEventListener('click', event => { const button = event.target.closest('[data-issue-transition]'); if (button) transitionCurrentIssue(button.dataset.issueTransition); });
document.querySelector('#searchIssues').addEventListener('click', loadIssues);
document.querySelector('#issueSearch').addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); loadIssues(); } });
['#issueProviderFilter', '#issueStatusFilter', '#issueSeverityFilter', '#issueCategoryFilter'].forEach(selector => document.querySelector(selector).addEventListener('change', () => { issueScope = ''; loadIssues(); }));
document.querySelector('#issueSummaryGrid').addEventListener('click', event => { const button = event.target.closest('[data-issue-scope]'); if (button) applyIssueScope(button.dataset.issueScope); });
document.querySelector('#issuesPage').addEventListener('click', event => {
  const tag = event.target.closest('[data-issue-tag]');
  if (tag) { issueTagScope = issueTagScope === tag.dataset.issueTag ? '' : tag.dataset.issueTag; loadIssues(); return; }
  if (event.target.closest('#clearIssueTag')) { issueTagScope = ''; loadIssues(); return; }
  const open = event.target.closest('[data-open-issue]');
  if (open) { openIssue(open.dataset.openIssue); return; }
  const link = event.target.closest('[data-issue-link]');
  if (link) {
    event.preventDefault();
    const target = link.dataset.page;
    history.replaceState(null, '', `#${target}`);
    showPage(target);
    if (link.dataset.issueLink === 'alert' && typeof loadAlerts === 'function') loadAlerts().then(() => openAlertAction(link.dataset.linkId));
    if (link.dataset.issueLink === 'history' && typeof loadWorkHistories === 'function') loadWorkHistories();
    if (link.dataset.issueLink === 'check' && link.dataset.providerId && typeof selectProvider === 'function') selectProvider(link.dataset.providerId);
  }
});
