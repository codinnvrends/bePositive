# BePositive! - Personalized Affirmations App

A Flutter-based hybrid mobile application that delivers personalized daily affirmations based on user demographics and focus areas.

## Features

- **Personalized Content**: Affirmations tailored to age group, gender, and focus areas
- **Daily Notifications**: Customizable reminder system
- **Favorites**: Save and revisit meaningful affirmations
- **Local Storage**: All data stored locally for privacy
- **Cross-Platform**: Runs on both iOS and Android

## Tech Stack

- **Framework**: Flutter 3.35.0
- **Language**: Dart 3.8+
- **Database**: SQLite (via sqflite)
- **State Management**: Provider
- **Navigation**: GoRouter
- **Notifications**: flutter_local_notifications

## Getting Started

### Prerequisites

- Flutter SDK 3.35.0 or higher
- Dart 3.8 or higher
- **JDK 17** (Required for Android builds)
- iOS development: Xcode 15.0+, macOS 13.0+
- Android development: Android Studio with API level 23+

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd bePositive
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. **IMPORTANT**: Set up Java 17 for Android builds:
   ```bash
   # Install JDK 17 (macOS with Homebrew)
   brew install --cask temurin@17
   
   # Set JAVA_HOME for current session
   export JAVA_HOME=$(/usr/libexec/java_home -v 17)
   
   # Persist JAVA_HOME (add to ~/.zshrc or ~/.bash_profile)
   echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
   source ~/.zshrc
   ```

4. Create required asset directories:
   ```bash
   mkdir -p assets/images assets/data
   ```

## Building and Running

### Android

1. **Set Java 17** (critical for build success):
   ```bash
   export JAVA_HOME=$(/usr/libexec/java_home -v 17)
   java -version  # Should show version 17.x.x
   ```

2. **Run on Android**:
   ```bash
   flutter run
   ```

3. **Build APK**:
   ```bash
   flutter build apk --release
   ```

### iOS

1. **Prerequisites**:
   - macOS 13.0 (Ventura) or higher
   - Xcode 15.0 or higher
   - iOS Simulator or physical iOS device

2. **Install iOS dependencies**:
   ```bash
   cd ios
   pod install
   cd ..
   ```

3. **Run on iOS Simulator**:
   ```bash
   flutter run -d "iPhone 15 Pro"
   ```

4. **Run on iOS Device**:
   ```bash
   # List available devices
   flutter devices
   
   # Run on specific device
   flutter run -d <device-id>
   ```

5. **Build iOS App**:
   ```bash
   flutter build ios --release
   ```

6. **Open in Xcode** (for App Store deployment):
   ```bash
   open ios/Runner.xcworkspace
   ```

## Project Structure

```
lib/
├── main.dart
├── models/          # Data models
├── screens/         # UI screens
├── widgets/         # Reusable widgets
├── services/        # Business logic services
├── providers/       # State management
├── utils/           # Utilities and constants
└── database/        # Database helpers
```

## Architecture

The app follows MVVM (Model-View-ViewModel) pattern with Repository pattern for data management:

- **Models**: Data structures and entities
- **Views**: Flutter widgets and screens
- **ViewModels**: Provider-based state management
- **Repository**: Data access layer with local SQLite storage

## Personalization Criteria

- **Age Groups**: Teenager (13-17), Young Adult (18-25), Adult (26-55), Senior (56+)
- **Gender**: Male, Female, Non-binary, Prefer not to say
- **Focus Areas**: Relationship, Family, Career, Health, Self-Esteem, Finances, Creative Pursuits

## Troubleshooting

### Common Issues and Solutions

#### 1. **Android Build Failures**

**Issue**: `Build failed due to use of deleted Android v1 embedding`
```
Solution:
- The project uses Flutter v2 embedding
- Ensure MainActivity.kt extends FlutterActivity() without manual plugin registration
- Check AndroidManifest.xml uses android:name="${applicationName}"
```

**Issue**: `Minimum supported Gradle version is X.X.X`
```
Solution:
- Update android/gradle/wrapper/gradle-wrapper.properties
- Use Gradle 8.11.1: distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-all.zip
- Ensure AGP compatibility in android/settings.gradle.kts
```

**Issue**: `Dependency requires core library desugaring`
```
Solution:
- Add to android/app/build.gradle.kts:
  compileOptions {
    isCoreLibraryDesugaringEnabled = true
  }
- Add dependency:
  dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.3")
  }
```

#### 2. **Java Version Issues**

**Issue**: Build fails with Java version errors
```
Solution:
1. Install JDK 17: brew install --cask temurin@17
2. Set JAVA_HOME: export JAVA_HOME=$(/usr/libexec/java_home -v 17)
3. Verify: java -version (should show 17.x.x)
4. Persist in shell profile (~/.zshrc)
```

#### 3. **Font Loading Errors**

**Issue**: `google_fonts was unable to load font` with network errors
```
Solution:
- App uses system fonts as fallback automatically
- These are warnings only - app functionality not affected
- Occurs when emulator lacks internet access to fonts.gstatic.com
```

#### 4. **Asset Directory Warnings**

**Issue**: `The asset directory 'assets/images/' doesn't exist`
```
Solution:
mkdir -p assets/images assets/data
```

#### 5. **Emulator Issues**

**Issue**: App installs but emulator crashes or becomes unresponsive
```
Solution:
1. Restart emulator: flutter emulators --launch <emulator-name>
2. Cold boot emulator from Android Studio
3. Increase emulator RAM allocation
4. Use different API level if persistent issues
```

#### 6. **iOS Build Issues**

**Issue**: iOS build fails with CocoaPods errors
```
Solution:
1. cd ios && pod install
2. If persistent: pod repo update && pod install
3. Clean: flutter clean && cd ios && rm -rf Pods Podfile.lock && pod install
```

**Issue**: Xcode version compatibility
```
Solution:
- Ensure Xcode 15.0+ for Flutter 3.35.0
- Update Xcode from App Store
- Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Development Tips

1. **Hot Reload**: Press `r` in terminal during `flutter run` for instant updates
2. **Hot Restart**: Press `R` for full app restart
3. **DevTools**: Access debugging at the URL shown during `flutter run`
4. **Clean Build**: Run `flutter clean` before building if encountering cache issues
5. **Dependency Updates**: Check `flutter pub outdated` for package updates

### Performance Optimization

- **First Build**: Initial Android build takes 10-15 minutes (normal)
- **Subsequent Builds**: Much faster due to Gradle caching
- **Release Builds**: Use `--release` flag for production APKs/IPAs
- **Emulator Performance**: Use hardware acceleration and adequate RAM

## License

This project is licensed under the MIT License - see the LICENSE file for details.
