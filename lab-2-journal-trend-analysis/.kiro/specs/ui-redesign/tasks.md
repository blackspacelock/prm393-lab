# Implementation Plan: Journal Trend Analyzer — UI Redesign

## Overview

Transform 5 existing Flutter screens from generic Material widgets to a polished design that faithfully matches the HTML prototypes. Work proceeds layer by layer: design tokens first, then shared widgets, then each screen in dependency order. All color, spacing, and typography values must be consumed from `lib/core/theme/` token files — no hardcoded hex or magic numbers in widget files.

The existing data/, domain/, and providers layers are untouched. Only `lib/core/theme/`, `lib/core/router/app_router.dart`, `lib/presentation/screens/`, and `lib/presentation/widgets/` are modified.

Reference documents:
- Design spec: `documents/Design.md`
- Requirements spec: `documents/Requirements.md`

---

## Tasks

- [ ] 1. Create design token files in `lib/core/theme/`
  - Create `lib/core/theme/app_colors.dart` — define all color constants as static `const Color` fields matching the HTML palette exactly:
    - `primary = Color(0xFF005BBF)`, `primaryContainer = Color(0xFF1A73E8)`, `onPrimary = Color(0xFFFFFFFF)`
    - `secondaryContainer = Color(0xFFB2C9FE)`, `onSecondaryContainer = Color(0xFF3D5481)`
    - `surface = Color(0xFFF9F9FF)`, `surfaceContainerLowest = Color(0xFFFFFFFF)`
    - `surfaceContainer = Color(0xFFECEDF7)`, `surfaceContainerHigh = Color(0xFFE6E8F2)`, `surfaceContainerHighest = Color(0xFFE0E2EC)`
    - `onSurface = Color(0xFF191C23)`, `onSurfaceVariant = Color(0xFF414754)`
    - `outline = Color(0xFF727785)`, `outlineVariant = Color(0xFFC1C6D6)`
    - `rankGold = Color(0xFFFDD835)`, `rankSilver = Color(0xFFB0BEC5)`, `rankBronze = Color(0xFFFFAB40)`
    - `citationChipBg = Color(0xFFE8F0FE)`, `citationChipText = Color(0xFF1A3E8E)`
  - Create `lib/core/theme/app_text_styles.dart` — define all `TextStyle` constants using `GoogleFonts.roboto(...)`:
    - `headlineLarge` (24sp/w500), `headlineMedium` (20sp/w500), `headlineSmall` (18sp/w500)
    - `titleLarge` (16sp/w500), `titleMedium` (14sp/w500)
    - `bodyLarge` (16sp/w400), `bodyMedium` (14sp/w400), `bodySmall` (13sp/w400)
    - `labelLarge` (13sp/w500), `labelMedium` (12sp/w500), `labelSmall` (11sp/w400)
  - Create `lib/core/theme/app_dimensions.dart` — define spacing (xs=4, sm=8, md=12, base=16, lg=20, xl=24, xxl=32) and shape (xs=4, sm=8, md=12, full=100) as static `const double` fields
  - Update `lib/core/theme/app_theme.dart` to build `ThemeData` using only the new token files:
    - Set `colorScheme` with exact token colors (no `fromSeed`, use explicit `ColorScheme` constructor)
    - Set `textTheme` from `AppTextStyles` constants
    - Configure `NavigationBarThemeData` with `indicatorColor: AppColors.secondaryContainer`, `labelTextStyle`, and icon colors
    - Configure `AppBarTheme` with `backgroundColor: AppColors.surfaceContainerLowest`, `titleTextStyle: AppTextStyles.headlineSmall`
    - Configure `CardTheme` with `elevation: 0`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.shapeMd))`, `color: AppColors.surfaceContainerLowest`
    - Configure `InputDecorationTheme` for the pill search bar shape
    - Configure `ChipThemeData` with correct selected/unselected colors from tokens
  - _Requirements: NFR-05 (token files), Design.md §2 (color palette, typography, spacing, shape)_

- [ ] 2. Update Bottom Navigation Bar in `lib/core/router/app_router.dart`
  - Replace the `NavigationBar` inside `_ScaffoldWithNav.build()` with a version that:
    - Uses 4 destinations: Search (`Icons.search`), Trends (`Icons.show_chart`), Dashboard (`Icons.dashboard`), Top Papers (`Icons.emoji_events`)
    - Sets `selectedIndex` and `onDestinationSelected` (existing logic is correct — keep it)
    - Sets `backgroundColor: AppColors.surfaceContainerLowest`
    - Sets `indicatorColor: AppColors.secondaryContainer` (active pill bg)
    - Active icon/label color: `AppColors.primaryContainer` (`#1A73E8`)
    - Inactive icon/label color: `AppColors.onSurfaceVariant`
    - Uses `selectedIcon` + `icon` on each `NavigationDestination` to toggle filled/outline variants (e.g., `Icons.search` for both — Material Icons uses the same name but theme drives fill)
    - Adds a top border: 0.5px `AppColors.outlineVariant` using `DecoratedBox` wrapping the bar
  - _Requirements: FR-01–FR-07 (navigation shell), NFR-03 (active tab indicator), Design.md §4.1_

