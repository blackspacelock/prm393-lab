# REQUIREMENTS.md — Journal Trend Analyzer

> **Version:** 1.0.0  
> **Last updated:** 2026-06-02  
> **Course:** PRM393 – Mobile Programming  
> **Assignment:** Lab 2 — Journal Trend Analysis Mobile Application

---

## 1. Project Overview

**Journal Trend Analyzer** is a Flutter-based Android mobile application that enables users to explore academic research publication trends by querying the OpenAlex API. The app provides interactive analytics, visualizations, and dashboards derived entirely from live API data.

### 1.1 Goals

- Enable users to search and browse research publications by keyword or topic
- Visualize publication trends over time through charts and rankings
- Surface key research insights (top journals, authors, papers) in a consumable dashboard
- Demonstrate clean Flutter architecture, API integration, and data visualization skills

### 1.2 Out of Scope

The following features are explicitly excluded:

- Custom backend services or REST APIs
- User authentication, login, registration, or role-based access
- Database design or deployment
- Cloud data persistence or real-time sync
- Push notifications
- Payment processing
- Social features (comments, likes, sharing)
- Administrative dashboards
- Machine learning model training or deployment
- Web application development
- Hard-coded or mock datasets (all data must come from OpenAlex API)

---

## 2. Stakeholders

| Role | Responsibility |
|---|---|
| Developer (student) | Design, implement, test, and document the application |
| Lecturer / Assessor | Review code quality, functionality, and documentation |
| End user | Research students or academics exploring publication trends |

---

## 3. Functional Requirements

### FR-01 — Topic Search

**Priority:** Must have

The application shall allow users to search for research publications by entering a keyword or selecting a predefined topic chip.

**Acceptance criteria:**
- A text input field accepts free-text keyword entry
- Predefined topic chips (Artificial Intelligence, Software Engineering, Data Science, Cybersecurity, Internet of Things, Blockchain) provide one-tap shortcuts
- On search submission, the app queries OpenAlex and displays a paginated list of results
- Each result card shows: publication title, publication year, journal name, citation count
- A result count label is displayed above the list (e.g., "2,847 papers found")
- An empty state is shown when no results are returned
- A loading skeleton state is shown while the API call is in progress
- Errors (network failure, timeout) display a user-facing error message with a retry option

**OpenAlex endpoint:** `GET /works?search={query}&per_page=50&sort=cited_by_count:desc`

---

### FR-02 — Publication Detail View

**Priority:** Must have

The application shall provide a full-detail screen for each publication accessible from the search results list.

**Acceptance criteria:**
- Tapping a result card navigates to the Publication Detail Screen
- The detail screen displays: full paper title, all author names, publication year, journal name, citation count, DOI (tappable — opens browser), abstract (when available)
- Abstract is reconstructed from OpenAlex's `abstract_inverted_index` field
- Authors are displayed as scrollable avatar chips with initials
- A "Open paper (DOI)" CTA button opens the DOI URL in the system browser
- A share icon in the app bar allows sharing the paper title + DOI

**OpenAlex fields used:** `id`, `title`, `publication_year`, `cited_by_count`, `doi`, `primary_location.source.display_name`, `authorships[].author.display_name`, `abstract_inverted_index`, `concepts[].display_name`

---

### FR-03 — Publication Trend Analysis

**Priority:** Must have

The application shall visualize publication activity over time grouped by year.

**Acceptance criteria:**
- A bar chart displays publication count per year (x: year, y: count)
- The chart covers at least the most recent 10 years of data
- Tapping a bar shows a tooltip with the exact year and count
- A trend line (dashed, secondary color) overlays the bar chart
- Below the chart, a ranked list of **Top 5 journals** is shown with proportional count bars
- Below journals, a ranked list of **Top 5 contributing authors** is shown with avatar initials, institution (if available), and paper count
- All data is derived from the current search query's result set

**Data derivation:**
- Group publications by `publication_year`, count per year
- Group by `primary_location.source.display_name`, count per journal
- Group by `authorships[].author.display_name`, count per author

---

### FR-04 — Top Influential Papers

**Priority:** Must have

