"""반입 런북(docs/폐쇄망-반입-런북.md)에 들어가는 화면 캡처.

운영 중인 서버(기본 http://127.0.0.1:8090)에 관리자 세션을 직접 만들어 붙고, 런북이 안내하는
순서(로그인 → 비밀번호 변경 → 공급자 등록 → 연결 진단 → 노드 탐색 → 점검)의 화면을 찍는다.
사이트 실명·IP·계정은 찍기 직전에 가린다. 숫자는 손대지 않는다.

연결 진단 결과는 실제 노드로 나가지 않고 화면 안에서 예시 결과를 그려 찍는다. 이 서버에는
sudo 비밀번호가 등록된 공급자가 없어 실제 진단은 항상 권한 상승 실패로 끝나기 때문이다.

실행(브라우저는 playwright 것을 쓴다):
    /root/portfolio/.capture-venv/bin/python tools/capture_runbook_screens.py [BASE_URL]
"""
import asyncio
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
OUT = PROJECT / "docs" / "images"
sys.path.insert(0, str(PROJECT))

from provider_store import admin_account_info, create_session, delete_session  # noqa: E402
from playwright.async_api import async_playwright  # noqa: E402

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8090"
VIEWPORT = {"width": 1440, "height": 900}

MASK_JS = """() => {
  const scrub = text => text
    .replace(/hnti/gi, 'SITE-A')
    .replace(/rocky/gi, 'SITE-B')
    .replace(/katech/gi, 'SITE-B')
    .replace(/ubuntu/gi, 'ops-user')
    .replace(/hcon(\\d+)/gi, 'controller-0$1')
    .replace(/hcom(\\d+)/gi, 'compute-0$1')
    .replace(/mixed(\\d+)/gi, 'node-0$1')
    .replace(/\\b10\\.(?:\\d{1,3}\\.){2}\\d{1,3}\\b/g, '10.xxx.xxx.xxx')
    .replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi, 'demo-id')
    .replace(/\\b[0-9a-f]{24,}\\b/gi, 'demo-id');
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  for (const node of nodes) node.nodeValue = scrub(node.nodeValue);
  for (const option of document.querySelectorAll('option')) option.textContent = scrub(option.textContent);
  for (const input of document.querySelectorAll('input[type=text], input:not([type])')) if (input.value) input.value = scrub(input.value);
  for (const element of document.querySelectorAll('[title]')) element.title = scrub(element.title);
}"""

# 연결 진단 화면의 예시 결과. js/providers.js 가 그리는 마크업과 같은 구조다.
DIAGNOSIS_JS = """() => {
  const panel = document.querySelector('#providerDiagnosis');
  panel.hidden = false;
  document.querySelector('#providerDiagnosisName').textContent = '운영 OpenStack · 연결 준비 상태';
  const steps = [
    ['ok',   'VIP 접속',            '10.xxx.xxx.xxx:22 응답. 호스트 키 승인됨', '1.2초'],
    ['ok',   '활성 Controller',     'controller-03 (Pacemaker VIP 보유)', '0.4초'],
    ['ok',   'root 권한(sudo)',     'ops-user → root. 저장된 sudo 비밀번호로 인증', '0.9초'],
    ['ok',   'OpenRC · OpenStack CLI', '/root/contrabass-openrc 확인. openstack token issue 성공', '3.1초'],
    ['ok',   '노드 접속',           'Controller 3 · Compute 2 모두 SSH·sudo 확인', '4.8초'],
    ['warn', 'Prometheus',          'http://10.xxx.xxx.xxx:9090 응답 없음. 모니터링은 점검 이력으로 대체', '2.0초'],
  ];
  const icons = {ok:'✓', warn:'!', fail:'✕', skip:'–'};
  const labels = {ok:'정상', warn:'주의', fail:'실패', skip:'건너뜀'};
  document.querySelector('#providerDiagnosisResult').innerHTML =
    '<div class="diagnosis-summary warn"><strong>주의 항목이 있습니다</strong><span>정상 5 · 주의 1 · 실패 0 · 건너뜀 0 · 12초</span></div>' +
    '<ol class="diagnosis-steps">' + steps.map(([s, label, detail, sec]) =>
      `<li class="${s}"><i>${icons[s]}</i><div><strong>${label}</strong><span>${detail}</span></div><em>${labels[s]} · ${sec}</em></li>`
    ).join('') + '</ol>';
  panel.scrollIntoView({block:'start'});
}"""


async def settle(page, ms=1200):
    try:
        await page.wait_for_load_state("networkidle", timeout=8000)
    except Exception:
        pass
    await page.wait_for_timeout(ms)


async def shot(page, selector, name, pad=0):
    target = page.locator(selector).first
    if not await target.count() or not await target.is_visible():
        print(f"  skip {name}: {selector} not visible")
        return
    await target.scroll_into_view_if_needed()
    await page.wait_for_timeout(250)
    await page.evaluate(MASK_JS)
    await page.wait_for_timeout(120)
    if pad:
        box = await target.bounding_box()
        clip = {"x": max(box["x"] - pad, 0), "y": max(box["y"] - pad, 0),
                "width": box["width"] + pad * 2, "height": box["height"] + pad * 2}
        await page.screenshot(path=str(OUT / f"{name}.png"), clip=clip)
    else:
        await target.screenshot(path=str(OUT / f"{name}.png"))
    print(f"  {name}")


