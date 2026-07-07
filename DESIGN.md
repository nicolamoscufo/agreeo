# Design

Visual system for **Agreeo** — the "Daylight" theme. Captured from `lib/shared/theme/agreeo_tokens.dart` (color) and `lib/shared/theme/ag_text.dart` (type). Those files are the source of truth; this document mirrors them for design reasoning. Never hardcode hex or `fontFamily` in widgets — read tokens.

## Theme

Warm dual-mode: **Daylight Light** (warm cream) and **Daylight Dark** (warm charcoal). Both are intentionally *warm* neutrals tinted toward the brand, never cold gray. Mode is user-selectable and persisted; every token has a Light and Dark value and the two cross-fade via `ThemeExtension.lerp`. Physical scene: someone on a couch in dim evening light choosing a film — light mode for daytime browsing, dark for the lights-down movie-night moment.

## Color

OKLCH reasoning, stored as Flutter `Color`. Roles (Light / Dark):

| Role | Token | Light | Dark | Use |
|------|-------|-------|------|-----|
| Background | `bg` | `#F7F2EA` | `#161310` | Scaffold |
| Background 2 | `bg2` | `#FCF8F1` | `#1E1A16` | Sheets / modals |
| Surface | `surface` | `#FFFFFF` | `#221D18` | Cards, inputs |
| Surface 2 | `surface2` | `#F1EADF` | `#2C251F` | Elevated containers |
| Line | `line` / `line2` | warm black 9% / 16% | warm white 8% / 15% | Hairline / emphasized borders |
| Ink | `text` | `#221A14` | `#F7F0E8` | Primary text |
| Sub | `sub` | ink @ 72% | warm white @ 74% | Secondary text (AA-clear) |
| Faint | `faint` | ink @ 62% | warm white @ 60% | Tertiary / placeholder (AA-clear) |
| Brand coral | `red` / `redDeep` | `#EF563B` / `#D8442B` | `#FF6F52` / `#E8542F` | Primary accent, dislike |
| Brand violet | `purple` / `purpleDeep` | `#6B45F0` / `#5A33E0` | `#9B7BFF` / `#7A5AF0` | Secondary accent |
| Gold | `gold` | `#C9890F` | `#FFC24B` | Ratings, stars, watchlist |
| Green | `green` | `#1E9E73` | `#46D4A0` | Success / online |

**Strategy: committed.** The coral→violet **brand gradient** (`grad`, 135°, coral→violet) is the signature, carried on CTAs, active chips, and progress — not sprinkled decoratively. `gradSoft` (low-alpha) tints backgrounds. Accent glow (violet, under gradient buttons) and a poster shadow (mode-dependent alpha) are the only elevation effects. Contrast note baked into tokens: `sub`/`faint` were lifted so body text clears WCAG AA on the cream and charcoal backgrounds.

## Typography

Two families on a contrast axis:
- **Bricolage Grotesque** (w800) — display & headings. Negative tracking that tightens as size grows.
- **Manrope** — body and labels (w400 body, w700 labels).

Loaded via `google_fonts`. **Always source type from `AgText`** (`AgText.h3`, `.body`, `.label`, …); literal `fontFamily` strings fall back to platform sans because google_fonts registers variant-suffixed names. Fixed (non-fluid) scale on ~1.12–1.18 ratio: `display 30 / h1 25 / h2 22 / h3 19 / h4 16` (Bricolage w800); `lead 16 / body 14.5 / caption 13 / micro 11.5` (Manrope w400); `label 13 / labelSm 11.5 / overline 11.5` (Manrope w700). Tokens carry family+size+weight+tracking+line-height only; color stays at the call site via `.copyWith(color: context.tokens.*)` so contrast decisions remain reviewable.

## Components

Reusable library in `lib/shared/ui/` (barrel `ag_ui.dart`): `AgButton`, `AgChip`, `AgPoster`, `AgAvatar`, `AgStars`, `AgStamp`, `AgSearchField`, `AgSectionHeader`, `AgStateCard`, `AgGlassBottomNav`, plus `ag_effects` and `ag_sheet_shell`. Glassmorphism appears only in the bottom nav. Interactive widgets carry `Semantics` (button/enabled/label).

## Layout & Motion

Mobile-first single-column app shell. Bottom nav: Home / Swipe / [center Movie-Night FAB] / Library / Friends; Profile opens from the header avatar. Page transitions: slide+fade `easeOutCubic` wired once via `pageTransitionsTheme`. Motion is intentional and ease-out, concentrated on the social/decision beats (matches, votes, stamps); reduced-motion must have a crossfade/instant fallback.
