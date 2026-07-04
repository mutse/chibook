# Chibook iPad Adaptive Layout Design

## Summary

This design adds real iPad large-screen support to the existing Flutter app without rewriting the navigation or business state model. The first iteration focuses on the core paths:

- Global app shell
- Home
- Bookshelf
- Discover
- Player
- Reader

The app should feel native on iPad by using a sidebar-driven shell at large widths, while still falling back to the current compact mobile layout in split-screen, Stage Manager narrow windows, and phone-sized widths.

## Goals

- Support iPad large-screen layouts for the main reading flows
- Replace bottom navigation with a sidebar at large widths
- Keep split-screen and narrow Stage Manager windows functional through compact fallback
- Reuse the current route structure and feature state as much as possible
- Improve use of horizontal space without letting reading content become too wide

## Non-Goals

- A full route architecture rewrite
- Converting book detail or notebook flows into persistent split-view detail panes
- Reworking every secondary screen in this iteration
- Creating iPad-only business logic or separate feature states

## Current State

The iOS project already targets both iPhone and iPad at the platform level:

- `TARGETED_DEVICE_FAMILY = "1,2"` is already set
- `UISupportedInterfaceOrientations~ipad` is already configured

The main limitation is the Flutter UI layer:

- `AppShell` is fixed to a bottom navigation layout
- Core screens are mostly phone-first single-column compositions
- Reader and player experiences are optimized for vertical mobile stacking

## Proposed Approach

Build a shared adaptive layout layer and migrate the core screens onto it. This avoids scattering width checks and hard-coded tablet rules across many features.

### Why this approach

- It solves the shell and layout problem once
- It keeps future iPad work incremental
- It avoids risky route churn
- It supports both full-screen iPad and narrow multitasking windows through the same width-based rules

## Adaptive Foundation

### 1. Adaptive breakpoints

Introduce a shared adaptive layout model that derives size classes from available width instead of device type.

Planned categories:

- `compact`: phone widths and narrow iPad split-screen widths
- `medium`: wider tablet windows that can support expanded content but not the full desktop-style shell
- `expanded`: full iPad large-screen widths

Exact threshold values should be centralized in one file and used consistently by shell and screen layouts.

### 2. Adaptive shell

Create a shared shell component that switches navigation chrome by width:

- `compact`: keep the current bottom navigation bar
- `medium` and `expanded`: switch to a left sidebar with the existing top-level destinations

The sidebar should include:

- Home
- Bookshelf
- Player
- Discover
- Profile

The current mini player should no longer float above a tablet bottom bar. On wide layouts it should move into the sidebar footer area or the main content header area, depending on available width.

### 3. Shared content containers

Introduce reusable layout helpers for:

- Max content width
- Horizontal page padding
- Adaptive spacing
- Grid column count
- Two-column page composition

This keeps page code readable and prevents repeated `MediaQuery` magic numbers.

## Screen Design

### Global app shell

Wide layouts:

- Use a left sidebar navigation rail or panel
- Keep the selected destination behavior identical to the current branch navigation
- Keep existing route locations and `GoRouter` branch logic unchanged

Compact layouts:

- Preserve the existing bottom navigation shell

### Home

Wide layouts should convert the current long mobile stack into a broader composition:

- Main content area for hero card, continue reading, recommendations, and key sections
- Secondary area for summary metrics and quick actions
- Cards should breathe horizontally instead of remaining stretched single-column rows

Compact layouts keep the current structure.

### Bookshelf

Bookshelf should receive the strongest large-screen upgrade:

- Search, filters, sort, and summary cards should align more naturally in wider rows
- Book presentation should move to an adaptive multi-column grid at wide widths
- Grid density should scale with width rather than staying in a phone-sized layout

Compact layouts keep the current list and existing grid toggle behavior.

### Discover

Discover should follow the same adaptive rules as Home:

- Wider content rhythm
- Section cards that can flow into two or more columns where appropriate
- Summary metrics presented without feeling compressed into phone proportions

Compact layouts keep the current mobile structure.

### Player

Player should shift from vertical stacking to a split composition on wide screens:

- Left column: cover art, waveform, primary playback controls
- Right column: progress, queue, chapter access, timer, speed, and related metadata

This keeps the current information architecture but makes large screens meaningfully useful.

Compact layouts keep the current vertically stacked experience.

### Reader

Reader should be enhanced carefully instead of being fully re-architected.

Wide layouts:

- Keep the reading surface centered with a controlled maximum width
- Improve access to table of contents, settings, and note-related tools through wider drawers or side panels where possible
- Avoid over-expanding line length for text content

Compact layouts:

- Keep the current drawer and overlay-first interactions

For this iteration, reader routing remains push-based and does not become a persistent split-view detail experience.

## Routing and State

The adaptive work should remain layout-focused.

- Keep the current `GoRouter` route structure
- Keep the existing shell branch model
- Keep existing Riverpod providers and feature controllers unchanged where possible
- Do not create separate tablet-specific navigation state

This reduces regression risk and keeps the change set reviewable.

## Fallback Rules

Layout changes should depend only on available width.

- If width is below the shared threshold, use compact layout
- If width is above the threshold, use sidebar shell and expanded screen compositions
- If a screen cannot usefully expand, it should limit content width instead of stretching edge to edge

This rule set ensures iPad full-screen, split-screen, and Stage Manager resizing all behave predictably.

## Implementation Notes

Planned refactoring sequence:

1. Add adaptive layout primitives and shared constants
2. Refactor `AppShell` to support compact and wide navigation shells
3. Migrate Home, Bookshelf, Discover, and Player to shared wide-layout helpers
4. Add controlled wide-layout treatment to Reader
5. Add widget tests for shell switching and at least one adapted page layout

Likely new code areas:

- `lib/app/adaptive/...`
- updates in `lib/features/navigation/presentation/app_shell.dart`
- targeted screen refactors in Home, Bookshelf, Discover, Player, and Reader

## Testing Strategy

Before calling the work complete, verify both layout behavior and regressions.

Planned validation:

- Widget test for `AppShell` compact vs wide navigation behavior
- Widget test for at least one core screen wide layout, preferably Bookshelf or Home
- Existing phone-oriented widget tests should keep passing
- Run `flutter analyze`
- Run `flutter test`

## Risks and Mitigations

### Risk: layout logic becomes fragmented

Mitigation:
Centralize breakpoints and shared layout helpers before changing page compositions.

### Risk: iPad full-screen works but split-screen regresses

Mitigation:
Make layout decisions width-based only, and test narrow and wide sizes explicitly.

### Risk: reader becomes harder to use on tablet

Mitigation:
Preserve the current reader interaction model as the fallback and keep reading width constrained.

### Risk: shell rewrite affects navigation behavior

Mitigation:
Do not change route topology; only swap the surrounding presentation shell.

## Recommended Scope for This Iteration

Ship the adaptive foundation and the first-pass iPad treatment for:

- App shell
- Home
- Bookshelf
- Discover
- Player
- Reader

Leave secondary screens on the compact layout unless they naturally benefit from shared container changes.

## Acceptance Criteria

- The app uses a sidebar-driven shell on wide iPad layouts
- The app falls back cleanly to compact layouts in narrow split-screen widths
- Core screens no longer look like stretched phone pages on iPad
- Reader content remains comfortably readable on large screens
- Existing route behavior and business state continue to work
