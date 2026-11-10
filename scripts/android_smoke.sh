#!/usr/bin/env bash
# Android emulator + UI smoke helper.
#
# Usage:
#   scripts/android_smoke.sh create [avd]      create the AVD
#   scripts/android_smoke.sh start [avd]       start headless emulator
#   scripts/android_smoke.sh wait              wait for sys.boot_completed=1
#   scripts/android_smoke.sh install [apk]     adb install -r -t
#   scripts/android_smoke.sh launch            launch the app and check its pid
#   scripts/android_smoke.sh shot [name]       save a screenshot
#   scripts/android_smoke.sh logcat [file]     dump logcat
#   scripts/android_smoke.sh dump              print the uiautomator hierarchy
#   scripts/android_smoke.sh tap <text>        tap the first matching node
#   scripts/android_smoke.sh tap-tab <text>    tap the lowest matching node (bottom nav)
#   scripts/android_smoke.sh back              press the system back key
#   scripts/android_smoke.sh smoke [apk]       start, wait, install, launch, shot, logcat
#   scripts/android_smoke.sh status            show adb state
#   scripts/android_smoke.sh stop              stop the emulator
#
# Environment:
#   ANDROID_HOME   default $HOME/Android/Sdk
#   AVD            default huayan_atd
#   EMULATOR_PORT  default 5554
#   APP_ID         default edu.buct.graduate.huayan
#   APK            default app/build/app/outputs/flutter-apk/app-debug.apk
#   ARTIFACTS      default .artifacts (gitignored)
#   BOOT_TIMEOUT   default 900 seconds
#   FIRST_FRAME_TIMEOUT  default 600 seconds
#
# On machines without /dev/kvm the emulator runs with -accel off (TCG).
# TCG is slow: keep the emulator running between iterations and use
# `start`/`stop` only when needed.

set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
AVD="${AVD:-huayan_atd}"
EMULATOR_PORT="${EMULATOR_PORT:-5554}"
SERIAL="emulator-$EMULATOR_PORT"
APP_ID="${APP_ID:-edu.buct.graduate.huayan}"
APK="${APK:-app/build/app/outputs/flutter-apk/app-debug.apk}"
ARTIFACTS="${ARTIFACTS:-.artifacts}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-900}"
FIRST_FRAME_TIMEOUT="${FIRST_FRAME_TIMEOUT:-600}"
IMAGE="${IMAGE:-system-images;android-35;aosp_atd;x86_64}"
DEVICE_PROFILE="${DEVICE_PROFILE:-pixel_5}"

ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR="$ANDROID_HOME/emulator/emulator"
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"

die() { echo "error: $*" >&2; exit 1; }

need_adb() { [ -x "$ADB" ] || die "adb not found: $ADB"; }
need_emulator() { need_adb; [ -x "$EMULATOR" ] || die "emulator not found: $EMULATOR"; }

is_known_serial() {
  "$ADB" devices 2>/dev/null | awk -v s="$SERIAL" '$1 == s { found = 1 } END { exit !found }'
}

cmd_create() {
  local name="${1:-$AVD}"
  [ -x "$AVDMANAGER" ] || die "avdmanager not found: $AVDMANAGER"
  echo no | "$AVDMANAGER" create avd -n "$name" -k "$IMAGE" -d "$DEVICE_PROFILE" --force
  echo "created AVD $name from $IMAGE"
}

cmd_start() {
  local name="${1:-$AVD}"
  need_emulator
  if is_known_serial; then
    echo "$SERIAL is already registered with adb"
    return 0
  fi
  mkdir -p "$ARTIFACTS"
  local args=(
    -avd "$name"
    -no-window
    -no-audio
    -no-boot-anim
    -gpu swiftshader_indirect
    -no-snapshot
    -memory 2048
    -cores 4
  )
  if [ ! -e /dev/kvm ]; then
    args+=(-accel off)
  fi
  nohup "$EMULATOR" "${args[@]}" > "$ARTIFACTS/emulator.log" 2>&1 &
  echo $! > "$ARTIFACTS/emulator.pid"
  echo "started $name (pid $(cat "$ARTIFACTS/emulator.pid"), log $ARTIFACTS/emulator.log)"
}

cmd_wait() {
  need_adb
  local started=$SECONDS
  "$ADB" start-server >/dev/null 2>&1 || true
  while [ $((SECONDS - started)) -lt "$BOOT_TIMEOUT" ]; do
    local boot
    boot="$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [ "$boot" = "1" ]; then
      echo "boot completed in $((SECONDS - started))s"
      return 0
    fi
    sleep 5
  done
  die "boot timeout after ${BOOT_TIMEOUT}s; see $ARTIFACTS/emulator.log"
}

cmd_install() {
  need_adb
  local apk="${1:-$APK}"
  [ -f "$apk" ] || die "APK not found: $apk"
  "$ADB" -s "$SERIAL" install -r -t "$apk"
}

