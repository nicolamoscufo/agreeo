# Graph Report - .  (2026-05-21)

## Corpus Check
- Large corpus: 191 files · ~853,911 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 1287 nodes · 1714 edges · 100 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `WebBrowserSession` - 23 edges
2. `invoke_json_service_extension()` - 20 edges
3. `FlutterMachineSession` - 19 edges
4. `session_or_error()` - 19 edges
5. `getMovieNight()` - 16 edges
6. `flutter_run_start()` - 14 edges
7. `format_page_summary()` - 14 edges
8. `Agreeo / MoveMate Project Context and Neo4j Integration Guide` - 11 edges
9. `Agreeo` - 11 edges
10. `get_session()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Neo4j Migration from Firestore` --aims_to_replace--> `Firebase`  [INFERRED]
  AGENTS.md → README.md
- `Friends and Movie Night Feature` --uses--> `Neo4jService`  [INFERRED]
  REMAINING_WORK.md → AGENTS.md
- `Proposed Architecture Improvements` --conceptually_related_to--> `vexp Agentic Search`  [AMBIGUOUS]
  CLEANUP_SUGGESTIONS.md → AGENTS.md
- `Backend API Layer` --conceptually_related_to--> `Node.js Backend`  [INFERRED]
  agreeo_neo4j_project_context.md → NEO4J_INTEGRATION_REPORT.md
- `Neo4j Migration from Firestore` --supports--> `Backend Movie MVP`  [INFERRED]
  AGENTS.md → README.md

## Hyperedges (group relationships)
- **Docker Deployment Stack** — docker_frontend_service, docker_backend_service, docker_neo4j_service, docker_neo4j_init [EXTRACTED 1.00]
- **Recommendation Pipeline** — remaining_collaborative_filtering, remaining_cold_start, remaining_tmdb_hydration, remaining_diversification, remaining_negative_penalty [EXTRACTED 1.00]
- **Neo4j Persistence Model** — agents_neo4j_service, remaining_appuser_model, remaining_graph_relationships, agents_graph_labels [EXTRACTED 1.00]
- **Three Data Sources: TMDB + MovieLens + Neo4j** — concept_TMDB, concept_MovieLens, concept_Neo4j, concept_MATCHES_TMDB, concept_TMDBMatching [EXTRACTED 1.00]
- **Core Graph Schema Entities** — concept_AppUser, concept_Movie, concept_MovieLensUser, concept_MovieLensMovie, concept_Genre, concept_MATCHES_TMDB, concept_PreferenceActions [EXTRACTED 1.00]
- **Movie Night Group Decision Flow** — concept_MovieNight, concept_ShortlistGeneration, concept_GroupConsensus, concept_PreferenceActions, concept_DeterministicScoring, concept_SocialGraph [EXTRACTED 1.00]
- **Agreeo Multi-Platform Deployment** — agreeo_linux_platform, agreeo_windows_platform, agreeo_web_platform, agreeo_ios_platform [EXTRACTED 1.00]
- **MovieLens Dataset Structure** — ml_data_files, ml_ratings_schema, ml_tags_schema, ml_movies_schema, ml_links_schema [EXTRACTED 1.00]
- **DM2526 Exam Modalities** — DM2526_Exam_Option1, DM2526_Exam_Option2, DM2526_Project_Proposal, DM2526_Presentation_Format [EXTRACTED 1.00]
- **Three Data Sources** — concept_TMDB, concept_MovieLens, concept_Neo4j, concept_MATCHES_TMDB, concept_TMDBMatching [EXTRACTED 1.00]
- **Core Graph Schema** — concept_AppUser, concept_Movie, concept_MovieLensUser, concept_MovieLensMovie, concept_MATCHES_TMDB, concept_PreferenceActions [EXTRACTED 1.00]
- **Movie Night Decision Flow** — concept_MovieNight, concept_ShortlistGeneration, concept_GroupConsensus, concept_PreferenceActions, concept_DeterministicScoring, concept_SocialGraph [EXTRACTED 1.00]
- **Agreeo Platforms** — agreeo_linux_platform, agreeo_windows_platform, agreeo_web_platform, agreeo_ios_platform [EXTRACTED 1.00]

## Communities

