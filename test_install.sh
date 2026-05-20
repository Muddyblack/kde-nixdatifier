#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/nixos-generation-explorer-test"

rm -rf "$TEMP_DIR"
cp -r "$HERE/package" "$TEMP_DIR"

sed -i 's/"Id": "org.muddyblack.nixosGenerationExplorer"/"Id": "org.muddyblack.nixosGenerationExplorerTest"/g' "$TEMP_DIR/metadata.json"
sed -i 's/"Name": "NixOS Generation Explorer"/"Name": "NixOS Generation Explorer (Test)"/g' "$TEMP_DIR/metadata.json"

echo "Installing test version of the widget..."
if kpackagetool6 -t Plasma/Applet -l | grep -q "org.muddyblack.nixosGenerationExplorerTest"; then
    kpackagetool6 -t Plasma/Applet -u "$TEMP_DIR"
else
    kpackagetool6 -t Plasma/Applet -i "$TEMP_DIR"
fi

echo ""
echo "=== Test Widget Installed! ==="
echo "Add 'NixOS Generation Explorer (Test)' to your desktop or panel."
echo "To uninstall the test version later, run:"
echo "  kpackagetool6 -t Plasma/Applet -r org.muddyblack.nixosGenerationExplorerTest"