cmd_launch() {
  need_adb
  mkdir -p "$ARTIFACTS"
  "$ADB" -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  "$ADB" -s "$SERIAL" shell wm dismiss-keyguard >/dev/null 2>&1 || true
  "$ADB" -s "$SERIAL" shell svc power stayon true >/dev/null 2>&1 || true
  "$ADB" -s "$SERIAL" logcat -c >/dev/null 2>&1 || true
  "$ADB" -s "$SERIAL" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
    || die "could not launch $APP_ID"
  local started=$SECONDS
  while [ $((SECONDS - started)) -lt "$FIRST_FRAME_TIMEOUT" ]; do
    local pid
    pid="$("$ADB" -s "$SERIAL" shell pidof "$APP_ID" 2>/dev/null | tr -d '\r' || true)"
    if [ -n "$pid" ] && "$ADB" -s "$SERIAL" logcat -d -v brief 2>/dev/null | grep -q "Displayed $APP_ID"; then
      echo "$pid" > "$ARTIFACTS/app.pid"
      echo "app pid $pid (first frame ready in $((SECONDS - started))s)"
      return 0
    fi
    sleep 5
  done
  die "first frame timeout after ${FIRST_FRAME_TIMEOUT}s; check logcat"
}

cmd_shot() {
  need_adb
  mkdir -p "$ARTIFACTS/screenshots"
  local name="${1:-screen-$(date +%H%M%S)}"
  "$ADB" -s "$SERIAL" exec-out screencap -p > "$ARTIFACTS/screenshots/$name.png"
  echo "$ARTIFACTS/screenshots/$name.png"
}

cmd_logcat() {
  need_adb
  mkdir -p "$ARTIFACTS"
  local out="${1:-$ARTIFACTS/logcat.txt}"
  "$ADB" -s "$SERIAL" logcat -d -v time > "$out"
  echo "$out"
}

cmd_dump() {
  need_adb
  "$ADB" -s "$SERIAL" shell uiautomator dump /sdcard/window.xml >/dev/null
  "$ADB" -s "$SERIAL" exec-out cat /sdcard/window.xml
}

cmd_tap() {
  local text="${1:-}"
  [ -n "$text" ] || die "usage: $0 tap <text>"
  need_adb
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local coords
  coords="$(cmd_dump | python3 "$here/tap_text.py" "$text")" || die "could not find '$text' on screen"
  # shellcheck disable=SC2086
  "$ADB" -s "$SERIAL" shell input tap $coords
  echo "tapped '$text' at $coords"
}

cmd_tap_tab() {
  local text="${1:-}"
  [ -n "$text" ] || die "usage: $0 tap-tab <text>"
  need_adb
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local coords
  coords="$(cmd_dump | python3 "$here/tap_text.py" --bottom "$text")" || die "could not find '$text' on screen"
  # shellcheck disable=SC2086
  "$ADB" -s "$SERIAL" shell input tap $coords
  echo "tapped tab '$text' at $coords"
}

cmd_back() {
  need_adb
  "$ADB" -s "$SERIAL" shell input keyevent 4
  echo "pressed back"
}

cmd_smoke() {
  cmd_start
  cmd_wait
  cmd_install "${1:-$APK}"
  "$ADB" -s "$SERIAL" logcat -c || true
  cmd_launch
  cmd_shot smoke
  cmd_logcat
  local app_pid
  app_pid="$(cat "$ARTIFACTS/app.pid")"
  if "$ADB" -s "$SERIAL" logcat -d --pid="$app_pid" -v brief | grep -qE 'FATAL EXCEPTION|AndroidRuntime.*FATAL'; then
    die "fatal exception in $APP_ID; see $ARTIFACTS/logcat.txt"
  fi
  echo "smoke ok"
}

cmd_status() {
  need_adb
  "$ADB" devices
  local boot
  boot="$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  echo "sys.boot_completed=${boot:-unknown}"
}

cmd_stop() {
  need_adb
  "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
  if [ -f "$ARTIFACTS/emulator.pid" ]; then
    local pid
    pid="$(cat "$ARTIFACTS/emulator.pid")"
    for _ in 1 2 3 4 5; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    kill "$pid" 2>/dev/null || true
    rm -f "$ARTIFACTS/emulator.pid"
  fi
  echo "emulator stopped"
}

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

command="${1:-help}"
shift || true
case "$command" in
  create) cmd_create "$@" ;;
  start) cmd_start "$@" ;;
  wait) cmd_wait ;;
  install) cmd_install "$@" ;;
  launch) cmd_launch ;;
  shot) cmd_shot "$@" ;;
  logcat) cmd_logcat "$@" ;;
  dump) cmd_dump ;;
  tap) cmd_tap "$@" ;;
  tap-tab) cmd_tap_tab "$@" ;;
  back) cmd_back ;;
  smoke) cmd_smoke "$@" ;;
  status) cmd_status ;;
  stop) cmd_stop ;;
  help | -h | --help) usage ;;
  *) echo "unknown command: $command" >&2; usage >&2; exit 2 ;;
esac
