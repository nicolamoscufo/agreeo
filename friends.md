You are working on the mobile app Agreeo.

Before writing or modifying code, read REMAINING_WORK.md from the project root.

The current REMAINING_WORK.md describes the state of the project. Treat everything already implemented in Phase 1 as completed and stable enough to build on top of it.

Do NOT restart Phase 1.
Do NOT rebuild Home.
Do NOT rebuild Swipe.
Do NOT rebuild Library.
Do NOT rebuild Movie Details.
Do NOT rebuild Profile unless a small integration change is strictly required.
Do NOT refactor the existing architecture unless strictly necessary to integrate Friends and Movie Night.

The only missing major product area to implement now is:

1. Friends
2. Friend Profile
3. Friend Requests
4. Friend Search
5. Movie Night creation
6. Invite friends flow
7. Waiting Room
8. Preference-based Shortlist
9. Voting
10. Winner Result

Update REMAINING_WORK.md immediately before starting:
- Move the current phase to: Friends and Movie Night phase.
- Mark Phase 1 core app flow as implemented.
- Remove Friends and Movie Night from “Do Not Start Yet”.
- Add the new current tasks for Friends and Movie Night.
- Keep existing backend/TMDB/Neo4j notes, but do not expand Neo4j unless necessary.

After every meaningful implementation step, update REMAINING_WORK.md with:
- what was completed;
- what is in progress;
- what remains;
- where you stopped;
- next steps;
- any issues or architectural concerns.

Never finish a coding session without updating REMAINING_WORK.md.

====================================================
CURRENT GOAL
====================================================

Implement the Friends and Movie Night phase of Agreeo.

Agreeo is a movie decision-making app for groups of friends. The goal is to reduce the time wasted choosing a movie together.

The app already has the individual flow:
- auth;
- onboarding;
- Home;
- Swipe;
- Library;
- Movie Details;
- Profile;
- movie interactions;
- backend movie read flows;
- TMDB-backed movie data;
- user movie interactions such as like, dislike and watchlist.

Now implement the social decision-making layer.

This phase must connect naturally with the existing app:
- Friends should be reachable from the existing BottomNavigation “Friends” tab.
- Movie Details should be reused when opening a movie from a friend profile, shortlist, voting screen, or result screen.
- Existing movie models/services should be reused where possible.
- Existing UserMovieState / backend movie interaction logic should be reused where possible.
- Existing theme, cards, chips, empty states, and visual style should be reused.

====================================================
IMPORTANT PRODUCT RULES
====================================================

Do not add streaming-platform features.

Remove or avoid all references to:
- streaming platforms;
- provider badges;
- platform filters;
- shared platforms;
- availability on Netflix/Prime/Disney+;
- provider-based constraints;
- provider-based scoring.

Agreeo currently focuses on group preference matching, not streaming availability.

Do not add TV Series support in this phase.

Movie Night content type is fixed to:
- Movie

Do not implement:
- TV Series;
- Both;
- Movie/TV selector;
- media type picker.

====================================================
NEO4J / BACKEND RULES
====================================================

The project already has a backend and Neo4j foundation.

Use existing backend/service/repository abstractions if they already exist.

Do not introduce large Neo4j refactors.
Do not rewrite the graph schema.
Do not create a complex graph recommendation system.
Do not create advanced Cypher recommendation algorithms unless strictly necessary.

For this phase:
- Prefer simple backend endpoints or local service scaffolding that can later be connected to the backend.
- If backend endpoints already exist, use them.
- If endpoints are missing, create clean service abstractions first.
- Only add backend/Neo4j persistence for Friends and Movie Night if it is straightforward and consistent with the existing architecture.
- If persistence is too large for this step, keep local/in-memory implementation but document exactly what backend endpoints are needed later in REMAINING_WORK.md.

If Neo4j changes are necessary, keep them minimal and document them in REMAINING_WORK.md before implementing.

Suggested graph relationships only if backend persistence is implemented:
- (:AppUser)-[:FRIEND]->(:AppUser)
- (:AppUser)-[:SENT_FRIEND_REQUEST]->(:AppUser)
- (:AppUser)-[:HOSTS]->(:MovieNight)
- (:AppUser)-[:PARTICIPATES_IN]->(:MovieNight)
- (:MovieNight)-[:HAS_CANDIDATE]->(:Movie)
- (:AppUser)-[:VOTED_IN {vote}]->(:Movie)

But do not implement these unless the current backend architecture makes it reasonable.

