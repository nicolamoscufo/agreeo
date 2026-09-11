# Agreeo / MoveMate Project Context and Neo4j Integration Guide

**Last updated:** 2026-05-10  
**Intended audience:** repository maintainers, backend and frontend developers, project reviewers  
**Project origin:** User-Driven Software Engineering course project, originally assigned as **Project D – MoveMate**  
**Current product name used in the assignment:** **Agreeo**

---

## 1. Executive Summary

Agreeo is a mobile-first application that helps groups of friends, roommates, couples, or young adults decide what movie or TV series to watch together.

The original course brief, **Project D – MoveMate**, describes an app that lets groups propose and vote on movies or TV shows, share preferences and recommendations, and make group decision-making more interactive, fun, and effortless. The current project expands that brief into **Agreeo**, a product focused on reducing the frustration of group movie selection.

The core idea is simple:

> Instead of forcing a group to choose a movie only when everyone is already together, Agreeo collects lightweight individual preferences over time and later uses those preferences to generate a small, fair, group-compatible shortlist for a movie night.

Agreeo is not just a movie discovery app. Its main value proposition is to act as a **decision-shortener**: it reduces the typical 10–30 minutes wasted scrolling, debating, rejecting suggestions, and manually checking availability across streaming services.

---

## 2. What the App Does

Agreeo supports two complementary modes of interaction:

1. **Individual mode**
   - The user receives a small number of movie recommendations.
   - The user reacts quickly using lightweight actions:
     - Like
     - Dislike
     - Already seen
     - Save for later
   - These interactions build a persistent preference profile.

2. **Group mode**
   - A user creates a movie night.
   - The user invites friends.
   - The group or organizer defines constraints such as:
     - Movie vs. TV series
     - Genres to include or exclude
     - Maximum duration
     - Available streaming platforms
   - Agreeo combines the preferences of all participating users.
   - The app produces a short, ranked list of movies that are likely to satisfy the group.
   - The group votes or confirms the final choice.
   - Once consensus is reached, the app clearly displays the chosen movie.

The target experience is:

> A group should start from a curated shortlist, not from an infinite catalog.

---

## 3. Problem Being Solved

The project identified a recurring social problem: people often spend more time choosing what to watch than actually enjoying the movie night.

The assignment highlights several concrete pain points:

- Too many options on streaming platforms.
- Difficulty finding something that satisfies everyone.
- Time wasted discussing and scrolling.
- Repetitive decision-making every time a group meets.
- Existing recommendation systems mostly optimize for individuals, not groups.
- Users often discover interesting movies during the week but forget them when the group is together.
- Group decisions are often made under pressure at the last minute.

Agreeo solves this by moving part of the decision process earlier in time. Daily micro-interactions produce useful preference data before the actual movie night.

---

## 4. Target Users

The primary target users are young adults, mainly aged **18–24 / 19–24**, especially:

- University students.
- Young workers.
- Friends.
- Roommates.
- Couples.
- Informal groups that watch movies together in domestic or social settings.

The assignment persona is **Giulia Romano**, a 22-year-old university student who often organizes movie nights with her roommates or friends. She wants the group to reach a decision quickly, but she does not want to impose her own preferences.

The product should therefore prioritize:

- Fast interactions.
- Mobile-first design.
- Low cognitive load.
- Fairness between participants.
- Clear group consensus.
- Minimal friction before watching.

---

## 5. Core User Needs

Agreeo must support the following user needs:

1. **Reduce decision time**
   - The app should shorten the group decision process.
   - Users should not have to scroll through huge catalogs together.

2. **Make group choice feel fair**
   - The final shortlist should reflect multiple people’s preferences.
   - The system should not simply follow the organizer’s taste.

3. **Capture preferences before the movie night**
   - Users should be able to like, dislike, save, or mark titles as already seen during the week.

4. **Avoid choice overload**
   - The app should show a small number of relevant options.
   - The swipe interface should focus on one title at a time.

5. **Respect contextual constraints**
   - Movie nights often have practical constraints:
     - Time available
     - Genre exclusions
     - Streaming platform availability
     - Whether the group wants a movie or a series

6. **Keep the interaction lightweight**
   - Users should not feel forced to perform long setup tasks.
   - Daily recommendations should remain optional and non-intrusive.

---

## 6. Product Positioning

Agreeo should be understood as a **group decision support system for entertainment**, not as a generic streaming catalog.

### It is not primarily:

