# Affirm! - Google Play Store Deployment Guide

This folder contains all resources and documentation needed for publishing Affirm! to the Google Play Store.

## App Information
- **App Name**: Affirm!
- **Package Name**: com.sapps.be_positive
- **Category**: Health & Fitness / Lifestyle
- **Target Audience**: Adults seeking personal development and mental wellness

## Folder Structure

### `/app-bundle/`
Contains the release app bundle (AAB) file for upload to Google Play Console.

### `/screenshots/`
Contains app screenshots for different device types:
- Phone screenshots (16:9 and 9:16 aspect ratios)
- Tablet screenshots (optional)
- Screenshots should showcase key features

### `/store-listing/`
Contains store listing assets:
- App descriptions (short and full)
- Privacy policy
- Terms of service
- Content rating information

### `/graphics/`
Contains visual assets for the store:
- App icon (512x512 PNG)
- Feature graphic (1024x500 PNG)
- Promo graphic (180x120 PNG, optional)
- TV banner (1280x720 PNG, for Android TV, optional)

### `/release-notes/`
Contains version release notes and changelog.

## Pre-Publishing Checklist

### Technical Requirements
- [ ] App bundle built and signed with release keystore
- [ ] App tested on multiple devices and Android versions
- [ ] All permissions properly declared and justified
- [ ] ProGuard/R8 enabled for code obfuscation
- [ ] App size optimized (under 150MB)
- [ ] 64-bit architecture support included

### Store Listing Requirements
- [ ] App title (max 50 characters)
- [ ] Short description (max 80 characters)
- [ ] Full description (max 4000 characters)
- [ ] App icon (512x512 PNG, no transparency)
- [ ] Feature graphic (1024x500 PNG)
- [ ] At least 2 screenshots per supported device type
- [ ] Content rating completed
- [ ] Privacy policy URL provided
- [ ] App category selected

### Legal & Policy Requirements
- [ ] Privacy policy created and hosted
- [ ] Terms of service created (if applicable)
- [ ] Content rating questionnaire completed
- [ ] Target audience and age rating defined
- [ ] Data safety section completed in Play Console

### Quality Assurance
- [ ] App follows Material Design guidelines
- [ ] No crashes or ANRs in testing
- [ ] Proper error handling implemented
- [ ] Accessibility features implemented
- [ ] Performance optimized (startup time, memory usage)

## Publishing Steps

1. **Prepare Release Build**
   ```bash
   flutter build appbundle --release
   ```

2. **Sign the App Bundle**
   - Use your release keystore to sign the AAB file
   - Store keystore securely and create backups

3. **Upload to Google Play Console**
   - Create new app in Play Console
   - Upload signed AAB file
   - Complete store listing information
   - Add screenshots and graphics
   - Set pricing and distribution

4. **Complete Review Process**
   - Submit for review
   - Address any policy violations
   - Respond to reviewer feedback

5. **Launch**
   - Choose release type (internal, closed, open testing, or production)
   - Monitor crash reports and user feedback
   - Plan post-launch updates

## Important Notes

- Keep your signing keystore secure and backed up
- Test thoroughly on different devices before release
- Monitor app performance and user reviews post-launch
- Plan regular updates with new features and bug fixes
- Ensure compliance with Google Play policies

## Support

For technical issues during deployment, refer to:
- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Android App Bundle Guide](https://developer.android.com/guide/app-bundle)
