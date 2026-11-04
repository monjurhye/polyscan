#!/usr/bin/env bash
# Runs inside the emulator step of play-screenshots.yml.
set -euo pipefail

PKG=com.pickixo.polyscan
OUT=store/play/screenshots
mkdir -p "$OUT"
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# A plain status bar: 9:41, full signal and battery, no notifications.
adb shell settings put global sysui_demo_allowed 1
demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4 -e fully true
demo network -e mobile show -e level 4 -e fully true -e datatype none
demo notifications -e visible false

shoot() { # shoot <prefix>
  local n=1
  for scene in documents bangla page arabic languages; do
    adb shell am force-stop "$PKG"
    # getApplicationDocumentsDirectory() is app_flutter on Android.
    adb shell "run-as $PKG sh -c 'mkdir -p app_flutter && printf $scene > app_flutter/screenshot_scene.txt'"
    adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
    sleep 20
    adb exec-out screencap -p > "$OUT/$1-$n-$scene.png"
    n=$((n+1))
  done
}

# Warm-up, so first-launch system banners time out before the first picture.
adb shell "run-as $PKG sh -c 'mkdir -p app_flutter && printf documents > app_flutter/screenshot_scene.txt'"
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 60

shoot phone

adb shell wm size 1600x2560
adb shell wm density 320
sleep 5
shoot tablet

adb shell wm size reset
adb shell wm density reset
ls -la "$OUT"
