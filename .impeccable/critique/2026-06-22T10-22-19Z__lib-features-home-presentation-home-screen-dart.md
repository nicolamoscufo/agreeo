---
target: Agreeo Daylight Home + design system
total_score: 34
p0_count: 0
p1_count: 0
timestamp: 2026-06-22T10-22-19Z
slug: lib-features-home-presentation-home-screen-dart
---
# Critique — Agreeo Daylight (Home + design system) — re-run

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 4 | Rails + search now show shimmer skeletons (reduced-motion aware, `Semantics(label:'Loading')`); load no longer ≡ empty |
| 2 | Match System / Real World | 4 | Voice natural and on-brand ("What's the move?", "Can't decide?") |
| 3 | User Control and Freedom | 3 | Search clearable; retry now exists; no swipe-level undo on Home (lives on Swipe) |
| 4 | Consistency and Standards | 4 | Token + component system cohesive; one residual bespoke button (`_RandomPickCard`) |
| 5 | Error Prevention | 3 | Destructive flows have sheets; inputs constrained |
| 6 | Recognition Rather Than Recall | 3 | Tooltip + Semantics on icon buttons; active-filter now carries a dot badge |
| 7 | Flexibility and Efficiency | 3 | Quick chips, mood, surprise-me; few accelerators (mobile-appropriate) |
| 8 | Aesthetic and Minimalist Design | 4 | One full-gradient+glow focal point (Movie Night CTA); mood button demoted to `gradSoft` |
| 9 | Error Recovery | 4 | `_SearchResults` branches on `hasError` → `_SearchStateCard` + Retry; preserves query. Feed rails still conflate error/empty (residual) |
| 10 | Help and Documentation | 2 | Onboarding exists; little contextual help (acceptable for category) |
| **Total** | | **34/40** | **Good — two P1/P2 gaps closed; only P3 polish remains** |

## Anti-Patterns Verdict

**Does this look AI-generated? No.** Unchanged from the prior run: committed Daylight identity, gradient on fills only, hand-painted diagonal CTA pattern, real voice, no banned tells. The loading + error work added genuine product-grade state handling without introducing slop.

**Deterministic scan**: `detect.mjs` returned `[]` (real attempt) — it scans HTML/CSS/JSX, not Dart, so no signal here. No browser overlay: a Flutter app has no inspectable browser target without a running emulator.

## What changed since 30/40

1. **Error Recovery 2→4.** `_SearchResults` now checks `snapshot.hasError && !snapshot.hasData` and renders `_SearchStateCard` with plain-language copy ("Check your connection and try again") and a working **Retry** that re-fires `_refreshSearch`. A dropped connection no longer masquerades as "No results", and the query is preserved.
2. **Visibility of System Status 3→4.** `_PosterRail` takes a `loading` flag → `AgPosterRailSkeleton`; search waiting → `AgPosterGridSkeleton`. Shimmer is reduced-motion aware (static fallback) and both skeletons announce `Loading` to screen readers, closing most of the Sam gap.
3. **Aesthetic 3→4.** Full brand gradient + glow is now reserved for the Movie Night CTA. The mood `_SquareButton` is demoted to `soft` (`gradSoft` tint + red glyph); the active chip stays gradient (small). One loud element leads the screen.
4. **Recognition (color-only fix).** The active filter button now shows a dot `badge`, so the active state isn't signalled by glyph color alone.

## Priority Issues (residual)

- **[P3] Quick-chip tap height still 36px.** The chip rail is wrapped in `SizedBox(height: 36)` (home_screen.dart:274); below the 44pt target despite `AgChip` using `HitTestBehavior.opaque`. Casey fat-fingers one-handed. Fix: raise the rail height to ≥44 and pad the chip vertically.
  - **Suggested command**: `/impeccable audit`
- **[P3] Home feed rails still conflate a *failed* load with empty.** `_PosterRail` distinguishes loading vs empty, but a failed feed fetch still falls to "Nothing here yet" with no retry. Search is fully fixed; the feed isn't. Fix: thread an error/retry state into the rails like `_SearchResults`.
  - **Suggested command**: `/impeccable harden`
- **[P3] `_RandomPickCard` "Surprise me" is a bespoke `t.text` button.** A third button style alongside `AgButton` primary/secondary and gradient pills. Fold into the `AgButton` system.
  - **Suggested command**: `/impeccable polish`

## Persona Red Flags

- **Sam (Accessibility)**: Much improved — skeletons announce "Loading", retry is a real focusable action. Residual: search result count change isn't a live region.
- **Riley (Stress tester)**: The headline failure is fixed — error ≠ empty in search, with retry. Residual: feed rails still look identical on failure vs genuinely-empty.
- **Casey (Distracted mobile)**: Good thumb ergonomics; 36px chips remain easy to mis-tap one-handed.

## Questions to Consider

- Should the home feed rails get the same error/retry treatment search now has?
- Is 36px on the chip rail worth the one-line fix to clear 44pt?
