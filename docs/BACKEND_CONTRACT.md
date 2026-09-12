# Agreeo — Backend & State Contract

> Technical reference documenting the backend API surface, Flutter Riverpod providers, shared state, and models.

---

## 1. Providers (the wiring the UI watches/reads)

| Provider | Type | Exposes | Location |
|---|---|---|---|
| `agreeoAppControllerProvider` | `StateNotifierProvider<AgreeoAppController, AgreeoAppState>` | Central app state + all movie/library/auth/onboarding/profile actions | `lib/shared/state/agreeo_app_controller.dart:1130` |
| `friendsMovieNightControllerProvider` | `StateNotifierProvider<FriendsMovieNightController, FriendsMovieNightState>` | Friends, requests, friend profiles, movie nights | `lib/features/friends/state/friends_movie_night_controller.dart:1146` |
| `notificationsProvider` | `StateNotifierProvider<NotificationsController, NotificationsState>` | In-app notifications + unread count | `lib/providers/notifications_provider.dart:133` |
| `navIndexProvider` | `StateProvider<int>` | Selected bottom-nav tab index | `lib/shared/state/nav_index_provider.dart:3` |
| `pendingMovieNightInviteProvider` | `StateProvider<String?>` | Deep-link invite eventId awaiting handling | `lib/shared/state/movie_night_invite_provider.dart:3` |
| `homeRefreshProvider` | `StateProvider<int>` | Bump counter to force Home re-pull | `lib/shared/state/home_refresh_provider.dart:3` |
| `realTimeServiceProvider` | `Provider<RealTimeService>` | Socket.IO connect/disconnect | `lib/services/real_time_service.dart:309` |
| `realTimeConnectionProvider` | `StateProvider<bool>` | Socket connected? (drives offline UI) | `lib/services/real_time_service.dart:313` |
| `movieServiceProvider` | `Provider<MovieService>` | Catalog/search/recommend/mood/random | `agreeo_app_controller.dart:1112` |
| `userMovieStateServiceProvider` | `Provider<UserMovieStateService>` | Pure state-mutation helpers (used by controller) | `agreeo_app_controller.dart:1122` |
| `backendMovieServiceProvider` | `Provider<BackendMovieService>` | Backend movie-state sync | `agreeo_app_controller.dart:1126` |
| `backendAuthSessionServiceProvider` | `Provider<BackendAuthSessionService>` | Auth/session | `agreeo_app_controller.dart:1116` |
| `shortlistServiceProvider` | `Provider<ShortlistService>` | Movie-night scoring/winner (used by controller) | `friends_movie_night_controller.dart:1138` |
| `backendSocialServiceProvider` | `Provider<BackendSocialService>` | Social HTTP API (used by controllers) | `friends_movie_night_controller.dart:1142` |

> **Rule of thumb for the UI:** watch the three `StateNotifier` controllers
> (`agreeoAppControllerProvider`, `friendsMovieNightControllerProvider`,
> `notificationsProvider`) plus the small `StateProvider`s. Call `movieServiceProvider`
> directly only for one-shot reads not cached in app state (search, mood, random,
> debug stats, movie details).

---

## 2. Public API surface

### 2.1 `AgreeoAppState` (read these getters/fields)
`hydrated`, `session` (`AgreeoUserSession?`), `onboarding` (`OnboardingState`),
`profilePreferences` (`ProfilePreferences`), `catalog` (`List<Movie>`),
`movieStates` (`Map<String,UserMovieState>`), `undoStack` (`List<UndoEntry>`),
`recommendedIds`, `dailySuggestionIds`, `trendingIds`.

Derived: `isAuthenticated`, `onboardingComplete`, `movieById(id)`,
`userMovieStateFor(id)`, `moviesByIds(ids)`, `remainingDailySuggestions`,
`recommendedForYou`, `trendingMovies`, `watchlistCount`, `likedCount`,
`watchedCount`, `hiddenCount`, `reviewCount`.

