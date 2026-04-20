# Samanyudu TV - App Release Launch Readiness Report

This document outlines the current state of the Samanyudu TV project (encompassing the Mobile App, Admin Portal, and Public Web App) across the 8 key stages of launch readiness. 

It specifies what has been **[✔] Completed** and what is **[⚠] Needed to Do**.

---

## 1. Product Quality
**[✔] Completed:**
- App launches and core navigation works accurately locally.
- UI handles responsive states on both the Web and the Flutter app correctly.
- Robust translations, TTS integration, and local API backend endpoints function without error.
- **Offline handling implemented**: News feed is now cached locally via SQLite (`sqflite`), allowing users to read previously fetched news without a connection.

## 2. Performance & Monitoring
**[✔] Completed:**
- Basic image bounding and rendering structures are clean.
- **Crash reporting enabled**: `firebase_crashlytics` is integrated and configured to report fatal/asynchronous errors.
- **Analytics tracking added**: `firebase_analytics` is integrated for tracking daily active user retention.
- **Push Notifications**: Integrated Firebase Cloud Messaging (FCM) for production-grade notifications.

## 3. Play Store Optimization (ASO)
**[✔] Completed:**
- **App icon created professionally**: Basic Flutter icons generated and `assets/app_icon.jpg` is in place.

**[⚠] Needed to Do:** *(To be done in Google Play Console)*
- Add App title with main keywords.
- Optimize Short & Long descriptions.
- Prepare 5–8 professional screenshots.
- Create a 1024x500 Feature graphic.

## 4. Legal & Compliance
**[✔] Completed:**
- **Privacy Policy created**: Hosted natively on the website (`/privacy-policy/`).
- **Support email added**: Contact email (`samanyudu@gmail.com`) is present in the public site.
- **Terms & Conditions added**: Hosted natively at (`/terms/`).

**[⚠] Needed to Do:**
- **Data Safety form**: Provide clear data explanations when submitting the Google Play Data Safety form.

## 5. Testing Before Release
**[✔] Completed:**
- Features are largely verified using local chrome web preview and emulators.

**[⚠] Needed to Do:**
- **Release build tested**: Build an `.apk` and manually install it on Android 11, 12, 13, and 14 models.
- **Debug logs removed**: While Flutter `debugPrint` logs strip out on release builds, manual audit to ensure no sensitive API outputs remain is recommended.
- **Version code updated**: The `pubspec.yaml` is currently set to default `1.0.0+1`. Advance this prior to final building.

## 6. Website & SEO
**[✔] Completed:**
- **Website created for app**: `public_web_app` is comprehensively built.
- **Privacy Policy hosted online**: Yes, linked natively in footer.
- **Sitemap created**: `sitemap.xml` exists in the codebase.
- **Robots mapping**: `robots.txt` exists.

**[⚠] Needed to Do:**
- Post-deployment, submit the domain to **Google Search Console**.
- Paste your website URL directly into the Play Console developer information.

## 7. Distribution & Promotion
*(All action items here rely on external marketing execution)*

**[⚠] Needed to Do:**
- Prepare an App demo video.
- Submit to app listing websites (e.g. Product Hunt).
- Construct an early-adopter user feedback channel (e.g., Discord, WhatsApp group).

## 8. Launch Readiness
**[✔] Completed:**
- The codebase architecture functionally operates from end to end (Admin -> API -> App).

**[⚠] Needed to Do (CRITICAL):**
- **Generate Release Keystore**: Use `keytool` to generate the `.jks` file and populate `android/key.properties`.
- **Final release build**: Advance version code in `pubspec.yaml` and execute `flutter build appbundle --release`.
- Back up the Keystore safely. Keep the password written externally.
- Execute Internal App Sharing on Google Play.
- Launch the final App-Bundle.
