# Agreeo

Agreeo is a Flutter app for lightweight group movie decisions.

## Step 1 Setup

The app shell now uses Riverpod and initializes Firebase on startup. The code is written so the app still opens during early UI work even if Firebase is not configured yet, but the backend features in later steps require the native Firebase files below.

### Firebase configuration

1. Run `flutterfire configure` from the project root to generate Firebase options for your platforms.
2. Add `android/app/google-services.json` for Android.
3. Add `ios/Runner/GoogleService-Info.plist` for iOS.
4. Rebuild the app after adding the platform files.

### Optional TMDb configuration

Agreeo falls back to the bundled demo catalog when TMDb is not configured. To enable remote discovery, pass a TMDb API key at build time:

```bash
flutter run --dart-define=TMDB_API_KEY=your_key_here
```

### Project structure

The app follows this `lib/` layout:

- `models/`
- `providers/`
- `screens/`
- `services/`
- `utils/`
- `widgets/`

## Getting Started

Use the usual Flutter commands to run the app and tests:

```bash
flutter pub get
flutter test
flutter run
```


netstat -ano | findstr :3000
taskkill //PID 15212 //F