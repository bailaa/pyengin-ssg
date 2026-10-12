#!/usr/bin/env bash
# Проверка опубликованной сборки: HTTP 200 и <meta name="build-commit" content="$SHA"> в HTML.
# Использование: healthcheck.sh URL SHA [попыток=10]
# Код выхода: 0 — ок; 1 — ответ есть, но не тот (код/контрольная строка); 2 — сайт недоступен по сети.
set -uo pipefail
url=$1 sha=$2 tries=${3:-10}
body=$(mktemp)
for i in $(seq 1 "$tries"); do
  code=$(curl -sS -m 20 -o "$body" -w '%{http_code}' "$url" 2>/dev/null) || code=000
  if [[ $code == 200 ]] && grep -q "name=\"build-commit\" content=\"$sha\"" "$body"; then
    echo "OK: $url → 200, build-commit=$sha (попытка $i)"
    exit 0
  fi
  echo "попытка $i: HTTP $code, build-commit=$(grep -o 'build-commit" content="[0-9a-f]*' "$body" | cut -d'"' -f3 || true)"
  sleep 6   # CDN Pages и кэш Apache могут отдавать прежнюю версию несколько секунд
done
[[ $code == 000 ]] && { echo "::error::$url недоступен по сети"; exit 2; }
echo "::error::$url: ожидался HTTP 200 и build-commit=$sha"
exit 1
