#!/usr/bin/env bash
# Проверка Android на эмуляторе (CI, .github/workflows/apps.yml).
#  1) РЕЛИЗНЫЙ APK (тот, что уходит людям): установить, запустить, убедиться, что живо и не падает, снять первый экран.
#  2) Скриншоты экранов: profile-сборка того же кода (релизный Flutter игнорирует intent-параметры от чужих
#     процессов, в т. ч. от adb — так и надо для безопасности), экраны открываются через extra «route» (/shot/<экран>):
#     демо-холодильник, ничего не сохраняется.
#   bash tool/ci/android_smoke.sh NutriMate-android.apk NutriMate-android-profile.apk shots/android
set -u
APK=${1:-NutriMate-android.apk}
SHOTS_APK=${2:-NutriMate-android-profile.apk}
OUT=${3:-shots/android}
PKG=kz.innotech.nutrimate.app
ACT=$PKG/kz.innotech.nutrimate.MainActivity
LOG=logs
mkdir -p "$OUT" "$LOG"

adb wait-for-device
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true

FAIL=0
alive() { adb shell pidof $PKG >/dev/null; }
shot() { # имя, маршрут (пусто — обычный запуск), ожидание
  local name=$1 route=$2 wait=${3:-12}
  adb shell am force-stop $PKG
  if [ -n "$route" ]; then
    adb shell am start -W -n "$ACT" --es route "$route" >/dev/null
  else
    adb shell am start -W -n "$ACT" >/dev/null
  fi
  sleep "$wait"
  if ! alive; then
    echo "::error::NutriMate is not running after start ($name) — crash?"
    FAIL=1
  fi
  adb exec-out screencap -p > "$OUT/$name.png"
  echo "📸 $name ($(stat -c %s "$OUT/$name.png") bytes)"
}
crashes() { # файл logcat → есть ли падения именно нашего процесса
  grep -E "Process: $PKG|Fatal signal.*$PKG|ANR in $PKG" "$1" >/dev/null
}

# ── 1. релизный APK ──
adb install -r -g "$APK" || { echo "::error::adb install of the release APK failed"; exit 1; }
adb shell dumpsys package $PKG | grep -E "versionName|versionCode" | head -2
adb logcat -c || true
shot 00-onboarding "" 20
sleep 10
alive || { echo "::error::release build died while idle"; FAIL=1; }
adb logcat -d > "$LOG/logcat-release.txt" || true
if crashes "$LOG/logcat-release.txt"; then
  echo "::error::Release build crashed:"
  grep -E -B 2 -A 20 "Process: $PKG|Fatal signal.*$PKG|ANR in $PKG" "$LOG/logcat-release.txt" | head -80
  FAIL=1
fi
grep -E "E/flutter" "$LOG/logcat-release.txt" | head -20 || true
echo "Release APK: FAIL=$FAIL"

# ── 2. скриншоты (profile-сборка поверх, та же подпись) ──
if [ -f "$SHOTS_APK" ]; then
  adb install -r -d -g "$SHOTS_APK" || { echo "::error::adb install of the profile APK failed"; exit 1; }
  adb logcat -c || true
  shot 01-home /shot/home
  shot 02-fridge /shot/fridge
  shot 03-search /shot/search
  shot 04-recipes /shot/recipes
  shot 05-chat /shot/chat
  shot 06-photo-notice /shot/photo
  shot 07-photo /shot/photosheet
  shot 08-photo-review /shot/photoresult
  shot 09-fridge-ru /shot/fridge-ru
  shot 10-search-kk /shot/search-kk
  shot 11-photo-review-ru /shot/photoresult-ru
  sleep 6
  alive || { echo "::error::NutriMate died while idle"; FAIL=1; }
  adb logcat -d > "$LOG/logcat-shots.txt" || true
  if crashes "$LOG/logcat-shots.txt"; then
    echo "::error::Crash during screenshots:"
    grep -E -B 2 -A 20 "Process: $PKG|Fatal signal.*$PKG|ANR in $PKG" "$LOG/logcat-shots.txt" | head -80
    FAIL=1
  fi
  grep -E "E/flutter" "$LOG/logcat-shots.txt" | head -40 || true
fi
echo "FAIL=$FAIL"
exit $FAIL
