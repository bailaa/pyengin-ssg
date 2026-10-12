# Лицензии

| Что | Где | Лицензия | Почему |
|---|---|---|---|
| Код: workflow, хуки, скрипты, шаблон темы | `.github/`, `hooks/`, `scripts/`, `overrides/`, `mkdocs*.yml` | [MIT](https://github.com/bailaa/pyengin-ssg/blob/main/LICENSE) | разрешительная лицензия для кода, совместима с лицензиями зависимостей (MkDocs — BSD-2, Material — MIT) |
| Текст отчёта, графики, скриншоты | `docs/` (кроме `docs/assets/mathjax/`) | [CC BY 4.0](https://github.com/bailaa/pyengin-ssg/blob/main/LICENSE-CONTENT) | лицензия для произведений, а не для программ; требует указания авторства |
| Данные эксперимента | `data/*.csv` | [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | таблицы содержат идентификаторы и теги объектов OpenStreetMap — это производная база данных OSM, к ней применяется share-alike ODbL; перечень выходов MTR — DATA.GOV.HK, условия требуют указать источник |
| MathJax | `docs/assets/mathjax/` | Apache 2.0 (файл `LICENSE` рядом) | сторонний код, размещён без изменений |

Источники данных: © участники OpenStreetMap (ODbL); MTR Corporation, «Barrier-free facilities» — DATA.GOV.HK.

Почему лицензии раздельные: CC BY не подходит для кода (в ней нет условий о патентах и об исходном коде), MIT не
подходит для текста (её формулировки рассчитаны на «software»). Для данных из OSM лицензию автор выбрать не может:
её наследует производная база.
