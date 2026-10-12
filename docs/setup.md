# Ход работы

## 1. Окружение

| Компонент | Версия | Как зафиксирована |
|---|---|---|
| Python | 3.12.14 | `.python-version`; uv скачивает именно её и локально, и на раннере |
| uv (менеджер пакетов и виртуальных окружений) | 0.12.17 | `astral-sh/setup-uv` по SHA |
| MkDocs | 1.6.1 | `pyproject.toml` (`==`) + `uv.lock` с хешами всех транзитивных пакетов |
| mkdocs-material | 9.7.7 | то же |
| matplotlib | 3.11.2 | то же |
| MathJax | 3.2.2 | `scripts/vendor_mathjax.py`, проверка sha512 тарбола npm |

Вместо связки `pip + virtualenv + requirements.txt` выбран **uv** с `pyproject.toml` и lock-файлом. Он создаёт
виртуальное окружение `.venv/` (аналог `virtualenv .venv`), а `uv sync --frozen` ставит ровно то, что записано в `uv.lock`,
и падает, если lock-файл не соответствует `pyproject.toml`. Так сборка воспроизводится на чистом раннере.

```bash title="Развёртывание проекта с нуля"
git clone https://github.com/bailaa/pyengin-ssg && cd pyengin-ssg
uv sync --frozen            # .venv + точные версии из uv.lock
uv run mkdocs serve         # предпросмотр на http://127.0.0.1:8000
uv run mkdocs build --strict
```

`.gitignore` исключает `.venv/`, `site/`, `_build/`, `.cache/` (кэш плагина privacy), `__pycache__/` и генерируемые
`docs/results/generated/`.

## 2. Структура репозитория

```text
pyengin-ssg/
├── .github/workflows/
│   ├── pages.yml          # сборка → GitHub Pages (upload-pages-artifact + deploy-pages)
│   └── helios.yml         # сборка → Helios по SSH/rsync, preview веток, откат, healthcheck
├── data/                  # исходные данные эксперимента WaySense (CSV)
├── docs/                  # исходники сайта (Markdown)
│   └── assets/mathjax/    # MathJax со шрифтами — работа без CDN (T4)
├── hooks/results.py       # MkDocs-хук: CSV → таблицы и графики, метка версии сборки
├── overrides/main.html    # частичное переопределение темы: <meta build-commit>, подвал с версией
├── scripts/
│   ├── healthcheck.sh     # HTTP 200 + контрольная строка
│   ├── helios-activate.sh # активация/откат релиза на Helios
│   ├── vendor_mathjax.py
│   └── t4_measure.py      # замеры T4 (Playwright)
├── mkdocs.yml             # рабочая конфигурация
├── mkdocs.t4-*.yml        # варианты для эксперимента T4 (INHERIT)
├── pyproject.toml, uv.lock, .python-version
├── LICENSE (MIT, код), LICENSE-CONTENT (CC BY 4.0, текст и данные)
```

## 3. Сборка

`mkdocs build --strict` превращает любое предупреждение (битая ссылка, страница вне навигации, отсутствующий файл
сниппета) в ошибку. В CI это стадия lint: сломанный сайт не уходит на площадку. Замеры на MacBook (Apple M-серии),
сайт из 124 файлов, 8,7 МБ:

| Операция | Время, с |
|---|---:|
| `uv sync --frozen`, пустой кэш uv | 2,34 |
| `uv sync --frozen`, кэш uv заполнен | 0,28 |
| `mkdocs build --strict`, холодная сборка (нет `.cache/`, плагин privacy скачивает шрифты) | 3,63 |
| `mkdocs build --strict`, холодная сборка, повтор | 3,12 |
| `mkdocs build --strict`, кэш privacy заполнен | 0,82–0,88 |

## 4. Базовый URL

Сайт публикуется в трёх местах с разными корнями:

| Площадка | Корень | `site_url` |
|---|---|---|
| GitHub Pages | подкаталог `/pyengin-ssg/` | `https://bailaa.github.io/pyengin-ssg/` |
| Helios, `main` | подкаталог `/~sXXXXXX/` | `https://se.ifmo.ru/~sXXXXXX/` |
| Helios, preview ветки | подкаталог `/~sXXXXXX/preview/<ветка>/` | `https://se.ifmo.ru/~sXXXXXX/preview/<ветка>/` |

`site_url: !ENV [SITE_URL, ...]` — значение передаёт workflow. `site_url` влияет на canonical-ссылки, `sitemap.xml`
и путь, по которому Material хранит состояние в `localStorage`. Все внутренние ссылки MkDocs делает относительными
(`../t4/`), поэтому одна и та же сборка работает в любом подкаталоге. `use_directory_urls: true` даёт адреса вида
`/t4/`, которые требуют, чтобы сервер отдавал `index.html` для каталога. Apache на Helios так и делает.

Проверка подкаталога выполнена локально: сайт раздаётся из `/~s000000/local/`, и все переходы, картинки,
поиск и MathJax работают (см. [T4](t4.md#3-работа-сайта-при-недоступных-cdn)). Типичная ошибка, когда сайт работает на Pages, но
ломается на Helios, — абсолютные пути вида `/assets/...` в ручном HTML или в `extra_javascript`. В этом проекте
все пути относительные: `assets/mathjax/tex-chtml.js`.

## 5. GitHub Actions

Settings → Pages → Source = **GitHub Actions**. Разница двух подходов:

| | `peaceiris/actions-gh-pages` (push в `gh-pages`) | `upload-pages-artifact` + `deploy-pages` |
|---|---|---|
| Что публикуется | содержимое ветки `gh-pages` | артефакт конкретного запуска |
| Права токена | `contents: write` — запись в репозиторий | `pages: write` + `id-token: write` — только Pages |
| История версий | каждая публикация — коммит в `gh-pages` (растёт размер репо) | хранится в Deployments, репозиторий не засоряется |
| Откат | `git revert` в `gh-pages` | повторный запуск старого workflow |
| Защита | правила ветки | environment `github-pages` с правилами (только `main`) |

Выбран официальный механизм: у него уже права и нет отдельной ветки (подробно в [T4](t4.md)).

## 6. Проверка развёртывания

Шаг healthcheck (`scripts/healthcheck.sh`) запрашивает опубликованный URL и требует **одновременно** HTTP 200 и
`<meta name="build-commit" content="<SHA текущего коммита>">`. Код 200 без нужного хеша означает, что отдаётся старая
версия (кэш CDN или неудачная выкладка). Это ловится повторными попытками, а затем ошибкой job.

Работа поиска и формул без CDN проверена в [T4](t4.md#3-работа-сайта-при-недоступных-cdn): поиск — встроенный lunr
с русским стеммером (`search: lang: [ru, en]`), его индекс лежит на том же хосте.

## 7. Лицензии

Раздельно для трёх видов результатов: код (workflow, хуки, скрипты) — [MIT](https://github.com/bailaa/pyengin-ssg/blob/main/LICENSE),
текст отчёта и графики — [CC BY 4.0](https://github.com/bailaa/pyengin-ssg/blob/main/LICENSE-CONTENT), данные из `data/` — ODbL 1.0,
так как они производные от OpenStreetMap. Подробнее — на странице [Лицензии](license.md).
