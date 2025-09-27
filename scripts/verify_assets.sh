#!/bin/bash

# Affirm! App Assets Verification Script
# This script verifies all generated app icons and splash screens

echo "🔍 Verifying Affirm! App Assets..."
echo "=================================="

TOTAL_CHECKS=0
PASSED_CHECKS=0

check_file() {
    local file_path="$1"
    local description="$2"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -f "$file_path" ]; then
        echo "✅ $description"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "❌ $description - MISSING: $file_path"
    fi
}

check_directory() {
    local dir_path="$1"
    local description="$2"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -d "$dir_path" ]; then
        local file_count=$(find "$dir_path" -type f | wc -l)
        echo "✅ $description ($file_count files)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "❌ $description - MISSING: $dir_path"
    fi
}

echo ""
echo "📱 Android Assets:"
echo "------------------"

# Android Icons
check_file "android/app/src/main/res/mipmap-hdpi/launcher_icon.png" "Android HDPI Icon (72x72)"
check_file "android/app/src/main/res/mipmap-mdpi/launcher_icon.png" "Android MDPI Icon (48x48)"
check_file "android/app/src/main/res/mipmap-xhdpi/launcher_icon.png" "Android XHDPI Icon (96x96)"
check_file "android/app/src/main/res/mipmap-xxhdpi/launcher_icon.png" "Android XXHDPI Icon (144x144)"
check_file "android/app/src/main/res/mipmap-xxxhdpi/launcher_icon.png" "Android XXXHDPI Icon (192x192)"

# Android Adaptive Icons (API 26+)
check_file "android/app/src/main/res/mipmap-hdpi/launcher_icon_foreground.png" "Android HDPI Adaptive Foreground"
check_file "android/app/src/main/res/mipmap-mdpi/launcher_icon_foreground.png" "Android MDPI Adaptive Foreground"
check_file "android/app/src/main/res/mipmap-xhdpi/launcher_icon_foreground.png" "Android XHDPI Adaptive Foreground"
check_file "android/app/src/main/res/mipmap-xxhdpi/launcher_icon_foreground.png" "Android XXHDPI Adaptive Foreground"
check_file "android/app/src/main/res/mipmap-xxxhdpi/launcher_icon_foreground.png" "Android XXXHDPI Adaptive Foreground"

# Android Splash Screens
check_file "android/app/src/main/res/drawable/launch_background.xml" "Android Launch Background"
check_file "android/app/src/main/res/drawable-v21/launch_background.xml" "Android Launch Background (API 21+)"

echo ""
echo "🍎 iOS Assets:"
echo "--------------"

# iOS Icons
check_directory "ios/Runner/Assets.xcassets/AppIcon.appiconset" "iOS App Icon Set"
check_file "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json" "iOS App Icon Contents"

# iOS Splash Screens
check_directory "ios/Runner/Assets.xcassets/LaunchImage.imageset" "iOS Launch Image Set"
check_file "ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json" "iOS Launch Image Contents"

echo ""
echo "⚙️  Configuration Files:"
echo "------------------------"

check_file "android/app/src/main/AndroidManifest.xml" "Android Manifest"
check_file "ios/Runner/Info.plist" "iOS Info.plist"
check_file "pubspec.yaml" "Flutter pubspec.yaml"

echo ""
echo "📊 Verification Summary:"
echo "========================"
echo "Passed: $PASSED_CHECKS/$TOTAL_CHECKS checks"

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo "🎉 All assets verified successfully!"
    echo ""
    echo "📱 App Name Verification:"
    
    # Check Android app name
    if grep -q 'android:label="Affirm!"' android/app/src/main/AndroidManifest.xml; then
        echo "✅ Android app name: Affirm!"
    else
        echo "❌ Android app name not set correctly"
    fi
    
    # Check iOS app name
    if [ -f "ios/Runner/Info.plist" ]; then
        if /usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" ios/Runner/Info.plist 2>/dev/null | grep -q "Affirm!"; then
            echo "✅ iOS app name: Affirm!"
        else
            echo "❌ iOS app name not set correctly"
        fi
    fi
    
    echo ""
    echo "🚀 Your Affirm! app is ready for testing and deployment!"
else
    echo "⚠️  Some assets are missing. Please run the generation script again."
    echo ""
    echo "To fix missing assets:"
    echo "1. Ensure assets/icons/app_icon.png exists"
    echo "2. Run: ./scripts/generate_icons.sh"
    echo "3. Run this verification script again"
fi
