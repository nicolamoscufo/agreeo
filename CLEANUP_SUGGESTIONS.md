# Legacy Code Cleanup & Improvements

## Cleanup Completed
- Removed the outdated polling logic (`MovieNightAutoRefresh` mixin) and eliminated its usage in waiting, voting and result screens.
- Purged polling-triggered timers to stop redundant periodic GET requests and UI rebuilds.
- Added targeted socket-driven refreshes: `real_time_service.dart` now asks the controller to refresh a specific `MovieNightEvent` when socket payloads include an `event.id`.
- Removed legacy local mock seeding (`_seedLocalSocialLayer`) and the `mock_movies.dart` dependency from the friends controller.
- Cleaned up small unused locals and duplicate helper methods introduced during iterative edits.

## Proposed Flaw/Architecture Improvements

### 1. Unified Socket Event Handling
The `real_time_service.dart` handles notifications, but current socket implementations often rely on firing generic "refreshAll" calls which reload entire datasets. 
**Improvement:** Use targeted state reducers instead. When receiving `movie_night_updated` via socket, transmit the actual payload of the changed event and use a targeted `.copyWith` to update just the single `MovieNightEvent` in Riverpod state. This will drastically reduce unnecessary UI builds.

Status: Implemented — the service now tries to extract `event.id` from incoming socket messages and calls `friendsMovieNightControllerProvider.notifier.refreshMovieNight(eventId)` to update only that event.

### 2. Idempotent Start Voting 
Right now, `startVoting` recalculates and triggers a DB call. If two people tap it, or one person double-taps out of impatience over a latency spike, it could try to lock the event twice and trigger multiple shortlist DB transactions.
**Improvement:** Implement an optimistic lock on the UI side (disable the button) and add backend state validation to ensure a `status: 'created'` transition to `'voting'` is atomic.

### 3. Move Score Calculation Entirely to Backend
Currently, `selectWinner` is being evaluated in Dart via `_shortlistService.selectWinner` while the system simultaneously polls or assumes that everyone has voted via backend evaluation.
**Improvement:** Shift all winner evaluations to Neo4j. The database graph structure is inherently suited to calculate node similarities and max scores efficiently. Have the `MovieNightEvent` returned by Socket.IO natively carry the `winnerCandidate`.

### 4. Remove Mock Dependencies
The mock seeding has been removed from the controller; profile population now relies on backend snapshot loading. Keep an eye on offline flows — if you need a local offline demo mode, add a small, explicit feature-flagged stub.
9