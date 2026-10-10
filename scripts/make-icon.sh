#!/bin/sh
# Renders App/Icon/AppIcon.svg into the app's icon (1024×1024 PNG, no transparency).
# Uses Quick Look to draw the SVG (ImageMagick's own SVG renderer drops gradients) and ImageMagick to drop the alpha.
set -e
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
qlmanage -t -s 1024 -o "$TMP" App/Icon/AppIcon.svg >/dev/null
magick "$TMP/AppIcon.svg.png" -background "#1E1B4B" -alpha remove -alpha off \
  App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
rm -r "$TMP"
echo "wrote App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
