# iOS Firebase handoff

Source preparation is complete for bundle ID `com.blackspace.journaltrend` and iOS 15+.

The remaining work requires Firebase access, Apple credentials, and macOS/Xcode:

1. Register an iOS app in Firebase project `journaltrend-8cc04` with bundle ID `com.blackspace.journaltrend`.
2. On macOS, run:

   ```bash
   flutterfire configure \
     --project=journaltrend-8cc04 \
     --platforms=android,ios \
     --android-package-name=com.blackspace.journaltrend \
     --ios-bundle-id=com.blackspace.journaltrend
   ```

3. Confirm `ios/Runner/GoogleService-Info.plist` is included in the Runner target.
4. Add its `REVERSED_CLIENT_ID` as a URL scheme in `ios/Runner/Info.plist` for Google Sign-In.
5. In Xcode, select the Apple Developer team and enable automatic signing.
6. Add the Push Notifications capability and Background Modes (`Background fetch` and `Remote notifications`).
7. Upload an APNs `.p8` key, Key ID, and Team ID in Firebase Project Settings > Cloud Messaging.
8. Run:

   ```bash
   flutter clean
   flutter pub get
   cd ios
   pod install --repo-update
   cd ..
   flutter run
   ```

9. Verify Google Sign-In, Analytics, Storage PDF upload, Remote Config, FCM on a physical iPhone, and Crashlytics after reopening the app following a test crash.