### 2.2 `AgreeoAppController` (actions)
Auth/onboarding: `signUp({...})`, `logIn({email,password})`, `logOut()`,
`updateOnboardingGenres(List<String>)`, `toggleFavoriteMovieSelection(id)`,
`finishOnboarding()`.
Feeds: `refreshMovieSuggestions()`, `refreshHomeFeed({page})`,
`ensureSwipeQueueFilled({force})`, `syncLibrary()`.
Profile: `updateProfile({displayName, bio, avatarUrl?})` *(persisted via
`PATCH /me/profile`; avatarUrl is an https URL or base64 data URI, '' removes it)*,
`updateFavoriteGenres(List<String>)` *(replaces `PREFERS_GENRE` via
`PATCH /me/onboarding`)*, `changePassword({currentPassword, newPassword})`
*(`POST /me/password`)*, `deleteAccount({password})` *(`DELETE /me`, DETACH
DELETE + local sign-out)*, `setPrivacyPreference({...4 bools})` *(local-first;
mirrors `canShowWatched/canShowReviews/canShowWatchlist` to the AppUser node via
`PATCH /me/privacy`, which the social layer enforces on friend profiles — the
"liked" toggle stays local as no friend surface shows likes)*,
`setNotificationPreference({...4 bools})` *(enforced by `RealTimeService`:
movie-night invite / voting-started / decision banners are suppressed when the
matching toggle is off; the in-app notifications list keeps full history.
`dailySuggestionReminder` schedules a recurring 24h local notification via
`NotificationService.scheduleDailySuggestionReminder` — re-armed on every app
open/login so it only fires after a full day away, cancelled on logout/account
deletion or when the toggle is off)*.
Movie state (each returns `Future<String>` = toast message):
`likeMovie(id)`, `dislikeMovie(id)`, `addToWatchlist(id)`, `removeFromWatchlist(id)`,
`markAsWatched(id)`, `removeFromWatched(id)`, `clearPreference(id)`,
`rateMovie(id,int)`, `saveReview(id,String)`, `deleteReview(id)`, `undoLastAction()`.

### 2.3 `MovieService` (`movieServiceProvider`)
`getCatalog()`, `getRecommendedForYou()`, `getDailySuggestions({...})`,
`searchMovies(query, MovieSearchFilters)`, `getMovieDetails(id)`,
`getTrendingMovies()`, `getMoviesByGenre(genre)`, `getShortMovies()`,
`getRandomMovie()`, `getRecommendationDebugStats()`,
`getMoviesByMood({required feeling, required wantToFeel})`.

### 2.4 `FriendsMovieNightState` (read)
`friends`, `incomingRequests`, `discoverableUsers`, `searchResults`,
`outgoingPendingIds`, `profiles`, `friendMovieStates`, `movieNights`,
`inflightEventIds`; helpers `isFriend(id)`, `isPending(id)`,
`incomingRequestIdFor(id)`, `profileFor(id)`, `eventById(id)`.

### 2.5 `FriendsMovieNightController` (actions)
`searchFriends(query)`, `sendFriendRequest(userId)`,
`acceptFriendRequest(requestId)`, `declineFriendRequest(requestId)`,
`cancelFriendRequest(userId)` *(withdraws my pending outgoing request —
`DELETE /friends/requests/outgoing/:userId`, emits `friend_request_cancelled`)*,
`removeFriend(id)`, `blockFriend(id)`, `loadFriendProfile(userId)`,
`refreshSocialLayer()`.
Blocked users (service-level, used by Settings › Blocked users):
`BackendSocialService.getBlockedUsers()` (`GET /friends/blocked`) and
`unblockFriend(userId)` (`DELETE /friends/:id/block`).
Movie night: `createMovieNight({...})`, `updateEventConstraints({...})`,
`refreshShortlist(eventId)`, `refreshMovieNight(eventId)`,
`resolveMovieNightInvite(eventId)`, `joinMovieNight(eventId)`,
`leaveMovieNight(eventId)`, `startVoting(eventId)`,
`submitVote({...})` **← this is "castVote"**, `deleteVote({...})`,
`createInviteLink(eventId)`, `inviteFriends({...})`,
`currentUserVoteFor(eventId, movieId)`.

### 2.6 `NotificationsController` / `NotificationsState`
State: `notifications` (`List<InAppNotification>`), `unreadCount`, `isLoading`.
Actions: `refreshNotifications()`, `markAsRead(id)`, `markLessImportantAsRead()`
*( = "mark all (less-important) as read")*.

### 2.7 `RealTimeService`
`connect(userId)`, `disconnect()`. Internally pushes socket events into
notifications + triggers `refreshSocialLayer`/movie-night updates. Connection
status mirrored in `realTimeConnectionProvider`.

