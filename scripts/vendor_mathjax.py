"""Размещает MathJax локально (docs/assets/mathjax/): tex-chtml.js + шрифты CHTML.

Плагин privacy копирует только tex-chtml.js, а шрифты MathJax подгружает сам из соседнего
каталога output/chtml/fonts/ — при недоступном CDN они дают 404 (см. «Отладка»).
Тарбол берётся из реестра npm и проверяется по sha512 из lock-строки package-lock.
"""

import base64
import hashlib
import io
import shutil
import sys
import tarfile
import urllib.request
from pathlib import Path

VERSION = "3.2.2"
URL = f"https://registry.npmjs.org/mathjax/-/mathjax-{VERSION}.tgz"
INTEGRITY = "sha512-Bt+SSVU8eBG27zChVewOicYs7Xsdt40qm4+UpHyX7k0/O9NliPc+x77k1/FEsPsjKPZGJvtRZM1vO+geW0OhGw=="
DEST = Path(__file__).resolve().parent.parent / "docs" / "assets" / "mathjax"

data = urllib.request.urlopen(URL, timeout=60).read()
got = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
if got != INTEGRITY:
    sys.exit(f"integrity mismatch: {got}")

shutil.rmtree(DEST, ignore_errors=True)
with tarfile.open(fileobj=io.BytesIO(data)) as tar:
    for m in tar.getmembers():
        rel = m.name.removeprefix("package/")
        if rel in ("es5/tex-chtml.js", "LICENSE") or rel.startswith("es5/output/chtml/fonts/woff-v2/"):
            out = DEST / rel.removeprefix("es5/")
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(tar.extractfile(m).read())
print(f"MathJax {VERSION} → {DEST}")
