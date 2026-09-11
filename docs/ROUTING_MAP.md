# Agreeo — Routing Map (Phase 0)

> How navigation works today. The new Daylight UI **reuses this same navigation
> scheme** (no router package; `Navigator` + an `IndexedStack` shell driven by
> `navIndexProvider`). Documented so each rewritten screen keeps the same entry/exit
> points and auth guards.

---

## 1. App entry & auth guard

```
main.dart
  └─ runApp(ProviderScope(child: AgreeoApp))

app.dart → MaterialApp
  • theme      = buildAgreeoTheme(Brightness.light)
  • darkTheme  = buildAgreeoTheme(Brightness.dark)
  • themeMode  = ThemeMode.dark        ← hardcoded today (see GAP §4.1 in CONTRACT)
  • builder    = _CompactPhoneUi (text/density scaling for <430px)
  • home       = AgreeoBootstrapGate
  • Deep links : AppLinks().uriLinkStream → movieNightInviteEventIdFromUri()
                 → pendingMovieNightInviteProvider = eventId
```

### `AgreeoBootstrapGate` (the only auth guard) — `features/bootstrap/presentation/`
```
watch(agreeoAppControllerProvider):
  !hydrated            → _AgreeoLoadingScreen        (Splash, screen #1)
  !isAuthenticated     → AgreeoAuthWelcomeScreen     (Login/Sign-up, #2/#3)
  !onboardingComplete  → AgreeoOnboardingFlowScreen  (Genres/Favorites, #4/#5)
  else                 → AgreeoHomeShell             (main app)
```
→ Rewrites of Splash/Auth/Onboarding/Shell must preserve these four branch widgets
(same class names, or update the gate's imports accordingly — the gate logic stays).

---

## 2. Main shell — `AgreeoHomeShell` (`features/shell/presentation/`)

- `Scaffold` with `extendBody`, an `AppBar` (hidden when Swipe tab active), an
  `IndexedStack` body, and `AgreeoBottomNavigation`.
- Tab index source of truth: **`navIndexProvider` (StateProvider<int>)**.

| Index | Tab | Screen widget |
|---|---|---|
| 0 | Home | `AgreeoHomeScreen` |
| 1 | Library | `AgreeoLibraryScreen` |
| 2 | Swipe | `AgreeoSwipeScreen(onNavigateTab:)` |
| 3 | Friends | `FriendsScreen` |
| 4 | Profile | `AgreeoProfileScreen` |

> ⚠️ This order differs from both the JSX `BottomNav` and the initial design specification — see
> **GAP §4.2** in `BACKEND_CONTRACT.md`. Resolve the canonical order before Phase 2.

**AppBar actions (Home tab only):** Mood sheet (`showMoodSelectorSheet`), Random-pick
dialog, and the notification bell with unread badge (`notificationsProvider.unreadCount`).

**Tab re-tap behavior:** tapping Home while already on Home calls
`refreshHomeFeed()` + bumps `homeRefreshProvider`.

---

## 3. Pushed routes (not tabs — `Navigator.push(MaterialPageRoute(...))`)

| Destination | Pushed from | Constructor |
|---|---|---|
| Notifications | bell button in shell AppBar | `NotificationsPage()` |
| Movie details | Home/Library/Swipe/Random/Search cards | `AgreeoMovieDetailsScreen(movieId:)` |
| Review editor | Movie details / Library | `review_editor.dart` (sheet/screen) |
| Friend profile | Friends list | `FriendProfileScreen(...)` |
| Movie Night (waiting) | Create flow / invite resolve | `MovieNightWaitingRoomScreen(eventId:)` |
| Movie Night (voting) | when status=voting | `MovieNightVotingScreen(eventId:)` |
| Movie Night (results) | when status=completed | `MovieNightResultScreen(eventId:)` |
| Edit profile / Settings | Profile screen | onboarding/profile screens |

**Movie-night status → screen** (`_routeForMovieNight` in shell):
```
draft | waiting → MovieNightWaitingRoomScreen
voting          → MovieNightVotingScreen
completed       → MovieNightResultScreen
```

---

## 4. Deep-link / invite flow

```
app_links stream → pendingMovieNightInviteProvider (eventId)
AgreeoHomeShell.ref.listen(pendingMovieNightInviteProvider):
  → resolveMovieNightInvite(eventId)
  → set navIndexProvider = 3 (Friends)
  → Navigator.push(_routeForMovieNight(event))
  (shows SnackBar if invite unavailable)
```
→ Preserve this listener + `_handlePendingInvite()` logic when rewriting the shell.

---

## 5. Modal sheets / dialogs (not routes)
- **Mood Matcher**: `showMoodSelectorSheet(context)` (`home/presentation/mood_selector_sheet.dart`).
- **Filters**: `filter_bottom_sheet.dart` (to be rewritten as `AgSheetShell` content).
- **Random Pick**: `_RandomMovieDialog` (currently inline in shell) → calls
  `movieServiceProvider.getRandomMovie()`.

---

## 6. Rebuild guidance
- Keep **`navIndexProvider`** as the tab controller; keep the **bootstrap gate's four
  branches**; keep the **deep-link listener**. These are the navigation contract.
- Decide the canonical 5-tab order (GAP §4.2) **before** building `AgGlassBottomNav`
  in Phase 2, since the index→screen mapping above depends on it.
- New screens are still plain widgets pushed via `Navigator`/shown via
  `showModalBottomSheet`; no routing package is introduced.
