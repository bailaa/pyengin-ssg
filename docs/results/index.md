# Результаты эксперимента WaySense

[WaySense](https://github.com/bailaa/waysense) — маршрутизатор для пользователей колясок в Гонконге
(Valhalla + OpenStreetMap). Здесь опубликованы два результата. Таблицы и графики строит хук
[`hooks/results.py`](https://github.com/bailaa/pyengin-ssg/blob/main/hooks/results.py) из CSV в каталоге
`data/` на этапе `on_pre_build`, поэтому новые данные попадают на сайт после обычного `git push`.

## 1. Полнота разметки лифтовых выходов MTR в OSM

Официальный перечень выходов MTR с лифтами (data.gov.hk) сопоставлен с объектами OSM.
Выход считается корректно размеченным, если у соответствующего узла есть `wheelchair=yes`.

<div class="grid" markdown>

<div markdown>
--8<-- "results/generated/lift_exits_table.md"
</div>

![Статус разметки лифтовых выходов MTR по типу лифта](generated/lift_exits.png)

</div>

Доля выходов, которые маршрутизатор может уверенно использовать:

\begin{equation}
  p_{\text{ok}} = \frac{N_{\text{ok}}}{N_{\text{ok}} + N_{\text{missing}} + N_{\text{conflict}} + N_{\text{not found}}}
  \label{eq:pok}
\end{equation}

Формула \(\eqref{eq:pok}\) считается по таблице выше. Разметка недостающих тегов в OSM — основная
ручная работа проекта.

## 2. Граф OSM и граф 3D Pedestrian Network

Одинаковый профиль (`pedestrian`, `type=wheelchair`, `use_hills=0`, `step_penalty=720`) запущен по двум
графам для шести пар точек.

--8<-- "results/generated/routes_table.md"

![Длины маршрутов на двух графах](generated/routes.png)

Граф 3DPN строит маршруты через лифты внутри зданий. Поэтому маршрут иногда короче
(Wan Chai → Emperor Hotel), но чаще длиннее, так как обходит эскалаторы, которые в OSM-графе
ошибочно остаются проходимыми.

!!! info "Версия результата"
    Хеш набора данных (SHA-256 по всем `data/*.csv`, первые 12 символов) и хеш коммита указаны в подвале
    страницы. Они однозначно связывают цифры на странице с версией кода и данных.
