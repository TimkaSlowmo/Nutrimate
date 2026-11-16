#!/usr/bin/env bash
# Проверка APK на эмуляторе (CI, .github/workflows/apps.yml): установить, запустить, убедиться, что приложение
# живо и не падает, снять скриншоты экранов. Экраны открываются через intent-extra «route» (/shot/<экран>) —
# приложение в этом режиме показывает демо-холодильник и ничего не сохраняет.
#   bash tool/ci/android_smoke.sh NutriMate-android.apk shots/android
set -u
APK=${1:-NutriMate-android.apk}
OUT=${2:-shots/android}
PKG=kz.innotech.nutrimate.app
ACT=$PKG/kz.innotech.nutrimate.MainActivity
LOG=logs
mkdir -p "$OUT" "$LOG"

adb wait-for-device
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true
adb install -r -g "$APK" || { echo "::error::adb install failed"; exit 1; }
adb shell dumpsys package $PKG | grep -E "versionName|versionCode" | head -2
adb logcat -c || true

FAIL=0
shot() { # имя, маршрут (пусто — обычный запуск), ожидание
  local name=$1 route=$2 wait=${3:-12}
  adb shell am force-stop $PKG
  if [ -n "$route" ]; then
    adb shell am start -W -n "$ACT" --es route "$route" >/dev/null
  else
    adb shell am start -W -n "$ACT" >/dev/null
  fi
  sleep "$wait"
  if ! adb shell pidof $PKG >/dev/null; then
    echo "::error::NutriMate is not running after start ($name) — crash?"
    FAIL=1
  fi
  adb exec-out screencap -p > "$OUT/$name.png"
  echo "📸 $name ($(stat -c %s "$OUT/$name.png") bytes)"
}

shot 00-onboarding "" 20
shot 01-home /shot/home
shot 02-fridge /shot/fridge
shot 03-search /shot/search
shot 04-recipes /shot/recipes
shot 05-chat /shot/chat
shot 06-fridge-ru /shot/fridge-ru
shot 07-search-kk /shot/search-kk

# живо ли спустя время (анимации Нутрика, таймеры)
sleep 8
adb shell pidof $PKG >/dev/null || { echo "::error::NutriMate died while idle"; FAIL=1; }

adb logcat -d > "$LOG/logcat.txt" || true
# падения именно нашего процесса (системные процессы эмулятора не считаем)
if grep -E "Process: $PKG|Fatal signal.*$PKG|ANR in $PKG" "$LOG/logcat.txt" >/dev/null; then
  echo "::error::Crash in logcat:"
  grep -E -B 2 -A 20 "Process: $PKG|Fatal signal.*$PKG|ANR in $PKG" "$LOG/logcat.txt" | head -80
  FAIL=1
fi
# необработанные ошибки Dart — видно в логе, но это не падение
grep -E "E/flutter" "$LOG/logcat.txt" | head -40 || true
grep -E "E/flutter" "$LOG/logcat.txt" > "$LOG/flutter-errors.txt" || true
echo "FAIL=$FAIL"
exit $FAIL
