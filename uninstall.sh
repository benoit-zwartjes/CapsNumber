#!/bin/bash
# Stops CapsNumber and removes it from ~/Applications and from login startup.
#   curl -fsSL https://raw.githubusercontent.com/benoit-zwartjes/CapsNumber/main/uninstall.sh | bash
set -uo pipefail

LABEL="be.benoit.CapsNumber"
DEST="$HOME/Applications/CapsNumber.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x CapsNumber 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$DEST"
tccutil reset Accessibility "$LABEL" >/dev/null 2>&1 || true

echo "CapsNumber removed, including its Accessibility permission."
