#!/bin/sh
# Builds the app, installs it on an iPad and launches it, without opening Xcode.
#   scripts/install-ipad.sh   -> lists the paired iPads/iPhones, asks which one, then builds, installs and launches
# The device must be paired with this Mac once (in Xcode, or by plugging it in and tapping Trust), with Developer Mode on.
# Free Apple ID: the app stops opening after 7 days; run this again.
set -e
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

xcrun devicectl list devices --json-output "$TMP/devices.json" >/dev/null
# One line per iOS device: devicectl id, UDID (for xcodebuild), name, connection state.
python3 - "$TMP/devices.json" > "$TMP/devices.txt" <<'EOF'
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    hw, conn = d["hardwareProperties"], d["connectionProperties"]
    if hw.get("platform") != "iOS":
        continue
    print("\t".join([d["identifier"], hw.get("udid", ""), d["deviceProperties"].get("name", "?"),
                     conn.get("tunnelState", "?")]))
EOF

COUNT=$(wc -l < "$TMP/devices.txt" | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
  echo "No paired iPad found. Plug it in, unlock it, tap Trust, and turn on Developer Mode." >&2
  exit 1
fi

echo "Devices:"
awk -F '\t' '{ printf "  %d) %s\n", NR, $3 }' "$TMP/devices.txt"
if [ "$COUNT" -eq 1 ]; then
  CHOICE=1
else
  printf "Which one? [1-%s] " "$COUNT"
  read -r CHOICE
fi
LINE=$(sed -n "${CHOICE}p" "$TMP/devices.txt")
if [ -z "$LINE" ]; then
  echo "No device number $CHOICE." >&2
  exit 1
fi
DEVICE_ID=$(printf '%s' "$LINE" | cut -f1)
UDID=$(printf '%s' "$LINE" | cut -f2)
NAME=$(printf '%s' "$LINE" | cut -f3)

echo "Building for $NAME..."
[ -d PianoGuide.xcodeproj ] || xcodegen generate
# Xcode's own DerivedData (no -derivedDataPath), so this and Xcode share one build cache.
BUILD="xcodebuild -project PianoGuide.xcodeproj -scheme PianoGuide -configuration Debug -destination platform=iOS,id=$UDID"
$BUILD -allowProvisioningUpdates -quiet build
PRODUCTS=$($BUILD -showBuildSettings 2>/dev/null | awk -F ' = ' '/ BUILT_PRODUCTS_DIR = / { print $2; exit }')

echo "Installing on $NAME..."
xcrun devicectl device install app --device "$DEVICE_ID" "$PRODUCTS/PianoGuide.app"
echo "Launching..."
xcrun devicectl device process launch --device "$DEVICE_ID" com.esnetsm.pianoguide
