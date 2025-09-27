#!/bin/bash

# Quick Icon Check Script
# This script checks if the app icon is ready for generation

echo "🔍 Checking App Icon Status..."
echo "=============================="

if [ ! -f "assets/icons/app_icon.png" ]; then
    echo "❌ App icon not found"
    echo ""
    echo "📋 Next steps:"
    echo "1. Right-click the app icon image from the chat"
    echo "2. Save it as: assets/icons/app_icon.png"
    echo "3. Run: ./scripts/generate_icons.sh"
    echo ""
    echo "📖 See SAVE_ICON_INSTRUCTIONS.md for detailed help"
    exit 1
fi

if [ ! -s "assets/icons/app_icon.png" ]; then
    echo "❌ App icon file is empty or corrupt"
    echo ""
    echo "📋 To fix:"
    echo "1. Delete current file: rm assets/icons/app_icon.png"
    echo "2. Right-click the app icon image from the chat"
    echo "3. Save it as: assets/icons/app_icon.png"
    echo "4. Run: ./scripts/generate_icons.sh"
    exit 1
fi

# Get file size
file_size=$(wc -c < "assets/icons/app_icon.png")
echo "✅ App icon found: assets/icons/app_icon.png"
echo "📏 File size: $file_size bytes"

if [ $file_size -gt 1000 ]; then
    echo "✅ File size looks good"
    echo ""
    echo "🚀 Ready to generate icons!"
    echo "Run: ./scripts/generate_icons.sh"
else
    echo "⚠️  File size seems small - please verify the image saved correctly"
fi

echo ""
echo "🎨 Expected image content:"
echo "   • Teal gradient upward arrow with organic leaves"
echo "   • Light mint green rounded background"
echo "   • 'Affirm!' text in dark teal"
echo "   • PNG format with transparency"
