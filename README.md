# pyengin-ssg

[![pages](https://github.com/bailaa/pyengin-ssg/actions/workflows/pages.yml/badge.svg)](https://github.com/bailaa/pyengin-ssg/actions/workflows/pages.yml)
[![helios](https://github.com/bailaa/pyengin-ssg/actions/workflows/helios.yml/badge.svg)](https://github.com/bailaa/pyengin-ssg/actions/workflows/helios.yml)

Отчёт по заданию 3 «Генераторы статических сайтов» (курс «Разработка на Python и инженерия данных»):
T4 — модель доставки и безопасность пайплайна, P4 — развёртывание на Helios с контролем качества доставки.
Публикуемые результаты — эксперимент [WaySense](https://github.com/bailaa/waysense) (доступные маршруты для колясок в Гонконге).

- GitHub Pages: https://bailaa.github.io/pyengin-ssg/
- Helios ИТМО: https://se.ifmo.ru/~s566056/

```bash
uv sync --frozen
uv run mkdocs serve
uv run mkdocs build --strict
```

Лицензии: код — MIT (`LICENSE`), текст — CC BY 4.0 (`LICENSE-CONTENT`), данные `data/` — ODbL 1.0.