---

## 3. Screen → backend map (all 30 prototype screens)

| # | Screen | Reads (provider) | Actions (method) | Models |
|---|---|---|---|---|
| 1 | App launch / Splash | `agreeoAppControllerProvider` (`hydrated`) | — (bootstrap auto-runs) | — |
| 2 | Login | `agreeoAppControllerProvider` | `logIn({email,password})` | `AgreeoUserSession` |
| 3 | Sign up | `agreeoAppControllerProvider` | `signUp({...})` | `AgreeoUserSession` |
| 4 | Onboarding · Genres | `state.onboarding`, `agreeoGenreOptions` | `updateOnboardingGenres()` | `OnboardingState` |
| 5 | Onboarding · Favorites | `state.catalog`, `state.onboarding.favoriteMovieIds` | `toggleFavoriteMovieSelection()`, `finishOnboarding()` | `Movie`, `OnboardingState` |
| 6 | Home | `state.recommendedForYou`, `state.trendingMovies`, `notificationsProvider.unreadCount`, `homeRefreshProvider` | `refreshHomeFeed()`, library actions | `Movie` |
| 7 | Filters sheet | local sheet state | feeds `MovieSearchFilters` into `searchMovies()` | `MovieSearchFilters` |
| 8 | Mood Matcher | local (feeling/wantToFeel) | `movieService.getMoviesByMood({feeling,wantToFeel})` | `Movie` |
| 9 | Mood · Loading | future pending | (awaits `getMoviesByMood`) | — |
| 10 | Mood · Results | result list | library actions | `Movie` |
| 11 | Random Pick | — | `showRandomPick()` → `movieService.getRandomMovie()` (spin/details) | `Movie` |
| 12 | Swipe | `state.remainingDailySuggestions` (+`ensureSwipeQueueFilled`) | `likeMovie()`, `dislikeMovie()`, `addToWatchlist()`, `undoLastAction()` | `Movie`, `UserMovieState` |
| 13 | Library | `state.movieStates`, `watchlistCount/likedCount/watchedCount` | `removeFromWatchlist()`, `removeFromWatched()`, `clearPreference()` | `Movie`, `UserMovieState` |
| 14 | Movie details | `state.movieById(id)` / `movieService.getMovieDetails(id)`, `state.userMovieStateFor(id)` | `likeMovie/dislikeMovie/addToWatchlist/markAsWatched/rateMovie` | `Movie`, `UserMovieState` |
| 15 | Review editor | `state.userMovieStateFor(id)` | `saveReview()`, `rateMovie()`, `deleteReview()` | `UserMovieState` |
| 16 | Friends | `friendsState.friends`, `.incomingRequests`, `.searchResults` | `searchFriends`, `sendFriendRequest`, `acceptFriendRequest`, `declineFriendRequest` | `Friend`, `FriendRequest` |
| 17–19 | Friend profile (Watched/Reviews/Private) | `friendsState.profileFor(id)` | `loadFriendProfile(userId)` | `FriendProfile`, `FriendMovieReview`, `PrivacySettings` |
| 20 | Movie Night · Create | `friendsState.friends`, `state.catalog` | `createMovieNight({...})`, `updateEventConstraints()`, `inviteFriends()` | `MovieNightEvent`, `MovieNightConstraints` |
| 21 | Movie Night · Waiting | `friendsState.eventById(id)` + `realTimeServiceProvider` | `joinMovieNight()`, `leaveMovieNight()`, `startVoting()`, `refreshMovieNight()` | `MovieNightEvent`, `MovieNightParticipant` |
| 22 | Movie Night · Voting | `friendsState.eventById(id)` + socket updates, `currentUserVoteFor()` | `submitVote({...})` (castVote), `deleteVote()` | `MovieNightEvent`, `ShortlistCandidate`, `MovieNightVote` |
| 23 | Movie Night · Results | `friendsState.eventById(id)` (`winnerMovieId`, `votes`) | — / `startVoting` for new round | `MovieNightEvent`, `ShortlistCandidate` |
| 24 | Profile | `state.session`, `state.*Count` getters | navigate to Edit/Settings | `AgreeoUserSession` |
| 25 | Edit profile | `state.session` | `updateProfile({displayName,bio,avatarUrl})` (photo picker → base64 data URI) | `AgreeoUserSession` |
| 26 | Settings | `state.profilePreferences`, **theme mode (GAP §4.1)** | `setPrivacyPreference()`, `setNotificationPreference()`, `changePassword()`, `deleteAccount()`, `logOut()` | `ProfilePreferences` |
| 27 | Notifications | `notificationsProvider` | `markAsRead()`, `markLessImportantAsRead()`, `refreshNotifications()` | `InAppNotification` |
| 28 | Library · Empty | `state.movieStates` (empty) | nav to Home/Swipe | — |
| 29 | Search · No results | `searchMovies()` returns empty | retry | `MovieSearchFilters` |
| 30 | Connection error | `connectivityProvider` (device reachability) | `connectivity.retry()` + `realTimeService.connect()` | — |

