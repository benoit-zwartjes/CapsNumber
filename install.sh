#!/bin/bash
# CapsNumber installer.
#
#   One line, no build tools needed (downloads the latest release):
#     curl -fsSL https://raw.githubusercontent.com/benoit-zwartjes/CapsNumber/main/install.sh | bash
#
#   From a clone of the repository (builds from source if Xcode tools are present):
#     ./install.sh
set -euo pipefail

REPO="benoit-zwartjes/CapsNumber"
ZIP_URL="${CAPSNUMBER_ZIP_URL:-https://github.com/$REPO/releases/latest/download/CapsNumber.app.zip}"
LABEL="be.benoit.CapsNumber"
APP_NAME="CapsNumber.app"
DEST="$HOME/Applications/$APP_NAME"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/CapsNumber.log"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "CapsNumber only runs on macOS." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. Get the app: build it if we are inside the repo with Xcode tools, otherwise download it.
if [ -f "$SCRIPT_DIR/Sources/main.swift" ] && xcode-select -p >/dev/null 2>&1; then
    echo "Building from source..."
    "$SCRIPT_DIR/build.sh"
    SRC_APP="$SCRIPT_DIR/build/$APP_NAME"
else
    echo "Downloading the latest release..."
    curl -fsSL "$ZIP_URL" -o "$TMP/$APP_NAME.zip"
    ditto -x -k "$TMP/$APP_NAME.zip" "$TMP/unzipped"
    SRC_APP="$TMP/unzipped/$APP_NAME"
    if [ ! -d "$SRC_APP" ]; then
        echo "The download did not contain $APP_NAME." >&2
        exit 1
    fi
fi

# 2. Stop any previous copy. Remember its code hash: if the new build differs, macOS will
#    not trust the old Accessibility approval, so we clear it to get a fresh prompt.
cdhash() { codesign -dvvv "$1" 2>&1 | sed -n 's/^CDHash=//p' | head -n 1; }
OLD_HASH=""
if [ -d "$DEST" ]; then OLD_HASH="$(cdhash "$DEST")"; fi
NEW_HASH="$(cdhash "$SRC_APP")"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x CapsNumber 2>/dev/null || true

# 3. Put the app in ~/Applications.
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$DEST"
cp -R "$SRC_APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
if [ -n "$OLD_HASH" ] && [ "$OLD_HASH" != "$NEW_HASH" ]; then
    tccutil reset Accessibility "$LABEL" >/dev/null 2>&1 || true
fi

# 4. Start it now and at every login.
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$DEST/Contents/MacOS/CapsNumber</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>StandardOutPath</key>
	<string>$LOG</string>
	<key>StandardErrorPath</key>
	<string>$LOG</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$PLIST"

# 5. Tell the user what is left to do.
sleep 3
if tail -n 1 "$LOG" 2>/dev/null | grep -q "is running"; then
    cat <<MSG

CapsNumber is installed and running. Turn Caps Lock on: the number row now types digits.
It starts automatically at login. Log file: $LOG
MSG
else
    cat <<MSG

CapsNumber is installed in $DEST and will start automatically at login.

One more step, macOS needs your permission:
  1. A prompt about Accessibility should be on screen. Click "Open System Settings".
     (Or open System Settings > Privacy & Security > Accessibility yourself.)
  2. Switch on "CapsNumber".
  (After an update this is normal: the app changed, so macOS asks again.)

Then turn Caps Lock on: the number row types digits. Log file: $LOG
MSG
fi
echo "Uninstall: curl -fsSL https://raw.githubusercontent.com/$REPO/main/uninstall.sh | bash"
