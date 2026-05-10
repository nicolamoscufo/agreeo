# Agreeo Remaining Work

## Current Phase
Phase 1 - Core MVP prototype + real auth/database foundation

## Last Updated
2026-05-10 - Auth/backend/Neo4j architecture reviewed and MVP database flow defined

## Current Status
The Phase 1 Flutter prototype already contains the main app flow: bootstrap gate, mock auth welcome screen, onboarding, 5-tab shell, Home, Swipe, Library, Movie Details, Profile, and Friends placeholder. The UI prototype has passed `flutter analyze`, `flutter test`, and a web build smoke test.

The project is now moving from pure mock prototype toward a real MVP backend foundation. The immediate priority is replacing mock/local auth with backend auth connected to Neo4j, while keeping the app simple and not production-oriented yet.

The decided MVP backend model uses Neo4j as the main graph database. App users must be stored as `:AppUser`, not `:User`, because the database will later also contain imported MovieLens users as `:MovieLensUser`.

TMDB will be used as the external movie catalog for posters, descriptions, search, movie details, cast, trailers, and images. MovieLens will be imported into Neo4j to provide historical ratings, tags, and recommendation data. The matching between TMDB movies and MovieLens movies must be done through `links.csv`, using `tmdbId`, not by comparing titles.

## Completed

### Existing Phase 1 Prototype
- [x] Read project docs and root config (`README.md`, `pubspec.yaml`, `analysis_options.yaml`).
- [x] Checked for `REMAINING_WORK.md` and created it because it did not exist.
- [x] Confirmed the project already uses Flutter and Riverpod.
- [x] Confirmed the current `lib/` tree contains legacy app shell code that needs to be evaluated against Agreeo Phase 1 requirements.
- [x] Audited the current app structure and chose a low-risk path: add a separate Phase 1 prototype layer without deleting the legacy code yet.
- [x] Added new Phase 1 shared models for movies, onboarding, profile preferences, and local user movie state.
- [x] Added a mock `MovieService` abstraction and local mock catalog.
- [x] Added a mock authentication service for local signup/login flows.
- [x] Added a local `UserMovieStateService` with undo-aware state mutations.
- [x] Added a persistent Riverpod controller for the Phase 1 prototype.
- [x] Added a cinematic Phase 1 theme.
- [x] Added reusable Phase 1 components for search, empty states, chips, rating stars, poster grids, movie cards, bottom navigation, filters, and review editing.
- [x] Implemented the new bootstrap gate and switched the app entrypoint to the new Phase 1 flow.
- [x] Implemented the welcome/authentication screen.
- [x] Implemented onboarding step 2: favorite genres.
- [x] Implemented onboarding step 3: favorite movies.
- [x] Implemented a polished 5-tab bottom navigation shell with emphasized Swipe tab.
- [x] Implemented the Home screen with search, chips, and horizontal carousels.
- [x] Implemented the Swipe screen as the Phase 1 core interaction.
- [x] Implemented the Movie Details screen with rating/review actions.
- [x] Implemented the Library screen with Watchlist, Liked, Watched, and Hidden tabs.
- [x] Implemented a basic Profile screen aligned with Agreeo Phase 1.
- [x] Added widget and service tests for the new Phase 1 flow and local movie-state rules.
- [x] Ran targeted analysis on the new prototype layer with no issues.
- [x] Ran the full Flutter test suite successfully.
- [x] Cleaned legacy analyzer warnings in old unused files outside the new Phase 1 flow.
- [x] Re-ran full-project `flutter analyze` successfully with no issues.
- [x] Ran a smoke `flutter build web` successfully.
- [x] Removed all streaming-platform references from the Phase 1 prototype flow.
- [x] Reduced the custom bottom navigation height and visual footprint.
- [x] Refined Swipe so the card occupies almost the whole screen and supports animated right/left swipe gestures for like/dislike.
- [x] Fixed the Home carousel card overflow by simplifying card metadata and resizing the carousel.
- [x] Re-ran full-project `flutter analyze` and `flutter test` after the UX refinement pass.
- [x] Moved Swipe actions directly inside the swipe card and aligned the layout closer to the provided reference.
- [x] Re-ran full-project `flutter analyze` and `flutter test` after embedding the swipe controls into the card.

### Architecture Decisions Completed
- [x] Decided that TMDB will be used as the movie catalog source.
- [x] Decided that MovieLens will be used for historical ratings/tags/recommendation data.
- [x] Decided that Neo4j will store app users, MovieLens users, movies, genres, ratings, tags, likes, dislikes, watchlist, and onboarding preferences.
- [x] Decided that MovieLens and TMDB matching must use `links.csv`.
- [x] Confirmed matching path: `MovieLens movieId -> links.csv -> tmdbId -> TMDB movie id`.
- [x] Decided not to match MovieLens and TMDB by title except as a last-resort fallback.
- [x] Decided that real app users must be stored as `:AppUser`.
- [x] Decided that imported MovieLens users must be stored separately as `:MovieLensUser`.
- [x] Decided that user movie preferences should be Neo4j relationships, not fields on the user node.
- [x] Decided that the MVP `Neo4jUser` model should remain minimal.

