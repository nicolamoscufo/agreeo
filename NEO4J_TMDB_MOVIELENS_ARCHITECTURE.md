# Agreeo Neo4j, TMDB and MovieLens Technical Architecture

## Purpose

This document explains the technical decisions made for integrating Neo4j, TMDB and MovieLens into the Agreeo MVP.

It is intended for:
- future development agents,
- maintainers,
- project documentation,
- a future technical report.

The current goal is not production hardening. The current goal is a clean MVP foundation that can support:
- real authentication,
- real movie catalog data,
- MovieLens-based ratings/recommendations,
- user movie interactions,
- future social/movie-night features.

---

## Current Backend Context

The backend is a small Node/Express service. The current backend structure includes files such as:

```txt
backend/
  authController.js
  jwtUtils.js
  neo4jService.js
  package.json
  seedInitialUsers.js
  server.js
```

The backend already handles authentication and connects to Neo4j.

The current auth decision is:

```cypher
(:AppUser {uid})
```

Real app users must use `:AppUser`, not `:User`, because the graph will also contain imported MovieLens users:

```cypher
(:MovieLensUser {movieLensUserId})
```

---

## Why Neo4j Is Used

Neo4j is used because Agreeo is naturally graph-shaped.

The app needs to model relationships between:
- app users,
- movies,
- genres,
- liked movies,
- disliked movies,
- watchlisted movies,
- app ratings,
- selected onboarding favorite genres,
- selected onboarding favorite movies,
- MovieLens users,
- MovieLens ratings,
- MovieLens tags,
- future friends,
- future group/movie-night sessions.

A relational model could support this, but Neo4j makes relationship-heavy queries more natural.

Example future queries:
- movies liked by similar users,
- movies common between friends,
- movies liked by users who liked the same onboarding favorites,
- compatibility between a group of friends,
- recommended movie shortlist for a movie night.

---

## Data Source Responsibilities

Agreeo uses three separate data layers.

### TMDB

TMDB is the catalog and presentation source.

It provides:
- movie title,
- poster,
- backdrop,
- overview,
- release date,
- vote average,
- cast,
- trailers,
- images,
- search,
- popular/trending lists,
- details pages.

TMDB movie IDs are treated as the canonical app-facing movie identifier:

```txt
tmdbId
```

### MovieLens

MovieLens is the historical recommendation dataset.

It provides:
- anonymous historical users,
- movie ratings,
- user-generated tags,
- movie genres,
- `links.csv` mapping MovieLens records to external IDs.

MovieLens does not provide rich posters or movie details. It should not be used as the UI catalog.

### Neo4j

Neo4j stores the graph that connects:
- real app users,
- canonical TMDB movies,
- raw MovieLens movie rows,
- MovieLens users,
- genres,
- ratings,
- tags,
- app interactions.

---

## Important Matching Decision

The matching between TMDB and MovieLens must not be done by title.

Title-based matching is fragile because MovieLens titles may be formatted differently from TMDB titles.

Examples:
- `Matrix, The (1999)` vs `The Matrix`
- `Lord of the Rings: The Fellowship of the Ring, The (2001)` vs `The Lord of the Rings: The Fellowship of the Ring`

The primary matching path is:

```txt
MovieLens movieId
  -> links.csv
  -> tmdbId
  -> TMDB movie id
```

Therefore:

```txt
TMDB movie.id == Neo4j Movie.tmdbId
```

---

## Duplicate `tmdbId` Issue and Final Schema Decision

A direct import initially attempted to store MovieLens movies as:

```cypher
(:Movie {movieLensId, tmdbId})
```

with a unique constraint on:

```cypher
Movie.tmdbId
```

This failed because some MovieLens rows can map to the same `tmdbId`.

Example failure pattern:

```txt
Node already exists with label Movie and property tmdbId = ...
```

The corrected model separates raw MovieLens records from canonical app movies.

### Final model

