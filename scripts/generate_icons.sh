#!/bin/bash

# Affirm! App Icon and Splash Screen Generation Script
# This script generates all required app icons and splash screens from the provided PNG image

echo "🎨 Generating Affirm! App Icons and Splash Screens..."
echo "=================================================="

# Check if the source image exists
if [ ! -f "assets/icons/app_icon.png" ]; then
    echo "❌ Error: assets/icons/app_icon.png not found!"
    echo ""
    echo "📋 To fix this:"
    echo "1. Right-click the app icon image from the chat"
    echo "2. Save it as: assets/icons/app_icon.png"
    echo "3. Run this script again"
    echo ""
    echo "See SAVE_ICON_INSTRUCTIONS.md for detailed steps"
    exit 1
fi

# Check if the image file has content (not empty/corrupt)
if [ ! -s "assets/icons/app_icon.png" ]; then
    echo "❌ Error: assets/icons/app_icon.png is empty or corrupt!"
    echo ""
    echo "📋 To fix this:"
    echo "1. Delete the current file: rm assets/icons/app_icon.png"
    echo "2. Right-click the app icon image from the chat"
    echo "3. Save it as: assets/icons/app_icon.png"
    echo "4. Run this script again"
    echo ""
    echo "See SAVE_ICON_INSTRUCTIONS.md for detailed steps"
    exit 1
fi

echo "✅ Source image found and valid"

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate app icons
echo "🔧 Generating app launcher icons..."
flutter pub run flutter_launcher_icons:main

# Generate splash screens
echo "🌟 Generating native splash screens..."
flutter pub run flutter_native_splash:create

# Update Android app name
echo "📱 Updating Android app name..."
sed -i '' 's/android:label="be_positive"/android:label="Affirm!"/' android/app/src/main/AndroidManifest.xml

# Update iOS app name
echo "🍎 Updating iOS app name..."
if [ -f "ios/Runner/Info.plist" ]; then
    # Update CFBundleDisplayName and CFBundleName in Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Affirm!" ios/Runner/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Affirm!" ios/Runner/Info.plist
    
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Affirm!" ios/Runner/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string Affirm!" ios/Runner/Info.plist
fi

echo ""
echo "✅ Icon and splash screen generation complete!"
echo ""
echo "📋 Generated Assets:"
echo "   • Android Icons: android/app/src/main/res/mipmap-*/"
echo "   • iOS Icons: ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "   • Android Splash: android/app/src/main/res/drawable*/"
echo "   • iOS Splash: ios/Runner/Assets.xcassets/LaunchImage.imageset/"
echo ""
echo "🔍 Verification:"
echo "   • Check android/app/src/main/AndroidManifest.xml for app name"
echo "   • Check ios/Runner/Info.plist for app name"
echo "   • Test on device/emulator to verify icons appear correctly"
echo ""
echo "🎉 Your Affirm! app is ready with beautiful icons and splash screens!"