- A Netflix clone.
- A full streaming platform.
- A trailer-watching app.
- A social network for movie reviews.
- A replacement for IMDb, Letterboxd, or JustWatch.

### It is primarily:

- A preference collection system.
- A group matching system.
- A social consensus tool.
- A movie night organizer.
- A lightweight recommendation and voting app.

---

## 7. Competitor Gap

The assignment identifies three competitor categories:

### 7.1 Fragmented Direct Competitors

Apps such as Movie Swiper or similar swipe-to-match tools use a relevant interaction model but often lack robust group synchronization, strong UX, and scalable group decision-making.

### 7.2 Indirect Social Platforms

Platforms such as Letterboxd or IMDb are strong for reviews, ratings, watchlists, and individual tracking. However, they do not provide a structured real-time mechanism for group consensus.

### 7.3 Utility Aggregators

Services such as JustWatch solve the question “where can I watch this?”, but they do not solve “what should our group choose together?”

Agreeo differentiates itself by combining:

- Quick preference capture.
- Group-aware recommendation.
- Contextual movie night constraints.
- Shared shortlist generation.
- Consensus-oriented voting.

---

## 8. Current Functional Scope

The current assignment defines the following preliminary functionalities:

- Onboarding for initial preference collection.
- Daily personalized movie recommendations.
- Quick feedback actions:
  - Like
  - Dislike
  - Already seen
  - Save for later
- Persistent tracking of user preferences.
- Group creation for shared viewing sessions.
- Contextual constraints for a movie night.
- Shared shortlist generation based on combined preferences.
- Support for quick and fair final group decision-making.

The final system requirements prioritize the following features:

### High Priority / MVP Core

- **Synchronized swiping**
  - Main mechanism for gathering preferences.
  - Should support individual and group contexts.

- **Group streaming filters**
  - The shortlist should only include content available on platforms accessible to the group.

- **Real-time match notifications**
  - Users should receive immediate feedback when a group match or consensus is reached.

### Medium Priority

- **Movie of the Day**
  - Useful but should remain optional.
  - It helps build personal preference history over time.

- **Shared group watchlist**
  - A collaborative list where members can seed the decision process with proposals.

### Low Priority / Deprioritized

- **In-app trailers**
  - Users showed limited interest.
  - The app should remain lightweight.
  - Trailer support can be replaced by external links or minimal metadata.

---

## 9. Current Known Implementation Baseline

The current implementation context, based on the latest project state, is approximately:

- Flutter mobile app.
- Riverpod-based state management.
- Phase 1 prototype flow connected at app level.
- Mock authentication welcome screen.
- Onboarding flow.
- Five-tab shell:
  - Home
  - Library
  - Swipe
  - Friends
  - Profile
- Implemented or partially implemented areas:
  - Home
  - Swipe
  - Library
  - Movie Details
  - Profile
  - Friends placeholder
- Swipe card interactions are embedded inside the card.
- Swipe UI uses a near full-screen cinematic layout.
- Horizontal animated gestures support like/dislike behavior.
- The repo has previously passed `flutter analyze` and the Flutter test suite.
- Windows desktop smoke run may be blocked locally if the Visual Studio toolchain is missing.

Treat this section as implementation guidance. If the repository has changed, inspect the repo first and update this file accordingly.

---

## 10. Main App Areas

### 10.1 Authentication / Welcome

Purpose:

- Introduce the value proposition.
- Allow sign up or login.
- Support standard email/password authentication.
- Optionally support Google/Apple sign-in later.

Important UX goal:

- The first screen must immediately communicate that the app helps organize movie nights and choose content together.

---

### 10.2 Onboarding

Purpose:

- Solve the cold start problem.
- Collect initial user preferences before recommendations start.

Expected steps:

1. Choose favorite genres.
2. Select favorite movies, up to 10 reference titles.
3. Optionally skip or complete faster in later prototypes, because usability testing showed that expert users may want to start using the app without a long setup.

Important UX details:

- Genre chips should clearly show selected/unselected states.
- A counter or progress indicator should be visible when selecting favorite movies.
- The “Continue” or “Get Started” action should clearly explain why it is disabled if the minimum selection threshold has not been reached.

---

### 10.3 Home

Purpose:

- Provide a lightweight discovery dashboard.
- Show curated or personalized content.
- Provide entry points to Swipe, search, movie details, and possibly movie night creation.

Expected content:

- Search bar.
- Recommended movies.
- Top-rated or trending sections.
- Continue preference-building prompts.
- Optional “Movie of the Day”.

