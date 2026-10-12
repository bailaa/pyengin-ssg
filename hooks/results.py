"""MkDocs-хук: пересчитывает результаты эксперимента WaySense и метку версии сборки.

on_config    — кладёт в config.extra хеш коммита, дату сборки и хеш набора данных
               (выводятся в подвале и в <meta name="build-commit">, по ней работает healthcheck).
on_pre_build — читает data/*.csv, строит таблицы (Markdown) и графики (PNG) в docs/results/generated/.
               Файл перезаписывается только при изменении содержимого, чтобы `mkdocs serve`
               не уходил в бесконечную пересборку.
"""

import csv
import hashlib
import io
import os
import subprocess
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
OUT = ROOT / "docs" / "results" / "generated"

STATUS_RU = {
    "ok": "совпадает",
    "missing_tag": "нет тега wheelchair",
    "conflict": "противоречие",
    "not_found": "выход не найден в OSM",
}


def _git(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def _dataset_hash() -> str:
    h = hashlib.sha256()
    for p in sorted(DATA.glob("*.csv")):
        h.update(p.name.encode())
        h.update(p.read_bytes())
    return h.hexdigest()[:12]


def _write(path: Path, data: bytes) -> None:
    if path.exists() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def _png(fig) -> bytes:
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=150, bbox_inches="tight", metadata={"Software": None})
    plt.close(fig)
    return buf.getvalue()


def on_config(config, **kwargs):
    commit = os.environ.get("GITHUB_SHA") or _git("rev-parse", "HEAD")
    config.extra["build"] = {
        "commit": commit,
        "commit_short": commit[:7],
        "date": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "dataset": _dataset_hash(),
        "target": os.environ.get("DEPLOY_TARGET", "local"),
    }
    return config


def lift_exits() -> None:
    rows = list(csv.DictReader(open(DATA / "mtr_lift_exits_vs_osm.csv", encoding="utf-8")))
    total = len(rows)
    by_status = Counter(r["status"] for r in rows)
    by_kind = defaultdict(Counter)
    for r in rows:
        by_kind[r["mtr_facility"]][r["status"]] += 1

    md = ["| Статус | Выходов | Доля |", "|---|---:|---:|"]
    for s in STATUS_RU:
        md.append(f"| {STATUS_RU[s]} | {by_status[s]} | {by_status[s] / total:.0%} |")
    md.append(f"| **Всего** | **{total}** | 100% |")
    _write(OUT / "lift_exits_table.md", ("\n".join(md) + "\n").encode())

    kinds = sorted(by_kind)
    fig, ax = plt.subplots(figsize=(6, 3.2))
    left = [0] * len(kinds)
    colors = {"ok": "#16a34a", "missing_tag": "#eab308", "conflict": "#dc2626", "not_found": "#6b7280"}
    for s in STATUS_RU:
        vals = [by_kind[k][s] for k in kinds]
        ax.barh([k.replace(" (", "\n(") for k in kinds], vals, left=left, label=STATUS_RU[s], color=colors[s])
        left = [a + b for a, b in zip(left, vals)]
    ax.set_xlabel("число выходов")
    ax.legend(ncol=2, fontsize=9, frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.25))
    ax.spines[["top", "right"]].set_visible(False)
    _write(OUT / "lift_exits.png", _png(fig))


def routes() -> None:
    rows = list(csv.DictReader(open(DATA / "compare_routes.csv", encoding="utf-8")))
    pairs = list(dict.fromkeys(r["pair"] for r in rows))
    get = {(r["pair"], r["graph"]): r for r in rows}

    md = ["| Маршрут | OSM, м | 3DPN, м | Δ, % | Лифтов (3DPN) |", "|---|---:|---:|---:|---:|"]
    for p in pairs:
        a, b = get[(p, "osm")], get[(p, "3dpn")]
        la, lb = int(a["length_m"]), int(b["length_m"])
        md.append(f"| {p} | {la} | {lb} | {(lb - la) / la:+.0%} | {b['elevators']} |")
    _write(OUT / "routes_table.md", ("\n".join(md) + "\n").encode())

    fig, ax = plt.subplots(figsize=(7, 3.2))
    y = range(len(pairs))
    ax.barh([i + 0.2 for i in y], [int(get[(p, "osm")]["length_m"]) for p in pairs], 0.4, label="OSM", color="#2563eb")
    ax.barh([i - 0.2 for i in y], [int(get[(p, "3dpn")]["length_m"]) for p in pairs], 0.4, label="3DPN", color="#16a34a")
    ax.set_yticks(list(y), pairs, fontsize=8)
    ax.invert_yaxis()
    ax.set_xlabel("длина маршрута, м")
    ax.legend(frameon=False)
    ax.spines[["top", "right"]].set_visible(False)
    _write(OUT / "routes.png", _png(fig))


def on_pre_build(config, **kwargs):
    lift_exits()
    routes()
