#!/usr/bin/env bash
# Runs inside the emulator step of android-release-launch.yml. Keeps going after a failed
# launch, so the logs are still collected; the last line fails the job if the app died.
set -uo pipefail

PKG=com.pickixo.polyscan
OUT=launch-results
mkdir -p "$OUT"

if ! adb install -r build/app/outputs/flutter-apk/app-release.apk > "$OUT/install.txt" 2>&1; then
  cat "$OUT/install.txt"
  echo "::error title=Launch::install failed"
  exit 1
fi

launch() { # launch <name>
  local name=$1 alive=no
  adb logcat -c
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
  for wait in 5 15 30; do
    sleep "$wait"
    adb exec-out screencap -p > "$OUT/$name-after-$wait.png"
  done
  adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' > "$OUT/$name-focus.txt"
  adb logcat -d -v time > "$OUT/$name-logcat.txt"
  # Android restarts a crashed app, so a live process alone doesn't prove it works.
  if adb shell pidof "$PKG" >/dev/null 2>&1 \
    && ! grep -q 'FATAL EXCEPTION\|Fatal signal' "$OUT/$name-logcat.txt" \
    && ! grep -q 'Application Error' "$OUT/$name-focus.txt"; then
    alive=yes
  fi
  grep -E 'FATAL EXCEPTION|AndroidRuntime|Unhandled Exception|flutter|MissingPlugin|PlatformException|ClassNotFound|NoSuchMethod|UnsatisfiedLink|ANR in|Force finishing' \
    "$OUT/$name-logcat.txt" > "$OUT/$name-errors.txt"
  echo "$name: alive=$alive, focus: $(tr -s ' ' < "$OUT/$name-focus.txt" | head -1)" | tee -a "$OUT/summary.txt"
  [ "$alive" = yes ]
}

status=0
launch first || status=1
adb shell am force-stop "$PKG"
launch second || status=1

sed 's/^/::notice title=Launch::/' "$OUT/summary.txt"
exit $status