Do not overload Home. It must remain a decision-support entry point, not an endless catalog.

---

### 10.4 Swipe

Purpose:

- Main interaction for collecting user preferences.
- Present one movie at a time.
- Reduce choice overload.

Expected actions:

- Like
- Dislike
- Already seen
- Save for later
- Undo accidental action
- Open movie details

Design principle:

> The swipe screen should make preference capture feel almost effortless.

Implementation notes:

- Store every user action as structured preference data.
- Actions should be idempotent where possible.
- The system should prevent duplicate contradictory states, for example the same user should not simultaneously `LIKED` and `DISLIKED` the same movie.
- A later action may update or supersede an earlier one.

---

### 10.5 Movie Details

Purpose:

- Give enough information to make a decision without turning the app into a content consumption platform.

Expected fields:

- Title
- Poster / backdrop
- Release year
- Duration
- Genres
- Synopsis
- Cast
- Rating / popularity
- Available streaming platforms, if integrated
- Action buttons:
  - Like
  - Dislike
  - Already seen
  - Save

Important UX detail:

- Quick action buttons should remain available even after opening details, so the user does not need to navigate back just to vote.

---

### 10.6 Library

Purpose:

- Store user-specific lists and preference history.

Expected sections:

- Saved for later.
- Liked movies.
- Already seen.
- Possibly disliked / hidden titles, mostly for debugging or preference management.
- Group watchlists, later.

Implementation note:

- Library should be backed by user preference relationships, not only local UI state.

---

### 10.7 Friends

Purpose:

- Manage social connections.
- Create movie nights.
- Invite friends to voting sessions.

Current phase may only include a placeholder, but the intended future behavior is central to the product.

Expected features:

- Friend list.
- Pending requests.
- Search users.
- Add/remove friends.
- Create movie night.
- Invite friends.
- Display active group sessions.

Important UX issues from prototype evaluation:

- Removing a friend from an invite list should avoid accidental destructive actions.
- Use confirmation or undo for accidental removal, especially when the list is long.
- Empty states must be designed clearly.

---

### 10.8 Movie Night Flow

Purpose:

- Transform chaotic group negotiation into a structured decision flow.

Expected steps:

1. Create movie night.
2. Invite friends.
3. Set constraints:
   - Content type: movie or TV series.
   - Genre exclusions.
   - Maximum duration.
   - Available streaming platforms.
   - Optional special constraints, such as including older classics.
4. Wait for participants or gather existing preference history.
5. Generate shortlist.
6. Let users vote.
7. Detect consensus.
8. Display final selected movie.
9. Provide clear next actions:
   - Back to Home.
   - Save to group watchlist.
   - Open external streaming/search link.
   - Start another round if no consensus is reached.

Important issue to fix:

- The final “Consensus Reached” screen must not be a dead end. It needs a clear CTA.

---

## 11. HCI Design Principles to Preserve

The project is part of a User-Driven Software Engineering course, so implementation must preserve the HCI reasoning behind the prototype.

### 11.1 User-Centered Development

The project follows an iterative user-centered process:

1. Analyze users and context.
2. Define personas and scenarios.
3. Collect user requirements.
4. Analyze competitors.
5. Model tasks through HTA.
6. Design flows through STNs.
7. Build prototypes.
8. Evaluate prototypes.
9. Improve the system based on findings.

Developers must not treat the UI as random screens. Each flow should map back to user needs and task models.

### 11.2 Interaction Design Basics

The UI should respect:

- Clear navigation.
- Clear indication of where the user is.
- Clear indication of what the user can do.
- Clear indication of what will happen after an action.
- Clear feedback after every meaningful action.
- Logical grouping of controls.
- Strong visual hierarchy.
- Enough white space.
- Consistent labels and icons.
- Avoidance of color-only information, for accessibility.
- Reversible or undoable actions where possible.
- Explicit confirmation for destructive actions.

### 11.3 Prototype Evaluation Findings

The current prototype evaluation identified issues to fix:

- Movie selection counter during onboarding was not visible enough.
- Final consensus screen lacked a clear CTA.
- Friend removal from invite list could happen accidentally.
- Some users wanted to skip the initial selection of 10 movies.
- Empty states and edge cases need more attention.
- Error messages should be designed for cases such as “no movies found with these constraints”.

---

## 12. Why Neo4j Is Being Integrated

Neo4j is being integrated because Agreeo’s core domain is naturally graph-shaped.