### MVP User Model Decisions Completed
- [x] Reviewed existing Flutter `Neo4jUser` class.
- [x] Decided to keep the MVP user model minimal.
- [x] Decided to keep only:
  - `uid`
  - `displayName`
  - `email`
  - `emailNormalized`
  - `createdAt`
  - `onboardingCompleted`
  - `passwordHash` only where backend auth requires it.
- [x] Decided not to add advanced user fields yet:
  - `username`
  - `photoUrl`
  - `bio`
  - `emailVerified`
  - `authProvider`
  - `preferredLanguage`
  - `visibility`
  - `accountStatus`
  - `updatedAt`
  - `lastLoginAt`
- [x] Decided not to store liked movies, disliked movies, watchlist movies, favorite genres, or friends as arrays on the user model.
- [x] Decided these must be graph relationships:
  - `(:AppUser)-[:LIKED]->(:Movie)`
  - `(:AppUser)-[:DISLIKED]->(:Movie)`
  - `(:AppUser)-[:WATCHLISTED]->(:Movie)`
  - `(:AppUser)-[:PREFERS_GENRE]->(:Genre)`
  - `(:AppUser)-[:SELECTED_FAVORITE]->(:Movie)`

### Backend Auth Review Completed
- [x] Reviewed current backend structure.
- [x] Confirmed backend currently contains:
  - `authController.js`
  - `jwtUtils.js`
  - `neo4jService.js`
  - `server.js`
  - `seedInitialUsers.js`
  - `package.json`
- [x] Identified old backend auth model uses `:User` and `userId`.
- [x] Decided to migrate backend auth model to `:AppUser` and `uid`.
- [x] Decided backend should return a structured `user` object on register/login.
- [x] Decided backend should never return `passwordHash` to Flutter.
- [x] Decided register response should return:
  - `accessToken`
  - `refreshToken`
  - `user.uid`
  - `user.email`
  - `user.displayName`
  - `user.createdAt`
  - `user.onboardingCompleted`
  - `user.roles`
- [x] Decided login response should return the same user shape as register.
- [x] Decided JWT payload should include:
  - `sub`
  - `uid`
  - `email`
  - `roles`
- [x] Decided refresh token payload should include:
  - `sub`
  - `uid`
  - `email`
  - `roles`
  - `type: "refresh"`
- [x] Decided backend should normalize email with `email.trim().toLowerCase()`.
- [x] Decided Neo4j should use `emailNormalized` for login and uniqueness checks.
- [x] Decided backend should create Neo4j constraints at startup.

### Backend Files Planned for Update
- [x] Planned replacement of `authController.js`.
- [x] Planned replacement of `neo4jService.js`.
- [x] Planned update of `server.js`.
- [x] Planned optional cleanup of `jwtUtils.js`.
- [x] Planned update of `seedInitialUsers.js`.

## In Progress

### Auth + Neo4j MVP Integration
- [ ] Replace backend `authController.js` with the new `:AppUser` / `uid` version.
- [ ] Replace backend `neo4jService.js` with the version that creates constraints and supports optional database selection.
- [ ] Replace backend `server.js` with the version that initializes Neo4j before starting Express.
- [ ] Update `jwtUtils.js` if needed.
- [ ] Update `seedInitialUsers.js` to seed `:AppUser`, not `:User`.
- [ ] Remove or migrate old `:User` nodes from Neo4j.
- [ ] Test `/health/db`.
- [ ] Test `/auth/register`.
- [ ] Test `/auth/login`.
- [ ] Test `/auth/refresh`.
- [ ] Test `/me`.
- [ ] Test `/me/onboarding`.

### Flutter Auth Alignment
- [ ] Update Flutter `AuthService` so it trusts backend auth as the source of truth.
- [ ] Store `accessToken` and `refreshToken` after register/login.
- [ ] Parse and store/read the returned `user` object.
- [ ] Use returned `user.onboardingCompleted` to route the user.
- [ ] Avoid direct Flutter-side Neo4j user creation during register/login.
- [ ] Keep direct Flutter Neo4j access only temporarily for MVP experiments if needed.
- [ ] Later move all Neo4j writes behind backend endpoints.

## Remaining Phase 1 Work