The application shall display a ranked list of the most-cited publications for the current search topic.

**Acceptance criteria:**
- Papers are sorted by `cited_by_count` descending
- Rank #1, #2, #3 display gold, silver, bronze medal badges respectively
- Ranks 4+ display a numbered circle badge
- Each list item shows: rank badge, paper title (max 2 lines), first author et al., journal name, citation count, publication year
- A sticky sort bar allows switching between: Citation Count (default), Publication Year, A–Z Title
- A floating scroll-to-top button appears after scrolling past the first screen height

---

### FR-05 — Top Research Journals

**Priority:** Must have

The application shall identify journals that publish the most papers for the selected topic.

**Acceptance criteria:**
- Top 5 journals are presented in the Trend Analysis screen as a ranked list
- Each row shows: rank number, journal name, paper count, proportional horizontal bar
- Data is derived from the current search result set (no separate API call required)

---

### FR-06 — Top Contributing Authors

**Priority:** Must have

The application shall identify authors with the highest publication counts for the selected topic.

**Acceptance criteria:**
- Top 5 authors are presented in the Trend Analysis screen as a ranked list
- Each row shows: rank number, author name, institution (if available), initials avatar, paper count
- Data is derived from the current search result set

---

### FR-07 — Research Trend Dashboard

**Priority:** Must have

The application shall provide a summary dashboard of key research insights for the selected topic.

**Acceptance criteria:**
- Dashboard displays a hero card with the current topic name and a sparkline chart
- A 2×2 KPI grid shows: Total Publications, Average Citation Count, Most Active Year, Year-over-Year Growth %
- A "Most Influential Paper" card shows the top-cited paper's title, journal, and citation count with a left-color accent
- A "Top Journal" mini-card shows the journal name and paper count
- A "Top Author" mini-card shows the author name, initials avatar, and paper count
- A mini area chart provides a compact trend preview with a "View full" link to the Trends tab
- All values update whenever the search topic changes

---

## 4. Non-Functional Requirements

### NFR-01 — Performance

- Initial search results must appear within 3 seconds on a standard 4G connection
- Chart rendering must complete within 500ms of data availability
- The app must not block the main thread during API calls or JSON parsing (all async)

### NFR-02 — Reliability & Error Handling

- All API calls must be wrapped in try/catch with typed exception handling
- Network errors, HTTP error codes (4xx, 5xx), and timeout errors must each produce distinct user-facing messages
- A retry mechanism must be available on all error states
- Partial data (e.g., missing abstract, missing journal name) must be handled gracefully with fallback labels ("Abstract not available", "Unknown journal")

### NFR-03 — Usability

- Minimum touch target size: 48dp for all interactive elements
- Loading states must be communicated through shimmer skeletons (not spinners alone)
- Empty states must include an illustrative message and a primary action (clear or retry)
- Navigation must always show the user's current location via the active bottom nav tab

### NFR-04 — Compatibility

- Target platform: Android
- Minimum SDK: API 21 (Android 5.0 Lollipop)
- Target SDK: API 34 (Android 14)
- Must run on Android emulator and physical Android devices
- Flutter SDK: stable channel, version ≥ 3.19.0
- Dart SDK: ≥ 3.3.0

### NFR-05 — Maintainability

- Code must follow the three-layer repository pattern (Data / Domain / Presentation)
- SOLID principles must be applied throughout:
  - **S** — Each class has a single responsibility
  - **O** — Features extend via new classes, not modifications
  - **L** — Repository implementations are substitutable for their interfaces
  - **I** — Service interfaces are fine-grained and specific
  - **D** — UI depends on abstract repositories, not concrete API clients
- No magic numbers or hardcoded strings in widget files
- All color, typography, and spacing values come from token files in `lib/core/theme/`

### NFR-06 — Code Quality

- An AI-assisted code review must be performed before submission using one of: SonarQube, Kodus AI, CodeRabbit, GitHub Copilot Code Review
- A minimum of 3 issues, warnings, or improvement opportunities must be identified and documented
- Evidence (screenshots + explanations) must be included in the project report

---

## 5. System Architecture

### 5.1 Architecture Pattern

**Three-layer repository pattern:**