The app is not only storing isolated users and movies. It must continuously reason about relationships between:

- Users.
- Friends.
- Groups.
- Movie nights.
- Movies.
- Genres.
- Streaming platforms.
- Preference actions.
- Votes.
- Watchlists.
- Shared constraints.
- Similar users.
- Similar movies.
- Group compatibility.

A relational database can store this information, but the most important product questions are relationship-heavy:

- Which movies are liked by several people in this group?
- Which movies are liked by friends of this user?
- Which movies match the group’s shared platforms?
- Which movies are compatible with the group’s genre and duration constraints?
- Which users have similar taste?
- Which saved movies should be proposed for a movie night?
- Which movies should be excluded because someone already disliked or already watched them?
- Which groups repeatedly agree on the same genres?
- Which title creates the highest consensus score for this specific group?

These are graph traversal and relationship scoring problems. Neo4j makes these relationships explicit and queryable.

Important:

> Neo4j should not be added just because it is trendy. It should be used because the app’s recommendation, consensus, and social matching logic depends on connected data.

---

## 13. What Neo4j Should Be Responsible For

Neo4j should act as the graph intelligence layer of the application.

It should be responsible for:

- Modeling users and their social graph.
- Modeling movies and metadata relationships.
- Modeling genres, actors, directors, platforms, and tags.
- Storing user preference relationships with properties.
- Finding candidate movies for individuals and groups.
- Computing group compatibility signals.
- Supporting shortlist generation.
- Supporting social discovery, such as movies liked by friends or similar users.
- Supporting future graph-based recommendations.

Neo4j should not necessarily be responsible for:

- Authentication credentials.
- Raw password storage.
- Large binary files.
- Image storage.
- Push notification delivery.
- Client session management.
- UI state that only matters locally.
- Payment or billing data, if ever added.
- Anything better handled by Firebase/Auth0/Supabase/Postgres/object storage/etc.

A clean architecture should keep authentication and application APIs separate from direct Neo4j access.

---

## 14. Recommended High-Level Architecture

Suggested architecture:

```text
Flutter Mobile App
        |
        v
Backend API / BFF Layer
        |
        +--> Auth Provider
        |
        +--> Movie Metadata Provider (e.g., TMDB or equivalent)
        |
        +--> Neo4j Graph Database
        |
        +--> Optional relational/document store for non-graph app data
```

### Why not connect Flutter directly to Neo4j?

The mobile app should not directly connect to Neo4j because:

- Database credentials would be exposed.
- Authorization rules would be harder to enforce.
- Query logic would be duplicated in the client.
- API evolution would become harder.
- Graph queries may need server-side validation, ranking, caching, and rate limiting.

Instead, create backend endpoints such as:

- `POST /users/{id}/preferences`
- `GET /users/{id}/recommendations/daily`
- `POST /movie-nights`
- `POST /movie-nights/{id}/invite`
- `POST /movie-nights/{id}/constraints`
- `GET /movie-nights/{id}/shortlist`
- `POST /movie-nights/{id}/votes`
- `GET /movie-nights/{id}/result`

The backend translates these API calls into Neo4j Cypher queries.

---

## 15. Proposed Neo4j Graph Model

This schema is intentionally practical and developer-friendly. Adapt names to the existing repository conventions.

### 15.1 Node Labels

```text
(:User)
(:Movie)
(:Genre)
(:Person)          // actor, director, creator
(:Platform)        // Netflix, Prime Video, Disney+, etc.
(:MovieNight)
(:Group)
(:Tag)
```

Optional later:

```text
(:Series)
(:Episode)
(:ProviderRegion)
(:Language)
(:Country)
```

### 15.2 Core User Properties

```text
User {
  id: string,
  username: string,
  displayName: string,
  emailHash?: string,
  createdAt: datetime,
  updatedAt: datetime,
  avatarUrl?: string,
  onboardingCompleted: boolean
}
```

Do not store plain passwords in Neo4j.

### 15.3 Core Movie Properties

```text
Movie {
  id: string,              // internal ID
  tmdbId?: integer,        // if TMDB is used
  imdbId?: string,
  title: string,
  originalTitle?: string,
  releaseYear?: integer,
  durationMinutes?: integer,
  overview?: string,
  posterUrl?: string,
  backdropUrl?: string,
  popularity?: float,
  voteAverage?: float,
  contentType: "movie" | "series",
  createdAt: datetime,
  updatedAt: datetime
}
```