---

## 4. Gaps — DA CHIARIRE (decide together before the affected phase)

1. **`theme_mode_provider.dart` does not exist.** The migration specification (Phases 1, 4,
   Settings) says to wire `themeMode` to an *existing*
   `lib/shared/state/theme_mode_provider.dart`. That file is **absent**; `app.dart`
   currently hardcodes `themeMode: ThemeMode.dark`. The Settings screen's
   Light/Dark/System toggle has nothing to bind to.
   → **Decision needed:** create a new `theme_mode_provider` (a tiny
   `StateNotifier<ThemeMode>` persisted via shared_preferences) — this is *new state*,
   not a backend change, so it likely doesn't violate "don't touch backend." Confirm.

2. **Bottom-nav shape mismatch (3 different specs).**
   - Current shell (`agreeo_home_shell.dart`): `Home(0) · Library(1) · Swipe(2) · Friends(3) · Profile(4)`.
   - JSX `BottomNav` (`ag-shared.jsx`): `Home · Swipe · [Movie-Night FAB] · Library · Friends` — **no Profile tab** (profile is reached via the header avatar).
   - Migration specification Phase 2: `Home · Swipe · Library · Friends · Profile`.
   → **Decision needed:** which tab order + does the center Movie-Night FAB stay?
   If we adopt the JSX layout, Profile moves to a header-avatar route and the shell's
   `navIndexProvider` index meaning changes.

3. ~~**No avatar/handle on the user session.**~~ **PARTIALLY RESOLVED.** The avatar
   gap is closed: `AppUser` now stores `bio` + `avatarUrl` (written by
   `PATCH /me/profile`, returned by `/me`, login, register and onboarding), the self
   session exposes `avatarUrl`, and the edit-profile sheet uploads a gallery photo as
   a resized base64 JPEG data URI (`AvatarImageService`). Friends already read
   `avatarUrl`/`bio` from the same node, so photos show up across social screens.
   Still omitted by design: the `@handle` (no backend field; initials remain the
   fallback in `AgAvatar`).

4. ~~**Connection-error screen trigger is partial.**~~ **RESOLVED.** Added
   `lib/shared/state/connectivity_provider.dart` — a presentation-layer
   `StateNotifier<bool>` that probes *device* reachability (lightweight HTTP probe to a
   204 endpoint, every 20s + on retry), deliberately independent of backend uptime so
   the local-fallback/demo mode isn't blocked by a down dev backend. `app.dart` overlays
   `OfflineScreen` whenever it reports offline; "Try again" re-probes and reconnects the
   realtime socket. (`realTimeConnectionProvider` still drives the per-event "Live" badge.)

5. **Mood vocabulary undefined.** `getMoviesByMood({feeling, wantToFeel})` takes free
   strings. The existing `mood_selector_sheet.dart` already defines option lists — the
   new Mood Matcher should reuse those exact option sets (confirm we keep them).

6. **Movie-night "settings" in Create.** `createMovieNight` + `MovieNightConstraints`
   (genres, maxDuration, minRating, language) cover the JSX settings step. No gap, but
   note: shortlist generation/winner is server+`ShortlistService` driven — UI only
   displays `event.shortlist` / `event.winnerMovieId`.

---

## 5. Notes for UI rebuild
- **All movie-state mutations return a `String` toast message** — surface it in a
  SnackBar/toast in the new components.
- **Optimistic updates** already happen inside the controllers; the UI should just
  `await` and reflect new state, not double-manage.
- **Realtime**: `RealTimeService.connect(userId)` must be called once after auth
  (it already is in the current flow — preserve that call site when rewriting the shell).