```
┌──────────────────────────────────────────┐
│           Presentation Layer             │
│  screens/ · widgets/ · providers/        │
│  (Flutter UI, Riverpod state management) │
├──────────────────────────────────────────┤
│             Domain Layer                 │
│  entities/ · repositories/ · usecases/  │
│  (Business logic, abstract interfaces)   │
├──────────────────────────────────────────┤
│              Data Layer                  │
│  api/ · models/ · datasources/           │
│  (OpenAlex API client, JSON parsing)     │
└──────────────────────────────────────────┘
```

### 5.2 Project Structure

```
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   └── api_constants.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_dimensions.dart
│   └── utils/
│       └── formatter.dart            # Abstract reconstruction, number formatting
├── data/
│   ├── api/
│   │   └── openalex_api_client.dart  # Dio HTTP client
│   ├── models/
│   │   ├── publication_model.dart    # JSON ↔ Dart, fromJson/toJson
│   │   ├── author_model.dart
│   │   └── journal_model.dart
│   ├── datasources/
│   │   └── publication_remote_datasource.dart
│   └── repositories/
│       └── publication_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── publication.dart          # Clean entity, no JSON logic
│   │   ├── author.dart
│   │   └── journal.dart
│   ├── repositories/
│   │   └── publication_repository.dart  # Abstract interface
│   └── usecases/
│       ├── search_publications.dart
│       ├── get_top_authors.dart
│       ├── get_top_journals.dart
│       ├── get_trend_data.dart
│       └── get_dashboard_summary.dart
└── presentation/
    ├── providers/
    │   ├── search_provider.dart
    │   ├── publications_provider.dart
    │   ├── trend_provider.dart
    │   ├── dashboard_provider.dart
    │   ├── top_authors_provider.dart
    │   └── top_journals_provider.dart
    ├── screens/
    │   ├── search_screen.dart
    │   ├── publication_detail_screen.dart
    │   ├── trend_analysis_screen.dart
    │   ├── dashboard_screen.dart
    │   └── top_papers_screen.dart
    └── widgets/
        ├── publication_card.dart
        ├── metric_card.dart
        ├── trend_chart.dart
        ├── ranked_list_tile.dart
        ├── author_chip.dart
        ├── shimmer_loader.dart
        ├── empty_state.dart
        └── error_state.dart
```

### 5.3 State Management

**Library:** `flutter_riverpod` (StateNotifier + FutureProvider pattern)

| Provider | Type | Description |
|---|---|---|
| `searchQueryProvider` | `StateProvider<String>` | Current search keyword |
| `publicationsProvider` | `FutureProvider<List<Publication>>` | Raw search results, depends on `searchQueryProvider` |
| `trendDataProvider` | `Provider<Map<int, int>>` | Publications grouped by year, derived from `publicationsProvider` |
| `topAuthorsProvider` | `Provider<List<Author>>` | Top 5 authors by count, derived |
| `topJournalsProvider` | `Provider<List<Journal>>` | Top 5 journals by count, derived |
| `dashboardSummaryProvider` | `Provider<DashboardSummary>` | All KPI values, derived |
| `sortModeProvider` | `StateProvider<SortMode>` | Current sort for Top Papers (enum) |

### 5.4 Navigation

**Library:** `go_router` ≥ 13.x

```
/ (redirect → /search)
├── ShellRoute (bottom nav shell)
│   ├── /search           → SearchScreen
│   ├── /trends           → TrendAnalysisScreen
│   ├── /dashboard        → DashboardScreen
│   └── /top-papers       → TopPapersScreen
└── /publication/:id      → PublicationDetailScreen (pushed, no shell)
```

Navigation extras: `Publication` entity is passed via `go_router` `extra` parameter to the detail screen to avoid redundant API calls.

---

## 6. API Integration

### 6.1 Base Configuration

| Parameter | Value |
|---|---|
| Base URL | `https://api.openalex.org` |
| HTTP client | Dio ≥ 5.4.0 |
| Connect timeout | 15 seconds |
| Receive timeout | 15 seconds |
| Polite pool header | `mailto: student@university.edu` (recommended by OpenAlex) |

