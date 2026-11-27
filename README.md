# hy Academy

Flutter application for the HY Academy store and learning platform.

## Main features

- Product store and bundles.
- University courses and professional training courses.
- Course and lecture video playback.
- Question banks and exam resources.
- Admin dashboard for products, courses, activations, sales, uploads, and notifications.
- Firebase Authentication and Cloud Firestore, with Supabase Storage for media files.

See [FIXES_README_AR.md](FIXES_README_AR.md) for Arabic setup notes, free-tier safeguards, and build commands.

## Build

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=FIREBASE_ANDROID_APP_ID=1:YOUR_SENDER_ID:android:YOUR_ANDROID_APP_ID
```