- [ ] 3. Rebuild shared widget: `lib/presentation/widgets/publication_card.dart`
  - Replace card-with-elevation style with flat divider-separated list row:
    - Remove `Card` wrapper; use `InkWell` directly on a `Container` with no elevation
    - Layout: 16dp horizontal padding, 14dp vertical padding
    - Row structure: `[content column] [spacer] [star icon + citation count column]`
    - Title: `AppTextStyles.titleLarge`, `AppColors.onSurface`, max 2 lines
    - Journal name (if present): `AppTextStyles.bodySmall`, `AppColors.onSurfaceVariant`, 8dp below title, max 1 line
    - Metadata row (8dp below journal): year chip + citation chip side by side using `AppColors.surfaceContainerHigh` bg + `AppColors.onSurfaceVariant` text, `AppDimensions.shapeXs` radius, 11sp
    - Right side: `Icons.star_outline` (20dp, `AppColors.onSurfaceVariant`) above citation count (`AppTextStyles.labelMedium`, `AppColors.onSurfaceVariant`)
    - Bottom divider: `Divider(height: 1, indent: AppDimensions.base, endIndent: AppDimensions.base, color: AppColors.outlineVariant)`
  - _Requirements: FR-01 (result card fields), NFR-03 (touch target 48dp), Design.md §5 Screen 1_

- [ ] 4. Rebuild shared widget: `lib/presentation/widgets/shimmer_loader.dart`
  - Update skeleton anatomy to match HTML prototype for a list item:
    - Use `AppColors.surfaceContainerHigh` as shimmer base color
    - Use `AppColors.surfaceContainerHighest` as shimmer highlight color
    - Each skeleton item: full-width container, 16dp padding, no card elevation
    - Inner layout: title bar (140dp × 14dp, radius 4dp) → journal bar (100dp × 12dp, radius 4dp, 8dp gap) → chip row (60dp + 80dp × 10dp, radius 4dp, 8dp gap)
    - Separate skeleton items with the same `Divider` style as the real `PublicationCard`
    - Keep configurable `itemCount` parameter (default 4)
    - Add `semanticsLabel: 'Loading...'` on the `Shimmer` widget for accessibility
  - _Requirements: NFR-03 (shimmer skeleton loading state), Design.md §4.9_