### Community 0 - "Web Search & Bing API"
Cohesion: 0.06
Nodes (64): build_output_path(), build_search_query_variants(), close_all_sessions(), close_all_sessions_sync(), decode_bing_redirect_url(), fetch_bing_rss_results(), fetch_bing_search_results(), format_json_block() (+56 more)

### Community 1 - "Social & Friends Backend"
Cohesion: 0.06
Nodes (56): buildShortlist(), calculateCompatibility(), cleanString(), cleanStringList(), clearShortlistAndVotes(), clearVotesForTiedMovies(), clearVotesOnly(), compareCandidates() (+48 more)

### Community 2 - "Daily Suggestions Engine"
Cohesion: 0.05
Nodes (27): dailyBreakdown, dailySourceBreakdown, favoriteGenres, filteredMovies, forYouIds, forYouSample, forYouSourceBreakdown, maxReleaseDate (+19 more)

### Community 3 - "Friends & Movie Night Controller"
Cohesion: 0.05
Nodes (2): FriendsMovieNightController, FriendsMovieNightState

### Community 4 - "App Controller & State Mgmt"
Cohesion: 0.05
Nodes (2): AgreeoAppController, AgreeoAppState

### Community 5 - "Project Docs & Configuration"
Cohesion: 0.09
Nodes (30): Neo4j Node Labels and Relationships, Neo4j Migration from Firestore, Neo4jService, vexp Agentic Search, Docker Compose Startup Guide, Legacy Cleanup Completed, Proposed Architecture Improvements, Backend Docker Service (+22 more)

### Community 6 - "Movie Recommendation Pipeline"
Cohesion: 0.1
Nodes (24): dislikeMovie(), findMovieByTmdbId(), getCandidatePoolStats(), getExploratoryCandidates(), getPersonalizedRecommendationCandidates(), getRecommendationCandidates(), getRecommendations(), getRecommendationUserProfile() (+16 more)

### Community 7 - "Neo4j Architecture Docs"
Cohesion: 0.16
Nodes (31): Agreeo / MoveMate Project Context and Neo4j Integration Guide, Neo4j TMDB MovieLens MVP Architecture, Friends and Movie Night Implementation Spec, Neo4j Integration & Implementation Report, Neo4j TMDB MovieLens Technical Architecture, Ricostruzione Ambiente, Agreeo, AppUser (+23 more)

### Community 8 - "Neo4j JavaScript Service"
Cohesion: 0.08
Nodes (17): neo4j, Neo4jService, bcrypt, emailNormalized, neo4jService, assert, calls, candidate() (+9 more)

### Community 9 - "Flutter Widget Tree & Layout"
Cohesion: 0.07
Nodes (30): build_vararg_params(), flutter_widget_children(), flutter_widget_children_details_subtree(), flutter_widget_children_summary_tree(), flutter_widget_creation_tracked(), flutter_widget_details_subtree(), flutter_widget_layout_explorer_node(), flutter_widget_location_id_map() (+22 more)

### Community 10 - "Backend Social Service"
Cohesion: 0.07
Nodes (4): BackendSocialService, FriendRequestMutationResult, FriendSearchResponse, SocialBackendSnapshot

### Community 11 - "Git Utility Functions"
Cohesion: 0.19
Nodes (23): ensure_git_repo(), format_command(), git_blame(), git_diff(), git_log(), git_status(), has_git_commit(), is_ignored_path() (+15 more)

### Community 12 - "Friends Screen UI"
Cohesion: 0.09
Nodes (11): _FriendCard, _FriendRequestCard, _FriendsListSection, FriendsScreen, _FriendsScreenState, _MiniPill, _MovieNightCard, _MovieNightCardState (+3 more)

### Community 13 - "Movie Night Wizard UI"
Cohesion: 0.09
Nodes (11): _BasicsStep, _ConstraintsStep, _GenreWrap, _InviteStep, MovieNightWizardScreen, _MovieNightWizardScreenState, _StepDots, _WizardActions (+3 more)

### Community 14 - "Flutter DevTools Extension"
Cohesion: 0.18
Nodes (21): call_flutter_service_extension(), flutter_call_service_extension(), flutter_hot_reload(), flutter_hot_restart(), flutter_widget_screenshot(), flutter_widget_selected_widget(), format_json_tool_output(), format_response_value() (+13 more)

### Community 15 - "Community 15"
Cohesion: 0.15
Nodes (18): flutter_detach(), flutter_list_devices(), flutter_run_start(), flutter_session_status(), flutter_stop(), format_command(), format_startup_summary(), get_session() (+10 more)

