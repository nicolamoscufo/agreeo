---
target: Agreeo Daylight Home + design system
total_score: 30
p0_count: 0
p1_count: 1
timestamp: 2026-06-22T09-49-15Z
slug: lib-features-home-presentation-home-screen-dart
---
# Critique — Agreeo Daylight (Home + design system)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Bare `CircularProgressIndicator`; poster rails show "Nothing here yet" during initial load (load ≡ empty) |
| 2 | Match System / Real World | 4 | Voice is natural and on-brand ("What's the move?", "Can't decide?") |
| 3 | User Control and Freedom | 3 | Standard back/cancel; filters clearable; no undo on swipe-level actions |
| 4 | Consistency and Standards | 4 | Token system + component library + single gradient identity; very cohesive |
| 5 | Error Prevention | 3 | Destructive flows have dedicated sheets; inputs constrained |
| 6 | Recognition Rather Than Recall | 3 | Icon buttons carry Tooltip + Semantics; chips labeled |
| 7 | Flexibility and Efficiency | 3 | Quick chips, mood, surprise-me; few accelerators (mobile-appropriate) |
| 8 | Aesthetic and Minimalist Design | 3 | Clean, but multiple full-gradient attractors compete on Home |
| 9 | Error Recovery | 2 | `_SearchResults` masks errors as "No results"; no retry on failed loads |
| 10 | Help and Documentation | 2 | Onboarding exists; little contextual help beyond tooltips (acceptable for the category) |
| **Total** | | **30/40** | **Good — solid foundation, two real gaps (error recovery, loading)** |

## Anti-Patterns Verdict

**Does this look AI-generated? No.** It has a committed, specific identity: warm Daylight cream/charcoal, coral→violet gradient used on *fills only* (never gradient text), a hand-painted diagonal pattern on the Movie Night CTA, and a real voice. It actively avoids the banned tells: no eyebrow kickers, no `01/02/03` section markers, no side-stripe borders, no identical-card-grid; glassmorphism is confined to the bottom nav. Posters/rails vary in size, breaking grid sameness.

**Deterministic scan**: `detect.mjs` returned `[]` — it targets HTML/CSS/JSX markup, not Dart widgets, so it offers no signal here (real attempt made). No browser overlay: a Flutter app has no inspectable browser target without running an emulator.

**One watch-item, not slop**: the brand gradient appears on three surfaces on the Home screen at once (mood square button + Movie Night CTA + active chip). It dilutes the single intended focal point.

## Overall Impression

This is a mature, genuinely on-brand product surface — warm, social, and confident, exactly matching PRODUCT.md. The Movie Night CTA is a real focal moment that embodies "agreement is the moment." The biggest opportunity is not visual polish but **state honesty**: loading and error states are the weakest link, and they're where trust is won or lost on a flaky mobile connection.

## What's Working

1. **One source of truth, fully realized.** Color from `AgreeoTokens`, type from `AgText`, dual-theme with WCAG-tuned `sub`/`faint`. The consistency is the product's spine and it pays off everywhere.
2. **The Movie Night CTA earns its loudness.** Gradient + diagonal pattern + friend-avatar stack + "Invite friends, swipe together, agree in minutes." It's the one element allowed to shout, and it points at the core job.
3. **Accessibility is built in, not bolted on.** Icon buttons pair `Tooltip` + `Semantics(button, label)`; the `AgStarRater` rater now announces each star. This is ahead of most apps at this stage.

## Priority Issues

- **[P1] Errors render as empty states.** `_SearchResults` uses `snapshot.data ?? []` and never checks `snapshot.hasError`. A failed search on a flaky connection shows "No results / Try a different title" — misleading, with no retry. Same load≡empty pattern in the poster rails.
  - **Why it matters**: users blame themselves ("my search is wrong") for a network failure, and have no path back. Erodes trust at exactly the wrong moment.
  - **Fix**: branch on `snapshot.hasError` → render `AgStateCard` (already supports `actionLabel`/`onAction`) with a Retry that re-fires the future. Distinguish load from empty.
  - **Suggested command**: `/impeccable harden`

- **[P2] Loading is a bare spinner; rails can't distinguish loading from empty.** During initial feed load, `state.recommendedHomeMovies` is empty so `_PosterRail` shows "Nothing here yet" instead of a loading affordance.
  - **Why it matters**: false "empty" flashes read as broken; a centered spinner gives no sense of what's coming.
  - **Fix**: skeleton/shimmer poster placeholders for rails; a dedicated loading state separate from the empty card.
  - **Suggested command**: `/impeccable harden` (states) then `/impeccable animate` (shimmer)

- **[P2] Three full-gradient attractors compete on Home.** Mood square button (gradient + glow), Movie Night CTA (gradient + glow), and active chip all use the full brand gradient simultaneously.
  - **Why it matters**: when everything glows, nothing leads. It softens the CTA's intended primacy.
  - **Fix**: reserve full gradient + glow for the Movie Night CTA; demote the mood button to `gradSoft`/outline and let the active chip stay gradient (it's small). One loud element per screen.
  - **Suggested command**: `/impeccable quieter` (scoped to Home) or `/impeccable layout`

- **[P3] Touch + color-only signals.** Quick-chip tap height is 36px (below the 44pt target); the filter "active" state is conveyed to sighted users by icon color alone (the Semantics label covers screen readers).
  - **Why it matters**: thumb misses on the chip rail; low-vision sighted users miss the active filter.
  - **Fix**: raise chip hit area to ≥44px; add a dot/fill or count badge to the active filter button.
  - **Suggested command**: `/impeccable audit`

## Persona Red Flags

**Sam (Accessibility-dependent)**: Strong baseline (labels, tooltips, contrast). Gaps: async loads use `CircularProgressIndicator` with no "loading" announcement; the search results count change isn't announced as a live region; the active-filter state is color-only for sighted low-vision users.

**Riley (Stress tester)**: The headline failure — `_SearchResults` swallows `hasError` and shows "No results." A dropped connection mid-search looks identical to a genuinely empty result. No retry path. Long titles and empty watchlist + "Surprise me" need a look.

**Casey (Distracted mobile)**: Good thumb ergonomics (center FAB, mid-screen CTA), but the primary search/filter row sits at the very top (a reach), and 36px chips are easy to fat-finger one-handed. Confirm home/search state survives an app-background interruption.

**The Indecisive Duo (project persona — warm/social/playful)**: Served well — Home → Movie Night is a single tap and the CTA copy speaks to "agree in minutes." Solo paths (mood, surprise-me) stay prominent without drowning the social hook. No red flag; this is the app's strongest throughline.

## Minor Observations

- `_RandomPickCard` "Surprise me" uses `t.text` as button fill — visually a third button style alongside `AgButton` primary/secondary and the gradient pills. Consider folding into the `AgButton` system for consistency.
- The Home quick-filter rail has 7 chips; fine as a horizontal scroller, but "For you" + 6 genres/sorts mixes two axes (recommendation vs genre vs rating) in one row.
- Independent of design: an open formatting decision (tall vs short style) and 7 pre-existing `curly_braces` analyzer infos remain as housekeeping.

## Questions to Consider

- What does a *failed* feed look like, not just an empty one? Right now they're the same screen.
- If only one element on Home could glow, is it always the Movie Night CTA?
- Does "loading" ever get announced to a screen reader, or is async invisible to Sam?
