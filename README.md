# Agreeo

Agreeo is a Flutter app for lightweight group movie decisions, backed by a
Node.js/Express API and a Neo4j graph database. Authentication uses backend
JWTs; there is no Firebase dependency.

## Architecture

- **Frontend**: Flutter (Riverpod state management), feature-first layout.
- **Backend**: Express + Socket.IO (`backend/`), owns all TMDB reads and Neo4j
  movie/social interactions. See `docs/BACKEND_CONTRACT.md`.
- **Database**: Neo4j 5 with the MovieLens dataset for recommendations. See
  `docs/NEO4J_TMDB_MOVIELENS_ARCHITECTURE.md`.

Main API surface:

- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`
- `GET /movies/popular`, `GET /movies/search?query=...`, `GET /movies/:tmdbId`
- authenticated `/me/movies/...`, `/me/library`, `/me/recommendations`
- authenticated `/friends/...`, `/movie-nights/...`, `/notifications`
- `GET /health` (liveness), `GET /health/db` (readiness)

## Backend environment

The backend loads `backend/.env` automatically through `dotenv`. For local
`npm start`, create it from the tracked template:

```bash
cp backend/.env.example backend/.env
```

For Docker Compose local development, create the root env file as well:

```bash
cp .env.example .env
```

Required variables (the server refuses to start otherwise):

- `JWT_SECRET` — cryptographically random, at least 32 characters
  (`openssl rand -base64 48`).
- `NEO4J_PASSWORD` — strong password; docker compose has no default.
- `TMDB_ACCESS_TOKEN` — TMDB API bearer token.

Do not edit secrets directly into `docker-compose.yml`.

## MovieLens import

Place `movies.csv`, `links.csv`, `ratings.csv`, and `tags.csv` in
`backend/data/movielens/`.

For Docker local development, the repo expects those files under
`backend/data/ml-latest-small/` and imports them with:

```bash
docker compose up neo4j-init
```

Without this import, authenticated swipe suggestions can be empty because
Neo4j has no `MovieLensMovie`, `MATCHES_TMDB`, or `RATED` recommendation data.

## Project structure

The app follows a feature-first `lib/` layout:

- `lib/features/` — one folder per feature (`auth`, `home`, `swipe`,
  `library`, `friends`, `movie_details`, `onboarding`, `profile`, `shell`,
  `bootstrap`), each with its `presentation/` (and where needed `state/`).
- `lib/shared/` — shared models, state (`agreeo_app_controller.dart`), theme
  tokens, widgets, and utilities.
- `lib/services/` — backend API clients (auth, movies, social, realtime).
- `lib/providers/` — global Riverpod providers.
- `lib/config/` — backend endpoints configuration (`BACKEND_BASE_URL`).
- `lib/models/` — data models shared with the backend contract.

Navigation is documented in `docs/ROUTING_MAP.md`.

## Getting started

Use the usual Flutter commands to run the app and tests:

```bash
flutter pub get
flutter test
flutter run
```

Run the backend from `backend/` with the Neo4j and TMDB environment variables
set:

```bash
npm start          # or: npm test for the unit suite
```

## Continuous integration

GitHub Actions (`.github/workflows/ci.yml`) runs on every PR:
`flutter analyze` + `flutter test` for the app, `npm audit
--audit-level=high` + `npm test` for the backend.

## Azure test deployment

For an Azure for Students test deployment, use the VM + Docker Compose path
documented in:

- `deploy/azure/README.md`