### Community 16 - "Community 16"
Cohesion: 0.17
Nodes (16): Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle(), GetWindowClass(), MessageHandler(), OnCreate() (+8 more)

### Community 17 - "Community 17"
Cohesion: 0.1
Nodes (9): AgreeoSwipeScreen, _AgreeoSwipeScreenState, _ImmersiveMovieCard, SwipeableCard, _SwipeableCardState, _SwipeCardActionButton, _SwipeCardActions, _SwipeCardFooterSkeleton (+1 more)

### Community 18 - "Community 18"
Cohesion: 0.12
Nodes (17): allUids, cleanString(), cleanStringList(), friendIds, joinedParticipants, joinedUids, movieId, otherUids (+9 more)

### Community 19 - "Community 19"
Cohesion: 0.13
Nodes (18): bool_string(), build_run_command(), flutter_debug_dump_app(), flutter_debug_dump_focus_tree(), flutter_debug_dump_layer_tree(), flutter_debug_dump_render_tree(), flutter_debug_dump_semantics_tree(), flutter_widget_root_tree() (+10 more)

### Community 20 - "Community 20"
Cohesion: 0.11
Nodes (10): MovieNightVotingScreen, _MovieNightVotingScreenState, _ParticipantVoteProgressCard, _PulsingIcon, _PulsingIconState, _SwipeStampOverlay, _VoteHistoryEntry, _VotingActionButton (+2 more)

### Community 21 - "Community 21"
Cohesion: 0.12
Nodes (13): _ConnectionBadge, _CountdownChip, _EditConstraintsSheet, _EditConstraintsSheetState, _GenreSheetWrap, _InviteFriendsSheet, _InviteFriendsSheetState, _JoinMovieNightCard (+5 more)

### Community 22 - "Community 22"
Cohesion: 0.12
Nodes (3): BackendMovieService, MovieDetails, UserLibrary

### Community 23 - "Community 23"
Cohesion: 0.13
Nodes (14): accessToken, app, authController, cors, express, http, movieController, neo4jService (+6 more)

### Community 24 - "Community 24"
Cohesion: 0.13
Nodes (11): _CountBadge, _FriendHeaderCard, FriendProfileScreen, _FriendProfileScreenState, _MiniStat, _MovieGrid, _MoviePosterCard, _PrivacyState (+3 more)

### Community 25 - "Community 25"
Cohesion: 0.13
Nodes (1): AuthService

### Community 26 - "Community 26"
Cohesion: 0.3
Nodes (3): FlutterMachineSession, summarize_params(), truncate_text()

### Community 27 - "Community 27"
Cohesion: 0.14
Nodes (11): bcrypt, DEFAULT_ROLES, displayNameFromEmail(), emailNormalized, neo4jService, normalizeEmail(), passwordHash, { sign, signRefresh } (+3 more)

### Community 28 - "Community 28"
Cohesion: 0.13
Nodes (11): _ActivityTile, AgreeoProfileScreen, _EmptyChip, _GradientChip, _PrivacySwitch, _ProfileActivity, _ProfileHeader, _SectionTitle (+3 more)

### Community 29 - "Community 29"
Cohesion: 0.13
Nodes (1): Neo4jService

### Community 30 - "Community 30"
Cohesion: 0.13
Nodes (1): RealTimeService

### Community 31 - "Community 31"
Cohesion: 0.28
Nodes (14): dart_format(), flutter_analyze(), flutter_pub_get(), flutter_test(), format_command(), Run flutter analyze and return the full analyzer output., Run flutter test and return the full test output., Run flutter pub get and return the full output. (+6 more)

### Community 32 - "Community 32"
Cohesion: 0.14
Nodes (11): Friend, FriendMovieReview, FriendProfile, FriendRequest, MovieNightConstraints, MovieNightEvent, MovieNightParticipant, MovieNightVote (+3 more)

### Community 33 - "Community 33"
Cohesion: 0.17
Nodes (9): ActionButton, AgreeoSearchBar, EmptyState, GenreChip, InfoBadge, RatingStars, SectionHeader, SelectableChip (+1 more)

### Community 34 - "Community 34"
Cohesion: 0.17
Nodes (3): AgreeoHomeScreen, _AgreeoHomeScreenState, _CollectionSection

