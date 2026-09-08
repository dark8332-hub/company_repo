// Minimal browser stand-in for running the app scripts inside QuickJS (no node/chromium on the host).
// It executes every top-level statement of the real scripts: missing element ids in index.html,
// references to functions that live in a later file, and plain syntax errors all surface as exceptions.
// __PAGE_IDS__ is injected by tests/test_js_smoke.py before this file is evaluated.
(function () {
  const pageIds = new Set(globalThis.__PAGE_IDS__ || []);
  const noop = function () {};
  function makeClassList() {
    const set = new Set();
    return {add: (...names) => names.forEach(n => set.add(n)), remove: (...names) => names.forEach(n => set.delete(n)), toggle: (name, force) => { if (force === undefined ? !set.has(name) : force) set.add(name); else set.delete(name); return set.has(name); }, contains: name => set.has(name), replace: noop};
  }
  function makeElement(tag) {
    const element = {
      tagName: String(tag || 'div').toUpperCase(), nodeType: 1, children: [], childNodes: [], style: {}, dataset: {}, classList: makeClassList(),
      hidden: false, disabled: false, checked: false, value: '', textContent: '', innerHTML: '', innerText: '', files: [], required: false, className: '', id: '',
      offsetWidth: 720, offsetHeight: 200, clientWidth: 720, clientHeight: 200, scrollTop: 0, scrollHeight: 0, parentElement: null, nextElementSibling: null, firstElementChild: null, lastElementChild: null,
      addEventListener: noop, removeEventListener: noop, dispatchEvent: noop, appendChild(child) { this.children.push(child); return child; }, append: noop, prepend: noop, remove: noop, replaceChildren: noop, insertAdjacentHTML: noop, insertBefore: noop, removeChild: noop, cloneNode() { return makeElement(tag); },
      setAttribute: noop, getAttribute: () => null, removeAttribute: noop, hasAttribute: () => false, toggleAttribute: noop, focus: noop, blur: noop, click: noop, select: noop, reset: noop, submit: noop, scrollIntoView: noop, scrollTo: noop,
      getBoundingClientRect: () => ({width: 720, height: 200, left: 0, top: 0, right: 720, bottom: 200}), closest: () => null, matches: () => false, contains: () => false, getContext: () => null, querySelector: () => makeElement('div'), querySelectorAll: () => [], getElementsByTagName: () => [], setPointerCapture: noop, releasePointerCapture: noop, requestSubmit: noop, checkValidity: () => true, reportValidity: () => true, showModal: noop, close: noop
    };
    element.elements = new Proxy({}, {get: (_, key) => (typeof key === 'string' ? makeElement('input') : undefined)});
    element.options = [];
    element.selectedOptions = [];
    return element;
  }
  const simpleId = /^#([A-Za-z0-9_-]+)$/;
  const document = {
    body: makeElement('body'), documentElement: makeElement('html'), head: makeElement('head'), title: '', hidden: false, visibilityState: 'visible', activeElement: null, readyState: 'complete',
    addEventListener: noop, removeEventListener: noop, dispatchEvent: noop, createElement: tag => makeElement(tag), createElementNS: (_, tag) => makeElement(tag), createTextNode: text => ({textContent: text}), createDocumentFragment: () => makeElement('fragment'),
    querySelector(selector) { const match = simpleId.exec(String(selector).trim()); if (match && !pageIds.has(match[1])) return null; return makeElement('div'); },
    querySelectorAll: () => [], getElementById(id) { return pageIds.has(id) ? makeElement('div') : null; }, execCommand: () => true, hasFocus: () => true
  };
  document.body.appendChild = child => child;
  globalThis.document = document;
  globalThis.window = globalThis;
  globalThis.self = globalThis;
  globalThis.location = {hash: '', search: '', pathname: '/', href: 'http://localhost/', origin: 'http://localhost', host: 'localhost', protocol: 'http:', replace: noop, reload: noop, assign: noop};
  globalThis.history = {replaceState: noop, pushState: noop, back: noop};
  globalThis.navigator = {clipboard: {writeText: () => Promise.resolve()}, userAgent: 'quickjs', language: 'ko-KR', onLine: true};
  const storage = () => { const map = new Map(); return {getItem: key => (map.has(key) ? map.get(key) : null), setItem: (key, value) => map.set(key, String(value)), removeItem: key => map.delete(key), clear: () => map.clear(), key: () => null, length: 0}; };
  globalThis.localStorage = storage();
  globalThis.sessionStorage = storage();
  globalThis.fetch = () => new Promise(noop);
  globalThis.addEventListener = noop;
  globalThis.removeEventListener = noop;
  globalThis.dispatchEvent = noop;
  globalThis.matchMedia = () => ({matches: false, addEventListener: noop, removeEventListener: noop, addListener: noop});
  globalThis.getComputedStyle = () => ({getPropertyValue: () => ''});
  globalThis.requestAnimationFrame = fn => 0;
  globalThis.cancelAnimationFrame = noop;
  globalThis.scrollTo = noop;
  globalThis.innerWidth = 1280;
  globalThis.innerHeight = 800;
  globalThis.devicePixelRatio = 1;
  let timerId = 0;
  globalThis.setTimeout = () => ++timerId;
  globalThis.setInterval = () => ++timerId;
  globalThis.clearTimeout = noop;
  globalThis.clearInterval = noop;
  globalThis.queueMicrotask = noop;
  globalThis.alert = noop;
  globalThis.confirm = () => true;
  globalThis.prompt = () => null;
  globalThis.open = noop;
  globalThis.print = noop;
  globalThis.console = {log: noop, warn: noop, error: noop, info: noop, debug: noop, table: noop, group: noop, groupEnd: noop};
  globalThis.performance = {now: () => 0};
  globalThis.crypto = {randomUUID: () => '00000000-0000-4000-8000-000000000000', getRandomValues: array => array};
  globalThis.structuredClone = value => JSON.parse(JSON.stringify(value));
  globalThis.Intl = {
    DateTimeFormat: function () { return {format: value => String(value), formatToParts: () => [], resolvedOptions: () => ({timeZone: 'Asia/Seoul'})}; },
    NumberFormat: function () { return {format: value => String(value)}; },
    RelativeTimeFormat: function () { return {format: (value, unit) => `${value} ${unit}`}; },
    PluralRules: function () { return {select: () => 'other'}; }
  };
  globalThis.URLSearchParams = function (init) { const map = new Map(); if (typeof init === 'string') init.replace(/^\?/, '').split('&').filter(Boolean).forEach(pair => { const [key, value = ''] = pair.split('='); map.set(decodeURIComponent(key), decodeURIComponent(value)); }); this.get = key => (map.has(key) ? map.get(key) : null); this.set = (key, value) => map.set(key, String(value)); this.has = key => map.has(key); this.delete = key => map.delete(key); this.toString = () => [...map].map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&'); this.entries = () => map.entries(); };
  globalThis.URL = function (href) { this.href = href; this.searchParams = new URLSearchParams(''); this.pathname = '/'; this.hash = ''; };
  globalThis.URL.createObjectURL = () => 'blob:mock';
  globalThis.URL.revokeObjectURL = noop;
  globalThis.Blob = function (parts, options) { this.parts = parts; this.type = options ? options.type : ''; this.size = 0; };
  globalThis.File = globalThis.Blob;
  globalThis.FormData = function () { const map = new Map(); this.get = key => (map.has(key) ? map.get(key) : null); this.set = (key, value) => map.set(key, value); this.append = (key, value) => map.set(key, value); this.has = key => map.has(key); this.entries = () => map.entries(); };
  globalThis.Event = function (type) { this.type = type; };
  globalThis.CustomEvent = globalThis.Event;
  globalThis.KeyboardEvent = globalThis.Event;
  globalThis.MouseEvent = globalThis.Event;
  globalThis.AbortController = function () { this.signal = {aborted: false, addEventListener: noop}; this.abort = noop; };
  globalThis.TextEncoder = function () { this.encode = value => Array.from(String(value)).map(c => c.charCodeAt(0)); };
  globalThis.TextDecoder = function () { this.decode = () => ''; };
  globalThis.DOMParser = function () { this.parseFromString = () => document; };
  globalThis.MutationObserver = function () { this.observe = noop; this.disconnect = noop; };
  globalThis.ResizeObserver = globalThis.MutationObserver;
  globalThis.IntersectionObserver = globalThis.MutationObserver;
  globalThis.Image = function () { return makeElement('img'); };
  globalThis.Audio = function () { return makeElement('audio'); };
  globalThis.Notification = {permission: 'default', requestPermission: () => Promise.resolve('default')};
  globalThis.__smokeElement = makeElement;
}());
