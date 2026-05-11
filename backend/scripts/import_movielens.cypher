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

LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
CALL {
  WITH row
  MERGE (m:MovieLensMovie {movieLensId: toInteger(row.movieId)})
  SET
    m.movieLensTitle = row.title,
    m.title = row.title,
    m.source = 'movielens'

  WITH m, split(row.genres, '|') AS genres
  UNWIND genres AS genreName
  WITH m, genreName
  WHERE genreName IS NOT NULL
    AND genreName <> ''
    AND genreName <> '(no genres listed)'
  MERGE (g:Genre {name: genreName})
  MERGE (m)-[:IN_GENRE]->(g)
} IN TRANSACTIONS OF 1000 ROWS;

LOAD CSV WITH HEADERS FROM 'file:///links.csv' AS row
CALL {
  WITH row
  MATCH (ml:MovieLensMovie {movieLensId: toInteger(row.movieId)})

  SET
    ml.imdbId = row.imdbId,
    ml.imdbFullId = CASE
      WHEN row.imdbId IS NULL OR trim(row.imdbId) = ''
      THEN null
      ELSE 'tt' + row.imdbId
    END

  WITH row, ml
  WHERE row.tmdbId IS NOT NULL AND trim(row.tmdbId) <> ''

  MERGE (m:Movie {tmdbId: toInteger(row.tmdbId)})
  ON CREATE SET
    m.title = ml.title,
    m.source = 'tmdb_movielens_link',
    m.createdFromMovieLens = true
  SET
    m.imdbId = row.imdbId,
    m.imdbFullId = CASE
      WHEN row.imdbId IS NULL OR trim(row.imdbId) = ''
      THEN null
      ELSE 'tt' + row.imdbId
    END

  MERGE (ml)-[:MATCHES_TMDB]->(m)
} IN TRANSACTIONS OF 1000 ROWS;

LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
CALL {
  WITH row
  MERGE (u:MovieLensUser {
    movieLensUserId: toInteger(row.userId)
  })

  MATCH (m:MovieLensMovie {
    movieLensId: toInteger(row.movieId)
  })

  MERGE (u)-[r:RATED]->(m)
  SET
    r.rating = toFloat(row.rating),
    r.timestamp = toInteger(row.timestamp),
    r.ratedAt = datetime({epochSeconds: toInteger(row.timestamp)})
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM 'file:///tags.csv' AS row
CALL {
  WITH row
  MERGE (u:MovieLensUser {
    movieLensUserId: toInteger(row.userId)
  })

  MATCH (m:MovieLensMovie {
    movieLensId: toInteger(row.movieId)
  })

  MERGE (u)-[t:TAGGED {tag: row.tag}]->(m)
  SET
    t.timestamp = toInteger(row.timestamp),
    t.taggedAt = datetime({epochSeconds: toInteger(row.timestamp)})
} IN TRANSACTIONS OF 10000 ROWS;

MATCH (m:MovieLensMovie)<-[r:RATED]-(:MovieLensUser)
WITH m, count(r) AS ratingCount, avg(r.rating) AS avgRating
SET
  m.movieLensRatingCount = ratingCount,
  m.movieLensAvgRating = round(avgRating * 100) / 100;

MATCH (m:Movie)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)<-[r:RATED]-(:MovieLensUser)
WITH m, count(r) AS ratingCount, avg(r.rating) AS avgRating
SET
  m.movieLensRatingCount = ratingCount,
  m.movieLensAvgRating = round(avgRating * 100) / 100;