### Community 35 - "Community 35"
Cohesion: 0.17
Nodes (4): _FakeMovieService, _FakeRealTimeService, _FakeRef, _StoredLoginAuthService

### Community 36 - "Community 36"
Cohesion: 0.18
Nodes (9): AppSession, EventConstraints, EventVote, InAppNotification, Movie, MovieEvent, MovieFeedbackRecord, MovieGroup (+1 more)

### Community 37 - "Community 37"
Cohesion: 0.18
Nodes (1): TmdbService

### Community 38 - "Community 38"
Cohesion: 0.18
Nodes (2): MockAuthException, MockAuthService

### Community 39 - "Community 39"
Cohesion: 0.2
Nodes (4): _ConfettiPainter, _FullLeaderboard, MovieNightResultScreen, _MovieNightResultScreenState

### Community 40 - "Community 40"
Cohesion: 0.2
Nodes (7): AgreeoUserSession, Movie, MovieSearchFilters, OnboardingState, ProfilePreferences, UndoEntry, UserMovieState

### Community 42 - "Community 42"
Cohesion: 0.22
Nodes (7): assert, calls, diversified, { diversifyRecommendations }, movieRepository, neo4jService, test

### Community 43 - "Community 43"
Cohesion: 0.22
Nodes (6): _DebugCard, _KeyValueRow, RecommendationDebugScreen, _RecommendationDebugScreenState, _StatBox, _TokenWrap

### Community 44 - "Community 44"
Cohesion: 0.22
Nodes (4): AgreeoLibraryScreen, _AgreeoLibraryScreenState, _LibraryMovieCard, _MiniPillBadge

### Community 45 - "Community 45"
Cohesion: 0.25
Nodes (9): MovieLens Dataset Files, GroupLens Research Group, Harper & Konstan 2015 Paper, MovieLens ml-latest-small Dataset, Links CSV Schema, MovieLens Recommendation Service, Movies CSV Schema, Ratings CSV Schema (+1 more)

### Community 46 - "Community 46"
Cohesion: 0.32
Nodes (8): buildDailySuggestionQueue(), buildTasteLearningPersonalizedPool(), diversifyRecommendations(), hydrateRecommendationEntries(), hydrateRecommendations(), loadDailySuggestions(), loadForYouRecommendations(), toPositiveInteger()

### Community 47 - "Community 47"
Cohesion: 0.29
Nodes (8): extractDirector(), extractTrailerUrl(), fetchInteractionMovie(), imageUrl(), mapInteractionMovie(), mapMovieLens(), mapTmdbMovie(), mapTmdbMovieDetails()

### Community 48 - "Community 48"
Cohesion: 0.25
Nodes (4): AgreeoBottomNavigation, _NavItem, PopcornIcon, PopcornPainter

### Community 49 - "Community 49"
Cohesion: 0.25
Nodes (3): NotificationsPage, _NotificationsPageState, _NotificationsTabList

### Community 50 - "Community 50"
Cohesion: 0.25
Nodes (1): NotificationService

### Community 51 - "Community 51"
Cohesion: 0.43
Nodes (6): jwt, sign(), signRefresh(), verify(), verifyMiddleware(), verifyRefresh()

### Community 52 - "Community 52"
Cohesion: 0.29
Nodes (6): GenreChip, _MovieArtwork, MovieHorizontalCarousel, MoviePosterCard, MovieSwipeCard, PosterGrid

### Community 53 - "Community 53"
Cohesion: 0.29
Nodes (7): Data Management 2025/2026, Exam Option 1: Written Only, Exam Option 2: Project + Written, DM2526 Instructions on Projects, Project Presentation Format, Project Proposal Requirement, Roberto Maria Delfino

### Community 54 - "Community 54"
Cohesion: 0.29
Nodes (2): AgreeoApp, _AgreeoAppState

### Community 55 - "Community 55"
Cohesion: 0.29
Nodes (4): AgreeoOnboardingFlowScreen, _AgreeoOnboardingFlowScreenState, _FavoriteMoviesStep, _GenresStep

### Community 56 - "Community 56"
Cohesion: 0.29
Nodes (3): AgreeoHomeShell, _AgreeoHomeShellState, _NotificationBadgeButton

### Community 57 - "Community 57"
Cohesion: 0.29
Nodes (2): ShortlistService, _WinnerScore