====================================================
EXISTING INTERACTION MODEL
====================================================

Respect the existing user-movie interaction logic:

UserMovieState:
- movieId
- preference: liked | disliked | neutral
- inWatchlist: boolean
- watched: boolean
- rating: number | null
- review: string | null
- updatedAt

Rules:
- Watchlist does not automatically mean Like.
- Like does not automatically mean Watchlist.
- Dislike removes the movie from Watchlist.
- Already Seen removes the movie from Watchlist.
- Like and Dislike are mutually exclusive.
- A watched movie can still be liked or disliked.
- Ratings and reviews are optional.

The Movie Night shortlist must use these preferences.

====================================================
FRIENDS SCREEN
====================================================

Use the existing bottom navigation tab:

Friends

Purpose:
This is the social area for:
- friends;
- friend requests;
- friend search;
- friend catalogs;
- Movie Nights.

Sections:
1. Friends list.
2. Friend requests.
3. Search friends.
4. Movie Nights.

The screen should match the existing Agreeo dark/cinematic design.

Do not make the screen look like a generic social network.
It should feel focused on movie decision-making.

----------------------------------------------------
FRIENDS LIST
----------------------------------------------------

Show a list of friends.

Each friend card should show:
- avatar;
- name;
- short stats:
  - watched count;
  - reviews count.

Do not show liked count unless it already exists naturally in the app.
Do not show streaming providers.

Friend card actions:
- tap to open Friend Profile;
- optional overflow menu for remove friend/block placeholder only if easy.

Empty state:
Title:
No friends yet

Text:
Search for friends and start building better movie nights together.

CTA:
Find friends

----------------------------------------------------
FRIEND PROFILE
----------------------------------------------------

Content:
- avatar;
- name;
- optional shared taste indicator placeholder;
- short stats:
  - watched;
  - reviews.

Tabs:
1. Watched
2. Reviews
3. Watchlist, only if privacy allows.

Privacy behavior:
- If a section is private, do not show its content.
- Show a locked/empty privacy-aware state instead.

Example:
“Carla’s watchlist is private.”

Do not expose private data.
Do not show streaming providers.

Watched tab card:
- poster;
- title;
- year;
- runtime;
- genres;
- friend rating if available.

Reviews tab:
- movie title;
- rating;
- review text preview;
- date.

Watchlist tab:
- visible only if privacy allows;
- poster;
- title;
- year;
- runtime;
- genres.

Tapping a movie opens the existing Movie Details screen.

----------------------------------------------------
SEARCH FRIENDS
----------------------------------------------------

Content:
- search input;
- results list;
- Add Friend button;
- Pending state;
- Already Friends state.

Friend search result card:
- avatar;
- name;
- optional mutual friends placeholder;
- button:
  - Add Friend
  - Pending
  - Friends

Friend requests section:
- incoming requests;
- Accept;
- Decline.

After accepting:
- move user to Friends list;
- remove request from incoming requests.

After declining:
- remove request from incoming requests.

Use local state or existing app service/state architecture.

====================================================
MOVIE NIGHTS SECTION
====================================================

Inside the Friends screen, add a Movie Nights section.

Show main button:
Create Movie Night

Show list of events:
- active events;
- past events.

Movie Night card:
- event name;
- host;
- optional date/time;
- participants;
- status:
  - Draft
  - Waiting for friends
  - Voting
  - Completed
- winner if completed.

Do not show streaming platform information.

Tap active event:
- Draft → continue wizard.
- Waiting for friends → Waiting Room.
- Voting → Voting Screen.
- Completed → Result Screen.

====================================================
MOVIE NIGHT FLOW
====================================================

Implement Movie Night as a multi-step wizard.

Do NOT implement it as one big form.

The host creates and modifies the event.
Only the host can edit event constraints.
Assume the decision to start a Movie Night has already been made by the group.

Use a stepper/progress indicator.

Expected flow:

Friends
→ Create Movie Night
→ Step 1 Event Basics
→ Step 2 Constraints
→ Step 3 Invite Friends
→ Waiting Room
→ Voting
→ Result

----------------------------------------------------
STEP 1 — EVENT BASICS
----------------------------------------------------

Fields:
- Event name.
- Content type fixed to Movie.
- Optional date/time.

Do not ask for:
- TV Series;
- Both;
- streaming platforms.

CTA:
Continue

Validation:
- Event name is required.
- Date/time is optional.

----------------------------------------------------
STEP 2 — CONSTRAINTS
----------------------------------------------------

