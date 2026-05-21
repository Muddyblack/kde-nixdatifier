#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/nixos-generation-explorer-test"
TOOL=/run/current-system/sw/bin/kpackagetool6
ID=org.muddyblack.nixosGenerationExplorerTest

if [ ! -x "$TOOL" ]; then
    echo "kpackagetool6 not found at $TOOL" >&2
    exit 1
fi

rm -rf "$TEMP_DIR"
cp -r "$HERE/package" "$TEMP_DIR"

# Replace both the Id and Icon properties (which now use the widget ID)
sed -i "s/org.muddyblack.nixosGenerationExplorer/$ID/g" "$TEMP_DIR/metadata.json"
sed -i 's/"Name": "nixdatifier"/"Name": "nixdatifier (Test)"/g' "$TEMP_DIR/metadata.json"

# Install the icon to the user's local hicolor icon theme directory
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"
cp "$HERE/package/icon.png" "$ICON_DIR/$ID.png"

echo "Installing test version of the widget..."
if "$TOOL" -t Plasma/Applet -l 2>/dev/null | grep -q "$ID"; then
    "$TOOL" -t Plasma/Applet -u "$TEMP_DIR" 2>/dev/null
    echo "Updated existing test install."
else
    "$TOOL" -t Plasma/Applet -i "$TEMP_DIR" 2>/dev/null
    echo "Installed fresh test widget."
fi

echo ""
echo "=== Done: NixOS Generation Explorer (Test) ==="
echo "Add it to your desktop/panel, or restart plasmashell if already added:"
echo "  plasmashell --replace &"
echo ""
echo "To remove the test version:"
echo "  $TOOL -t Plasma/Applet -r $ID"
echo "  rm -f $HOME/.local/share/icons/hicolor/256x256/apps/$ID.png"