### 15.4 Relationship Types

```text
(:User)-[:FRIEND_OF {since, status}]->(:User)

(:User)-[:LIKED {createdAt, source, strength}]->(:Movie)
(:User)-[:DISLIKED {createdAt, source}]->(:Movie)
(:User)-[:SEEN {createdAt, source}]->(:Movie)
(:User)-[:SAVED {createdAt, source}]->(:Movie)

(:User)-[:MEMBER_OF]->(:Group)
(:Group)-[:HAS_MEMBER]->(:User)

(:User)-[:CREATED]->(:MovieNight)
(:User)-[:INVITED_TO {status, invitedAt, respondedAt}]->(:MovieNight)
(:User)-[:PARTICIPATES_IN {status}]->(:MovieNight)
(:MovieNight)-[:HAS_PARTICIPANT]->(:User)

(:MovieNight)-[:HAS_CONSTRAINT]->(:Tag)
(:MovieNight)-[:SHORTLISTED {score, rank, reason}]->(:Movie)
(:User)-[:VOTED_FOR {createdAt, weight}]->(:Movie)
(:MovieNight)-[:WINNER {decidedAt, score}]->(:Movie)

(:Movie)-[:HAS_GENRE]->(:Genre)
(:Movie)-[:AVAILABLE_ON {region, updatedAt}]->(:Platform)
(:Movie)-[:ACTED_IN] / [:DIRECTED_BY] / [:CREATED_BY]->(:Person)
(:Movie)-[:HAS_TAG]->(:Tag)
```

Direction can be adjusted for query convenience, but stay consistent.

---

## 16. Preference Semantics

The app has four main preference actions:

### Like

Means:

- The user is interested in watching the movie.
- The movie can be proposed for recommendations and group sessions.

Graph relationship:

```text
(:User)-[:LIKED]->(:Movie)
```

### Dislike

Means:

- The user is not interested.
- The movie should be deprioritized or excluded for that user.
- In group sessions, strong dislikes may reduce or block compatibility.

Graph relationship:

```text
(:User)-[:DISLIKED]->(:Movie)
```

### Already Seen

Means:

- The user has already watched the movie.
- It may be excluded from future movie night suggestions unless the user is willing to rewatch.

Graph relationship:

```text
(:User)-[:SEEN]->(:Movie)
```

### Save for Later

Means:

- The user is interested but not necessarily committed.
- Saved items are useful as seeds for group watchlists.

Graph relationship:

```text
(:User)-[:SAVED]->(:Movie)
```

### Conflict Resolution

A user should not have contradictory preference edges at the same time unless the product explicitly supports history.

Recommended MVP rule:

- A new explicit action supersedes incompatible previous actions.
- For example:
  - If a user dislikes a movie after liking it, remove or deactivate `LIKED`.
  - If a user marks a movie as already seen, it may coexist with `LIKED`, but the recommendation system should handle it carefully.
  - If a user saves a movie and later dislikes it, remove `SAVED`.

Optional advanced rule:

- Keep historical actions as event nodes or relationship versions, but expose only the latest active preference to recommendation queries.

---

## 17. Why Neo4j Fits the Recommendation Logic

Agreeo’s recommendation logic is based on relationships, not just static movie attributes.

### 17.1 Individual Recommendations

Neo4j can help recommend movies based on:

- Genres liked by the user.
- Movies liked by similar users.
- Movies liked by friends.
- Saved movies not yet seen.
- Movies connected to actors/directors from liked movies.
- Movies available on platforms used by the user.
- Movies not disliked or already seen.

Example product question:

> “Show movies that are close to what this user likes, but exclude movies they already disliked or saw.”

### 17.2 Group Recommendations

Neo4j is especially useful for group movie nights.

A group shortlist should consider:

- Positive signals from multiple participants.
- Negative signals from any participant.
- Already-seen conflicts.
- Shared streaming platform availability.
- Genre constraints.
- Duration constraints.
- Explicit votes.
- Saved titles from participants.
- Social fairness, not only average rating.

Example product question:

> “Find movies that at least two participants liked or saved, that nobody strongly disliked, that fit the group constraints, and that are available on at least one shared platform.”

This kind of query maps naturally to graph traversal.

### 17.3 Social Graph

Neo4j can support:

- Friend recommendations.
- Taste similarity between users.
- Group history.
- Repeated movie night patterns.
- “People with similar taste liked this.”
- “Your friends saved this.”
- “This movie is popular in your group.”

---