Fields:
- included genres;
- excluded genres;
- maximum duration;
- minimum rating optional;
- language optional.

Use:
- chips for genres;
- slider or picker for maximum duration;
- dropdown/bottom sheet for language if already supported;
- simple rating selector for minimum rating.

Do not include:
- streaming platforms;
- provider selection;
- availability filter.

CTA:
Continue

Validation:
- included and excluded genres cannot conflict;
- maximum duration must be valid if provided.

----------------------------------------------------
STEP 3 — INVITE FRIENDS
----------------------------------------------------

Two invitation modes:

1. Invite friends already in app.
2. Create shareable invite link.

UI:
- friend multi-select list;
- search friends;
- invite link card;
- copy link button.

CTA:
Generate Shortlist

Rules:
- at least one friend should be invited before generating the shortlist;
- the host is always included in the event participants;
- invited users have status:
  - joined
  - pending.

After this step:
- create the event;
- navigate to Waiting Room.

====================================================
WAITING ROOM SCREEN
====================================================

After creating the event, show a Waiting Room.

Content:
- event summary;
- constraints summary;
- participants list:
  - joined;
  - pending;
- host controls:
  - edit constraints;
  - generate/refresh shortlist;
  - start voting;
- non-host view:
  - Waiting for host.

Do not show streaming information.

If invite link exists:
- show invite link card;
- copy link action.

If some participants are still pending:
- the host can still start voting, but show a warning:
  “Some friends have not joined yet.”

====================================================
SHORTLIST GENERATION
====================================================

Implement a real deterministic shortlist generation function based on available user preferences.

Do not use random selection.
Do not use a placeholder shortlist.
Do not implement a fake algorithm that ignores preferences.
Do not label the shortlist as “mock” in the UI.

The shortlist must be generated from:
- event constraints;
- joined participants;
- available movie catalog;
- user movie states/interactions:
  - liked;
  - disliked;
  - watchlist;
  - watched;
  - rating/review if available.

Create or update a service/function similar to:

generateShortlist({
  eventConstraints,
  participants,
  movies,
  userMovieStates
})

Inputs:
- event constraints;
- joined participants;
- available movie catalog;
- user movie states for each participant.

Output:
- ordered list of candidate movies;
- each candidate includes a compatibility score;
- each candidate includes explanation tags;
- optional score breakdown for debugging.

Candidate filtering:
1. Keep only movies.
2. Apply included genres if selected.
3. Remove movies with excluded genres.
4. Apply maximum duration if selected.
5. Apply minimum rating if selected.
6. Apply language if selected and movie language data exists.

Candidate scoring:
Use a transparent and readable scoring model.

Suggested scoring per participant:
- +4 if movie is in that participant’s Watchlist.
- +3 if movie is Liked by that participant.
- +1 if movie has a positive rating from that participant.
- -4 if movie is Disliked by that participant.
- -1 if movie is Already Seen by that participant.

Group-level bonuses:
- +2 if the movie matches many included genres.
- +1 if the movie is not watched by most participants.
- +1 if the movie has a good general rating.

Group-level penalties:
- -3 if many participants already watched it.
- -5 if at least half of the group disliked it.

Important:
Keep weights simple and readable.
This is not an advanced ML recommendation algorithm.
This is a deterministic group preference scoring function.

Tie-breaking:
If two movies have the same score:
1. Prefer the movie with more watchlist saves among participants.
2. Then prefer the movie with more likes.
3. Then prefer the movie with higher general rating.
4. Then prefer the most recent movie.
5. Then stable sort by title.

Shortlist size:
- return top 5 movies by default;
- if fewer than 5 valid candidates exist, return all valid candidates;
- if no valid candidates exist, show a clear empty state.

Shortlist empty state:
Title:
No movies matched this group

Text:
Try removing some excluded genres or increasing the maximum duration.

Actions:
- Edit constraints.
- Back to Friends.

Shortlist explanation tags:
Each shortlisted movie should show simple explanation tags such as:
- Saved by 2 friends
- Liked by most participants
- Matches selected genres
- Mostly unwatched
- High rating

Do not mention streaming availability.

====================================================
SHORTLIST / VOTING SCREEN
====================================================

Display the generated shortlist.

Shortlist UI:
- stack or vertical list of movie cards.

Each card shows:
- poster;
- title;
- year;
- runtime;
- genres;
- compatibility explanation tags;
- optional compatibility score only in debug/dev mode.

