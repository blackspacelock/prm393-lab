# Task List — UI Update & Additional Pages

Based on `requirements.md` (FR-01 through FR-04).

---

## Current State

- 6-tab bottom navigation: Trending, Search, Dashboard, Heatmap, Network, Saved
- Router: `lib/core/router/app_router.dart` (ShellRoute + NavigationBar)
- Screens: `lib/presentation/screens/`

## Target State

- 4-tab bottom navigation: **Home**, **Journals**, **Keywords**, **Profile**

---

## Tasks

### Task 1 — Restructure Bottom Navigation to 4 Tabs (FR-01)

**Goal:** Replace the current 6-tab NavigationBar with a 4-tab layout: Home, Journals, Keywords, Profile.

**Changes:**
- In `app_router.dart`, update `_ScaffoldWithNav` to have 4 `NavigationDestination` items:
  - Home (icon: `Icons.home_outlined` / `Icons.home`) → route `/home`
  - Journals (icon: `Icons.menu_book_outlined` / `Icons.menu_book`) → route `/journals`
  - Keywords (icon: `Icons.search_outlined` / `Icons.search`) → route `/keywords`
  - Profile (icon: `Icons.person_outlined` / `Icons.person`) → route `/profile`
- Update `initialLocation` to `/home`
- Update `_selectedIndex` logic for the new 4 routes
- Update `onDestinationSelected` switch for 4 tabs
- Keep the `/publication/:id` route as-is

**Files:**
- `lib/core/router/app_router.dart`

---

### Task 2 — Rename Trending → Home (FR-01)

**Goal:** The current "Trending" page becomes the "Home" page.

**Changes:**
- Rename the route from `/trending` to `/home` in the router
- Update `TrendingScreen` AppBar title from `'All Trending'` to `'Home'` (or keep trending content, just change the navigation label)
- Optionally rename the file/class for clarity (not strictly required)

**Files:**
- `lib/core/router/app_router.dart`
- `lib/presentation/screens/trending_screen.dart`

---

### Task 3 — Create Journals Page (FR-03)

**Goal:** Create a new "Journals" page that displays a searchable, filterable list of journals.

**Changes:**
- Create `lib/presentation/screens/journals_screen.dart`
- Include a search bar at the top for searching journal names
- Include a filter button (similar to existing filter patterns)
- Display a list of journals (from API/data source)
- Each journal item is clickable → navigates to a journal detail page
- Create `lib/presentation/screens/journal_detail_screen.dart` with 2 tab bars:
  - **Authors list** tab: shows authors who have papers in this journal (clickable → shows author's papers, similar to Author Network node click)
  - **Paper list** tab: shows papers belonging to the journal (50 results at a time + "Show more" button for next 50)
- Register routes: `/journals` and `/journals/:id`

**Files:**
- `lib/presentation/screens/journals_screen.dart` (new)
- `lib/presentation/screens/journal_detail_screen.dart` (new)
- `lib/core/router/app_router.dart`
- Domain/data layers as needed for journal data

---

### Task 4 — Create Integrated Keywords Page with Tabs (FR-04)

**Goal:** The current "Search" page becomes "Keywords" and integrates Dashboard, Heatmap, and Network as tabs.

**Changes:**
- Create `lib/presentation/screens/keywords_screen.dart` (or refactor `search_screen.dart`)
- The Keywords page has:
  - Search bar at top
  - Buttons row below the search bar (Topic Hierarchy, Filter) — see Task 5
  - A `TabBar` with 4 tabs below the buttons:
    1. **Keywords** (the current search results content)
    2. **Dashboard** (current `TrendAnalysisScreen` content)
    3. **Heatmap** (current `HeatmapScreen` content)
    4. **Network** (current `AuthorNetworkScreen` content)
- Route: `/keywords`
- Remove old standalone routes `/search`, `/dashboard`, `/heatmap`, `/network`

**Files:**
- `lib/presentation/screens/keywords_screen.dart` (new or refactored)
- `lib/presentation/screens/search_screen.dart` (refactor into tab content)
- `lib/presentation/screens/trend_analysis_screen.dart` (embed as tab)
- `lib/presentation/screens/heatmap_screen.dart` (embed as tab)
- `lib/presentation/screens/author_network_screen.dart` (embed as tab)
- `lib/core/router/app_router.dart`

---

### Task 5 — Move Buttons Below Search/AppBar (FR-02)

**Goal:** Relocate top-corner buttons to below the search bar as visible, labeled buttons.

**Changes:**

1. **Keywords page (formerly Search):**
   - Remove the hamburger menu icon from AppBar leading
   - Remove the filter icon from AppBar actions
   - Below the search bar, add a row with two buttons:
     - `[icon] Topic Hierarchy` button (opens topic hierarchy drawer/modal)
     - `[icon] Filter` button (opens filter drawer/modal)

2. **Profile > Saved tab (formerly Bookmarks):**
   - Move "Clear all" button from AppBar to below the search bar
   - Move filter controls below the search bar alongside "Clear all"

3. **Keywords > Dashboard tab (formerly TrendAnalysisScreen):**
   - Move the "Filter by year range" icon button from the AppBar into the page body
   - Display as a full-width or inline button labeled `"Filter by year range"`

**Files:**
- `lib/presentation/screens/keywords_screen.dart`
- `lib/presentation/screens/bookmarks_screen.dart`
- `lib/presentation/screens/trend_analysis_screen.dart`

---

### Task 6 — Create Profile Page with Saved Tab (FR-04)

**Goal:** Create a Profile page that currently just shows the Saved/Bookmarks content.

**Changes:**
- Create `lib/presentation/screens/profile_screen.dart`
- For now, simply embed/display the `BookmarksScreen` content (Saved papers)
- Future: will add login/account customization
- Route: `/profile`
- Remove old standalone route `/bookmarks`

**Files:**
- `lib/presentation/screens/profile_screen.dart` (new)
- `lib/core/router/app_router.dart`

---

### Task 7 — Clean Up Old Routes & Navigation References

**Goal:** Remove dead routes and ensure all internal navigation references point to new paths.

**Changes:**
- Remove old route definitions (`/trending`, `/search`, `/dashboard`, `/heatmap`, `/network`, `/bookmarks`) from `app_router.dart`
- Update any `context.go(...)` or `context.push(...)` calls throughout the codebase that reference old paths
- Ensure the SearchScreen's internal navigation (e.g., topic click → search) still works within the Keywords tab
- Verify Dashboard's "search this keyword" feature navigates to Keywords tab properly

**Files:**
- `lib/core/router/app_router.dart`
- Any screen/widget files that use `context.go(...)` or `context.push(...)` with old routes

---

### Task 8 — Verify Build & Test

**Goal:** Ensure the app compiles and runs without errors after all changes.

**Steps:**
- Run `flutter analyze` to check for lint/static errors
- Run `flutter build apk --debug` or `flutter run` to verify compilation
- Manually verify navigation between all 4 tabs
- Verify Keywords tab switching between Keywords/Dashboard/Heatmap/Network sub-tabs
- Verify Journal search, detail page, Authors/Papers tabs
- Verify Profile page shows saved papers

---

## Execution Order

Complete tasks in order (1 → 8). Tasks 2–6 depend on Task 1's navigation structure. Task 7 is cleanup. Task 8 is verification.
