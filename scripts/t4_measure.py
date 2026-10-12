"""T4: поведение страницы при недоступных CDN и её вес для трёх вариантов сборки.

Варианты собираются в <root>/~s000000/{cdn,privacy,local}/ (подкаталог как на Helios) и раздаются
`python -m http.server 8765 -d <root>`. Для каждого варианта страница results/ открывается дважды:
с открытой сетью и с заблокированными внешними хостами. Считаются переданные байты (CDP,
encodedDataLength), внешние запросы, ошибки загрузки, отрисованы ли формула и шрифт Roboto.
Отдельно — вес локальных ресурсов страницы с gzip (http.server не сжимает, а Apache/CDN сжимают).

    uv run --with playwright python scripts/t4_measure.py <root> <screenshots-dir>
"""

import gzip
import os
import sys
from urllib.parse import unquote, urlparse

from playwright.sync_api import sync_playwright

ROOT, SHOTS = sys.argv[1], sys.argv[2]
BASE = "http://127.0.0.1:8765/~s000000"
VARIANTS = ["cdn", "privacy", "local"]


def local(u: str) -> bool:
    return urlparse(u).hostname == "127.0.0.1"


def gz_weight(urls: list[str]) -> int:
    total = 0
    for u in set(urls):
        if not local(u):
            continue
        f = os.path.join(ROOT, unquote(urlparse(u).path).lstrip("/"))
        if f.endswith("/"):
            f += "index.html"
        if os.path.isfile(f):
            d = open(f, "rb").read()
            total += len(d) if f.endswith((".png", ".woff", ".woff2")) else len(gzip.compress(d, 6))
    return total


rows = []
with sync_playwright() as p:
    browser = p.chromium.launch()
    for v in VARIANTS:
        for blocked in (False, True):
            ctx = browser.new_context(viewport={"width": 1100, "height": 800})
            page = ctx.new_page()
            if blocked:
                page.route("**/*", lambda r: r.continue_() if local(r.request.url) else r.abort())
            cdp = ctx.new_cdp_session(page)
            cdp.send("Network.enable")
            cdp.send("Network.setCacheDisabled", {"cacheDisabled": True})
            urls, done = {}, []
            st = {"bytes": 0, "ext_bytes": 0, "ext": 0, "err": 0}

            def on_req(e, urls=urls, st=st):
                urls[e["requestId"]] = e["request"]["url"]
                st["ext"] += not local(e["request"]["url"])

            def on_fin(e, urls=urls, st=st, done=done):
                u = urls.get(e["requestId"], "")
                st["bytes"] += e["encodedDataLength"]
                st["ext_bytes"] += 0 if local(u) else e["encodedDataLength"]
                done.append(u)

            def on_resp(e, st=st):
                st["err"] += e["response"]["status"] >= 400

            def on_fail(e, st=st):
                st["err"] += 1

            cdp.on("Network.requestWillBeSent", on_req)
            cdp.on("Network.loadingFinished", on_fin)
            cdp.on("Network.responseReceived", on_resp)
            cdp.on("Network.loadingFailed", on_fail)

            page.goto(f"{BASE}/{v}/results/", wait_until="networkidle", timeout=60000)
            math = page.locator(".arithmatex").first
            math.scroll_into_view_if_needed()
            page.wait_for_timeout(2500)
            # формула видна, если у глифа есть content и шрифты MathJax не в состоянии error
            math_ok = page.evaluate(
                """(() => { const c = document.querySelector('mjx-c');
                    if (!c) return false;
                    const ok = getComputedStyle(c, '::before').content !== 'none';
                    const err = [...document.fonts].some(f => f.family.startsWith('MJX') && f.status === 'error');
                    return ok && !err; })()"""
            )
            roboto = page.evaluate("[...document.fonts].some(f => f.family === 'Roboto' && f.status === 'loaded')")
            box = math.bounding_box()
            page.screenshot(
                path=f"{SHOTS}/{v}-{'offline' if blocked else 'online'}.png",
                clip={"x": box["x"] - 10, "y": box["y"] - 50, "width": box["width"] + 20, "height": box["height"] + 100},
            )
            rows.append((v, blocked, st["bytes"] // 1024, gz_weight(done) // 1024, st["ext_bytes"] // 1024, st["ext"], st["err"], math_ok, roboto))
            ctx.close()
    browser.close()

yn = {True: "да", False: "**нет**"}
table = ["| Вариант | Внешние хосты | Передано, КБ | из них внешних, КБ | Внешних запросов | Ошибок загрузки | Формула | Roboto |",
         "|---|---|---:|---:|---:|---:|---|---|"]
for v, b, kb, gz, ext_kb, ext, err, m, r in rows:
    table.append(f"| {v} | {'заблокированы' if b else 'доступны'} | {kb} | {ext_kb} | {ext} | {err} | {yn[m]} | {yn[r]} |")
weight = ["| Вариант (сеть открыта) | Локальные ресурсы с gzip, КБ | Внешние ресурсы (уже сжаты CDN), КБ | **Итого для читателя, КБ** |",
          "|---|---:|---:|---:|"]
for v, b, kb, gz, ext_kb, *_ in rows:
    if not b:
        weight.append(f"| {v} | {gz} | {ext_kb} | **{gz + ext_kb}** |")
os.makedirs("snippets", exist_ok=True)
open("snippets/t4_table.md", "w").write("\n".join(table) + "\n")
open("snippets/t4_weight.md", "w").write("\n".join(weight) + "\n")
print("\n".join(table)); print(); print("\n".join(weight))