## 18. Example Cypher-Like Queries

These are conceptual examples. Adjust labels, IDs, relationship names, indexes, and parameters to the actual implementation.

### 18.1 Movies liked by a user’s friends

```cypher
MATCH (:User {id: $userId})-[:FRIEND_OF]-(friend:User)-[:LIKED]->(m:Movie)
WHERE NOT EXISTS {
  MATCH (:User {id: $userId})-[:SEEN|DISLIKED]->(m)
}
RETURN m, count(friend) AS friendLikes
ORDER BY friendLikes DESC, m.popularity DESC
LIMIT 20;
```

### 18.2 Group shortlist candidates

```cypher
MATCH (night:MovieNight {id: $movieNightId})-[:HAS_PARTICIPANT]->(u:User)
MATCH (u)-[pref:LIKED|SAVED]->(m:Movie)
WHERE NOT EXISTS {
  MATCH (night)-[:HAS_PARTICIPANT]->(other:User)-[:DISLIKED]->(m)
}
AND NOT EXISTS {
  MATCH (night)-[:HAS_PARTICIPANT]->(other:User)-[:SEEN]->(m)
}
WITH night, m,
     count(DISTINCT u) AS positiveUsers,
     sum(CASE type(pref) WHEN 'LIKED' THEN 2 ELSE 1 END) AS preferenceScore
WHERE positiveUsers >= $minimumPositiveUsers
RETURN m, positiveUsers, preferenceScore
ORDER BY preferenceScore DESC, positiveUsers DESC, m.popularity DESC
LIMIT 10;
```

### 18.3 Apply genre and duration constraints

```cypher
MATCH (night:MovieNight {id: $movieNightId})-[:HAS_PARTICIPANT]->(u:User)
MATCH (u)-[pref:LIKED|SAVED]->(m:Movie)
WHERE m.durationMinutes <= $maxDurationMinutes
AND m.contentType = $contentType
AND NOT EXISTS {
  MATCH (m)-[:HAS_GENRE]->(:Genre)
  WHERE _.name IN $excludedGenres
}
RETURN m, count(DISTINCT u) AS supporters
ORDER BY supporters DESC
LIMIT 10;
```

Note: the exact syntax may need correction depending on the final Cypher version and schema. The point is to show the intended traversal logic.

---

## 19. Recommendation Scoring Strategy

For the MVP, keep scoring explainable and deterministic. Do not overcomplicate the algorithm early.

Suggested score:

```text
groupScore =
  + 3 * number_of_participants_who_liked
  + 2 * number_of_participants_who_saved
  + 1 * genre_match_score
  + 1 * platform_availability_score
  - 4 * number_of_participants_who_disliked
  - 2 * number_of_participants_who_already_saw
```

Then apply hard filters:

- Exclude movies outside max duration.
- Exclude blocked genres.
- Exclude unavailable platforms if group streaming filters are active.
- Exclude content type mismatch.
- Optionally exclude titles seen by too many participants.

The shortlist should include a `reason` field where possible:

```text
"Recommended because 3 friends liked it, it matches your group genres, and it is available on Netflix."
```

Explainability is important for trust and fairness.

---

## 20. Data Source Strategy

Movie metadata should come from an external provider such as TMDB or an equivalent movie database.

The external provider should be responsible for:

- Titles.
- Posters.
- Backdrops.
- Overviews.
- Cast.
- Genres.
- Runtime.
- Ratings.
- Popularity.
- Release dates.

Neo4j should store:

- The subset of movie data needed for graph queries.
- Stable IDs mapping external provider IDs to internal nodes.
- User interactions.
- Relationships between users, movies, groups, platforms, and movie nights.

Avoid duplicating huge external datasets unnecessarily during the MVP. Import only what the app needs.

---

## 21. Backend Integration Rules

### 21.1 API-First Access

The Flutter client should call a backend API. The backend should own:

- Neo4j driver configuration.
- Cypher queries.
- Ranking logic.
- Security.
- Validation.
- Mapping graph results to DTOs.

### 21.2 Repository Pattern

Use a clean separation:

```text
Presentation Layer
  -> State Management / Controllers
  -> Application Services
  -> Repositories
  -> API Client
  -> Backend
  -> Neo4j
```

### 21.3 DTOs

The backend should return frontend-friendly DTOs, for example:

