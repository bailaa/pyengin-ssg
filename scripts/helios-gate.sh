#!/bin/sh
# Шлюз для deploy-ключа на Helios (FreeBSD, POSIX sh). Устанавливается один раз в ~/ssg/bin/ssg-gate.sh
# и прописывается в ~/.ssh/authorized_keys как принудительная команда:
#   restrict,command="$HOME/ssg/bin/ssg-gate.sh" ssh-ed25519 AAAA... pyengin-ssg-deploy
# Ключ CI не получает shell: разрешены только rsync В каталог релизов и подкоманды ниже.
# Сам шлюз ключом изменить нельзя — rsync пишет только в ~/ssg/releases/.
#
#   ssg current  <slot>              — id текущего релиза (пусто, если нет)
#   ssg activate <slot> <id>         — выложить релиз (rsync релиза в public_html)
#   ssg rollback <slot> [id]         — вернуть предыдущий или указанный релиз
#   ssg list     <slot>              — релизы, * — текущий
#   ssg remove   <slot>              — удалить preview ветки
#   ssg check    <url> <sha>         — healthcheck изнутри Helios
# slot: main → ~/public_html/ ; preview-<ветка> → ~/public_html/preview/<ветка>/
set -eu
umask 022
KEEP=${KEEP:-5}
ID_RE='^[A-Za-z0-9._-]{1,80}$'

deny() { echo "ssg-gate: запрещено: $*" >&2; logger -t ssg-gate "denied: $*" 2>/dev/null || true; exit 77; }
valid() { printf '%s' "$1" | grep -Eq "$ID_RE" && [ "$1" != . ] && [ "$1" != .. ]; }

cmd=${SSH_ORIGINAL_COMMAND:-}
[ -n "$cmd" ] || deny "интерактивный вход"
case $cmd in *[\;\&\|\`\$\<\>\(\)\\\'\"]*) deny "спецсимволы: $cmd" ;; esac
# shellcheck disable=SC2086
set -f; set -- $cmd; set +f

# ---------- rsync: только приём файлов в ~/ssg/releases/<slot>/<id>/ ----------
if [ "$1" = rsync ]; then
  [ "${2:-}" = --server ] || deny "$cmd"
  shift 2
  dest=""; prev=""
  for a in "$@"; do
    if [ "$prev" = --link-dest ]; then
      case $a in ../*) valid "${a#../}" || deny "link-dest $a" ;; *) deny "link-dest $a" ;; esac
      prev=""; continue
    fi
    case $a in
      --sender) deny "чтение с сервера" ;;
      --delete|--delete-after|--delete-during|--delete-delay) ;;
      --link-dest) prev=--link-dest ;;
      --link-dest=../*) valid "${a#--link-dest=../}" || deny "$a" ;;
      --*) deny "опция $a" ;;
      -*) printf '%s' "$a" | grep -Eq '^-[A-Za-z.]+$' || deny "опция $a" ;;
      .) ;;
      ssg/releases/*) dest=$a ;;
      *) deny "аргумент $a" ;;
    esac
  done
  d=${dest#ssg/releases/}; d=${d%/}
  slot=${d%%/*}; id=${d#*/}
  { [ -n "$dest" ] && valid "$slot" && valid "$id" && [ "$slot/$id" = "$d" ]; } || deny "путь $dest"
  mkdir -p "$HOME/ssg/releases/$slot"
  cd "$HOME"
  exec $cmd
fi

# ---------- подкоманды ssg ----------
[ "$1" = ssg ] || deny "$cmd"
sub=${2:-}; slot=${3:-}; id=${4:-}

if [ "$sub" = check ]; then
  url=$slot sha=$id
  printf '%s' "$url" | grep -Eq '^https://se\.ifmo\.ru/~[a-z0-9]+/[A-Za-z0-9._/-]*$' || deny "url $url"
  printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$' || deny "sha $sha"
  i=0
  while [ $i -lt 5 ]; do
    i=$((i + 1))
    body=$(curl -s -m 20 -w '\n%{http_code}' "$url" 2>/dev/null || fetch -q -o - "$url" 2>/dev/null || true)
    code=$(printf '%s' "$body" | tail -n 1)
    if [ "$code" = 200 ] && printf '%s' "$body" | grep -q "name=\"build-commit\" content=\"$sha\""; then
      echo "OK (с Helios): $url → 200, build-commit=$sha (попытка $i)"; exit 0
    fi
    echo "попытка $i (с Helios): HTTP $code"; sleep 5
  done
  exit 1
fi

valid "$slot" || deny "slot $slot"
case $slot in
  main)      target=$HOME/public_html; excl="--exclude=/preview/" ;;
  preview-*) target=$HOME/public_html/preview/${slot#preview-}; excl="" ;;
  *) deny "slot $slot" ;;
esac
base=$HOME/ssg/releases/$slot
state=$HOME/ssg/state/$slot
mkdir -p "$base" "$state"

publish() {
  valid "$1" || deny "id $1"
  [ -f "$base/$1/index.html" ] || { echo "релиз $1 неполный или отсутствует" >&2; exit 65; }
  mkdir -p "$target"
  # Релиз уже целиком лежит в releases/, здесь копирование внутри сервера (секунды).
  # SIGHUP игнорируем: если SSH-сессия раннера оборвётся, копирование всё равно дойдёт до конца.
  trap '' HUP PIPE
  rsync -a --checksum --delete $excl "$base/$1/" "$target/"
  chmod -R a+rX "$target"
  cur=$(cat "$state/current" 2>/dev/null || true)
  if [ -n "$cur" ] && [ "$cur" != "$1" ]; then echo "$cur" > "$state/previous"; fi
  echo "$1" > "$state/current"
  echo "активен релиз $1 → $target"
}

case $sub in
  current) cat "$state/current" 2>/dev/null || true ;;
  activate)
    publish "$id"
    keep=$(cat "$state/current" "$state/previous" 2>/dev/null || true)
    ls -1t "$base" | tail -n +$((KEEP + 1)) | while read -r r; do
      echo "$keep" | grep -qx "$r" || rm -rf "${base:?}/$r"
    done ;;
  rollback)
    if [ -z "$id" ]; then id=$(cat "$state/previous" 2>/dev/null || true); fi
    [ -n "$id" ] || { echo "нет предыдущего релиза" >&2; exit 66; }
    publish "$id" ;;
  list)
    cur=$(cat "$state/current" 2>/dev/null || true)
    ls -1t "$base" | while read -r r; do if [ "$r" = "$cur" ]; then echo "* $r"; else echo "  $r"; fi; done ;;
  remove)
    [ "$slot" != main ] || deny "удаление main"
    rm -rf "${target:?}" "${base:?}" "${state:?}" ;;
  *) deny "подкоманда $sub" ;;
esac