- [ ] 5. Rebuild shared widget: `lib/presentation/widgets/ranked_list_tile.dart`
  - Replace rank number text with a `CircleAvatar`-based rank badge (36dp):
    - Rank 1: `AppColors.rankGold` bg, dark text (`Color(0xFF4A3900)`)
    - Rank 2: `AppColors.rankSilver` bg, dark text (`Color(0xFF2C3A40)`)
    - Rank 3: `AppColors.rankBronze` bg, dark text (`Color(0xFF4E2900)`)
    - Rank 4+: `AppColors.surfaceContainerHigh` bg, `AppColors.onSurfaceVariant` text
    - Badge font: `AppTextStyles.titleMedium` (14sp/w500)
  - Progress bar: 80dp wide × 6dp tall, `AppColors.surfaceContainerHigh` track, `AppColors.primaryContainer` fill, radius 3dp
  - Title: `AppTextStyles.bodyMedium` w500, `AppColors.onSurface`, max 2 lines
  - Subtitle: `AppTextStyles.bodySmall`, `AppColors.onSurfaceVariant`
  - Count label: right-aligned, `AppTextStyles.labelMedium`, `AppColors.primaryContainer`
  - Horizontal padding 16dp, vertical 10dp
  - _Requirements: FR-03 (top journals/authors list), FR-04 (rank badges), Design.md §4.7, §4.13_

- [ ] 6. Create new shared widget: `lib/presentation/widgets/author_chip.dart`
  - `AuthorChip` is a pill (`AppDimensions.shapeFull` radius) with:
    - Left: 32dp circle avatar (`AppColors.citationChipBg` bg), initials in `AppColors.citationChipText`, 13sp/w500, max 2 chars computed from `displayName`
    - Right: author name text (`AppTextStyles.bodySmall`, `AppColors.onSurface`), 8dp gap from avatar
    - Container: 40dp height, `AppColors.surfaceContainerLowest` bg, 1dp border `AppColors.outlineVariant`, `ContentPadding(left: 4, top: 4, right: 12, bottom: 4)`
    - Constructor takes `String displayName`
    - Helper: extract initials by splitting on space, taking first char of first and last word, uppercase
  - _Requirements: FR-02 (author chips on detail screen), Design.md §4.5 (author chip), §4.8 (avatar)_

- [ ] 7. Create new shared widget: `lib/presentation/widgets/empty_state.dart`
  - `EmptyState` widget with:
    - Centered column layout
    - `IconData icon` parameter (default `Icons.find_in_page`)
    - 48dp icon, `AppColors.onSurfaceVariant`
    - `String message` text, `AppTextStyles.bodyMedium`, `AppColors.onSurfaceVariant`, centered, max 2 lines
    - Optional `String? actionLabel` + `VoidCallback? onAction` — shows an outlined pill button if both are provided using `AppColors.primaryContainer` border/text
    - 16dp gaps between elements
  - _Requirements: NFR-03 (empty state with icon + message + action), Design.md §5 Screen 1_

- [ ] 8. Create new shared widget: `lib/presentation/widgets/error_state.dart`
  - `ErrorState` widget with:
    - Centered column layout
    - `Icons.error_outline` icon (48dp, `Colors.red`)
    - `String message` parameter for human-readable error text (`AppTextStyles.bodyMedium`)
    - `VoidCallback onRetry` parameter — filled pill retry button (`AppColors.primaryContainer` bg, white text, `AppDimensions.shapeFull`)
    - 24dp horizontal padding, 16dp gaps between elements
  - _Requirements: NFR-02 (retry mechanism on all error states), FR-01 (retry on search error)_

- [ ] 9. Update shared widget: `lib/presentation/widgets/metric_card.dart`
  - Rebuild to match KPI mini-card spec:
    - Container with: `AppColors.surfaceContainerLowest` bg, 1dp border `AppColors.outlineVariant`, `AppDimensions.shapeMd` radius, 14dp padding
    - Top: 20dp icon using `iconColor` param (default `AppColors.primaryContainer`)
    - Value: 22sp/w500 `AppColors.onSurface` (use `AppTextStyles.headlineMedium` font size overridden to 22sp)
    - Label: `AppTextStyles.labelMedium`, `AppColors.onSurfaceVariant`
    - No `Card` widget — use a plain `DecoratedBox` / `Container` so elevation is 0
    - Keep existing constructor signature: `title`, `value`, `icon`, `iconColor`
  - _Requirements: FR-07 (2×2 KPI grid), Design.md §4.4 (metric mini-card)_

