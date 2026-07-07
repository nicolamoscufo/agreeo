# Product

## Register

product

## Users

People who want to decide what to watch — alone or, especially, with friends. They open Agreeo in casual, low-focus moments: on the couch before a movie night, in bed scrolling for something to save, or mid-argument over what to put on. The job to be done is *"help us agree on something to watch, quickly, without it feeling like work."* Movie-night is the social heart: a group swipes/votes and the app surfaces the match.

## Product Purpose

Agreeo is a movie discovery + movie-night app (Flutter, existing backend) built around swiping, saving, reviewing, and group voting. Success is a decision reached with delight: a couple or group goes from "I don't know, what do you want?" to a title everyone's happy with, in a few taps. The catalog and recommendation surface is a means to that end, not the point.

## Brand Personality

Warm, social, playful. The voice is a friend who's good at picking films — relaxed, a little witty, never corporate. The interface should feel inviting and alive (warm cream/charcoal Daylight palette, coral→violet brand gradient, soft posters and rounded surfaces), with small moments of delight around the social and decision beats (matches, votes, stamps, ratings).

## Anti-references

- **Netflix-corporate / streaming-service chrome.** Cold black UI, dense rows, aggressive merchandising. Agreeo is warm and personal, not a storefront.
- **Analytics-dashboard energy.** No data-tool density, hero-metric templates, or enterprise grids.
- **Generic TMDB clone.** Not a thin catalog browser; the social and decision flows are the product.
- **Over-decorated theming.** Glassmorphism is used sparingly and purposefully (the bottom nav), never as a default coat of paint.

## Design Principles

1. **Agreement is the moment.** Discovery flows exist to serve the decision; spend the delight budget on matches, votes, and "we agreed" beats.
2. **Warmth carries the brand, not chrome.** Identity lives in palette, type, and posters — not in heavy effects or borrowed streaming-service patterns.
3. **One source of truth for surface.** Color comes from `AgreeoTokens`, type from `AgText`; no hardcoded hex or `fontFamily` literals in widgets. Light/Dark parity is automatic.
4. **Readable first.** Every text tier clears WCAG AA against its real background; legibility beats elegant-but-faint gray.
5. **Calm motion.** Motion is intentional and ease-out; it punctuates the social/decision beats rather than animating everything uniformly.

## Accessibility & Inclusion

Target **WCAG AA**: body text ≥4.5:1 and large text ≥3:1 against real backgrounds (already enforced via the `sub`/`faint` token tuning), adequate touch targets, and semantic labels on interactive widgets (the in-progress `Semantics` pass). Honor reduced-motion with crossfade/instant alternatives. Full Light/Dark support is a first-class requirement, not an afterthought.