### 6.2 Endpoints Used

#### Search publications
```
GET /works
  ?search={query}
  &per_page=50
  &sort=cited_by_count:desc
  &select=id,title,publication_year,cited_by_count,doi,
          primary_location,authorships,abstract_inverted_index,concepts
```

#### Group by year (trend data)
```
GET /works
  ?search={query}
  &group_by=publication_year
  &per_page=200
```

### 6.3 JSON Field Mapping

| OpenAlex field | Entity field | Notes |
|---|---|---|
| `id` | `Publication.id` | Full URI, strip prefix for display |
| `title` | `Publication.title` | String |
| `publication_year` | `Publication.year` | int |
| `cited_by_count` | `Publication.citationCount` | int |
| `doi` | `Publication.doi` | Nullable string |
| `primary_location.source.display_name` | `Publication.journalName` | Nullable |
| `authorships[].author.display_name` | `Publication.authors` | List<String> |
| `abstract_inverted_index` | `Publication.abstract` | Reconstruct via `formatter.dart` |
| `concepts[].display_name` | `Publication.keywords` | List<String>, top 5 |

### 6.4 Abstract Reconstruction

OpenAlex returns abstracts as an inverted index (`Map<String, List<int>>`). Reconstruction algorithm:

```dart
String reconstructAbstract(Map<String, List<int>> invertedIndex) {
  final wordMap = <int, String>{};
  invertedIndex.forEach((word, positions) {
    for (final pos in positions) {
      wordMap[pos] = word;
    }
  });
  final sorted = wordMap.keys.toList()..sort();
  return sorted.map((pos) => wordMap[pos]!).join(' ');
}
```

This must live in `lib/core/utils/formatter.dart`.

### 6.5 Error Handling Strategy

| Error type | Handling |
|---|---|
| `DioException` (timeout) | Throw `NetworkTimeoutException`, show "Connection timed out. Try again." |
| `DioException` (no internet) | Throw `NetworkException`, show "No internet connection." |
| HTTP 429 (rate limit) | Retry after 1 second delay, max 2 retries |
| HTTP 5xx | Throw `ServerException`, show "Server error. Try again later." |
| JSON parse error | Throw `ParseException`, log error, return empty list gracefully |
| Missing optional fields | Return `null`, UI handles with fallback labels |

---

## 7. Dependencies

### 7.1 pubspec.yaml

```yaml
name: journal_trend_analyzer
description: Academic research trend analysis mobile app using OpenAlex API
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  fl_chart: ^0.68.0
  shimmer: ^3.0.0
  url_launcher: ^6.2.5
  google_fonts: ^6.2.1
  go_router: ^13.2.4
  equatable: ^2.0.5
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.8
  freezed: ^2.5.2
  json_serializable: ^6.7.1
  riverpod_generator: ^2.4.0
  flutter_lints: ^4.0.0
```

### 7.2 Dependency Rationale

| Package | Purpose |
|---|---|
| `dio` | HTTP client with interceptors, timeout, error handling |
| `flutter_riverpod` | Reactive state management, dependency injection |
| `riverpod_annotation` + `riverpod_generator` | Code generation for providers |
| `fl_chart` | Bar charts, line charts, area charts |
| `shimmer` | Skeleton loading animations |
| `url_launcher` | Open DOI URLs in system browser |
| `google_fonts` | Roboto font (Material Design compliant) |
| `go_router` | Declarative routing, ShellRoute for bottom nav |
| `equatable` | Value equality for entities |
| `freezed` + `freezed_annotation` | Immutable data classes, union types |
| `json_serializable` + `json_annotation` | JSON deserialization code generation |

---

## 8. UI Requirements

### 8.1 Minimum Screens

The app must contain exactly these four major screens, plus the detail route:

| # | Screen | Route | Bottom nav tab |
|---|---|---|---|
| 1 | Search Screen | `/search` | Search (tab 0) |
| 2 | Publication Detail Screen | `/publication/:id` | None (pushed) |
| 3 | Trend Analysis Screen | `/trends` | Trends (tab 1) |
| 4 | Research Dashboard Screen | `/dashboard` | Dashboard (tab 2) |
| 5 | Top Papers Screen | `/top-papers` | Top Papers (tab 3) |