### Community 58 - "Community 58"
Cohesion: 0.29
Nodes (2): _AcceptFailingBackendSocialService, _OfflineBackendSocialService

### Community 59 - "Community 59"
Cohesion: 0.33
Nodes (5): code, endIdx, fs, lines, startIdx

### Community 60 - "Community 60"
Cohesion: 0.4
Nodes (2): init(), socketIo

### Community 61 - "Community 61"
Cohesion: 0.33
Nodes (3): _FilterSection, _MovieFilterBottomSheet, _MovieFilterBottomSheetState

### Community 62 - "Community 62"
Cohesion: 0.33
Nodes (2): _ReviewEditorSheet, _ReviewEditorSheetState

### Community 63 - "Community 63"
Cohesion: 0.33
Nodes (2): AgreeoAuthWelcomeScreen, _AgreeoAuthWelcomeScreenState

### Community 64 - "Community 64"
Cohesion: 0.33
Nodes (3): AgreeoMovieDetailsScreen, _AgreeoMovieDetailsScreenState, _GlassButton

### Community 65 - "Community 65"
Cohesion: 0.33
Nodes (2): NotificationsController, NotificationsState

### Community 66 - "Community 66"
Cohesion: 0.33
Nodes (1): MovieNightCandidateRank

### Community 67 - "Community 67"
Cohesion: 0.33
Nodes (1): FlutterWindow()

### Community 68 - "Community 68"
Cohesion: 0.6
Nodes (5): Linux Desktop Platform, Linux Binary: agreeo, Linux CMake Project Runner, Linux Flutter Build, Linux Runner Executable

### Community 69 - "Community 69"
Cohesion: 0.5
Nodes (5): Windows Desktop Platform, Windows Binary: agreeo, Windows CMake Project, Windows Flutter Build, Windows Runner Executable

### Community 70 - "Community 70"
Cohesion: 0.4
Nodes (4): assert, { hydrateRecommendations }, test, warned

### Community 71 - "Community 71"
Cohesion: 0.4
Nodes (3): controller, { initNeo4j, closeNeo4j }, repo

### Community 72 - "Community 72"
Cohesion: 0.4
Nodes (3): LocalUserMovieStateService, UserMovieStateMutation, UserMovieStateService

### Community 73 - "Community 73"
Cohesion: 0.5
Nodes (4): buildSearchRequest(), genreIdsForNames(), parseSearchFilters(), parseStringList()

### Community 74 - "Community 74"
Cohesion: 0.67
Nodes (3): doReq(), http, test()

### Community 75 - "Community 75"
Cohesion: 0.67
Nodes (3): doReq(), http, test()

### Community 76 - "Community 76"
Cohesion: 0.5
Nodes (1): http

### Community 77 - "Community 77"
Cohesion: 0.5
Nodes (2): controller, { initNeo4j, closeNeo4j }

### Community 78 - "Community 78"
Cohesion: 0.5
Nodes (2): movieRepository, neo4jService

### Community 79 - "Community 79"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 80 - "Community 80"
Cohesion: 0.67
Nodes (2): GetCommandLineArguments(), Utf8FromUtf16()

### Community 81 - "Community 81"
Cohesion: 0.67
Nodes (3): iOS Platform, iOS Launch Screen Assets, iOS Runner Xcode Project

### Community 82 - "Community 82"
Cohesion: 0.67
Nodes (3): Web Platform, Agreeo Web App, Flutter Web Entry Point

### Community 83 - "Community 83"
Cohesion: 0.67
Nodes (1): GeneratedPluginRegistrant

### Community 84 - "Community 84"
Cohesion: 0.67
Nodes (3): attachRecommendationMetadata(), buildForYouReason(), toFiniteNumber()

### Community 85 - "Community 85"
Cohesion: 0.67
Nodes (1): http

### Community 86 - "Community 86"
Cohesion: 0.67
Nodes (1): controller

### Community 87 - "Community 87"
Cohesion: 0.67
Nodes (1): http

### Community 88 - "Community 88"
Cohesion: 0.67
Nodes (1): http

### Community 89 - "Community 89"
Cohesion: 0.67
Nodes (1): controller

### Community 90 - "Community 90"
Cohesion: 0.67
Nodes (2): AgreeoBootstrapGate, _AgreeoLoadingScreen

### Community 92 - "Community 92"
Cohesion: 0.67
Nodes (1): BackendCatalogMovieService