- [ ] 10. Checkpoint — Verify token files and shared widgets compile cleanly
  - Run `flutter analyze lib/core/theme/ lib/presentation/widgets/` and resolve all warnings or errors before proceeding to screen rewrites.
  - Ensure all new/updated widgets import only from `lib/core/theme/` for colors, text styles, and dimensions — no raw `Color(0xFF...)` literals or magic numbers.

- [ ] 11. Redesign `lib/presentation/screens/search_screen.dart`
  - Replace the existing inline `_EmptyState` and `_ErrorState` private classes with the new shared `EmptyState` and `ErrorState` widgets from step 7–8
  - App bar: keep `title: const Text('Journal Trend Analyzer')` but add `leading: const Icon(Icons.analytics, color: AppColors.onSurfaceVariant)` and `actions: [IconButton(icon: Icon(Icons.tune), ...)]`; set `backgroundColor: AppColors.surfaceContainerLowest`; `elevation: 0`, `scrolledUnderElevation: 1`
  - Search bar: update `TextField` decoration to use `fillColor: AppColors.surfaceContainer`, `borderRadius: BorderRadius.circular(AppDimensions.shapeFull)`, `prefixIcon: Icon(Icons.search, size: 20)` — relies on `InputDecorationTheme` from updated `AppTheme`
  - Topic chips: update `_suggestions` list to: `['AI', 'Software Engineering', 'Data Science', 'Cybersecurity', 'IoT', 'Blockchain']`; style `FilterChip` using theme (selected: `AppColors.secondaryContainer` bg, `AppColors.onSecondaryContainer` label; unselected: `AppColors.surfaceContainerHighest` bg, `AppColors.onSurfaceVariant` label, 1dp border `AppColors.outlineVariant`); chip height 32dp, `AppDimensions.shapeSm` radius
  - Results label: add a `Text` row above the list when `pubs.isNotEmpty`: `"Results for '$query' · ${pubs.length} papers"`, `AppTextStyles.bodySmall`, `AppColors.onSurfaceVariant`, left-padded 16dp
  - List: replace `ListView.builder` wrapping `PublicationCard` — the updated `PublicationCard` already handles dividers, so just call it directly with no extra wrapping
  - Empty state: use `EmptyState(icon: Icons.find_in_page, message: ...)` — pass `actionLabel: 'Clear'` + `onAction` that clears the query when query is non-empty
  - Error state: use `ErrorState(message: ..., onRetry: ...)` 
  - Keep all existing provider reads (`searchQueryProvider`, `publicationsProvider`) and the `ref.listen` error snackbar unchanged
  - _Requirements: FR-01 (search UI, chips, result count, empty/error states), NFR-03 (48dp touch targets), Design.md §5 Screen 1_

