# Neo4j, TMDB, and MovieLens MVP Architecture

## Why Neo4j

Agreeo needs to connect two different user populations and two different movie datasets while also storing app actions as graph relationships. Neo4j fits the MVP because likes, dislikes, watchlist state, favorites, MovieLens ratings, tags, and similarity paths are all naturally modeled as connected nodes and edges instead of wide documents or join-heavy tables.

## Why `:AppUser` and `:MovieLensUser` are separate

Real Agreeo users and imported MovieLens users are not the same entity and should never be merged.

- `:AppUser` represents authenticated product users identified by `uid`.
- `:MovieLensUser` represents imported collaborative-filtering users identified by `movieLensUserId`.

Keeping them separate prevents auth data from mixing with imported dataset identities and keeps recommendation queries explicit.

## Why `:Movie` and `:MovieLensMovie` are separate

Canonical app movies use TMDB IDs because TMDB is the UI catalog source for posters, details, search, and media assets.

MovieLens rows cannot be treated as canonical app movies because `links.csv` can map multiple `movieId` values to the same `tmdbId`. A previous direct import failed for exactly that reason. The safe split is:

- `(:Movie {tmdbId})` for canonical app movies
- `(:MovieLensMovie {movieLensId})` for raw MovieLens rows
- `(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)` for the cross-dataset match

## Why `tmdbId` is the canonical app movie identifier

TMDB is the source of truth for:

- posters
- backdrops
- search
- popular/trending lists
- movie details
- cast
- trailers
- images

Using `tmdbId` as the canonical identifier lets the app request UI-ready movie data from a single stable source while still enriching those movies with MovieLens graph data in Neo4j.

## How `links.csv` performs matching

`links.csv` is the explicit bridge from MovieLens to external movie IDs.

- `movieId` matches `:MovieLensMovie.movieLensId`
- `tmdbId` becomes the canonical `:Movie.tmdbId`
- `imdbId` is stored for traceability and future fallback work

This means the matching path is:

`MovieLens movieId -> links.csv -> tmdbId -> TMDB movie id`

## Why title-based matching is avoided

Title matching is unreliable because of alternate titles, localization, punctuation differences, remasters, duplicate franchise names, and year/version ambiguity. The MVP intentionally avoids title-based matching because `links.csv` already provides a cleaner structured bridge.

## Graph Schema

```cypher
(:AppUser)-[:LIKED]->(:Movie)
(:AppUser)-[:DISLIKED]->(:Movie)
(:AppUser)-[:WATCHLISTED]->(:Movie)
(:AppUser)-[:RATED_APP {rating}]->(:Movie)
(:AppUser)-[:PREFERS_GENRE]->(:Genre)
(:AppUser)-[:SELECTED_FAVORITE]->(:Movie)

(:MovieLensUser)-[:RATED {rating, timestamp, ratedAt}]->(:MovieLensMovie)
(:MovieLensUser)-[:TAGGED {tag, timestamp, taggedAt}]->(:MovieLensMovie)

(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)
(:MovieLensMovie)-[:IN_GENRE]->(:Genre)
(:Movie)-[:IN_GENRE]->(:Genre)
```

For the current MVP, genres are imported onto `:MovieLensMovie`. Canonical `(:Movie)-[:IN_GENRE]->(:Genre)` can be added later if app queries need it.

## Constraints And Indexes

The import script and backend startup align on these core schema rules:

```cypher
CREATE CONSTRAINT movielens_movie_id IF NOT EXISTS
FOR (m:MovieLensMovie)
REQUIRE m.movieLensId IS UNIQUE;

CREATE CONSTRAINT movie_tmdb_id IF NOT EXISTS
FOR (m:Movie)
REQUIRE m.tmdbId IS UNIQUE;

CREATE CONSTRAINT movielens_user_id IF NOT EXISTS
FOR (u:MovieLensUser)
REQUIRE u.movieLensUserId IS UNIQUE;

CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre)
REQUIRE g.name IS UNIQUE;

CREATE INDEX movie_title IF NOT EXISTS
FOR (m:Movie)
ON (m.title);

CREATE INDEX movielens_movie_title IF NOT EXISTS
FOR (m:MovieLensMovie)
ON (m.title);
```