async def page_shot(page, name):
    await page.evaluate("() => window.scrollTo(0, 0)")
    await page.evaluate(MASK_JS)
    await page.wait_for_timeout(200)
    await page.screenshot(path=str(OUT / f"{name}.png"))
    print(f"  {name}")


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    account = admin_account_info()
    if not account:
        raise RuntimeError("관리자 계정을 찾을 수 없습니다.")
    token, _ = create_session(account["username"], 1, "127.0.0.1", "runbook-capture")
    try:
        async with async_playwright() as pw:
            browser = await pw.chromium.launch(headless=True, args=["--no-sandbox"])

            # 1·2. 로그인, 첫 로그인의 비밀번호 변경 — 세션 없이
            anon = await browser.new_context(viewport=VIEWPORT, device_scale_factor=1)
            apage = await anon.new_page()
            await apage.goto(f"{BASE}/login.html", wait_until="networkidle")
            await apage.wait_for_timeout(600)
            await apage.fill("#loginUsername", "admin")
            # 두 패널(브랜드 + 폼)을 함께, 주변의 빈 배경은 조금만
            async def login_clip():
                brand = await apage.locator(".login-brand").bounding_box()
                card = await apage.locator(".login-card").bounding_box()
                x = min(brand["x"], card["x"]) - 24
                y = min(brand["y"], card["y"]) - 24
                right = max(brand["x"] + brand["width"], card["x"] + card["width"]) + 24
                bottom = max(brand["y"] + brand["height"], card["y"] + card["height"]) + 24
                return {"x": x, "y": y, "width": right - x, "height": bottom - y}
            await apage.screenshot(path=str(OUT / "01-login.png"), clip=await login_clip())
            print("  01-login")
            await apage.evaluate("""() => {
                document.querySelector('#loginForm').hidden = true;
                document.querySelector('#passwordForm').hidden = false;
            }""")
            await apage.wait_for_timeout(300)
            await apage.screenshot(path=str(OUT / "02-password-change.png"), clip=await login_clip())
            print("  02-password-change")
            await anon.close()

            context = await browser.new_context(viewport=VIEWPORT, device_scale_factor=1)
            await context.add_cookies([{"name": "okestro_session", "value": token, "url": BASE, "httpOnly": True, "sameSite": "Lax"}])
            page = await context.new_page()
            await page.goto(f"{BASE}/", wait_until="networkidle")
            await page.add_style_tag(content="* { animation: none !important; transition: none !important; }")
            await settle(page)

            # 3. 로그인 직후 대시보드, 왼쪽 아래 버전 표시
            await page_shot(page, "03-dashboard")
            await shot(page, ".sidebar-footer", "04-sidebar-version", pad=8)

            # 4. 공급자 등록 폼 — 비밀번호 인증 + sudo 비밀번호 칸이 보이는 상태
            await page.locator('[data-page="providers"]').first.click()
            await settle(page)
            await page.locator('#connectionForm input[name="auth_method"][value="password"]').check()
            await page.evaluate("""() => {
                const form = document.querySelector('#connectionForm');
                form.elements.name.value = '운영 OpenStack';
                form.elements.vip.value = '10.10.10.100';
                form.elements.username.value = 'ops-user';
                form.elements.password.value = 'example-password';
                form.elements.sudo_password.value = 'example-password';
                document.querySelector('#passwordFields').hidden = false;
                document.querySelector('#sudoFields').hidden = false;
            }""")
            await page.wait_for_timeout(300)
            await shot(page, "#connectionForm", "05-provider-form", pad=12)

            # 5. 등록된 공급자 목록(카드)과 카드의 버튼
            await shot(page, ".saved-providers", "06-provider-list", pad=12)

            # 6. 연결 진단 결과 — 예시 결과를 화면 안에서 그린다
            await page.evaluate(DIAGNOSIS_JS)
            await page.wait_for_timeout(300)
            await shot(page, "#providerDiagnosis", "07-provider-diagnosis", pad=12)

            # 7·8. 일일점검 — 노드 인벤토리와 탐색 버튼, 점검 결과
            await page.locator('[data-page="daily-inspection"]').first.click()
            await settle(page, 1500)
            select = page.locator("#inspectionProviderSelect")
            options = await select.locator("option[value]:not([value=''])").all()
            if options:
                await select.select_option(value=await options[0].get_attribute("value"))
                await settle(page, 1500)
            # 노드 인벤토리는 「설정 카드」 뒤에 접혀 있다. 카드를 열고 찍는다.
            card = page.locator('button.setup-card[data-setup="inventory"]').first
            if await card.count() and (await card.get_attribute("aria-expanded")) != "true":
                await card.click()
                await page.wait_for_timeout(500)
            await shot(page, ".inspection-setup", "09-inspection-setup", pad=12)
            await shot(page, '[data-setup-panel="inventory"]', "10-inspection-inventory", pad=12)
            await shot(page, ".inspection-summary", "11-inspection-summary", pad=12)
            await shot(page, ".inspection-checklist", "12-inspection-checklist", pad=12)

            await browser.close()
    finally:
        delete_session(token)


asyncio.run(main())