```cypher
(:MovieLensMovie {movieLensId})
  -[:MATCHES_TMDB]->
(:Movie {tmdbId})
```

This allows multiple MovieLens records to point to the same canonical TMDB movie.

The canonical app movie remains unique by `tmdbId`.

---

## Labels

### `:AppUser`

Real users registered in Agreeo.

Core MVP properties:

```txt
uid
email
emailNormalized
displayName
passwordHash
createdAt
onboardingCompleted
roles
```

`passwordHash` must stay backend/Neo4j only. It must never be returned to Flutter.

### `:MovieLensUser`

Anonymous users imported from MovieLens.

Core property:

```txt
movieLensUserId
```

These users are not real Agreeo accounts.

### `:MovieLensMovie`

Raw movie records imported from MovieLens.

Core properties:

```txt
movieLensId
movieLensTitle
title
source
imdbId
imdbFullId
movieLensAvgRating
movieLensRatingCount
```

### `:Movie`

Canonical app movie, identified by TMDB.

Core properties:

```txt
tmdbId
title
originalTitle
overview
posterPath
backdropPath
posterUrl
backdropUrl
releaseDate
voteAverage
imdbId
imdbFullId
movieLensAvgRating
movieLensRatingCount
source
createdFromMovieLens
updatedAt
```

### `:Genre`

Genre node.

Core property:

```txt
name
```

---

## Relationships

### App user relationships

```cypher
(:AppUser)-[:LIKED]->(:Movie)
(:AppUser)-[:DISLIKED]->(:Movie)
(:AppUser)-[:WATCHLISTED]->(:Movie)
(:AppUser)-[:RATED_APP {rating, createdAt}]->(:Movie)
(:AppUser)-[:PREFERS_GENRE]->(:Genre)
(:AppUser)-[:SELECTED_FAVORITE]->(:Movie)
```

Important: liked movies, disliked movies, watchlist movies and favorite genres must not be arrays on the user node. They must be graph relationships.

### MovieLens relationships

```cypher
(:MovieLensUser)-[:RATED {rating, timestamp, ratedAt}]->(:MovieLensMovie)
(:MovieLensUser)-[:TAGGED {tag, timestamp, taggedAt}]->(:MovieLensMovie)
(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)
(:MovieLensMovie)-[:IN_GENRE]->(:Genre)
```

---

## Constraints and Indexes

Recommended constraints:

```cypher
CREATE CONSTRAINT app_user_uid IF NOT EXISTS
FOR (u:AppUser)
REQUIRE u.uid IS UNIQUE;
```

```cypher
CREATE CONSTRAINT app_user_email IF NOT EXISTS
FOR (u:AppUser)
REQUIRE u.emailNormalized IS UNIQUE;
```

```cypher
CREATE CONSTRAINT movielens_movie_id IF NOT EXISTS
FOR (m:MovieLensMovie)
REQUIRE m.movieLensId IS UNIQUE;
```

```cypher
CREATE CONSTRAINT movie_tmdb_id IF NOT EXISTS
FOR (m:Movie)
REQUIRE m.tmdbId IS UNIQUE;
```

```cypher
CREATE CONSTRAINT movielens_user_id IF NOT EXISTS
FOR (u:MovieLensUser)
REQUIRE u.movieLensUserId IS UNIQUE;
```

```cypher
CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre)
REQUIRE g.name IS UNIQUE;
```

Recommended indexes:

```cypher
CREATE INDEX movie_title IF NOT EXISTS
FOR (m:Movie)
ON (m.title);
```

```cypher
CREATE INDEX movielens_movie_title IF NOT EXISTS
FOR (m:MovieLensMovie)
ON (m.title);
```

---

## Docker-Based Neo4j Setup

The project uses Neo4j through Docker.

Recommended local folder:

```txt
backend/
  data/
    movielens/
      movies.csv
      links.csv
      ratings.csv
      tags.csv
```