### Community 93 - "Community 93"
Cohesion: 0.67
Nodes (1): MockMovieService

### Community 94 - "Community 94"
Cohesion: 0.67
Nodes (1): MovieService

### Community 95 - "Community 95"
Cohesion: 1
Nodes (2): matchesSearchFilters(), normalizeGenreName()

### Community 96 - "Community 96"
Cohesion: 1
Nodes (2): parseTmdbId(), parseTmdbIds()

### Community 97 - "Community 97"
Cohesion: 1
Nodes (1): BackendConfig

### Community 98 - "Community 98"
Cohesion: 1
Nodes (1): Neo4jConfig

### Community 101 - "Community 101"
Cohesion: 1
Nodes (1): FriendsPlaceholderScreen

### Community 103 - "Community 103"
Cohesion: 1
Nodes (1): Neo4jUser

### Community 104 - "Community 104"
Cohesion: 1
Nodes (1): AgreeoColors

## Ambiguous Edges - Review These
- `Proposed Architecture Improvements` → `vexp Agentic Search`  [AMBIGUOUS]
  CLEANUP_SUGGESTIONS.md · relation: conceptually_related_to

## Knowledge Gaps
- **404 isolated node(s):** `neo4jService`, `bcrypt`, `{ sign, signRefresh }`, `DEFAULT_ROLES`, `emailNormalized` (+399 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Friends & Movie Night Controller`** (2 nodes): `FriendsMovieNightController`, `FriendsMovieNightState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `App Controller & State Mgmt`** (2 nodes): `AgreeoAppController`, `AgreeoAppState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (1 nodes): `AuthService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (1 nodes): `Neo4jService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 30`** (1 nodes): `RealTimeService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (1 nodes): `TmdbService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (2 nodes): `MockAuthException`, `MockAuthService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (1 nodes): `NotificationService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 54`** (2 nodes): `AgreeoApp`, `_AgreeoAppState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 57`** (2 nodes): `ShortlistService`, `_WinnerScore`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 58`** (2 nodes): `_AcceptFailingBackendSocialService`, `_OfflineBackendSocialService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 60`** (2 nodes): `init()`, `socketIo`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 62`** (2 nodes): `_ReviewEditorSheet`, `_ReviewEditorSheetState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 63`** (2 nodes): `AgreeoAuthWelcomeScreen`, `_AgreeoAuthWelcomeScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 65`** (2 nodes): `NotificationsController`, `NotificationsState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 66`** (1 nodes): `MovieNightCandidateRank`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 67`** (1 nodes): `FlutterWindow()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 76`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 77`** (2 nodes): `controller`, `{ initNeo4j, closeNeo4j }`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 78`** (2 nodes): `movieRepository`, `neo4jService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 79`** (2 nodes): `handle_new_rx_page()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 80`** (2 nodes): `GetCommandLineArguments()`, `Utf8FromUtf16()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 83`** (1 nodes): `GeneratedPluginRegistrant`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 85`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 86`** (1 nodes): `controller`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 87`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 88`** (1 nodes): `http`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 89`** (1 nodes): `controller`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 90`** (2 nodes): `AgreeoBootstrapGate`, `_AgreeoLoadingScreen`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 92`** (1 nodes): `BackendCatalogMovieService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 93`** (1 nodes): `MockMovieService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 94`** (1 nodes): `MovieService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 95`** (2 nodes): `matchesSearchFilters()`, `normalizeGenreName()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 96`** (2 nodes): `parseTmdbId()`, `parseTmdbIds()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 97`** (1 nodes): `BackendConfig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 98`** (1 nodes): `Neo4jConfig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 101`** (1 nodes): `FriendsPlaceholderScreen`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 103`** (1 nodes): `Neo4jUser`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 104`** (1 nodes): `AgreeoColors`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Proposed Architecture Improvements` and `vexp Agentic Search`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `FlutterMachineSession` connect `Community 26` to `Community 19`, `Community 15`, `Flutter DevTools Extension`?**
  _High betweenness centrality (0.001) - this node is a cross-community bridge._
- **What connects `neo4jService`, `bcrypt`, `{ sign, signRefresh }` to the rest of the system?**
  _404 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Web Search & Bing API` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Social & Friends Backend` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Daily Suggestions Engine` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Friends & Movie Night Controller` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._