### Auth / User Flow
- [ ] Replace mock auth flow with backend-backed auth.
- [ ] Connect welcome/login/register UI to the real `AuthService`.
- [ ] On app start, check stored access token.
- [ ] Add `/me` call or local token/user restore to rebuild session.
- [ ] Route user based on `onboardingCompleted`.
- [ ] After onboarding genres and favorite movies are selected, mark onboarding as completed.
- [ ] Persist onboarding completion in Neo4j through backend endpoint.
- [ ] Make logout clear tokens and return to welcome screen.
- [ ] Handle duplicate email registration gracefully.
- [ ] Handle wrong password/login failure gracefully.
- [ ] Add basic loading/error states to auth screens.

### Neo4j App User Schema
- [ ] Create constraint:
  - `AppUser.uid` unique.
- [ ] Create constraint:
  - `AppUser.emailNormalized` unique.
- [ ] Confirm new users are created as `:AppUser`.
- [ ] Confirm no new users are created as old `:User`.
- [ ] Confirm `passwordHash` exists only in Neo4j/backend and is never returned to Flutter.
- [ ] Confirm user properties:
  - `uid`
  - `email`
  - `emailNormalized`
  - `displayName`
  - `passwordHash`
  - `createdAt`
  - `onboardingCompleted`
  - `roles`

### Neo4j Cleanup
- [ ] Check if old test users exist with label `:User`.
- [ ] Either delete old test nodes:
  - `MATCH (u:User) DETACH DELETE u`
- [ ] Or migrate old nodes:
  - add `:AppUser`
  - copy `userId` to `uid`
  - create `emailNormalized`
  - remove old `:User` label.
- [ ] Re-run seed script only after it has been updated to `:AppUser`.

### TMDB Integration
- [ ] Create or finalize TMDB config.
- [ ] Store TMDB token through environment / dart define for MVP.
- [ ] Create `TmdbApiClient`.
- [ ] Create TMDB DTOs:
  - `TmdbMovieDto`
  - `TmdbMovieDetailsDto`
  - `TmdbPageResponseDto`
  - `TmdbGenreDto`
- [ ] Create clean domain model:
  - `Movie`
  - `MovieDetails`
  - `Genre`
- [ ] Create `TmdbMovieMapper`.
- [ ] Create `MovieRepository` abstraction.
- [ ] Create `TmdbMovieRepository`.
- [ ] Connect Home to real popular/trending TMDB movies.
- [ ] Connect search to TMDB `/search/movie`.
- [ ] Connect movie details to TMDB `/movie/{movie_id}`.
- [ ] Build poster/backdrop URLs from TMDB image paths.
- [ ] Keep mock movie service available until real TMDB flow is stable.
- [ ] Decide whether TMDB calls stay in Flutter for MVP or move behind backend later.

### MovieLens Import
- [ ] Place downloaded MovieLens files in an importable folder:
  - `movies.csv`
  - `ratings.csv`
  - `tags.csv`
  - `links.csv`
- [ ] Create import script or Cypher file for MovieLens.
- [ ] Import `movies.csv` as `(:Movie)`.
- [ ] Import genres from `movies.csv` as `(:Genre)`.
- [ ] Create relationships:
  - `(:Movie)-[:IN_GENRE]->(:Genre)`
- [ ] Import `links.csv` and set:
  - `movieLensId`
  - `imdbId`
  - `imdbFullId`
  - `tmdbId`
- [ ] Import `ratings.csv`.
- [ ] Create MovieLens rating graph:
  - `(:MovieLensUser)-[:RATED {rating, timestamp, ratedAt}]->(:Movie)`
- [ ] Import `tags.csv`.
- [ ] Create MovieLens tag graph:
  - `(:MovieLensUser)-[:TAGGED {tag, timestamp, taggedAt}]->(:Movie)`
- [ ] Compute and store:
  - `movieLensAvgRating`
  - `movieLensRatingCount`
- [ ] Add useful constraints/indexes for:
  - `Movie.movieLensId`
  - `Movie.tmdbId`
  - `MovieLensUser.movieLensUserId`
  - `Genre.name`

### TMDB ↔ MovieLens Matching
- [ ] Use `links.csv.tmdbId` as the primary matching key.
- [ ] Confirm that TMDB movie `id` maps to Neo4j `Movie.tmdbId`.
- [ ] Add backend query:
  - find movie by `tmdbId`.
- [ ] Add backend query:
  - return MovieLens rating info by `tmdbId`.
- [ ] Add fallback matching using IMDb ID where `tmdbId` is missing.
- [ ] Avoid title-based matching unless absolutely necessary.
- [ ] Store only interacted-with TMDB movies if a movie does not exist in MovieLens.
- [ ] When user likes/dislikes/watchlists a TMDB movie, `MERGE` it into Neo4j by `tmdbId`.

### User Movie Interactions
- [ ] When user likes a movie, create:
  - `(:AppUser)-[:LIKED]->(:Movie)`