Recommended Docker run command from inside `backend/` on PowerShell:

```powershell
docker run `
  --name agreeo-neo4j `
  -p 7474:7474 `
  -p 7687:7687 `
  -e NEO4J_AUTH=neo4j/password `
  -v "${PWD}\data\movielens:/var/lib/neo4j/import" `
  -v agreeo_neo4j_data:/data `
  neo4j:5
```

The CSV files are mounted into:

```txt
/var/lib/neo4j/import
```

Inside Cypher, they are addressed as:

```cypher
file:///movies.csv
file:///links.csv
file:///ratings.csv
file:///tags.csv
```

---

## MovieLens Import Script

The import script should be placed at:

```txt
backend/scripts/import_movielens.cypher
```

The script should:
1. create constraints,
2. import MovieLens movies as `:MovieLensMovie`,
3. import `links.csv`,
4. create canonical `:Movie` nodes by `tmdbId`,
5. connect raw MovieLens records to canonical TMDB movies,
6. import ratings,
7. import tags,
8. calculate average ratings.

The script can be executed with:

```bash
docker cp scripts/import_movielens.cypher agreeo-neo4j:/var/lib/neo4j/import/import_movielens.cypher
```

```bash
docker exec -it agreeo-neo4j cypher-shell -u neo4j -p password -d neo4j --file /var/lib/neo4j/import/import_movielens.cypher
```

---

## Verification Queries

Count canonical app movies:

```cypher
MATCH (m:Movie)
RETURN count(m) AS canonicalMovies;
```

Count raw MovieLens movies:

```cypher
MATCH (ml:MovieLensMovie)
RETURN count(ml) AS movieLensMovies;
```

Count TMDB matches:

```cypher
MATCH (:MovieLensMovie)-[r:MATCHES_TMDB]->(:Movie)
RETURN count(r) AS tmdbMatches;
```

Check Toy Story by TMDB ID:

```cypher
MATCH (m:Movie {tmdbId: 862})
RETURN
  m.title,
  m.tmdbId,
  m.movieLensAvgRating,
  m.movieLensRatingCount;
```

Inspect high-signal movies:

```cypher
MATCH (m:Movie)
WHERE m.movieLensRatingCount IS NOT NULL
RETURN
  m.title AS title,
  m.tmdbId AS tmdbId,
  m.movieLensAvgRating AS avgRating,
  m.movieLensRatingCount AS ratingCount
ORDER BY ratingCount DESC
LIMIT 20;
```

Show old accidental `:User` nodes:

```cypher
MATCH (u:User)
RETURN u
LIMIT 20;
```

If old test users are not needed:

```cypher
MATCH (u:User)
DETACH DELETE u;
```

Do not delete `:AppUser` nodes unless intentionally resetting auth.

---

## Backend TMDB Integration

TMDB should be called from the backend for the MVP, not directly from Flutter.

Reasons:
- the TMDB token stays outside the Flutter app,
- the backend can enrich TMDB results with MovieLens data from Neo4j,
- Flutter receives a stable app-specific movie shape.

Required backend files:

```txt
backend/tmdbClient.js
backend/movieRepository.js
backend/movieController.js
```

Required environment variable:

```env
TMDB_ACCESS_TOKEN=...
```

### Public movie endpoints

```txt
GET /movies/popular
GET /movies/search?query=...
GET /movies/:tmdbId
```

These endpoints should:
1. call TMDB,
2. map the response to the app movie format,
3. enrich each result with MovieLens metadata from Neo4j using `tmdbId`.

### Authenticated user interaction endpoints

```txt
POST   /me/movies/:tmdbId/like
POST   /me/movies/:tmdbId/dislike
POST   /me/movies/:tmdbId/watchlist
DELETE /me/movies/:tmdbId/watchlist
GET    /me/library
GET    /me/recommendations
```

These endpoints require JWT middleware.

---

## App Movie JSON Shape

The backend should return movies in this shape:

```json
{
  "tmdbId": 862,
  "title": "Toy Story",
  "originalTitle": "Toy Story",
  "overview": "...",
  "posterPath": "/...",
  "backdropPath": "/...",
  "posterUrl": "https://image.tmdb.org/t/p/w500/...",
  "backdropUrl": "https://image.tmdb.org/t/p/w780/...",
  "releaseDate": "1995-10-30",
  "voteAverage": 7.9,
  "genreIds": [16, 12],
  "movieLens": {
    "avgRating": 3.9,
    "ratingCount": 215
  }
}
```

---

## Backend Query Patterns

### Find canonical movie by TMDB ID

```cypher
MATCH (m:Movie {tmdbId: $tmdbId})
RETURN
  m.tmdbId AS tmdbId,
  m.title AS title,
  m.movieLensAvgRating AS movieLensAvgRating,
  m.movieLensRatingCount AS movieLensRatingCount
