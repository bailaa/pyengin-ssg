# Задание 3. Генераторы статических сайтов

Отчёт по заданию 3 темы 4 курса «Разработка на Python и инженерия данных».
Сайт собран генератором **MkDocs** с темой **Material** и публикуется автоматически из репозитория
[bailaa/pyengin-ssg](https://github.com/bailaa/pyengin-ssg) в два места:

| Площадка | Адрес | Workflow |
|---|---|---|
| GitHub Pages | <https://bailaa.github.io/pyengin-ssg/> | [`pages.yml`](https://github.com/bailaa/pyengin-ssg/blob/main/.github/workflows/pages.yml) |
| Helios ИТМО | `https://se.ifmo.ru/~s566056/` | [`helios.yml`](https://github.com/bailaa/pyengin-ssg/blob/main/.github/workflows/helios.yml) |

[![pages](https://github.com/bailaa/pyengin-ssg/actions/workflows/pages.yml/badge.svg)](https://github.com/bailaa/pyengin-ssg/actions/workflows/pages.yml)
[![helios](https://github.com/bailaa/pyengin-ssg/actions/workflows/helios.yml/badge.svg)](https://github.com/bailaa/pyengin-ssg/actions/workflows/helios.yml)

## Состав отчёта

- [Ход работы](setup.md): окружение, зависимости, сборка, базовый URL, проверки, лицензии.
- [Результаты WaySense](results/index.md): публикуемые результаты эксперимента. Таблицы и графики
  пересчитываются из CSV при каждой сборке.
- [T4. Модель доставки и безопасность пайплайна](t4.md): исследовательское задание.
- [P4. Развёртывание на Helios с контролем качества доставки](p4.md): практическое задание.
- [Отладка](debugging.md): реальные ошибки, гипотезы, проверки и решения.
- [Вывод](conclusion.md): рекомендуемый стек и условия, при которых рекомендация меняется.

В подвале каждой страницы указаны хеш коммита, дата сборки, хеш набора данных и площадка.
По этим же значениям из `<meta name="build-commit">` пайплайн проверяет, что выложена нужная версия.
