#!/bin/bash

# BePositive! Flutter App Setup Script
echo "🌟 Setting up BePositive! Flutter Application..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Check Flutter version
echo "📱 Checking Flutter version..."
flutter --version

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Check for any issues
echo "🔍 Running Flutter doctor..."
flutter doctor

# Generate necessary files (if any)
echo "🔧 Checking project structure..."

# Create missing directories
mkdir -p assets/images
mkdir -p assets/fonts

# Set permissions for gradlew (Android)
if [ -f "android/gradlew" ]; then
    chmod +x android/gradlew
fi

echo "✅ Setup complete!"
echo ""
echo "🚀 To run the app:"
echo "   flutter run"
echo ""
echo "📱 To build for release:"
echo "   Android: flutter build apk --release"
echo "   iOS: flutter build ios --release"
echo ""
echo "🎯 Features included:"
echo "   ✓ Personalized affirmations based on age, gender, and focus areas"
echo "   ✓ Local SQLite database for data storage"
echo "   ✓ Daily notification reminders"
echo "   ✓ Favorites system"
echo "   ✓ Customizable settings"
echo "   ✓ Beautiful UI with animations"
echo "   ✓ Complete onboarding flow"
echo ""
echo "Happy affirming! 🌟"