LIMIT 1;
```

### Merge TMDB movie data

```cypher
MERGE (m:Movie {tmdbId: $tmdbId})
SET
  m.title = $title,
  m.originalTitle = $originalTitle,
  m.overview = $overview,
  m.posterPath = $posterPath,
  m.backdropPath = $backdropPath,
  m.posterUrl = $posterUrl,
  m.backdropUrl = $backdropUrl,
  m.releaseDate = $releaseDate,
  m.voteAverage = $voteAverage,
  m.updatedAt = datetime()
RETURN m;
```

### Like a movie

```cypher
MATCH (u:AppUser {uid: $uid})
MERGE (m:Movie {tmdbId: $movie.tmdbId})
SET
  m.title = $movie.title,
  m.originalTitle = $movie.originalTitle,
  m.overview = $movie.overview,
  m.posterPath = $movie.posterPath,
  m.backdropPath = $movie.backdropPath,
  m.posterUrl = $movie.posterUrl,
  m.backdropUrl = $movie.backdropUrl,
  m.releaseDate = $movie.releaseDate,
  m.voteAverage = $movie.voteAverage,
  m.updatedAt = datetime()
WITH u, m
OPTIONAL MATCH (u)-[oldDislike:DISLIKED]->(m)
DELETE oldDislike
MERGE (u)-[r:LIKED]->(m)
SET r.createdAt = datetime()
RETURN m;
```

### Dislike a movie

```cypher
MATCH (u:AppUser {uid: $uid})
MERGE (m:Movie {tmdbId: $movie.tmdbId})
SET
  m.title = $movie.title,
  m.posterPath = $movie.posterPath,
  m.posterUrl = $movie.posterUrl,
  m.updatedAt = datetime()
WITH u, m
OPTIONAL MATCH (u)-[oldLike:LIKED]->(m)
DELETE oldLike
MERGE (u)-[r:DISLIKED]->(m)
SET r.createdAt = datetime()
RETURN m;
```

### Watchlist a movie

```cypher
MATCH (u:AppUser {uid: $uid})
MERGE (m:Movie {tmdbId: $movie.tmdbId})
SET
  m.title = $movie.title,
  m.posterPath = $movie.posterPath,
  m.posterUrl = $movie.posterUrl,
  m.updatedAt = datetime()
MERGE (u)-[r:WATCHLISTED]->(m)
SET r.createdAt = datetime()
RETURN m;
```

---

## MVP Recommendation Strategy

Do not implement a complex recommendation algorithm yet.

The first MVP recommendation strategy is:

1. take movies liked or selected as favorites by the app user,
2. find MovieLens users who rated the corresponding MovieLens movies highly,
3. find other movies those MovieLens users rated highly,
4. return canonical TMDB movies,
5. filter out already liked/disliked/watchlisted movies.

Recommendation query:

```cypher
MATCH (me:AppUser {uid: $uid})-[:LIKED|SELECTED_FAVORITE]->(liked:Movie)
MATCH (liked)<-[:MATCHES_TMDB]-(likedMl:MovieLensMovie)<-[r1:RATED]-(similar:MovieLensUser)
WHERE r1.rating >= 4.0

