#!/usr/bin/env bash
# Однократная настройка Helios для деплоя из CI. Запускается ЛОКАЛЬНО, из сети, где Helios доступен
# (без зарубежного VPN), спросит пароль Helios один раз (https://se.ifmo.ru/passwd/):
#   scripts/helios-bootstrap.sh s123456 ~/.ssh/pyengin-ssg-deploy.pub
# Что делает на сервере: проверяет rsync/curl, ставит шлюз ~/ssg/bin/ssg-gate.sh,
# создаёт ~/public_html, дописывает deploy-ключ в authorized_keys с restrict,command=…
# и печатает отпечатки ключей хоста для сверки с HELIOS_KNOWN_HOSTS.
set -euo pipefail
user=$1 pub=$(cat "$2")
here=$(cd "$(dirname "$0")" && pwd)
{
  echo 'set -eu'
  echo 'echo "== $(uname -sr), $(hostname)"'
  echo 'for t in rsync curl fetch logger; do printf "%-7s %s\n" "$t" "$(command -v $t || echo НЕТ)"; done'
  echo 'mkdir -p ~/ssg/bin ~/public_html ~/.ssh && chmod 700 ~/.ssh && chmod 755 ~ ~/public_html'
  echo "cat > ~/ssg/bin/ssg-gate.sh <<'GATE_EOF'"
  cat "$here/helios-gate.sh"
  echo 'GATE_EOF'
  echo 'chmod 755 ~/ssg/bin/ssg-gate.sh'
  echo "line='restrict,command=\"'\$HOME'/ssg/bin/ssg-gate.sh\" $pub'"
  echo 'touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
  echo 'grep -qF "$(echo "$line" | cut -d" " -f3)" ~/.ssh/authorized_keys || echo "$line" >> ~/.ssh/authorized_keys'
  echo 'echo "== authorized_keys:"; grep -n ssg-gate ~/.ssh/authorized_keys | cut -c1-120'
  echo 'echo "== host keys:"; for f in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -lf "$f"; done'
} | ssh -p 2222 -o StrictHostKeyChecking=ask "$user@helios.cs.ifmo.ru" 'sh -s'