```json
{
  "movieId": "movie_123",
  "title": "Inception",
  "posterUrl": "...",
  "releaseYear": 2010,
  "durationMinutes": 148,
  "genres": ["Sci-Fi", "Thriller"],
  "score": 14,
  "reason": "3 participants liked similar movies and nobody disliked it."
}
```

The Flutter UI should not need to understand the full graph structure.

---

## 22. MVP vs Future Neo4j Usage

### MVP Neo4j Goals

Implement only what directly supports the core product:

- User nodes.
- Movie nodes.
- User preference edges.
- Friend relationships.
- Movie night nodes.
- Participant relationships.
- Constraints.
- Shortlist generation.
- Voting.
- Winner selection.

### Future Neo4j Goals

Later iterations can add:

- Taste similarity between users.
- Community-based recommendations.
- Graph Data Science algorithms.
- Embedding/vector search combined with graph filters.
- Friend suggestions.
- Group personality profiles.
- “Because you and your friends liked...” explanations.
- Better cold start recommendations.
- Regional platform availability.
- Rewatch willingness.

---

## 23. Non-Goals

Do not implement these as part of the first Neo4j integration unless explicitly requested:

- Full streaming playback.
- Full social network feed.
- Public reviews and comments.
- Complex ML model training.
- Payment systems.
- Admin dashboards.
- Full clone of IMDb or Letterboxd.
- Full import of all TMDB data.
- In-app trailers as a core feature.
- Direct mobile-to-Neo4j connection.

---

## 24. Edge Cases to Handle

### Onboarding

- User selects too few genres.
- User wants to skip favorite movie selection.
- User has no initial preferences.
- External movie provider fails.

### Swipe

- No more daily suggestions.
- User undoes last action.
- User changes opinion on a movie.
- Poster image fails to load.
- Duplicate movie appears.

### Friends

- User has no friends yet.
- Search returns no users.
- Friend request already exists.
- User removes friend accidentally.
- User tries to invite duplicate friends.

### Movie Night

- No participants accept.
- Not enough preference data.
- Constraints are too strict.
- No movies match constraints.
- Users vote for different movies.
- Tie between top movies.
- A participant has seen the winning movie.
- Streaming platform availability is unknown.
- Consensus is reached but user needs a next action.

---

## 25. UX Requirements for Prototype 2 / Next Iteration

The next prototype should improve:

1. **Onboarding visibility**
   - Make counters and progress indicators more visible.
   - Explain why actions are disabled.

2. **Skip path**
   - Add a controlled way to skip long initial movie selection.
   - If skipped, use fallback recommendations.

3. **Final CTA**
   - Add a clear “Back to Home”, “Save result”, or “Open streaming platform” CTA after consensus.

4. **Invite safety**
   - Add undo or confirmation when removing friends from an invite list.

5. **Empty states**
   - Friends tab with no friends.
   - No saved movies.
   - No recommendations.
   - No shortlist generated.

6. **Error states**
   - External data unavailable.
   - Constraints too restrictive.
   - Invite failed.
   - Vote submission failed.

7. **Micro-interactions**
   - Smooth card transitions.
   - Clear feedback after like/dislike/save.
   - Active/inactive button states.
   - Confirmation popups for destructive actions.

---

## 26. Engineering Acceptance Criteria
 
The system implementation should satisfy these acceptance criteria.

### 26.1 Product Criteria

- The app must remain focused on group movie decision-making.
- The UI must prioritize fast, lightweight interactions.
- The group flow must end with a clear final decision.
- The app must collect and persist preference signals.
- The app must support at least the MVP actions: like, dislike, already seen, save.

### 26.2 Neo4j Criteria

- User, Movie, preference, friend, and movie night data must be represented as graph entities.
- Cypher queries must be centralized in backend/repository code.
- The mobile app must not contain Neo4j credentials.
- Graph queries must support individual and group recommendation use cases.
- The graph model must support relationship properties, especially timestamps and scores.
- Recommendation output must be explainable enough for UI display.

### 26.3 Code Quality Criteria

- Keep code modular.
- Avoid hardcoded mock data once real data integration begins.
- Add tests for preference state transitions.
- Add tests for shortlist scoring logic.
- Add tests for edge cases such as strict constraints and tie votes.
- Keep UI components reusable.
- Keep naming consistent with existing repository conventions.
- Update this document or a `REMAINING_WORK.md` file after major implementation changes.

---

## 27. Suggested Implementation Roadmap

### Phase 1: Stabilize UI Prototype

- Keep mock data if backend is not ready.
- Ensure navigation flows work end-to-end.
- Fix known UX issues from evaluation.
- Add empty and error states.
- Ensure `flutter analyze` and tests pass.

