# Affirm! App Icon & Splash Screen Generation

This document explains how to generate all app icons and splash screens for the Affirm! Flutter app using the provided brand icon.

## 📋 Overview

The Affirm! app uses a beautiful teal gradient design featuring:
- **Main Symbol**: Upward arrow with organic leaves symbolizing growth and positivity
- **Color Scheme**: Teal gradients (#6ABDB8 to #4A9B96)
- **Background**: Light mint green (#A8D5D0)
- **Typography**: "Affirm!" in dark teal
- **Style**: Modern, clean design with organic elements

## 🎨 Source Image Requirements

The source image should be:
- **Format**: PNG with transparency
- **Size**: Minimum 1024x1024 pixels (recommended)
- **Quality**: High resolution for best results across all platforms
- **Location**: `assets/icons/app_icon.png`

## 🚀 Quick Start

### Step 1: Save the App Icon
Save the provided app icon image as:
```
assets/icons/app_icon.png
```

### Step 2: Generate All Assets
Run the automated generation script:
```bash
./scripts/generate_icons.sh
```

### Step 3: Verify Assets
Check that all assets were generated correctly:
```bash
./scripts/verify_assets.sh
```

## 📱 Generated Assets

### Android Icons
- **Standard Icons**: 5 sizes (MDPI to XXXHDPI)
  - `mipmap-mdpi/launcher_icon.png` (48x48)
  - `mipmap-hdpi/launcher_icon.png` (72x72)
  - `mipmap-xhdpi/launcher_icon.png` (96x96)
  - `mipmap-xxhdpi/launcher_icon.png` (144x144)
  - `mipmap-xxxhdpi/launcher_icon.png` (192x192)

- **Adaptive Icons** (Android 8.0+):
  - Foreground layers for all densities
  - Background color: `#A8D5D0`

### iOS Icons
- **App Icon Set**: 15 different sizes for various contexts
  - iPhone app icons (60pt, 120pt, 180pt)
  - iPad app icons (76pt, 152pt, 167pt)
  - App Store icon (1024pt)
  - Settings icons (29pt, 58pt, 87pt)
  - Spotlight icons (40pt, 80pt, 120pt)

### Splash Screens
- **Android**: Native splash with brand colors
  - Background: Light teal (#A8D5D0)
  - Dark mode: Dark teal (#2D5A56)
  - Android 12+ support included

- **iOS**: Launch images with brand consistency
  - Background colors match Android
  - Support for light and dark modes

## ⚙️ Configuration Details

### pubspec.yaml Configuration
```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icons/app_icon.png"
  min_sdk_android: 21
  web:
    generate: true
    background_color: "#A8D5D0"
    theme_color: "#6ABDB8"

flutter_native_splash:
  color: "#A8D5D0"
  image: "assets/icons/app_icon.png"
  color_dark: "#2D5A56"
  android_12:
    icon_background_color: "#A8D5D0"
    icon_background_color_dark: "#2D5A56"
```

### App Names
- **Android**: "Affirm!" (set in AndroidManifest.xml)
- **iOS**: "Affirm!" (set in Info.plist)

## 🎨 Brand Colors Used

| Color | Hex Code | Usage |
|-------|----------|--------|
| Primary Teal | #6ABDB8 | Main brand color, gradients |
| Secondary Teal | #4A9B96 | Gradient end, accents |
| Light Teal | #A8D5D0 | Backgrounds, splash screens |
| Dark Teal | #2D5A56 | Dark mode, text |

## 🔧 Manual Generation (Alternative)

If you prefer to run commands manually:

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Generate app icons**:
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

3. **Generate splash screens**:
   ```bash
   flutter pub run flutter_native_splash:create
   ```

4. **Update app names**:
   - Android: Edit `android/app/src/main/AndroidManifest.xml`
   - iOS: Edit `ios/Runner/Info.plist`

## ✅ Verification Checklist

After generation, verify:
- [ ] Android icons in all 5 densities
- [ ] Android adaptive icons (foreground/background)
- [ ] iOS app icon set (15 sizes)
- [ ] Android splash screens (light/dark)
- [ ] iOS launch images (light/dark)
- [ ] App names set correctly on both platforms
- [ ] Colors match brand guidelines

## 🐛 Troubleshooting

### Common Issues

1. **"Image not found" error**:
   - Ensure `assets/icons/app_icon.png` exists
   - Check file permissions and path

2. **Icons appear blurry**:
   - Use higher resolution source image (1024x1024+)
   - Ensure PNG format with transparency

3. **Colors don't match**:
   - Verify hex codes in pubspec.yaml
   - Check if image has correct color profile

4. **App name not updating**:
   - Clean and rebuild the app
   - Check manifest files manually

### Getting Help

If you encounter issues:
1. Run the verification script: `./scripts/verify_assets.sh`
2. Check Flutter doctor: `flutter doctor`
3. Clean and rebuild: `flutter clean && flutter pub get`

## 🎉 Success!

Once all assets are generated and verified, your Affirm! app will have:
- ✨ Beautiful, consistent icons across all platforms
- 🌟 Professional splash screens with brand colors
- 📱 Proper app names and metadata
- 🎨 Perfect brand representation

Your app is now ready for testing and app store submission!
