# Agreeo Remaining Work

## Current Phase
Phase 1 - Core MVP prototype

## Last Updated
2026-05-08 - Swipe card controls embedded in card

## Current Status
The repo now has a dedicated Agreeo Phase 1 prototype flow connected end-to-end at the app level: new bootstrap gate, mock auth welcome screen, onboarding steps, 5-tab shell, Home, Swipe, Library, Movie Details, Profile, and a Friends placeholder tab. The full repo passes `flutter analyze` and the Flutter test suite passes. The Swipe card now keeps all core interactions inside the card itself, with a near full-screen cinematic layout and animated horizontal swipe gestures for like/dislike. A true desktop smoke run on Windows is still blocked locally by the missing Visual Studio toolchain.

## Completed
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

## In Progress
- [ ] Manual device/emulator walkthrough of the full Phase 1 flow for visual polish and interaction tuning.

## Remaining Phase 1 Work
- [ ] Manual device/emulator walkthrough of the full Phase 1 flow for visual polish and interaction tuning.
- [ ] Run a true local app walkthrough on a target with an available interactive runtime (Chrome, Edge, or Windows once the Visual Studio toolchain is installed).

## Blocked / Issues
- [ ] The existing codebase appears to contain a broader legacy flow, including events and backend-oriented services, which may not map cleanly to the requested Phase 1-only prototype.
- [ ] Current project structure does not yet match the requested Agreeo feature set, so some files may need to be replaced or bypassed.
- [ ] Windows desktop smoke run/build is blocked locally because the Visual Studio toolchain is not installed/configured for Flutter desktop builds.

## Next Steps
- Open the app in Chrome or Edge and do a manual pass through auth, onboarding, swipe card gestures, embedded controls, library updates, details, and profile.
- Optionally install/fix the Visual Studio desktop toolchain if Windows desktop verification is required.
- If the prototype feels stable after manual QA, either remove or refactor the old legacy flow before starting Phase 2.

## Do Not Start Yet
- Friends screen
- Friend Profile
- Friend Requests
- Movie Night creation
- Invite friends flow
- Waiting Room
- Shortlist voting
- Winner result screen
- Real recommendation algorithm
- Real backend integration
- Real TMDB API integration
