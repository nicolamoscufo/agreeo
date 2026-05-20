# Graph Report - .  (2026-05-20)

## Corpus Check
- Large corpus: 199 files · ~842.086 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 1097 nodes · 1454 edges · 91 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output


## Input Scope
- Requested: auto
- Resolved: committed (source: default-auto)
- Included files: 199 · Candidates: 279
- Excluded: 0 untracked · 9711 ignored · 0 sensitive · 0 missing committed
- Recommendation: Use --scope all or graphify.yaml inputs.corpus for a knowledge-base folder.

## Graph Freshness
- Built from Git commit: `7dbd579`
- Compare this hash to `git rev-parse HEAD` before trusting freshness-sensitive graph output.
## God Nodes (most connected - your core abstractions)
1. `WebBrowserSession` - 23 edges
2. `invoke_json_service_extension()` - 20 edges
3. `FlutterMachineSession` - 19 edges
4. `session_or_error()` - 19 edges
5. `getMovieNight()` - 14 edges
6. `flutter_run_start()` - 14 edges
7. `format_page_summary()` - 14 edges
8. `generateShortlist()` - 10 edges
9. `get_session()` - 10 edges
10. `invoke_text_service_extension()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `get_workspace_session()` --calls--> `resolve_working_directory()`  [EXTRACTED]
  tools/mcp/flutter_runtime_server.py → tools/mcp/flutter_runtime_server.py  _Bridges community 12 → community 13_
- `flutter_list_devices()` --calls--> `resolve_flutter_command()`  [EXTRACTED]
  tools/mcp/flutter_runtime_server.py → tools/mcp/flutter_runtime_server.py  _Bridges community 13 → community 16_
- `flutter_run_start()` --calls--> `FlutterMachineSession`  [EXTRACTED]
  tools/mcp/flutter_runtime_server.py → tools/mcp/flutter_runtime_server.py  _Bridges community 13 → community 19_
- `invoke_json_service_extension()` --calls--> `get_workspace_session()`  [EXTRACTED]
  tools/mcp/flutter_runtime_server.py → tools/mcp/flutter_runtime_server.py  _Bridges community 8 → community 12_
- `flutter_debug_dump_app()` --calls--> `invoke_text_service_extension()`  [EXTRACTED]
  tools/mcp/flutter_runtime_server.py → tools/mcp/flutter_runtime_server.py  _Bridges community 16 → community 12_

## Communities

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (64): build_output_path(), build_search_query_variants(), close_all_sessions(), close_all_sessions_sync(), decode_bing_redirect_url(), fetch_bing_rss_results(), fetch_bing_search_results(), format_json_block() (+56 more)

### Community 1 - "Community 1"
Cohesion: 0.08
Nodes (47): buildShortlist(), calculateCompatibility(), cleanString(), cleanStringList(), clearShortlistAndVotes(), clearVotesOnly(), compareCandidates(), createInviteLink() (+39 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (38): bcrypt, DEFAULT_ROLES, displayNameFromEmail(), emailNormalized, neo4jService, normalizeEmail(), passwordHash, { sign, signRefresh } (+30 more)

### Community 3 - "Community 3"
Cohesion: 0.05
Nodes (25): dailyBreakdown, dailySourceBreakdown, favoriteGenres, filteredMovies, forYouIds, forYouSample, forYouSourceBreakdown, maxReleaseDate (+17 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (2): FriendsMovieNightController, FriendsMovieNightState

### Community 5 - "Community 5"
Cohesion: 0.06
Nodes (2): AgreeoAppController, AgreeoAppState

### Community 6 - "Community 6"
Cohesion: 0.1
Nodes (24): dislikeMovie(), findMovieByTmdbId(), getCandidatePoolStats(), getExploratoryCandidates(), getPersonalizedRecommendationCandidates(), getRecommendationCandidates(), getRecommendations(), getRecommendationUserProfile() (+16 more)

### Community 7 - "Community 7"
Cohesion: 0.08
Nodes (17): neo4j, Neo4jService, bcrypt, emailNormalized, neo4jService, assert, calls, candidate() (+9 more)

### Community 8 - "Community 8"
Cohesion: 0.07
Nodes (30): build_vararg_params(), flutter_widget_children(), flutter_widget_children_details_subtree(), flutter_widget_children_summary_tree(), flutter_widget_creation_tracked(), flutter_widget_details_subtree(), flutter_widget_layout_explorer_node(), flutter_widget_location_id_map() (+22 more)

### Community 9 - "Community 9"
Cohesion: 0.08
Nodes (2): AppController, AppState

### Community 10 - "Community 10"
Cohesion: 0.19
Nodes (23): ensure_git_repo(), format_command(), git_blame(), git_diff(), git_log(), git_status(), has_git_commit(), is_ignored_path() (+15 more)

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (4): BackendSocialService, FriendRequestMutationResult, FriendSearchResponse, SocialBackendSnapshot

### Community 12 - "Community 12"
Cohesion: 0.18
Nodes (21): call_flutter_service_extension(), flutter_call_service_extension(), flutter_hot_reload(), flutter_hot_restart(), flutter_widget_screenshot(), flutter_widget_selected_widget(), format_json_tool_output(), format_response_value() (+13 more)

### Community 13 - "Community 13"
Cohesion: 0.15
Nodes (18): flutter_detach(), flutter_list_devices(), flutter_run_start(), flutter_session_status(), flutter_stop(), format_command(), format_startup_summary(), get_session() (+10 more)

### Community 14 - "Community 14"
Cohesion: 0.17
Nodes (16): Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle(), GetWindowClass(), MessageHandler(), OnCreate() (+8 more)

### Community 15 - "Community 15"
Cohesion: 0.1
Nodes (11): _BasicsStep, _ConstraintsStep, _GenreWrap, _InviteStep, MovieNightWizardScreen, _MovieNightWizardScreenState, _StepDots, _WizardActions (+3 more)

### Community 16 - "Community 16"
Cohesion: 0.13
Nodes (18): bool_string(), build_run_command(), flutter_debug_dump_app(), flutter_debug_dump_focus_tree(), flutter_debug_dump_layer_tree(), flutter_debug_dump_render_tree(), flutter_debug_dump_semantics_tree(), flutter_widget_root_tree() (+10 more)

### Community 17 - "Community 17"
Cohesion: 0.12
Nodes (3): BackendMovieService, MovieDetails, UserLibrary

### Community 18 - "Community 18"
Cohesion: 0.13
Nodes (8): _FriendCard, _FriendRequestCard, _FriendsListSection, FriendsScreen, _FriendsScreenState, _MovieNightCard, _RequestsSection, _SearchResults

### Community 19 - "Community 19"
Cohesion: 0.3
Nodes (3): FlutterMachineSession, summarize_params(), truncate_text()

### Community 20 - "Community 20"
Cohesion: 0.13
Nodes (1): AuthService

### Community 21 - "Community 21"
Cohesion: 0.13
Nodes (1): Neo4jService

### Community 22 - "Community 22"
Cohesion: 0.28
Nodes (14): dart_format(), flutter_analyze(), flutter_pub_get(), flutter_test(), format_command(), Run flutter analyze and return the full analyzer output., Run flutter test and return the full test output., Run flutter pub get and return the full output. (+6 more)

### Community 23 - "Community 23"
Cohesion: 0.14
Nodes (10): _EditConstraintsSheet, _EditConstraintsSheetState, _GenreSheetWrap, _InviteLinkCard, _JoinMovieNightCard, MovieNightWaitingRoomScreen, _MovieNightWaitingRoomScreenState, _ParticipantsCard (+2 more)

### Community 24 - "Community 24"
Cohesion: 0.14
Nodes (11): Friend, FriendMovieReview, FriendProfile, FriendRequest, MovieNightConstraints, MovieNightEvent, MovieNightParticipant, MovieNightVote (+3 more)

### Community 25 - "Community 25"
Cohesion: 0.15
Nodes (7): AgreeoSwipeScreen, _AgreeoSwipeScreenState, _ImmersiveMovieCard, _SwipeBackground, _SwipeCardActionButton, _SwipeCardActions, _SwipeCardFooterSkeleton

### Community 26 - "Community 26"
Cohesion: 0.17
Nodes (9): ActionButton, AgreeoSearchBar, EmptyState, GenreChip, InfoBadge, RatingStars, SectionHeader, SelectableChip (+1 more)

### Community 27 - "Community 27"
Cohesion: 0.17
Nodes (6): _DebugCard, _KeyValueRow, RecommendationDebugScreen, _RecommendationDebugScreenState, _StatCard, _TokenWrap

### Community 28 - "Community 28"
Cohesion: 0.18
Nodes (1): TmdbService

### Community 29 - "Community 29"
Cohesion: 0.18
Nodes (6): MovieCard, _MovieCardState, _OutlineAction, _PosterFallback, _SwipeBadge, _Tag

### Community 30 - "Community 30"
Cohesion: 0.2
Nodes (7): FriendProfileScreen, _FriendProfileScreenState, _MovieList, _MovieTile, _PrivacyState, _ReviewList, _StatPill

### Community 31 - "Community 31"
Cohesion: 0.2
Nodes (8): AppSession, EventConstraints, EventVote, Movie, MovieEvent, MovieFeedbackRecord, MovieGroup, UserPreferences

### Community 32 - "Community 32"
Cohesion: 0.2
Nodes (1): BackendService

### Community 33 - "Community 33"
Cohesion: 0.2
Nodes (7): AgreeoUserSession, Movie, MovieSearchFilters, OnboardingState, ProfilePreferences, UndoEntry, UserMovieState

### Community 35 - "Community 35"
Cohesion: 0.22
Nodes (7): assert, calls, diversified, { diversifyRecommendations }, movieRepository, neo4jService, test

### Community 36 - "Community 36"
Cohesion: 0.22
Nodes (3): AgreeoHomeScreen, _AgreeoHomeScreenState, _CollectionSection

### Community 37 - "Community 37"
Cohesion: 0.22
Nodes (2): MockAuthException, MockAuthService

### Community 38 - "Community 38"
Cohesion: 0.32
Nodes (8): buildDailySuggestionQueue(), buildTasteLearningPersonalizedPool(), diversifyRecommendations(), hydrateRecommendationEntries(), hydrateRecommendations(), loadDailySuggestions(), loadForYouRecommendations(), toPositiveInteger()

### Community 39 - "Community 39"
Cohesion: 0.29
Nodes (8): extractDirector(), extractTrailerUrl(), fetchInteractionMovie(), imageUrl(), mapInteractionMovie(), mapMovieLens(), mapTmdbMovie(), mapTmdbMovieDetails()

### Community 40 - "Community 40"
Cohesion: 0.25
Nodes (3): AgreeoLibraryScreen, _AgreeoLibraryScreenState, _LibraryMovieCard

### Community 41 - "Community 41"
Cohesion: 0.29
Nodes (6): GenreChip, _MovieArtwork, MovieHorizontalCarousel, MoviePosterCard, MovieSwipeCard, PosterGrid

### Community 42 - "Community 42"
Cohesion: 0.29
Nodes (2): AgreeoApp, _AgreeoAppState

### Community 43 - "Community 43"
Cohesion: 0.29
Nodes (4): AgreeoOnboardingFlowScreen, _AgreeoOnboardingFlowScreenState, _FavoriteMoviesStep, _GenresStep

### Community 44 - "Community 44"
Cohesion: 0.29
Nodes (1): NotificationService

### Community 45 - "Community 45"
Cohesion: 0.29
Nodes (2): ShortlistService, _WinnerScore

### Community 46 - "Community 46"
Cohesion: 0.29
Nodes (2): _AcceptFailingBackendSocialService, _OfflineBackendSocialService

### Community 47 - "Community 47"
Cohesion: 0.33
Nodes (5): code, endIdx, fs, lines, startIdx

### Community 48 - "Community 48"
Cohesion: 0.33
Nodes (3): _FilterSection, _MovieFilterBottomSheet, _MovieFilterBottomSheetState

### Community 49 - "Community 49"
Cohesion: 0.33
Nodes (2): _ReviewEditorSheet, _ReviewEditorSheetState

### Community 50 - "Community 50"
Cohesion: 0.33
Nodes (2): AgreeoAuthWelcomeScreen, _AgreeoAuthWelcomeScreenState

### Community 51 - "Community 51"
Cohesion: 0.33
Nodes (4): MovieNightVotingScreen, _MovieNightVotingScreenState, _VoteButton, _VotingCandidateCard

### Community 52 - "Community 52"
Cohesion: 0.33
Nodes (3): AgreeoMovieDetailsScreen, _AgreeoMovieDetailsScreenState, _GlassButton

### Community 53 - "Community 53"
Cohesion: 0.33
Nodes (2): AgreeoHomeShell, _AgreeoHomeShellState

### Community 54 - "Community 54"
Cohesion: 0.33
Nodes (1): FlutterWindow()

### Community 55 - "Community 55"
Cohesion: 0.4
Nodes (4): assert, { hydrateRecommendations }, test, warned

### Community 56 - "Community 56"
Cohesion: 0.4
Nodes (3): controller, { initNeo4j, closeNeo4j }, repo

### Community 57 - "Community 57"
Cohesion: 0.4
Nodes (2): MovieNightResultScreen, _MovieNightResultScreenState

### Community 58 - "Community 58"
Cohesion: 0.4
Nodes (3): AgreeoProfileScreen, _ProfileActivity, _StatCard

### Community 59 - "Community 59"
Cohesion: 0.4
Nodes (3): LocalUserMovieStateService, UserMovieStateMutation, UserMovieStateService

### Community 60 - "Community 60"
Cohesion: 0.4
Nodes (2): RecommendationEngine, _VoteTally

### Community 61 - "Community 61"
Cohesion: 0.5
Nodes (4): buildSearchRequest(), genreIdsForNames(), parseSearchFilters(), parseStringList()

### Community 62 - "Community 62"
Cohesion: 0.67
Nodes (3): doReq(), http, test()

### Community 63 - "Community 63"
Cohesion: 0.67
Nodes (3): doReq(), http, test()

### Community 64 - "Community 64"
Cohesion: 0.5
Nodes (1): http

### Community 65 - "Community 65"
Cohesion: 0.5
Nodes (2): controller, { initNeo4j, closeNeo4j }

### Community 66 - "Community 66"
Cohesion: 0.5
Nodes (2): movieRepository, neo4jService

### Community 68 - "Community 68"
Cohesion: 0.5
Nodes (1): ThemeModeController

### Community 69 - "Community 69"
Cohesion: 0.67
Nodes (2): GetCommandLineArguments(), Utf8FromUtf16()

### Community 70 - "Community 70"
Cohesion: 0.5
Nodes (1): _FakeMovieService

### Community 71 - "Community 71"
Cohesion: 0.67
Nodes (3): attachRecommendationMetadata(), buildForYouReason(), toFiniteNumber()

### Community 72 - "Community 72"
Cohesion: 0.67
Nodes (1): http

### Community 73 - "Community 73"
Cohesion: 0.67
Nodes (1): controller

### Community 74 - "Community 74"
Cohesion: 0.67
Nodes (1): http

### Community 75 - "Community 75"
Cohesion: 0.67
Nodes (1): http

### Community 76 - "Community 76"
Cohesion: 0.67
Nodes (1): controller

### Community 77 - "Community 77"
Cohesion: 0.67
Nodes (2): AgreeoBottomNavigation, _NavItem

### Community 78 - "Community 78"
Cohesion: 0.67
Nodes (2): AgreeoBootstrapGate, _AgreeoLoadingScreen

### Community 80 - "Community 80"
Cohesion: 0.67
Nodes (1): BackendCatalogMovieService

### Community 81 - "Community 81"
Cohesion: 0.67
Nodes (1): MockMovieService

### Community 82 - "Community 82"
Cohesion: 0.67
Nodes (1): MovieService

### Community 83 - "Community 83"
Cohesion: 0.67
Nodes (1): _FakeTmdbService

### Community 84 - "Community 84"
Cohesion: 1
Nodes (2): matchesSearchFilters(), normalizeGenreName()

### Community 85 - "Community 85"
Cohesion: 1
Nodes (2): parseTmdbId(), parseTmdbIds()

### Community 86 - "Community 86"
Cohesion: 1
Nodes (1): BackendConfig

### Community 87 - "Community 87"
Cohesion: 1
Nodes (1): Neo4jConfig

### Community 90 - "Community 90"
Cohesion: 1
Nodes (1): FriendsPlaceholderScreen

### Community 92 - "Community 92"
Cohesion: 1
Nodes (1): Neo4jUser

### Community 93 - "Community 93"
Cohesion: 1
Nodes (1): ConsensusBanner

### Community 94 - "Community 94"
Cohesion: 1
Nodes (1): EmptyState

### Community 95 - "Community 95"
Cohesion: 1
Nodes (1): GradientScaffold

### Community 96 - "Community 96"
Cohesion: 1
Nodes (1): SectionHeader

## Knowledge Gaps
- **336 isolated node(s):** `neo4jService`, `bcrypt`, `{ sign, signRefresh }`, `DEFAULT_ROLES`, `emailNormalized` (+331 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 4`** (2 nodes): `FriendsMovieNightController`, `FriendsMovieNightState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 5`** (2 nodes): `AgreeoAppController`, `AgreeoAppState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 9`** (2 nodes): `AppController`, `AppState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 20`** (1 nodes): `AuthService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 21`** (1 nodes): `Neo4jService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 28`** (1 nodes): `TmdbService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (1 nodes): `BackendService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (2 nodes): `MockAuthException`, `MockAuthService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (2 nodes): `AgreeoApp`, `_AgreeoAppState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (1 nodes): `NotificationService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (2 nodes): `ShortlistService`, `_WinnerScore`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (2 nodes): `_AcceptFailingBackendSocialService`, `_OfflineBackendSocialService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (2 nodes): `_ReviewEditorSheet`, `_ReviewEditorSheetState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (2 nodes): `AgreeoAuthWelcomeScreen`, `_AgreeoAuthWelcomeScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 53`** (2 nodes): `AgreeoHomeShell`, `_AgreeoHomeShellState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 54`** (1 nodes): `FlutterWindow()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 57`** (2 nodes): `MovieNightResultScreen`, `_MovieNightResultScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 60`** (2 nodes): `RecommendationEngine`, `_VoteTally`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 64`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 65`** (2 nodes): `controller`, `{ initNeo4j, closeNeo4j }`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 66`** (2 nodes): `movieRepository`, `neo4jService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 68`** (1 nodes): `ThemeModeController`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 69`** (2 nodes): `GetCommandLineArguments()`, `Utf8FromUtf16()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 70`** (1 nodes): `_FakeMovieService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 72`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 73`** (1 nodes): `controller`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 74`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 75`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 76`** (1 nodes): `controller`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 77`** (2 nodes): `AgreeoBottomNavigation`, `_NavItem`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 78`** (2 nodes): `AgreeoBootstrapGate`, `_AgreeoLoadingScreen`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 80`** (1 nodes): `BackendCatalogMovieService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 81`** (1 nodes): `MockMovieService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 82`** (1 nodes): `MovieService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 83`** (1 nodes): `_FakeTmdbService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 84`** (2 nodes): `matchesSearchFilters()`, `normalizeGenreName()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 85`** (2 nodes): `parseTmdbId()`, `parseTmdbIds()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 86`** (1 nodes): `BackendConfig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 87`** (1 nodes): `Neo4jConfig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 90`** (1 nodes): `FriendsPlaceholderScreen`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 92`** (1 nodes): `Neo4jUser`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 93`** (1 nodes): `ConsensusBanner`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 94`** (1 nodes): `EmptyState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 95`** (1 nodes): `GradientScaffold`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 96`** (1 nodes): `SectionHeader`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `FlutterMachineSession` connect `Community 19` to `Community 16`, `Community 13`, `Community 12`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **What connects `neo4jService`, `bcrypt`, `{ sign, signRefresh }` to the rest of the system?**
  _336 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._