### 8.2 Navigation Rules

- The bottom navigation bar must be visible on all four tab screens
- The bottom navigation bar must not be visible on the Publication Detail Screen
- Switching bottom nav tabs must preserve scroll position (AutomaticKeepAliveClientMixin or equivalent)
- The active tab indicator uses a `NavigationBar` widget (M3) — not a custom `BottomNavigationBar`

### 8.3 Responsiveness

- All layouts must be tested at 360dp width (minimum supported)
- No content must overflow or be clipped at 360dp width
- Horizontal scroll rows (chips, authors) must not wrap; use `SingleChildScrollView(scrollDirection: Axis.horizontal)`

---

## 9. AI-Assisted Code Review

### 9.1 Requirement

Before submission, an AI-assisted code review must be performed using one of:
- SonarQube (with Flutter/Dart plugin)
- Kodus AI
- CodeRabbit (GitHub PR integration)
- GitHub Copilot Code Review

### 9.2 Deliverables

The project report must include:

1. **Tool used** — name and version/plan
2. **Minimum 3 findings** — each documented with:
   - Screenshot of the tool's output
   - File and line number affected
   - Category (bug / code smell / security / performance / style)
   - Description of the issue
   - Action taken (fixed / acknowledged / deferred with reason)
3. **Before/after code diff** for each finding that was fixed

### 9.3 Common Expected Findings

| Category | Example finding |
|---|---|
| Code smell | Provider accessed in `initState` without `ref.listen` |
| Performance | `const` missing on stateless widgets |
| Security | API URL hardcoded as string literal instead of constant |
| Style | Missing `const` constructor where possible |
| Bug | Null check missing on nullable `doi` field before `url_launcher` call |

---

## 10. Testing Requirements

### 10.1 Minimum Test Coverage

| Layer | Type | Minimum |
|---|---|---|
| `formatter.dart` (abstract reconstruction) | Unit test | ✅ Required |
| `PublicationRepositoryImpl` | Unit test with mock Dio | ✅ Required |
| `SearchScreen` | Widget test | ✅ Required |
| Integration | End-to-end search flow | Optional (bonus) |

### 10.2 Test File Locations

```
test/
├── core/
│   └── utils/
│       └── formatter_test.dart
├── data/
│   └── repositories/
│       └── publication_repository_impl_test.dart
└── presentation/
    └── screens/
        └── search_screen_test.dart
```

---

## 11. Submission Checklist

- [ ] App runs on Android emulator with `flutter run` without errors
- [ ] All five screens are implemented and accessible via navigation
- [ ] All data is fetched from OpenAlex API (no hard-coded data)
- [ ] Three-layer repository pattern is implemented
- [ ] SOLID principles are applied and documented in the report
- [ ] Bottom navigation bar is persistent across all tab screens
- [ ] Loading, empty, and error states are implemented on all data screens
- [ ] Abstract reconstruction from inverted index is implemented
- [ ] AI code review performed with minimum 3 findings documented
- [ ] `pubspec.yaml` contains all required dependencies
- [ ] Code compiles without warnings (`flutter analyze` passes)
- [ ] Project report includes architecture diagrams, screenshots, and code review evidence

---

## 12. Glossary

| Term | Definition |
|---|---|
| OpenAlex | Open-source academic knowledge graph providing free access to scholarly publication data via REST API |
| Publication | A single academic paper, article, or research output tracked by OpenAlex |
| Citation count | Number of times a publication has been cited by other works |
| DOI | Digital Object Identifier — a persistent URL linking to a publication |
| Abstract inverted index | OpenAlex representation of a paper's abstract as a `Map<word, List<position>>` |
| Provider | Riverpod unit of reactive state, scoped to the widget tree |
| Repository | Abstraction layer between domain use cases and data sources |
| Entity | A domain object with no framework dependencies (no JSON, no Flutter widgets) |
| Use case | A single, focused business operation (e.g., "search publications") |
| Three-layer architecture | Separation of Data, Domain, and Presentation concerns into distinct module boundaries |