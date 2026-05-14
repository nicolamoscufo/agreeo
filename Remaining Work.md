# Remaining Work

## Recommendation Separation and Debugging Pass

Completed in this step:
- Split backend recommendation concepts into distinct `for-you` ranking and `daily-suggestions` taste-learning flows.
- Added backend support for `ALREADY_SEEN` mutations so swipe feedback can become a real exclusion signal.
- Added backend debug/stat plumbing for recommendation diagnostics and daily-swipe configuration flags.
- Wired the active Flutter prototype to separate Home recommendations and Swipe daily suggestions.
- Synced frontend like/dislike/watchlist/seen actions to backend movie-feedback endpoints.
- Added a dev-only recommendation debug screen entry from Profile.
- Refreshed the swipe card presentation and replaced the old inconsistent Movie Details layout.

Follow-up fixes in this step:
- Restored `Movie Details` to its previous implementation on request.
- Fixed Neo4j debug/daily query `LIMIT` handling so integer-only Cypher limits do not throw runtime `500` errors.
- Added stronger server-side fallback behavior so Home does not stay empty and Swipe does not fall back only through the client when recommendation candidates are unavailable.
- Removed the hardcoded backend daily-suggestions cap of `30` and made the batch size request-driven.
- Added swipe queue auto-refill so the app appends fresh untouched suggestions when the remaining queue gets low instead of waiting to fully exhaust.

