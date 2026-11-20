#!/bin/bash
# Rigenera le icone delle due app dal logo SwiftUI (Shared/UI/AppLogo.swift).
# Uso: Tools/icongen/make-icons.sh   (dalla radice del progetto)
set -euo pipefail
tmp=$(mktemp -d)
swiftc -O Shared/UI/AppLogo.swift Tools/icongen/main.swift -o "$tmp/icongen"
"$tmp/icongen" "$tmp"

# iOS: un'unica icona 1024.
ios=Phone/Assets.xcassets/AppIcon.appiconset
mkdir -p "$ios"
cp "$tmp/phone-1024.png" "$ios/icon-1024.png"
cat > "$ios/Contents.json" <<JSON
{ "images": [ { "filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" } ],
  "info": { "author": "xcode", "version": 1 } }
JSON

# macOS: 16…512 @1x/@2x.
mac=Mac/Assets.xcassets/AppIcon.appiconset
mkdir -p "$mac"
entries=""
for spec in 16:1 16:2 32:1 32:2 128:1 128:2 256:1 256:2 512:1 512:2; do
  pt=${spec%:*}; scale=${spec#*:}; px=$((pt * scale)); file="icon-${pt}@${scale}x.png"
  sips -z "$px" "$px" "$tmp/mac-1024.png" --out "$mac/$file" >/dev/null
  entries+="{ \"filename\": \"$file\", \"idiom\": \"mac\", \"scale\": \"${scale}x\", \"size\": \"${pt}x${pt}\" },"
done
echo "{ \"images\": [${entries%,}], \"info\": { \"author\": \"xcode\", \"version\": 1 } }" > "$mac/Contents.json"

for d in Phone Mac; do echo '{ "info": { "author": "xcode", "version": 1 } }' > "$d/Assets.xcassets/Contents.json"; done
rm -rf "$tmp"
echo "icone generate in $ios e $mac"
