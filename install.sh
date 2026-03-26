#!/usr/bin/env bash
# Installs QueuePaste.app from the GitHub release DMG into /Applications.
# Usage: curl -fsSL https://raw.githubusercontent.com/tmarhguy/QueuePaste/main/install.sh | bash
set -euo pipefail

QUEUEPASTE_DMG_URL="${QUEUEPASTE_DMG_URL:-https://github.com/tmarhguy/QueuePaste/releases/latest/download/QueuePaste.dmg}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "QueuePaste is macOS-only." >&2
  exit 1
fi

TMP_DMG="$(mktemp -t queuepaste)"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" ]] && [[ -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  fi
  rm -f "$TMP_DMG"
}
trap cleanup EXIT

echo "Downloading QueuePaste…"
curl -fsSL -o "$TMP_DMG" "$QUEUEPASTE_DMG_URL"

echo "Mounting disk image…"
MOUNT_POINT="$(hdiutil attach -nobrowse "$TMP_DMG" | tail -1 | grep -o '/Volumes/.*' | head -1 || true)"
if [[ -z "$MOUNT_POINT" ]] || [[ ! -d "$MOUNT_POINT/QueuePaste.app" ]]; then
  echo "Install failed: could not find QueuePaste.app in the disk image." >&2
  exit 1
fi

echo "Installing to /Applications…"
ditto "$MOUNT_POINT/QueuePaste.app" "/Applications/QueuePaste.app"

hdiutil detach "$MOUNT_POINT" -quiet
MOUNT_POINT=""

echo "Done. Launch with: open -a QueuePaste"
