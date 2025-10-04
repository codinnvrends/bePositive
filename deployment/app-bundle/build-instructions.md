# App Bundle Build Instructions

## Prerequisites

Before building the release app bundle, ensure you have:

1. **Flutter SDK**: Version 3.35.0 or higher
2. **Android SDK**: API level 35+ with build tools 34.0.0+
3. **Java JDK**: Version 17 or 21
4. **Release Keystore**: Created and configured for signing

## Step 1: Create Release Keystore (First Time Only)

If you haven't created a keystore yet:

```bash
keytool -genkey -v -keystore ~/affirm-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias affirm-key
```

**Important**: 
- Store the keystore file securely
- Remember the keystore password and key alias password
- Back up the keystore file - losing it means you can't update your app

## Step 2: Configure Key Properties

Create `android/key.properties` file:

```properties
storePassword=[Your keystore password]
keyPassword=[Your key password]
keyAlias=affirm-key
storeFile=[Path to your keystore file]
```

**Example**:
```properties
storePassword=myStorePassword123
keyPassword=myKeyPassword123
keyAlias=affirm-key
storeFile=/Users/username/affirm-release-key.jks
```

## Step 3: Update build.gradle.kts

Ensure your `android/app/build.gradle.kts` includes signing configuration:

```kotlin
android {
    // ... existing configuration

    signingConfigs {
        create("release") {
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            }

            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

## Step 4: Clean and Build

1. **Clean previous builds**:
```bash
flutter clean
flutter pub get
```

2. **Build the release app bundle**:
```bash
flutter build appbundle --release
```

## Step 5: Locate the App Bundle

The signed app bundle will be created at:
```
build/app/outputs/bundle/release/app-release.aab
```

Copy this file to the deployment folder:
```bash
cp build/app/outputs/bundle/release/app-release.aab deployment/app-bundle/
```

## Step 6: Verify the Build

1. **Check file size**: Should be under 150MB (preferably under 50MB)
2. **Verify signing**: 
```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

3. **Test the bundle** (optional):
```bash
bundletool build-apks --bundle=app-release.aab --output=app-release.apks
bundletool install-apks --apks=app-release.apks
```

## Build Configuration Checklist

- [ ] Release keystore created and secured
- [ ] key.properties file configured
- [ ] Signing configuration added to build.gradle.kts
- [ ] ProGuard/R8 enabled for code obfuscation
- [ ] App version updated in pubspec.yaml
- [ ] All dependencies are production-ready versions
- [ ] Debug logging disabled in release builds
- [ ] App bundle built successfully
- [ ] Bundle size optimized (under 150MB)
- [ ] Signing verification passed

## Troubleshooting

### Common Issues:

**Build fails with keystore error**:
- Check key.properties file path and passwords
- Ensure keystore file exists and is accessible

**App bundle too large**:
- Enable R8/ProGuard minification
- Remove unused resources
- Optimize images and assets

**Signing verification fails**:
- Verify keystore passwords are correct
- Check that signing configuration is properly applied

**Flutter version issues**:
- Ensure Flutter SDK is up to date
- Run `flutter doctor` to check for issues

## Security Notes

1. **Never commit key.properties to version control**
2. **Store keystore file in a secure location with backups**
3. **Use strong passwords for keystore and key**
4. **Consider using Play App Signing for additional security**

## Final Steps

Once you have the signed app bundle (`app-release.aab`):

1. Upload to Google Play Console
2. Complete store listing information
3. Set up release tracks (internal testing → production)
4. Submit for review

The app bundle is now ready for Google Play Store submission!
