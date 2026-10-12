#!/bin/sh
# Выполняется НА Helios (FreeBSD, POSIX sh). Переключает опубликованную версию.
#   helios-activate.sh activate <slot> <release-id>   — выложить релиз
#   helios-activate.sh rollback <slot> [release-id]   — вернуть предыдущий (или указанный) релиз
#   helios-activate.sh list     <slot>                — список релизов, * — текущий
#   helios-activate.sh remove   <slot>                — удалить preview ветки
# slot: main → ~/public_html/ ; preview-<ветка> → ~/public_html/preview/<ветка>/
# Релизы хранятся в ~/ssg/releases/<slot>/<id>/, хранится KEEP последних.
set -eu
KEEP=${KEEP:-5}
cmd=$1 slot=$2 id=${3:-}
base=$HOME/ssg/releases/$slot
state=$HOME/ssg/state/$slot
mkdir -p "$base" "$state"

case $slot in
  main)       target=$HOME/public_html; excl="--exclude=/preview/" ;;
  preview-*)  target=$HOME/public_html/preview/${slot#preview-}; excl="" ;;
  *) echo "bad slot: $slot" >&2; exit 64 ;;
esac

publish() {
  [ -f "$base/$1/index.html" ] || { echo "релиз $1 неполный или отсутствует" >&2; exit 65; }
  mkdir -p "$target"
  # Копирование внутри одного сервера: секунды. Обрыв связи с раннером на этом шаге не прерывает его.
  rsync -a --delete $excl "$base/$1/" "$target/"
  chmod -R a+rX "$target"
  cur=$(cat "$state/current" 2>/dev/null || true)
  [ -n "$cur" ] && [ "$cur" != "$1" ] && echo "$cur" > "$state/previous"
  echo "$1" > "$state/current"
  echo "активен релиз $1 → $target"
}

case $cmd in
  activate)
    publish "$id"
    # чистка: оставить KEEP последних релизов, не трогая current/previous
    keep=$(cat "$state/current" "$state/previous" 2>/dev/null || true)
    ls -1t "$base" | tail -n +$((KEEP + 1)) | while read -r r; do
      echo "$keep" | grep -qx "$r" || rm -rf "${base:?}/$r"
    done ;;
  rollback)
    [ -n "$id" ] || id=$(cat "$state/previous" 2>/dev/null) || { echo "нет предыдущего релиза" >&2; exit 66; }
    publish "$id" ;;
  list)
    cur=$(cat "$state/current" 2>/dev/null || true)
    ls -1t "$base" | while read -r r; do [ "$r" = "$cur" ] && echo "* $r" || echo "  $r"; done ;;
  remove)
    case $slot in main) echo "main не удаляется" >&2; exit 64 ;; esac
    rm -rf "$target" "$base" "$state" ;;
  *) echo "unknown command: $cmd" >&2; exit 64 ;;
esac