- [ ] When user dislikes a movie, create:
  - `(:AppUser)-[:DISLIKED]->(:Movie)`
- [ ] When user adds to watchlist, create:
  - `(:AppUser)-[:WATCHLISTED]->(:Movie)`
- [ ] When user rates a movie inside the app, create:
  - `(:AppUser)-[:RATED_APP {rating}]->(:Movie)`
- [ ] When user selects favorite genres during onboarding, create:
  - `(:AppUser)-[:PREFERS_GENRE]->(:Genre)`
- [ ] When user selects favorite movies during onboarding, create:
  - `(:AppUser)-[:SELECTED_FAVORITE]->(:Movie)`
- [ ] Update Library screen to read real user relationships.
- [ ] Update Swipe screen to write real like/dislike relationships.
- [ ] Update Movie Details screen to write real rating/watchlist actions.

### Recommendations
- [ ] Do not build full recommendation algorithm yet.
- [ ] Start with simple MovieLens-backed recommendations.
- [ ] Recommend movies liked by similar MovieLens users.
- [ ] Recommend movies sharing genres with liked/favorite movies.
- [ ] Filter out movies the app user already liked/disliked/watchlisted.
- [ ] Return only movies with valid `tmdbId` when UI needs TMDB poster/details.
- [ ] Add minimum rating count threshold to avoid unreliable MovieLens ratings.
- [ ] Keep recommendation query simple for Phase 1 MVP.

### Manual QA
- [ ] Manual device/emulator walkthrough of full Phase 1 flow.
- [ ] Manual Chrome/Edge walkthrough with backend running.
- [ ] Register new user.
- [ ] Login existing user.
- [ ] Logout.
- [ ] Restart app and restore session.
- [ ] Complete onboarding.
- [ ] Confirm onboarding does not repeat after completion.
- [ ] Swipe right/left and confirm Neo4j relationships are created.
- [ ] Add movie to watchlist and confirm Library updates.
- [ ] Open Movie Details and confirm data source consistency.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run backend manually with `npm start`.
- [ ] Run backend health check.
- [ ] Confirm Neo4j Browser shows expected graph nodes/relationships.

## Blocked / Issues
- [ ] Windows desktop smoke run/build is blocked locally because the Visual Studio toolchain is not installed/configured for Flutter desktop builds.
- [ ] Current Flutter prototype still contains mock Phase 1 services that need to be replaced gradually.
- [ ] Some legacy flow files may not map cleanly to Agreeo Phase 1 and should be removed or bypassed later.
- [ ] Backend auth currently needs migration from old `:User`/`userId` model to new `:AppUser`/`uid` model.
- [ ] Existing Neo4j database may contain old test `:User` nodes.
- [ ] MovieLens is downloaded but not yet imported into Neo4j.
- [ ] TMDB integration is not started yet.
- [ ] Real user/movie interaction persistence is not connected yet.

## Next Steps

### Immediate Next Steps
1. Update backend files:
   - `authController.js`
   - `neo4jService.js`
   - `server.js`
   - `jwtUtils.js` if needed
   - `seedInitialUsers.js`
2. Start Neo4j.
3. Start backend with `npm start`.
4. Test:
   - `GET /health/db`
   - `POST /auth/register`
   - `POST /auth/login`
   - `GET /me`
   - `PATCH /me/onboarding`
5. Clean or migrate old `:User` nodes.
6. Update Flutter `AuthService` to use backend auth response.
7. Connect Flutter welcome/login/register screens to real backend auth.
8. Use `onboardingCompleted` to route user after login/register.
9. Only after auth works, start MovieLens import.
10. Only after MovieLens import works, start TMDB integration.

### Backend Test Checklist
- [ ] `GET /health/db` returns `{ ok: true }`.
- [ ] Register creates `(:AppUser)`.
- [ ] Register returns access token, refresh token, and user object.
- [ ] Login returns access token, refresh token, and user object.
- [ ] Login does not reset onboarding.
- [ ] `/me` returns current user.
- [ ] `/me/onboarding` updates `onboardingCompleted`.
- [ ] No endpoint returns `passwordHash`.

### Neo4j Browser Test Queries
MATCH (u:AppUser)
RETURN u;
MATCH (u:User)
RETURN u;
SHOW CONSTRAINTS;
MATCH (u:AppUser {emailNormalized: "demo@example.com"})
RETURN u.uid, u.email, u.displayName, u.onboardingCompleted;

Do Not Start Yet
Friends screen
Friend Profile
Friend Requests
Movie Night creation
Invite friends flow
Waiting Room
Shortlist voting
Winner result screen
Advanced recommendation algorithm
Production auth hardening
Payment/subscription features
Real deployment
Full backend refactor
Full removal of legacy Flutter flow until Phase 1 auth + movie data are stable