### Phase 2: Introduce Movie Metadata Provider

- Add API integration for movie search/details.
- Cache basic movie metadata.
- Map external IDs to internal movie IDs.
- Replace static mock movie lists progressively.

### Phase 3: Introduce Backend API

- Create backend service.
- Add authentication boundary.
- Add movie preference endpoints.
- Add movie night endpoints.
- Keep Flutter unaware of database internals.

### Phase 4: Introduce Neo4j Graph Layer

- Create initial graph schema.
- Add constraints/indexes.
- Import users and movies.
- Store preference relationships.
- Store friend relationships.
- Implement individual recommendations.
- Implement group shortlist generation.

### Phase 5: Real Group Consensus

- Add movie night lifecycle.
- Add invitations.
- Add voting.
- Add real-time or near-real-time match notifications.
- Add final result screen with clear CTA.

### Phase 6: Advanced Recommendations

- Add similarity-based recommendations.
- Add friend-of-friend/taste graph logic.
- Add graph algorithms if needed.
- Add vector search only if it clearly improves recommendations.

---

## 28. Important Design Philosophy

Agreeo should feel like this:

> “We already know what our group might enjoy. Let’s pick from a few good options.”

It should not feel like this:

> “Here is another endless catalog. Good luck choosing.”

Every feature should be evaluated against this question:

> Does this reduce the time, effort, or frustration involved in choosing something together?

If the answer is no, it should be deferred.

---

## 29. Core Development Guidelines
 
When contributing to this project:

1. Read this file first.
2. Preserve the core value proposition: reduce group decision fatigue.
3. Do not implement features that turn the app into a generic movie database.
4. Keep the UI fast, mobile-first, and low-friction.
5. Treat Neo4j as the relationship intelligence layer, not as a dumping ground for every piece of app state.
6. Do not connect the Flutter client directly to Neo4j.
7. Keep graph schema and Cypher queries backend-side.
8. Implement MVP graph features before advanced graph algorithms.
9. Keep recommendations explainable.
10. Update project documentation after meaningful changes.

---

## 30. Glossary

### Agreeo

The current app name used in the assignment. A mobile-first group movie decision app.

### MoveMate

The original course project brief name. The selected project was “Project D – MoveMate”.

### Movie Night

A shared viewing session created by a user and joined by friends.

### Daily Suggestions

Small set of movie recommendations shown to the user to collect lightweight preference feedback.

### Swipe

The core interaction used to like, dislike, mark as seen, or save movies.

### Shared Shortlist

A curated set of movies generated for a specific group and movie night.

### Consensus

The final agreement reached by the group, either through algorithmic matching, voting, or both.

### Neo4j

The graph database intended to model users, movies, friendships, preferences, groups, votes, and recommendation relationships.

### Decision-Shortener

The central product concept: the app exists to reduce the time and friction needed for a group to choose what to watch.

---

## 31. Minimal First Neo4j Integration Checklist

Use this checklist when implementing Neo4j for the first time:

- [ ] Create backend service.
- [ ] Configure Neo4j connection through environment variables.
- [ ] Do not expose Neo4j credentials to Flutter.
- [ ] Create indexes/constraints for `User.id`, `Movie.id`, `Movie.tmdbId`, `MovieNight.id`.
- [ ] Create user nodes.
- [ ] Create movie nodes from external metadata.
- [ ] Create `LIKED`, `DISLIKED`, `SEEN`, `SAVED` relationships.
- [ ] Implement preference update logic with conflict handling.
- [ ] Create friend relationships.
- [ ] Create movie night nodes.
- [ ] Attach participants to movie nights.
- [ ] Store constraints.
- [ ] Generate shortlist query.
- [ ] Store votes.
- [ ] Compute winner.
- [ ] Return frontend-friendly DTOs.
- [ ] Add tests for graph repository methods.
- [ ] Add fallback behavior when Neo4j is unavailable.

---

## 32. Final Product Goal

The final product should allow users to:

1. Create an account.
2. Set initial preferences.
3. Quickly rate movies over time.
4. Save interesting movies.
5. Connect with friends.
6. Create a movie night.
7. Invite participants.
8. Set constraints.
9. Receive a fair shortlist.
10. Vote or confirm the final movie.
11. Start watching without wasting half the evening choosing.

The success of the product is not measured by how many movies it displays, but by how quickly and fairly it helps a group decide.