- [ ] 12. Redesign `lib/presentation/screens/publication_detail_screen.dart`
  - App bar: `leading: BackButton(color: AppColors.primaryContainer)`, title `'Publication Details'`, `actions: [IconButton(Icons.share), IconButton(Icons.bookmark_border)]`, `backgroundColor: AppColors.surfaceContainerLowest`
  - Hero title: `AppTextStyles.headlineMedium`, `AppColors.onSurface`, max 3 lines, 16dp top padding
  - Metadata pills row (wrap): year chip (`AppColors.surfaceContainerHigh` bg, `AppColors.onSurfaceVariant` text), journal chip (same style), DOI tappable chip (`AppColors.citationChipBg` bg, `AppColors.primaryContainer` text, `Icons.open_in_new` trailing, 16dp, calls `_openDoi`)
  - Citation card: full-width `Container`, `AppColors.citationChipBg` bg, 12dp radius, 16dp padding, row with `Icons.emoji_events` (24dp, `AppColors.primaryContainer`) + citation count (24sp/w500, `AppColors.onSecondaryContainer`) + "citations" label
  - Authors section: `Text('Authors', style: AppTextStyles.titleLarge)`, then `SingleChildScrollView(scrollDirection: Axis.horizontal)` containing a `Row` of `AuthorChip` widgets (from step 6), 8dp gap between chips
  - Abstract section: implement 4-line clamp with gradient fade + "Show more / Show less" toggle using a `StatefulWidget` inner widget or `ValueNotifier`; body text: `AppTextStyles.bodyLarge`, `AppColors.onSurface`; gradient: `AppColors.surfaceContainerLowest` transparent to opaque; "Show more" text: `AppTextStyles.labelLarge`, `AppColors.primaryContainer`
  - Research topics: `Text('Research Topics')` header + `Wrap` of flat chips (`AppColors.surfaceContainerHigh` bg), max 10 concepts
  - Stats row: 3 equal `Expanded` mini-cards in a `Row` (year, authors count, journal name), each: label on top (`AppTextStyles.labelSmall`, `AppColors.onSurfaceVariant`), value below (`AppTextStyles.titleMedium`, `AppColors.onSurface`), `AppColors.surfaceContainer` bg, `AppDimensions.shapeSm` radius, 12dp padding; 8dp gap between cards
  - Sticky CTA bottom bar: wrap `Scaffold.bottomNavigationBar` with a `Container` (72dp, `AppColors.surfaceContainerLowest`, top border `AppColors.outlineVariant`): full-width pill `ElevatedButton` "Open paper" using `AppColors.primaryContainer` bg + `AppColors.onPrimary` text + `Icons.open_in_new`; DOI url as `Text` below in `AppTextStyles.labelSmall`, `AppColors.onSurfaceVariant`; hide CTA if `doi == null`
  - Keep `_openDoi()` logic unchanged
  - Replace old `_InfoRow` private widget with the new structured layout (no longer needed)
  - _Requirements: FR-02 (all detail fields, DOI CTA, share, authors chips, abstract), Design.md §5 Screen 2_

- [ ] 13. Redesign `lib/presentation/screens/trend_analysis_screen.dart`
  - App bar: title `'Trend Analysis'`, `actions: [IconButton(Icons.date_range), IconButton(Icons.share)]`, `backgroundColor: AppColors.surfaceContainerLowest`
  - Sticky topic context bar (44dp): `Container` pinned below app bar using `SliverAppBar` or `CustomScrollView` with a `SliverPersistentHeader`; contains: `Text('Topic:', style: AppTextStyles.labelMedium, color: AppColors.onSurfaceVariant)` + active topic chip (`AppColors.secondaryContainer` bg, `AppColors.onSecondaryContainer` text) + `Spacer()` + paper count (`AppTextStyles.labelSmall`, `AppColors.onSurfaceVariant`); topic chip reads from `searchQueryProvider`; if query is empty, hide the bar
  - Bar chart card: wrap `TrendChart` in a `Container` with `AppColors.surfaceContainerLowest` bg, 1dp border `AppColors.outlineVariant`, `AppDimensions.shapeMd` radius; add section header `'Publications per year'` (`AppTextStyles.titleLarge`) inside the card with 16dp padding; chart height stays 180dp
  - Update `TrendChart` widget (`lib/presentation/widgets/trend_chart.dart`) to use design tokens: bar color `AppColors.primaryContainer`, tooltip bg `AppColors.onSurface`, axis label style `AppTextStyles.labelSmall` in `AppColors.onSurfaceVariant`, grid line color `AppColors.surfaceContainerHigh`
  - Top Journals section: add `'Top Journals'` header (`AppTextStyles.titleLarge`, 16dp padding); the updated `RankedListTile` from step 5 provides correct badges and progress bars automatically
  - Top Authors section: same header pattern; pass `AuthorChip` (or just initials `CircleAvatar`) as `leading` to `RankedListTile`; compute initials the same way as existing code
  - Empty state: use new `EmptyState` widget with `Icons.show_chart` icon and message `'Search for a topic to see trends'`
  - Error state: use new `ErrorState` widget
  - Keep all existing provider reads unchanged
  - _Requirements: FR-03 (bar chart, top journals, top authors), FR-05, FR-06, Design.md §5 Screen 3_

