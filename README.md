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

## Backend Movie MVP

The backend now owns TMDB movie reads and Neo4j movie interactions for the MVP. Use the backend for:

- `GET /movies/popular`
- `GET /movies/search?query=matrix`
- `GET /movies/:tmdbId`
- authenticated `/me/movies/...`, `/me/library`, and `/me/recommendations`

### Backend environment

The backend now loads `backend/.env` automatically through `dotenv`. A ready-to-edit local file is already in place at `backend/.env`.

Keep `backend/.env.example` as the tracked template. The critical new variable is:

```txt
TMDB_ACCESS_TOKEN=your_tmdb_bearer_token
```

### MovieLens import

Place `movies.csv`, `links.csv`, `ratings.csv`, and `tags.csv` in `backend/data/movielens/`.

The import workflow, Docker command, graph schema, and verification queries are documented in:

- `docs/NEO4J_TMDB_MOVIELENS_ARCHITECTURE.md`

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

Run the backend from `backend/` with the Neo4j and TMDB environment variables set:

```bash
npm start
```

Run the backend from `backend/` with the Neo4j and TMDB environment variables set:

```bash
npm start
```


netstat -ano | findstr :3000
taskkill //PID 15212 //F