Files changed in this step:
- `backend/movieRepository.js`
- `backend/movieController.js`
- `backend/server.js`
- `backend/.env.example`
- `lib/services/backend_movie_service.dart`
- `lib/shared/services/movie_service.dart`
- `lib/shared/services/backend_catalog_movie_service.dart`
- `lib/shared/services/mock_movie_service.dart`
- `lib/shared/services/user_movie_state_service.dart`
- `lib/shared/state/agreeo_app_controller.dart`
- `lib/shared/models/agreeo_models.dart`
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/swipe/presentation/swipe_screen.dart`
- `lib/features/movie_details/presentation/movie_details_screen.dart`
- `lib/features/debug/presentation/recommendation_debug_screen.dart`
- `lib/features/profile/presentation/profile_screen.dart`
- `lib/features/movie_details/presentation/movie_details_screen.dart`
- `backend/movieRepository.test.js`
- `lib/shared/services/movie_service.dart`
- `lib/shared/services/backend_catalog_movie_service.dart`
- `lib/shared/services/mock_movie_service.dart`
- `lib/services/backend_movie_service.dart`
- `lib/shared/state/agreeo_app_controller.dart`
- `lib/features/swipe/presentation/swipe_screen.dart`
- `test/shared/state/agreeo_app_controller_test.dart`

Still to do:
- Run a manual end-to-end pass against a live backend + Neo4j + TMDB setup to validate the new recommendation split and debug stats with real data.

Known bugs / technical debt right now:
- The recommendation debug screen currently renders the backend payload dynamically rather than via strongly typed Flutter models.
- `flutter analyze` now passes with only 16 existing info/warning items in older auth and shared movie-widget files outside this change.

Verification completed:
- Backend syntax checks pass for `movieRepository.js`, `movieController.js`, and `server.js`.
- Backend tests pass: `12/12`.
- Full Flutter test suite passes.
- `flutter analyze` reports only pre-existing non-blocking issues outside the new recommendation/debug/details flow.
- Swipe queue refill changes verified with passing controller tests and no new analyzer errors in the touched files.

Regression fix notes:
- `Recommendation debug` previously failed with Neo4j `LIMIT ... must be a non-negative integer`; the debug and exploratory recommendation queries now inline sanitized integer limits.
- Home no longer depends on an empty Neo4j candidate list alone; the backend now serves a server-side popular fallback when graph candidates are missing or cannot be hydrated.
- Swipe no longer has to drop immediately to the client-side popular fallback when the backend learning queue is empty; the backend now provides its own broader popular exploration fallback.
- The frontend debug screen now handles empty/partial payloads gracefully and shows explicit Home/Swipe fallback status, strategy, reason, and source breakdown.

## Final Recommendation Regression Pass

Final status:
- Recommendation flow is wired end-to-end from Flutter onboarding to Neo4j preference relationships, backend ranking, cold-start fallback, TMDB hydration, diversification, and Flutter Home consumption.
- API response shape remains compatible with the Flutter app: `/me/recommendations` still returns `{ results: [...] }` with movie payloads plus existing recommendation metadata.
- All recommendation paths explicitly exclude already processed movies where backend state exists: `LIKED`, `DISLIKED`, `WATCHLISTED`, `SELECTED_FAVORITE`, and `ALREADY_SEEN`.
- Flutter Home now treats backend recommendations as source of truth and only uses client fallback when the recommendation request fails.

What changed:
- Added `SELECTED_FAVORITE` and `PREFERS_GENRE` persistence from onboarding.
- Reworked personalized recommendations with weighted similarity, rating intensity, popularity dampening, negative genre penalties, and candidate score reranking.
- Reworked cold start fallback with onboarding genre boosts, favorite-movie genre boosts, Bayesian quality, and rating-count confidence.
- Added bounded TMDB hydration, stale-ID logging, deterministic diversification, and duplicate/near-duplicate filtering.
- Updated Flutter fallback hierarchy and fixed stale widget test expectations for the current auth UI.

How to test:
- Backend syntax and tests: `cd backend && node --check movieRepository.js && node --check movieController.js && node --check movieRepository.test.js && node --check movieController.test.js && npm test`
- Flutter formatting: `dart format lib/shared/services/backend_catalog_movie_service.dart test/services/backend_catalog_movie_service_test.dart test/widget_test.dart`
- Flutter focused fallback test: `flutter test test/services/backend_catalog_movie_service_test.dart`
- Full Flutter tests: `flutter test`
- Static analysis: `flutter analyze`

Verified:
- Backend tests pass: `10/10`.
- Focused Flutter Home fallback service tests pass: `2/2`.
- Full Flutter tests pass: `10/10`.
- Flutter web build passes: `flutter build web`.
- `flutter analyze` still reports 33 pre-existing info/warning items in unrelated auth/movie-details/movie-widgets files.

Known limitations:
- `ALREADY_SEEN` is excluded by recommendation queries, but a backend mutation path for marking it is still not part of the current API surface.
- Invalid TMDB IDs are logged but not persisted back to Neo4j because there is no safe invalidation schema yet.
- Ranking and diversification remain heuristic; there is no learned embedding, Pearson/cosine normalization, or experimentation framework.
- Bayesian fallback priors are static instead of computed from the imported graph.
- Genre balancing depends on TMDB hydration and MovieLens genre coverage.

Next possible improvements:
- Add backend mutation support for `ALREADY_SEEN` and wire it from Flutter watched state.
- Add a safe `tmdbInvalid` or `tmdbStatus` property/migration for stale IDs.
- Compute global rating priors from Neo4j instead of hardcoding them.
- Add integration tests against a seeded local Neo4j fixture for all five recommendation scenarios: no data, onboarding genres, selected favorites, likes/dislikes, and partial TMDB failures.

## SELECTED_FAVORITE Recommendation Signal

Changed:
- Flutter onboarding now sends selected favorite TMDB IDs when finishing onboarding.
- `PATCH /me/onboarding` still accepts the existing `{ "completed": true }` payload and now optionally accepts `selectedFavoriteTmdbIds`.
- The backend fetches those TMDB movies, merges `Movie` nodes by `tmdbId`, and creates `(:AppUser)-[:SELECTED_FAVORITE {createdAt, weight: 4.0}]->(:Movie)` relationships.
- Recommendation exclusions now include `SELECTED_FAVORITE` and `ALREADY_SEEN` in both personalized and fallback paths.

Tested:
- Added backend `node:test` coverage for selected favorite persistence Cypher and recommendation exclusion Cypher.
- `npm test` in `backend/` passes.
- `dart format` was run on touched Dart files.
- `flutter analyze` still reports pre-existing warnings/infos in unrelated files, including unused imports in `lib/features/movie_details/presentation/movie_details_screen.dart` and deprecated `withOpacity` usage.
- `flutter test` still fails in `test/widget_test.dart` because the auth landing screen now renders two `Text("Agreeo")` widgets for the glow effect.

Remains:
- Run an end-to-end manual check against local Neo4j and TMDB credentials to confirm onboarding creates the relationships in a real graph.
- Consider surfacing selected favorites in `/me/library` if the product needs users to review or edit onboarding favorites later.
- Clean up existing Flutter analyzer/test failures outside this change.

## Collaborative Filtering Similarity

Changed:
- Personalized recommendations now seed from `SELECTED_FAVORITE`, `LIKED`, and `WATCHLISTED` instead of only `SELECTED_FAVORITE|LIKED`.
- Similar MovieLens users are scored with `sum(userPreferenceWeight * (r1.rating - 3.0) * popularityPenalty)`.
- Signal weights are `SELECTED_FAVORITE: relationship weight or 4.0`, `LIKED: 3.0`, and `WATCHLISTED: 1.25`.
- MovieLens 5-star overlap now contributes more than 4-star overlap through `(rating - 3.0)`.
- Seed popularity is dampened with `1 / log(movieLensRatingCount + 2)`, falling back to `0` safely when counts are missing.
- Candidate ranking now uses `collaborativeScore = sum(similarityScore * (candidateRating - 3.0))` before the existing tie-breakers.

Tested:
- Added backend `node:test` coverage for weighted similarity terms, popularity penalty, overlap aggregation, and collaborative-score ordering.

Limitations:
- This is still a lightweight heuristic, not a normalized cosine/Pearson similarity model.
- Duplicate MovieLens rows mapping to the same TMDB movie may still add extra overlap weight if they exist in the imported dataset.

## Negative Feedback Recommendation Penalty

Changed:
- `DISLIKED` movies remain excluded from recommendation results.
- Personalized recommendations now collect genres from movies the user disliked through both available schema paths: `(:Movie)<-[:MATCHES_TMDB]-(:MovieLensMovie)-[:IN_GENRE]->(:Genre)` and optional canonical `(:Movie)-[:IN_GENRE]->(:Genre)`.
- A genre penalty only applies after repeated dislikes in the same genre. The current threshold is `2` disliked movies.
- Candidate movies sharing repeatedly disliked genres receive a soft `negativePenalty` instead of being hard-blocked.
- Final ranking now uses `finalScore = collaborativeScore - negativePenalty`, preserving collaborative ranking while lowering candidates close to repeatedly disliked content.

Tested:
- Added backend `node:test` coverage for the disliked-genre collection, safe optional genre paths, penalty threshold, and `finalScore` ordering.

Limitations:
- Genre coverage depends on the MovieLens import; canonical `Movie` genre relationships are optional and may not exist yet.
- The penalty is genre-level only. It does not yet learn disliked directors, actors, franchises, language, or finer-grained embeddings/clusters.
- The fallback cold-start query still only excludes disliked titles; genre penalties currently apply to the personalized collaborative path.

## Cold Start Fallback

Changed:
- Flutter onboarding now sends selected genres to the existing `/me/onboarding` endpoint along with selected favorite TMDB IDs.
- The backend persists onboarding genres as `(:AppUser)-[:PREFERS_GENRE]->(:Genre)` while keeping the old onboarding payload valid.
- The recommendation fallback now ranks candidates with a tiered score:
  - selected onboarding genres get the strongest boost,
  - genres shared with selected favorite/reference movies get a secondary boost,
  - users with no usable onboarding data fall back to global quality.
- Fallback candidates still exclude `LIKED`, `DISLIKED`, `WATCHLISTED`, `SELECTED_FAVORITE`, and `ALREADY_SEEN` movies.
- Fallback quality now uses a Bayesian rating estimate with rating-count confidence instead of raw average rating only.
- Low-confidence movies are filtered with `minFallbackRatingCount: 50`.

Tested:
- Added backend `node:test` coverage for `PREFERS_GENRE` persistence and the tiered cold-start fallback query.
- `npm test` in `backend/` passes.
- `dart format` was run on touched Dart files.
- `flutter analyze` still reports existing unrelated warnings/infos in auth/movie details/movie widgets files.

Limitations:
- The fallback uses genre overlap only for favorite/reference movies when collaborative favorite expansion has no personalized results.
- Genre quality depends on the MovieLens genre import; canonical `Movie` genre relationships are optional and may be sparse.
- The Bayesian prior is currently static (`globalMeanRating: 3.5`, `bayesianPriorWeight: 100.0`) rather than computed from the imported graph.

## Recommendation Diversification

Changed:
- The repository now returns a larger candidate pool (`LIMIT 80`) for both personalized and fallback paths.
- The controller applies a deterministic `diversifyRecommendations` rerank before returning the top 30 results.
- Diversification removes duplicate TMDB IDs and near-duplicate normalized titles.
- When genre data exists, the reranker caps repeated genre pressure so one cluster does not dominate the final list.
- When genre data is missing, the reranker still deduplicates safely and keeps a TODO for future genre-aware balancing.

Tested:
- Added backend `node:test` coverage for duplicate removal, genre caps, and the no-genre fallback behavior.
- `npm test` in `backend/` passes.

Limitations:
- The current reranker is heuristic and deterministic, not a learned diversity model.
- Near-duplicate detection is title-based and may miss some franchise variants.
- Genre balancing depends on hydrated TMDB genre IDs in the controller layer.

## TMDB Hydration

Changed:
- The recommendation endpoint now hydrates Neo4j-ranked candidates in bounded batches instead of serially one-by-one.
- TMDB 404s and invalid payloads are skipped without failing the whole response.
- Hydration preserves ranking order as much as possible by processing batches in input order and stopping once 30 valid movies are collected.
- Stale TMDB IDs are logged clearly in the backend.

Tested:
- Added backend `node:test` coverage for stale TMDB IDs, ordering, and early-stop hydration.
- `npm test` in `backend/` passes.

Limitations:
- Invalid TMDB IDs are only logged for now; there is no safe Neo4j invalidation flag yet.
- The hydrator still depends on TMDB availability for full enrichment, so the final list can shrink if many candidates are stale.

## Flutter Home Fallback Hierarchy

Changed:
- The Home screen service now treats backend recommendations as the primary source of truth.
- Flutter only falls back to backend popular movies, then mock/local fallback, when the recommendation request itself fails completely.
- Empty backend recommendation results are now respected instead of being replaced by popular movies.
- Emergency fallback logs are emitted through `debugPrint` for easier debugging.

Tested:
- Added Flutter service coverage for empty backend recommendations and backend failure emergency fallback.
- `flutter test test/services/backend_catalog_movie_service_test.dart` passes.

Limitations:
- The client still relies on backend popular movies as an emergency path if the backend recommendation request throws.
- This does not change the backend ranking/fallback logic; it only makes Flutter respect it consistently.
