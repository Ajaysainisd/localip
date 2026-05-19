#!/bin/bash
set -e

echo "=== 🚀 Building LocalIP.app ==="

# 0. Stop any running instances to release file lock on the binary
echo "🛑 Stopping any running instances of LocalIP..."
killall LocalIP > /dev/null 2>&1 || true

# 1. Compile Swift source
echo "📦 Compiling main.swift into binary..."
swiftc -O main.swift -o LocalIP

# 2. Create directory structures
echo "📂 Creating application bundle directories..."
mkdir -p LocalIP.app/Contents/MacOS
mkdir -p LocalIP.app/Contents/Resources

# Move binary into the app bundle
mv LocalIP LocalIP.app/Contents/MacOS/LocalIP

# 3. Create Info.plist
echo "📝 Writing Info.plist metadata..."
cat <<EOF > LocalIP.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LocalIP</string>
    <key>CFBundleIdentifier</key>
    <string>com.ajaysaini.localip</string>
    <key>CFBundleName</key>
    <string>LocalIP</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/> <!-- Hides from Dock, runs as background menu bar item -->
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 4. Generate App Icon (if icon.png exists)
if [ -f icon.png ]; then
    echo "🎨 Converting icon.png to standard PNG format..."
    sips -s format png icon.png --out icon_temp.png > /dev/null 2>&1
    
    echo "🎨 Creating AppIcon.icns from icon_temp.png..."
    mkdir -p AppIcon.iconset
    sips -z 16 16     icon_temp.png --out AppIcon.iconset/icon_16x16.png > /dev/null 2>&1
    sips -z 32 32     icon_temp.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null 2>&1
    sips -z 32 32     icon_temp.png --out AppIcon.iconset/icon_32x32.png > /dev/null 2>&1
    sips -z 64 64     icon_temp.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null 2>&1
    sips -z 128 128   icon_temp.png --out AppIcon.iconset/icon_128x128.png > /dev/null 2>&1
    sips -z 256 256   icon_temp.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null 2>&1
    sips -z 256 256   icon_temp.png --out AppIcon.iconset/icon_256x256.png > /dev/null 2>&1
    sips -z 512 512   icon_temp.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null 2>&1
    sips -z 512 512   icon_temp.png --out AppIcon.iconset/icon_512x512.png > /dev/null 2>&1
    sips -z 1024 1024 icon_temp.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null 2>&1
    
    iconutil -c icns AppIcon.iconset
    mv AppIcon.icns LocalIP.app/Contents/Resources/AppIcon.icns
    rm -rf AppIcon.iconset icon_temp.png
    echo "✅ AppIcon.icns generated successfully!"
fi

# 5. Ad-hoc Codesign the App Bundle
echo "🔐 Ad-hoc codesigning the app bundle to seal resources and metadata..."
codesign --force --deep --sign - LocalIP.app

echo "=== ✨ Build Complete: LocalIP.app created! ==="