MATCH (similar)-[r2:RATED]->(recMl:MovieLensMovie)-[:MATCHES_TMDB]->(rec:Movie)
WHERE r2.rating >= 4.0
  AND rec.tmdbId IS NOT NULL
  AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED]->(rec)

RETURN
  rec.tmdbId AS tmdbId,
  rec.title AS title,
  count(DISTINCT similar) AS similarUsers,
  avg(r2.rating) AS avgSimilarRating,
  rec.movieLensAvgRating AS globalAvg,
  rec.movieLensRatingCount AS ratingCount

ORDER BY
  similarUsers DESC,
  avgSimilarRating DESC,
  ratingCount DESC

LIMIT 30;
```

Fallback for users without likes/favorites:

```cypher
MATCH (m:Movie)
WHERE m.tmdbId IS NOT NULL
  AND m.movieLensRatingCount >= 50
RETURN
  m.tmdbId AS tmdbId,
  m.title AS title,
  m.movieLensAvgRating AS avgRating,
  m.movieLensRatingCount AS ratingCount
ORDER BY
  m.movieLensAvgRating DESC,
  m.movieLensRatingCount DESC
LIMIT 30;
```

---

## Flutter Integration Plan

Flutter should not talk directly to Neo4j for movie data once backend routes exist.

Recommended service:

```txt
lib/services/backend_movie_service.dart
```

or:

```txt
lib/features/movies/data/backend_movie_service.dart
```

Required methods:

```dart
Future<List<Movie>> getPopularMovies();
Future<List<Movie>> searchMovies(String query);
Future<MovieDetails> getMovieDetails(int tmdbId);
Future<void> likeMovie(Movie movie);
Future<void> dislikeMovie(Movie movie);
Future<void> addToWatchlist(Movie movie);
Future<void> removeFromWatchlist(int tmdbId);
Future<UserLibrary> getLibrary();
Future<List<Movie>> getRecommendations();
```

Migration order:
1. Home uses `/movies/popular`.
2. Search uses `/movies/search`.
3. Movie Details uses `/movies/:tmdbId`.
4. Swipe uses `/me/recommendations` or popular fallback.
5. Like/dislike/watchlist actions use `/me/movies/:tmdbId/...`.
6. Library uses `/me/library`.

Keep the mock movie service until all real flows are tested.

---

## Known MVP Limitations

- TMDB data is not cached yet.
- MovieLens import is batch/offline only.
- Recommendations are simple and query-based.
- No advanced graph algorithms are required yet.
- No Friends/Movie Night features should be started yet.
- Some MovieLens records may not have `tmdbId`.
- Some canonical `:Movie` nodes may be TMDB-only and have no MovieLens rating.
- Title-based matching is intentionally avoided.
- Auth is functional but not production-hardened.
- Direct Flutter-to-Neo4j code may still exist temporarily but should be phased out.

---

## Final Design Summary

The final MVP data design is:

```txt
TMDB = movie catalog and UI metadata
MovieLens = historical ratings/tags dataset
Neo4j = graph connecting users, movies, ratings and preferences
```

The central movie node for the app is:

```cypher
(:Movie {tmdbId})
```

The raw MovieLens movie node is:

```cypher
(:MovieLensMovie {movieLensId})
```

The bridge is:

```cypher
(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)
```

Real users interact only with canonical movies:

```cypher
(:AppUser)-[:LIKED|DISLIKED|WATCHLISTED]->(:Movie)
```

MovieLens users rate raw MovieLens movie records:

```cypher
(:MovieLensUser)-[:RATED]->(:MovieLensMovie)
```

This avoids duplicate `tmdbId` import problems and keeps the model clean for future recommendations and report writing.
