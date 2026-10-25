#!/usr/bin/env bash
# Boots an iOS simulator on the CI Mac, opens Echo Lap on chosen screens and saves screenshots.
# Usage: tools/ci/screenshots.sh <path to EchoLap.app> <output folder> <phone|small|pad>
# One device per call, so each can have its own time limit in the workflow. Scenes come from ScreenshotScene.swift.
set -uo pipefail
APP="$1"; OUT="$2"; WHICH="${3:-phone}"; BUNDLE="${BUNDLE_ID:-com.echolap.app}"
mkdir -p "$OUT"
log() { echo "[$(date +%H:%M:%S)] $*"; }
# Any single simulator command that hangs is killed after N seconds, so one stuck device cannot block the whole job.
limit() { local secs="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }

udid() { xcrun simctl list devices available | grep -E "$1" | tail -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
# Every matching simulator, newest runtime first: if one hangs while booting, the next is tried.
udids() { xcrun simctl list devices available | grep -E "$1" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' | sed '1!G;h;$!d'; }

PHONE=$(udids 'iPhone [0-9]+ Pro Max' | head -3 | tr '\n' ' ')
[ -z "${PHONE// /}" ] && PHONE=$(udids 'iPhone .*Pro Max' | head -3 | tr '\n' ' ')
SMALL=$(udid 'iPhone SE')
SMALL_LABEL=iphone-se
if [ -z "$SMALL" ] && [ "$WHICH" = small ]; then
  # Recent Xcode images ship no iPhone SE simulator; create the smallest phone the newest runtime still supports.
  RUNTIME=$(xcrun simctl list runtimes available | grep -E "^iOS" | tail -1 | sed -E 's/.* - (com\.apple\.CoreSimulator\.SimRuntime\.[^ ]+).*/\1/')
  echo "runtime=${RUNTIME:-none}"
  for NAME in "iPhone SE (3rd generation)" "iPhone SE (2nd generation)" "iPhone 13 mini" "iPhone 12 mini" "iPhone 16e"; do
    [ -z "$RUNTIME" ] && break
    SE_TYPE=$(xcrun simctl list devicetypes | grep -F "$NAME (com.apple" | head -1 | sed -E 's/.*\((com\.apple\.CoreSimulator\.SimDeviceType\.[^)]*)\).*/\1/')
    [ -z "$SE_TYPE" ] && continue
    NEWDEV=$(xcrun simctl create "EchoLap small" "$SE_TYPE" "$RUNTIME" 2>&1 | tail -1)
    case "$NEWDEV" in
      [0-9A-F]*-*-*-*-*) SMALL="$NEWDEV"; echo "created a $NAME simulator: $SMALL"; SMALL_LABEL=$(echo "$NAME" | tr 'A-Z ' 'a-z-' | tr -d '()'); break ;;
      *) echo "could not create $NAME: $NEWDEV" ;;
    esac
  done
fi
PAD=$(udid 'iPad Pro 13-inch')
[ -z "$PAD" ] && PAD=$(udid 'iPad Pro 12.9-inch')
echo "phone=$PHONE small=$SMALL pad=$PAD"

# Each entry: scene|seconds to wait|extra launch arguments.
# The race scenes run the robot driver; -EchoFastForward speeds the simulation so echoes have built up.
SCENES=(
  "intro|8|"
  "home|6|"
  "race|16|-EchoFastForward 1"
  "results|24|-EchoFastForward 4"
  "world|8|"
  "daily|6|"
  "garage|5|"
  "trophies|5|"
)

shoot_device() {   # <label> <"udid [udid...]">: the first simulator that boots is used
  local label="$1" candidates="$2" id=""
  [ -z "${candidates// /}" ] && { echo "no simulator for $label, skipping"; return; }
  for c in $candidates; do
    log "boot $label ($c)"
    limit 60 xcrun simctl boot "$c" 2>&1 || log "boot returned $?"
    if limit 300 xcrun simctl bootstatus "$c" -b >/dev/null 2>&1; then id="$c"; break; fi
    log "boot of $label ($c) did not finish, trying the next simulator"
    limit 60 xcrun simctl shutdown "$c" 2>/dev/null
  done
  [ -z "$id" ] && { log "no $label simulator would boot, skipping"; return; }
  limit 30 xcrun simctl status_bar "$id" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --operatorName "" 2>/dev/null
  log "install on $label"
  limit 120 xcrun simctl install "$id" "$APP" || { log "install failed on $label"; return; }
  # A cold first launch on a fresh simulator can take longer than any scene's wait: warm the app up once first.
  limit 60 xcrun simctl launch "$id" "$BUNDLE" -EchoScene home >/dev/null 2>&1 || true
  sleep 12
  limit 30 xcrun simctl terminate "$id" "$BUNDLE" >/dev/null 2>&1
  sleep 2
  for entry in "${SCENES[@]}"; do
    IFS='|' read -r scene wait extra <<< "$entry"
    log "$label: $scene"
    limit 30 xcrun simctl terminate "$id" "$BUNDLE" >/dev/null 2>&1
    sleep 2   # let the previous run (often a busy race) shut down before relaunching
    # shellcheck disable=SC2086
    limit 60 xcrun simctl launch "$id" "$BUNDLE" -EchoScene "$scene" $extra || log "launch failed: $scene"
    sleep "$wait"
    # A busy simulator (a race running fast-forward) can make one capture stall; try once more before giving up.
    limit 60 xcrun simctl io "$id" screenshot "$OUT/${label}_${scene}.png" \
      || { sleep 3; limit 90 xcrun simctl io "$id" screenshot "$OUT/${label}_${scene}.png"; } \
      || log "screenshot failed: $scene"
  done
  limit 60 xcrun simctl shutdown "$id" 2>/dev/null
}

case "$WHICH" in
  phone) shoot_device iphone-pro-max "$PHONE" ;;
  small) shoot_device "$SMALL_LABEL" "$SMALL" ;;
  pad)   shoot_device ipad-pro-13 "$PAD" ;;
esac
ls -la "$OUT"
for entry in "${SCENES[@]}"; do   # one line per missing scene, so the workflow log shows it
  scene="${entry%%|*}"
  ls "$OUT"/*_"$scene".png >/dev/null 2>&1 || echo "MISSING: $scene"
done