Do not show:
- provider badges;
- streaming platforms.

Voting options:
- Like;
- Dislike;
- Already Seen;
- Maybe / Neutral.

Each participant can vote once per candidate.

Voting progress:
Show:
3/5 friends voted

or:
Waiting for 2 friends

Voting ends automatically when all joined participants have submitted their votes.

Do not require the host to manually end voting.

When all votes are collected:
- compute the winner;
- navigate to Result screen automatically.

Winner selection:
Use votes and shortlist compatibility score together.

Suggested winner logic:
1. Start from the shortlist compatibility score.
2. Add vote score:
   - Like = +3
   - Maybe / Neutral = +1
   - Already Seen = -1
   - Dislike = -4
3. Pick the movie with the highest final score.

Tie-breaking:
1. More Like votes.
2. Fewer Dislike votes.
3. Higher original shortlist score.
4. Higher general rating.
5. Stable sort by title.

Keep the logic simple, deterministic, readable and testable.

====================================================
RESULT / WINNER SCREEN
====================================================

Show a celebratory result screen.

Title:
Tonight’s pick is…

Show winning movie:
- poster;
- title;
- year;
- runtime;
- genres.

Do not show:
- provider badges;
- streaming platforms.

Show explanation:
- Matched your group’s genres.
- Liked by most participants.
- Saved by people in the group.
- Mostly unwatched.

Actions:
- Open details.
- Mark as Watched.
- Save event.
- Back to Friends.

When current user taps Mark as Watched:
- mark the winning movie as watched for the current user;
- do not automatically mark it watched for all participants unless the app already supports group watch confirmation.

====================================================
DATA MODELS
====================================================

Create or update models as needed, following the existing project style.

Friend:
- id
- name
- avatarUrl
- watchedCount
- reviewsCount
- privacySettings

FriendRequest:
- id
- fromUser
- toUser
- status: pending | accepted | declined
- createdAt

MovieNightEvent:
- id
- name
- hostUserId
- contentType: movie
- dateTime
- constraints
- participants
- inviteLink
- status: draft | waiting | voting | completed
- shortlist
- winnerMovieId
- createdAt
- updatedAt

MovieNightConstraints:
- includedGenres
- excludedGenres
- maxDuration
- minimumRating
- language

MovieNightParticipant:
- userId
- name
- avatarUrl
- status: joined | pending
- isHost

ShortlistCandidate:
- movie
- compatibilityScore
- explanationTags
- scoreBreakdown optional

MovieNightVote:
- eventId
- userId
- movieId
- vote: like | dislike | alreadySeen | neutral
- createdAt

PrivacySettings:
- canShowWatched
- canShowReviews
- canShowWatchlist

====================================================
SERVICE ABSTRACTIONS
====================================================

Create or update services/repositories using the existing architecture.

FriendsService:
- getFriends()
- searchFriends(query)
- sendFriendRequest(userId)
- acceptFriendRequest(requestId)
- declineFriendRequest(requestId)
- getFriendProfile(userId)

MovieNightService:
- createEvent(data)
- updateEvent(eventId, data)
- inviteFriends(eventId, friends)
- createInviteLink(eventId)
- generateShortlist(eventId)
- submitVote(eventId, movieId, vote)
- hasEveryoneVoted(eventId)
- concludeVoting(eventId)
- getMovieNightResult(eventId)

ShortlistService:
- generateShortlist(eventConstraints, participants, movies, userMovieStates)
- calculateMovieCompatibility(movie, participants, userMovieStates, constraints)
- explainCandidate(movie, scoreBreakdown)
- selectWinner(shortlist, votes)

Important:
If the project already has service abstractions, extend them instead of creating duplicate parallel systems.

If backend endpoints are not ready, implement the services locally for now but keep the API clean and replaceable.

The shortlist logic must be real over the available data, even if the data source is local for now.

====================================================
BACKEND ENDPOINTS TO ADD ONLY IF REASONABLE
====================================================

If the backend architecture is ready and the change is not too large, add simple endpoints for:

Friends:
- GET /friends
- GET /friends/search?q=
- POST /friends/requests
- POST /friends/requests/:id/accept
- POST /friends/requests/:id/decline
- GET /friends/:id/profile

Movie Nights:
- GET /movie-nights
- POST /movie-nights
- GET /movie-nights/:id
- PATCH /movie-nights/:id
- POST /movie-nights/:id/invite
- POST /movie-nights/:id/invite-link
- POST /movie-nights/:id/shortlist
- POST /movie-nights/:id/votes
- GET /movie-nights/:id/result

