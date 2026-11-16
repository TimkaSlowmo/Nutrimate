#!/usr/bin/env bash
# Проверка Linux-сборки (CI): запустить под Xvfb, убедиться, что не упала, снять скриншоты
# (окно телефонного размера и широкое окно — колонка по центру).
#   xvfb-run -a -s "-screen 0 1440x960x24" bash tool/ci/linux_smoke.sh NutriMate shots/desktop
set -u
APP_DIR=${1:-NutriMate}
OUT=${2:-shots/desktop}
mkdir -p "$OUT" logs
FAIL=0

run() { # имя экрана (--shot), имя файла
  local what=$1 name=$2
  "$APP_DIR/NutriMate" --shot "$what" > "logs/linux-$what.log" 2>&1 &
  local pid=$!
  sleep 14
  if ! kill -0 $pid 2>/dev/null; then
    echo "::error::NutriMate (Linux) exited early on --shot $what"
    tail -40 "logs/linux-$what.log"
    FAIL=1
    return
  fi
  local wid
  wid=$(xdotool search --pid $pid 2>/dev/null | tail -1)
  if [ -n "$wid" ]; then
    import -window "$wid" "$OUT/$name.png" || true
    # широкое окно: интерфейс не растягивается, колонка по центру на бордовом фоне
    xdotool windowsize "$wid" 1280 860 && sleep 8 && import -window "$wid" "$OUT/$name-wide.png" || true
  else
    import -window root "$OUT/$name.png" || true
  fi
  sleep 2
  kill -0 $pid 2>/dev/null || { echo "::error::NutriMate (Linux) died during the test"; FAIL=1; }
  kill $pid 2>/dev/null
  wait $pid 2>/dev/null
  echo "📸 $name"
}

run home linux-home
run fridge linux-fridge
run photoresult linux-photo-review
ls -la "$OUT"
exit $FAIL
