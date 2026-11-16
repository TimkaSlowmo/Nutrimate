#!/usr/bin/env bash
# Проверка релизного APK на эмуляторе (CI, .github/workflows/apps.yml): установить, запустить, убедиться, что живо
# и не падает, снять скриншоты экранов. Экран для скриншота выбирается свойством debug.nutrimate.shot
# (его может выставить только adb; MainActivity превращает его в маршрут /shot/<экран> — демо-данные, ничего не сохраняется).
#   bash tool/ci/android_smoke.sh NutriMate-android.apk shots/android
set -u
APK=${1:-NutriMate-android.apk}
OUT=${2:-shots/android}
PKG=kz.innotech.nutrimate.app
ACT=$PKG/kz.innotech.nutrimate.MainActivity
LOG=logs
mkdir -p "$OUT" "$LOG"
A() { timeout 90 adb "$@"; }  # ни одна команда adb не может повесить проверку

A wait-for-device
A shell settings put global window_animation_scale 0 || true
A shell settings put global transition_animation_scale 0 || true
A shell settings put global animator_duration_scale 0 || true
A install -r -g "$APK" || { echo "::error::adb install failed"; exit 1; }
A shell dumpsys package $PKG | grep -E "versionName|versionCode" | head -2
A logcat -c || true

FAIL=0
alive() { A shell pidof $PKG >/dev/null; }
shot() { # имя, экран (пусто — обычный запуск), ожидание
  local name=$1 what=$2 wait=${3:-12}
  A shell am force-stop $PKG
  A shell setprop debug.nutrimate.shot "${what:-none}"
  A shell am start -n "$ACT" >/dev/null
  sleep "$wait"
  if ! alive; then
    echo "::error::NutriMate is not running after start ($name) — crash?"
    FAIL=1
  fi
  timeout 40 adb exec-out screencap -p > "$OUT/$name.png"
  local size
  size=$(stat -c %s "$OUT/$name.png")
  if [ "$size" -le 1000 ]; then
    # screencap внутри Android не всегда может прочитать кадр (эмулятор без GPU) — снимаем экран со стороны эмулятора
    echo "screencap: $(timeout 40 adb shell screencap -p /sdcard/s.png 2>&1 | head -3) rc=$?"
    timeout 40 adb emu screenrecord screenshot "$PWD/$OUT/$name.png" >/dev/null 2>&1 || true
    size=$(stat -c %s "$OUT/$name.png" 2>/dev/null || echo 0)
  fi
  [ "$size" -gt 1000 ] || { echo "::warning::empty screenshot $name"; rm -f "$OUT/$name.png"; }
  echo "📸 $name ($size bytes) $(date -u +%T)"
}

shot 00-onboarding "" 20
shot 01-home home
shot 02-fridge fridge
shot 03-search search
shot 04-recipes recipes
shot 05-chat chat
shot 06-photo-notice photo
shot 07-photo photosheet
shot 08-photo-review photoresult
shot 09-fridge-ru fridge-ru
shot 10-search-kk search-kk
shot 11-photo-review-ru photoresult-ru
A shell setprop debug.nutrimate.shot none || true

# обычный запуск снова (без демо) и живо ли спустя время (анимации Нутрика, таймеры)
A shell am force-stop $PKG
A shell am start -n "$ACT" >/dev/null
sleep 15
alive || { echo "::error::NutriMate died while idle"; FAIL=1; }

A logcat -d > "$LOG/logcat.txt" || true
if grep -E "Process: $PKG|Fatal signal.*$PKG|ANR in $PKG" "$LOG/logcat.txt" >/dev/null; then
  echo "::error::Crash in logcat:"
  grep -E -B 2 -A 20 "Process: $PKG|Fatal signal.*$PKG|ANR in $PKG" "$LOG/logcat.txt" | head -80
  FAIL=1
fi
grep -E "E/flutter" "$LOG/logcat.txt" | head -40 || true
echo "── render diagnostics ──"
grep -iE "screencap|impeller|vulkan|egl|SurfaceFlinger.*(err|fail|timeout)" "$LOG/logcat.txt" | grep -v "^--" | tail -30 || true
echo "FAIL=$FAIL"
exit $FAIL