Do not build a production-grade backend.
Do not overengineer.
Do not add authentication hardening beyond what already exists.
Do not add deployment work.

If these endpoints are too large for this pass:
- keep frontend/local services;
- document backend TODOs in REMAINING_WORK.md.

====================================================
UI / UX REQUIREMENTS
====================================================

Use the same visual language as Phase 1:

- dark theme;
- cinematic movie posters;
- rounded cards;
- clear typography;
- horizontal/vertical movie cards consistent with existing components;
- empty states;
- loading states;
- error states;
- snackbars where needed;
- bottom sheets for compact forms;
- stepper for Movie Night creation.

Accessibility:
- buttons must have readable labels;
- touch targets must be large enough;
- do not rely only on color;
- use clear selected states;
- respect safe areas.

Movie Night wizard UX:
- one decision per step;
- do not overload screens;
- make host controls visually clear;
- make voting progress obvious;
- make the result screen celebratory.

====================================================
NAVIGATION REQUIREMENTS
====================================================

Add or connect routes for:

- Friends screen.
- Friend Profile.
- Create Movie Night Step 1.
- Create Movie Night Step 2.
- Create Movie Night Step 3.
- Waiting Room.
- Voting Screen.
- Result Screen.
- Movie Details from friend catalog and shortlist cards.

Ensure back navigation works correctly.

Expected flow:

Friends
→ Create Movie Night
→ Step 1 Event Basics
→ Step 2 Constraints
→ Step 3 Invite Friends
→ Waiting Room
→ Voting
→ Result

Friend flow:

Friends
→ Friend Profile
→ Movie Details

Movie Night card flow:

Friends
→ Existing Movie Night
→ Waiting Room / Voting / Result depending on status

====================================================
TESTING REQUIREMENTS
====================================================

Add or update tests where reasonable.

At minimum, test the shortlist logic.

Test cases:
1. Movie in multiple users’ watchlists should rank higher.
2. Movie liked by multiple users should rank higher.
3. Movie disliked by half or more of the group should be penalized strongly.
4. Excluded genres should remove movies.
5. Maximum duration should filter movies.
6. Already watched movies should be penalized.
7. Tie-breaking should be deterministic.
8. Winner selection should use vote scores and shortlist score.
9. Voting should complete when all joined participants have voted.

Run:
- flutter analyze
- flutter test

If backend is modified, also test backend endpoints manually or with existing backend test approach.

====================================================
DO NOT IMPLEMENT
====================================================

Do not implement:
- streaming platforms;
- provider badges;
- platform filters;
- TV Series;
- Both media type;
- advanced recommendation algorithm;
- full ML recommender;
- random shortlist;
- placeholder shortlist;
- fake shortlist that ignores preferences;
- production auth hardening;
- payment/subscription features;
- real deployment;
- large backend refactor;
- full removal of legacy Flutter flow;
- major redesign of Phase 1 screens.

Do not redo Phase 1.

====================================================
REMAINING_WORK.md FINAL UPDATE
====================================================

Before finishing, update REMAINING_WORK.md.

The file must include:

# Agreeo Remaining Work

## Current Phase
Friends and Movie Night phase.

## Last Updated
Update this field.

## Current Status
Explain what currently works now.

## Completed
Mark completed Friends/Movie Night tasks.

## In Progress
Mark partially completed tasks.

## Remaining Work
List what still needs to be done.

## Blocked / Issues
List bugs, missing data, unclear requirements, or architectural risks.

## Next Steps
Write exact next steps.

Also document:
- whether Friends screen is implemented;
- whether Friend Profile is implemented;
- whether Friend Requests are implemented;
- whether Movie Night wizard is implemented;
- whether Waiting Room is implemented;
- whether shortlist generation is implemented;
- where shortlist logic lives;
- what data the shortlist uses;
- whether voting/winner logic is implemented;
- whether backend endpoints were added or only local services were used;
- whether streaming/platform references were fully removed.

====================================================
FINAL REPORT
====================================================

After implementation, provide a concise report with:

1. Files created or modified.
2. Navigation added.
3. Screens implemented.
4. Services/models created or updated.
5. Shortlist generation logic summary.
6. Voting and winner logic summary.
7. What still uses local data.
8. What uses backend data.
9. What needs backend integration later.
10. Tests run.
11. Any bugs or limitations.
12. Suggested next improvements.