## MovieLens Import Workflow

Run these commands from `backend/` after placing the CSV files in `backend/data/movielens/`.

### Docker

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

### Copy and execute the Cypher import

```bash
docker cp scripts/import_movielens.cypher agreeo-neo4j:/var/lib/neo4j/import/import_movielens.cypher

docker exec -it agreeo-neo4j cypher-shell -u neo4j -p password -d neo4j --file /var/lib/neo4j/import/import_movielens.cypher
```

## Verification Queries

```cypher
MATCH (m:Movie)
RETURN count(m) AS canonicalMovies;
```

```cypher
MATCH (ml:MovieLensMovie)
RETURN count(ml) AS movieLensMovies;
```

```cypher
MATCH (:MovieLensMovie)-[r:MATCHES_TMDB]->(:Movie)
RETURN count(r) AS tmdbMatches;
```

```cypher
MATCH (m:Movie {tmdbId: 862})
RETURN m.title, m.tmdbId, m.movieLensAvgRating, m.movieLensRatingCount;
```

## Backend Endpoints

Public movie reads:

- `GET /movies/popular`
- `GET /movies/search?query=...`
- `GET /movies/:tmdbId`

Authenticated movie actions:

- `POST /me/movies/:tmdbId/like`
- `POST /me/movies/:tmdbId/dislike`
- `POST /me/movies/:tmdbId/watchlist`
- `DELETE /me/movies/:tmdbId/watchlist`
- `GET /me/library`
- `GET /me/recommendations`

The backend calls TMDB for catalog data and enriches the response with Neo4j MovieLens aggregates by `tmdbId`.

## Backend Environment Setup

The Node backend now loads environment variables automatically from `backend/.env` via `dotenv`.

- edit `backend/.env`
- keep `backend/.env.example` as the tracked template
- set `TMDB_ACCESS_TOKEN` to the TMDB bearer token value there

Example:

```txt
NEO4J_URI=bolt://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=password
NEO4J_DATABASE=neo4j
JWT_SECRET=CHANGE_ME
TMDB_ACCESS_TOKEN=your_tmdb_bearer_token
```

## Flutter Integration Plan

The migration path is incremental so the mock service stays available until the real flow passes manual QA.

1. Home catalog reads `/movies/popular`.
2. Search reads `/movies/search`.
3. Movie Details reads `/movies/:tmdbId`.
4. Swipe reads `/me/recommendations` and can fall back to popular.
5. Like, dislike, and watchlist actions write through `/me/movies/:tmdbId/...`.
6. Library reads `/me/library`.

### Current Flutter status

The active prototype flow now uses a shared backend-backed movie adapter for read operations.

- bootstrap catalog load uses backend popular movies with mock fallback
- Home query search uses `/movies/search`
- Movie Details loads from `/movies/:tmdbId`
- Swipe suggestions resolve through recommendations first, then popular fallback

The active interaction state is still partially local for MVP safety. The app currently preserves its local undo-based behavior for likes, dislikes, watchlist toggles, watched state, ratings, and reviews until the backend exposes a fully symmetric mutation surface for those actions.

## Validation Status

The local Neo4j instance was checked after the MovieLens import and returned these counts:

- canonical `:Movie`: `87425`
- raw `:MovieLensMovie`: `87585`
- `:MATCHES_TMDB`: `87461`

Backend auth and health were also revalidated successfully against the local Neo4j container.

## Known MVP Limitations

- Recommendations use a simple MovieLens similarity query and are not tuned yet.
- Recommendation responses currently hydrate TMDB details one movie at a time.
- The import is manual; the repo does not download MovieLens automatically.
- The backend expects `TMDB_ACCESS_TOKEN` to be present in the runtime environment.
- Genre relationships are attached to `:MovieLensMovie` first; canonical movie genres can be added later if app queries need them.
- The mock Flutter movie service is still present as a fallback until full backend QA is complete.
- The active Flutter interaction flow still relies on local undo state for some movie mutations.