- [ ] 14. Redesign `lib/presentation/screens/dashboard_screen.dart`
  - App bar: `leading: Icon(Icons.analytics)`, title `'Research Dashboard'`, `actions: [IconButton(Icons.refresh), IconButton(Icons.more_vert)]`, `backgroundColor: AppColors.surfaceContainerLowest`
  - Hero topic card: full-width `Container`, `AppColors.primaryContainer` bg, `AppDimensions.shapeMd` radius, 16dp padding; left column: topic name (`AppTextStyles.headlineLarge`, white), growth % subtitle (white muted); right: 80dp height `_Sparkline` using white color override; reads topic from `searchQueryProvider`; compute YoY growth % from `dashboardSummaryProvider.sparklineData` (last 2 years); show `'Search a topic to begin'` placeholder if query is empty
  - KPI 2×2 grid: use existing `MetricCard` (updated in step 9), `CrossAxisCount: 2`, `childAspectRatio: 1.3`, `crossAxisSpacing: 10`, `mainAxisSpacing: 10`; update the 4 metric icons/colors to match design: total publications (`Icons.article`, `AppColors.primaryContainer`), avg citations (`Icons.format_quote`, `Color(0xFFFF6D00)`), most active year (`Icons.calendar_today`, `Color(0xFF1E8E3E)`), YoY growth (`Icons.trending_up`, `Color(0xFF9C27B0)`)
  - Most Influential Paper card: replace existing `Card` with a left-accent card — `Container` with `AppColors.surfaceContainerLowest` bg, 1dp border `AppColors.outlineVariant`, `AppDimensions.shapeMd` radius, plus a 4dp wide `AppColors.primaryContainer` left bar (use `Stack` or `DecoratedBox` with `BoxDecoration.border` on left only); inside: `Icons.emoji_events` (20dp, `AppColors.primaryContainer`) + paper title (`AppTextStyles.titleLarge`, max 3 lines) + citation chip (`AppColors.citationChipBg` bg, `AppColors.citationChipText`, trophy icon)
  - Top Journal + Top Author: replace with side-by-side `Row` of two equal `Expanded` cards (`AppColors.surfaceContainerLowest` bg, 1dp border, `AppDimensions.shapeMd`): left card shows journal icon + name; right card shows `AuthorChip` + name (or initials avatar + name if chip is too wide)
  - Publication trend mini-chart: `Container` card with `AppColors.surfaceContainerLowest` bg, border; header row: `Text('Publication Trend', ...)` + `TextButton('View full →', ...)` that calls `context.go('/trends')`; 80dp `_Sparkline` using `AppColors.primaryContainer` color with `AppColors.citationChipBg` area fill
  - Update `_Sparkline` to accept a `Color? lineColor` parameter so the dashboard can pass `AppColors.primaryContainer`
  - Empty state: use `EmptyState(icon: Icons.dashboard, message: 'Search for a topic to see insights')`
  - Error state: use `ErrorState`
  - Keep all existing `dashboardSummaryProvider` reads unchanged
  - _Requirements: FR-07 (hero card, KPI grid, influential paper, top journal, top author, mini chart), Design.md §5 Screen 4_

- [ ] 15. Redesign `lib/presentation/screens/top_papers_screen.dart`
  - App bar: title `'Most Influential Papers'`, `actions: [IconButton(Icons.filter_list)]`, `backgroundColor: AppColors.surfaceContainerLowest`
  - Add subtitle `Text` row directly below app bar: `"Ranked by citation count · ${query}"`, `AppTextStyles.bodySmall`, `AppColors.onSurfaceVariant`, 16dp horizontal + 8dp vertical padding; reads from `searchQueryProvider`
  - Sort filter bar (sticky 44dp): convert existing `Padding + Row + SingleChildScrollView` to a proper sticky bar using `SliverPersistentHeader` or a `Column`-pinned `Container`; add a 4th sort option `PaperSortOption.relevance` (displays as `'Relevance'` — sorts by year desc as proxy); all `ChoiceChip`s use: selected state `AppColors.secondaryContainer` bg + `AppColors.onSecondaryContainer` label + 1dp `AppColors.primaryContainer` border; unselected: `AppColors.surfaceContainerLowest` + `AppColors.onSurface` + 1dp `AppColors.outlineVariant` border; chip height 32dp, `AppDimensions.shapeSm` radius; update `providers.dart` to add `PaperSortOption.relevance` and its sort logic
  - Paper list items: replace `ListTile` with a custom row:
    - Left: updated `_RankBadge` using `AppColors.rankGold/Silver/Bronze` + correct dark text colors (matching step 5 badge spec)
    - Content: title (`AppTextStyles.bodyMedium` w500, `AppColors.onSurface`, max 2 lines) → journal (`AppTextStyles.bodySmall`, `AppColors.onSurfaceVariant`, max 1 line) → author first name et al (`AppTextStyles.labelSmall`, `AppColors.onSurfaceVariant`)
    - Right column: citation count badge (`AppColors.citationChipBg` bg, `AppColors.citationChipText`, `AppTextStyles.labelMedium`) above year badge (`AppColors.surfaceContainerHigh` bg, `AppColors.onSurfaceVariant`, `AppTextStyles.labelSmall`); 4dp gap between badges
    - Bottom divider: same as `PublicationCard` divider style
    - Tap: keeps `context.push('/publication/...', extra: pub)` unchanged
  - FAB scroll-to-top: add `ScrollController` to the `ConsumerStatefulWidget` (convert from `ConsumerWidget`); FAB with `backgroundColor: AppColors.primaryContainer`, `Icon(Icons.keyboard_arrow_up, color: AppColors.onPrimary)`, 48dp; show FAB only when `scrollController.offset > 300`; on tap, `scrollController.animateTo(0, ...)`; position 16dp from right edge using `floatingActionButton` + `floatingActionButtonLocation: FloatingActionButtonLocation.endFloat`
  - Empty state: use `EmptyState(icon: Icons.emoji_events, message: 'Search for a topic to see top papers')`
  - Error state: use `ErrorState`
  - Keep all existing provider reads unchanged
  - _Requirements: FR-04 (rank badges, sort bar, citation/year chips, FAB), Design.md §5 Screen 5_

- [ ] 16. Final checkpoint — Full app integration and polish
  - Run `flutter analyze` and fix all warnings (missing `const`, unused imports, deprecated API usage)
  - Verify no hardcoded `Color(0xFF...)` hex literals remain in any `presentation/` or `core/theme/` file outside `app_colors.dart` — use a grep search: `grep -r "Color(0x" lib/presentation/ lib/core/router/`
  - Verify no hardcoded numeric spacing or font size literals outside `app_dimensions.dart` and `app_text_styles.dart`
  - Confirm all 5 screens use `EmptyState` and `ErrorState` (no more private `_EmptyState`/`_ErrorState` classes)
  - Confirm `AuthorChip` is used in both `publication_detail_screen.dart` (authors row) and `trend_analysis_screen.dart` (top authors list)
  - Confirm `ShimmerLoader` is invoked in all 5 screens' loading branches
  - Ensure all tests pass, ask the user if questions arise.

---

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2", "3", "4", "5", "6", "7", "8", "9"] },
    { "wave": 3, "tasks": ["10"] },
    { "wave": 4, "tasks": ["11", "12", "13", "14", "15"] },
    { "wave": 5, "tasks": ["16"] }
  ]
}
```

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster iteration — none in this plan are marked optional since this is purely a UI redesign with no logic changes
- Tasks 1–9 (token files + shared widgets) must be completed before any screen rewrite — screens depend on these widgets and tokens
- Tasks 11–15 (screen rewrites) can be done in any order after task 10 completes, but 12 depends on `AuthorChip` (task 6) being done first
- The `data/`, `domain/`, and `providers/` layers are completely off-limits — all providers, entities, use cases, repositories, and API client code stays unchanged
- The only change to `providers.dart` allowed is adding `PaperSortOption.relevance` (task 15)
- Dark mode token mapping (Design.md §8) is out of scope for this task — the app uses light theme only
- `trend_chart.dart` is updated as part of task 13 (not a separate task) since it is tightly coupled to the Trend Analysis screen
