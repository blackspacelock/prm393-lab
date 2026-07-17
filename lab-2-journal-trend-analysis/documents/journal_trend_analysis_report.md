# Journal Trend Analyzer - Technical Report

**Project:** `journal_trend_analysis`

**Framework:** Flutter / Dart SDK `^3.12.0`

**Firebase project:** `journaltrend-8cc04`

**Last updated:** July 17, 2026

---

## 1. Overview

Journal Trend Analyzer is a Flutter application for researching scientific publications and journals through the OpenAlex REST API. It combines search, journal exploration, keyword analytics, trend visualisation, report export, and Firebase-backed account features.

The app supports two access levels:

- **Guest users** can browse Home, Journals, Keywords, papers, dashboards, heatmaps, and author networks.
- **Google-authenticated users** can also save papers, view saved papers, enable research-update notifications, export PDF reports, and use the authenticated Profile features.

The project follows a practical Clean Architecture style: providers compose dependencies, repositories hide data sources, use cases hold reusable calculations, and screens render Riverpod state.

---

## 2. Navigation

The router uses a `ShellRoute` with a persistent four-item `NavigationBar`.

```text
ShellRoute
|-- /home       Home / trending publications
|-- /journals   Journal search and ranking
|-- /keywords   Keyword search with four analysis tabs
`-- /profile    Guest sign-in prompt or authenticated Profile

Standalone routes
|-- /login
|-- /publication/:id
|-- /journals/:id
`-- /profile/bookmarks
```

The `/keywords` screen contains the **Papers**, **Dashboard**, **Heatmap**, and **Network** analysis tabs. Publication and journal detail routes receive their loaded entity through `GoRouter` route extras.

---

## 3. Current Source Structure

```text
journal_trend_analysis/
|-- lib/
|   |-- core/                 API constants, router, theme, format/export helpers
|   |-- data/                 OpenAlex API client, remote/local data sources, models, repositories
|   |-- domain/               entities, repository contracts, analysis/search use cases
|   |-- firebase/             Auth, Analytics, Crashlytics, FCM, Remote Config, PDF report services
|   |-- presentation/
|   |   |-- providers/        Riverpod dependency injection and UI state
|   |   |-- screens/          Home, Journals, Keywords, Profile, detail and saved-paper screens
|   |   `-- widgets/          shared charts, cards, loading/error/empty states
|   |-- firebase_options.dart
|   `-- main.dart
|-- android/                  Firebase plugins, FCM channel, Patrol instrumentation setup
|-- ios/                      Runner configuration and GoogleService-Info.plist
|-- patrol_test/              Android end-to-end Patrol scenarios
|-- test/                     service and widget tests
|-- storage.rules             per-user PDF report protection
`-- pubspec.yaml
```

Important source files include:

- `lib/main.dart`: Firebase initialisation, Crashlytics error capture, background FCM handler registration, and Remote Config subscription.
- `lib/core/router/app_router.dart`: routing and guest protection for saved papers.
- `lib/presentation/screens/keywords_screen.dart`: topic search input and the integrated analysis tabs.
- `lib/presentation/screens/profile_screen.dart`: authenticated features, notification history, PDF export, and compact Crashlytics test controls.
- `lib/firebase/notification_service.dart`: FCM permission/topic subscription and local message history.

---

## 4. OpenAlex Research Features

### Home

The Home tab presents trending publications, domain categories, and yearly publication counts. It uses OpenAlex work data and local derived state.

### Journals

The Journals tab supports journal discovery and sorting by papers, citations, author-related statistics, or recent activity. Selecting a journal opens its details and publications.

### Keywords and Analysis

Users can enter free-text queries or select an OpenAlex hierarchy item (domain, field, subfield, or topic). A selected search drives four connected views:

- **Papers:** paginated publication results, local sorting, and detail navigation.
- **Dashboard:** publication KPIs, yearly trends, top journals, and top authors.
- **Heatmap:** country or institution research distribution.
- **Network:** collaboration graph derived from the loaded publications.

Publication detail shows title, authors, journal, year, citations, topics, abstract, DOI/external links, and a bookmark action for signed-in users.

### OpenAlex endpoints

| Use case | Endpoint | Main parameters |
| --- | --- | --- |
| Free-text publication search | `GET /works` | `search`, `page`, `per_page`, `sort=relevance_score:desc` |
| Topic-filter search | `GET /works` | `filter`, `page`, `per_page`, citation sorting |
| Trending publications | `GET /works` | recent date/type filter, page, citation sorting |
| Journal browse/search | OpenAlex sources endpoint | query, page, sort, journal filter |
| Topic hierarchy/autocomplete | domains, fields, subfields, topics endpoints | parent filter or search text |
| Heatmap and yearly aggregates | `GET /works` | `group_by` or yearly grouping |

`OpenAlexApiClient` owns the Dio configuration, including timeouts and the polite-pool user agent. Models are converted to framework-independent domain entities by repository implementations.

---

## 5. State and Architecture

```text
Screen interaction
  -> Riverpod state provider
  -> Future/Stream provider
  -> use case or repository
  -> OpenAlex or Firebase service
  -> domain entity / UI state
  -> reactive screen rebuild
```

Key state includes `searchQueryProvider`, `selectedTopicFilterProvider`, pagination, sort choices, journal state, bookmarks, authentication state, and Remote Config limits. Derived providers calculate dashboard summaries, top authors, top journals, trends, and network/heatmap input from the current publication set.

The project uses:

- **Repository pattern:** OpenAlex publication and journal repository contracts hide data-source details.
- **Dependency injection:** Riverpod providers construct API clients, data sources, repositories, and services.
- **Reactive state:** asynchronous values expose loading, error, empty, and data states to screens.
- **Local analysis:** dashboard, ranking, heatmap inputs, and network relationships are calculated from loaded data where appropriate.

---

## 6. Firebase Features

### Google Authentication and Guest Access

`AuthService` authenticates with Google Sign-In and exchanges the Google ID token for Firebase Auth credentials. Authentication state controls Profile access and protects the saved-paper route. Sign-out clears both Firebase Auth and the Google session.

Guests remain able to research content. The Profile tab explains that saving, notifications, and PDF reports require a sign-in.

### Analytics and Crashlytics

Firebase Analytics records key research and account events through `AnalyticsService`. Crashlytics collection is enabled at startup; Flutter framework errors and uncaught platform errors are recorded.

The Profile screen exposes only small icon controls for testing:

- record a handled demonstration exception;
- confirm and trigger a fatal test crash.

These controls are for development verification and are not presented as primary product features.

### Remote Config

Remote Config is deliberately hidden from end users. `RemoteConfigService` supplies these parameters:

| Parameter | Default | Runtime effect |
| --- | ---: | --- |
| `max_journals_displayed` | 10 | page size for journal lists |
| `max_keywords_displayed` | 10 | keyword autocomplete limit and publication result page size |

Values are clamped to 1-100. The service fetches and activates at launch (with a one-hour minimum fetch interval), retains defaults if offline, and listens for Firebase real-time config updates. Screens/providers consume the resulting limits, so configuration changes affect actual API result sizes rather than merely showing diagnostic values in Profile.

### Cloud Messaging and Notification Center

Authenticated users can enable notifications from Profile. The app requests platform permission, checks the APNs token on iOS, and subscribes the device to the FCM topic:

```text
journaltrend_updates
```

Firebase Console campaigns can target this topic, so testing does not require copying an individual FCM token. Incoming messages are stored locally in `SharedPreferences`, deduplicated by message ID, and limited to the newest 50 entries. Tapping **Notification Center** opens a bottom sheet with the stored message history and timestamps.

Android declares `POST_NOTIFICATIONS` and creates the high-importance `research_updates` channel used by FCM background notification messages. A foreground message is still handled by the app and stored in Notification Center; a separate local-notification implementation would be needed for a system heads-up banner while the app is open.

### PDF Export and Firebase Storage

Authenticated users can export analytics for the active search topic. `ReportService` builds a PDF containing:

- dashboard summary and publication trend table;
- top journals and authors;
- most influential publications by citation count.

The PDF is stored at `reports/{uid}/report-{timestamp}.pdf`. The app retrieves its download URL and exposes an **Open PDF** action through `url_launcher`.

Storage rules allow read/write only when the Firebase Auth user ID matches the `{uid}` path segment:

```text
reports/{userId}/{fileName}: request.auth.uid == userId
```

---

## 7. Android and iOS Notes

### Android

- Package ID: `com.blackspace.journaltrend`.
- Firebase is configured through `android/app/google-services.json` and the Google Services/Crashlytics Gradle plugins.
- FCM uses the `research_updates` notification channel for new background notification campaigns.
- Patrol uses `PatrolJUnitRunner` with AndroidX Test Orchestrator and clears app data between test cases.

On Xiaomi/MIUI devices, Android instrumentation can be blocked or killed by device background restrictions. A standard Android emulator or a device without aggressive battery management is more reliable for unattended Patrol runs.

### iOS

The repository contains `GoogleService-Info.plist` and the Google Sign-In URL scheme for bundle ID `com.blackspace.journaltrend`. Building and signing an IPA, configuring APNs, adding Push Notifications and Background Modes, and uploading an APNs key to Firebase require a macOS/Xcode environment and Apple Developer credentials. See `documents/IOS_FIREBASE_HANDOFF.md` for the remaining handoff steps.

---

## 8. Testing

### Unit and widget tests

The `test/` directory covers:

- notification JSON persistence and refresh from local storage;
- Remote Config bounds/default behavior;
- PDF report service behavior;
- core widget/provider setup.

### Patrol end-to-end tests

`patrol_test/lab03_e2e_test.dart` defines 11 Android scenarios:

1. Guest research access and Google Sign-In unlock.
2. Topic search returns publication results.
3. Publication details open.
4. Journals tab loads statistics.
5. Journal detail opens.
6. Keywords navigation exposes analysis tabs.
7. Dashboard displays trend, top journals, and top authors.
8. Authenticated Profile displays account features.
9. PDF report uploads and can be opened.
10. Remote Config diagnostics are not visible to users.
11. Logout returns to the guest profile.

Search/dashboard cases intentionally run as guests because research is a guest feature. Tests that require Profile actions perform Google Sign-In. A physical Xiaomi device may intermittently fail at the Android instrumentation level; those failures are separate from Dart test assertions.

---

## 9. Main Libraries

| Library | Role |
| --- | --- |
| `flutter_riverpod` | dependency injection and reactive state |
| `go_router` | shell and detail navigation |
| `dio` | OpenAlex HTTP client |
| `fl_chart` | trend charts |
| `countries_world_map` | geographic visualisation |
| `firebase_core`, `firebase_auth`, `google_sign_in` | Firebase initialisation and Google authentication |
| `firebase_analytics`, `firebase_crashlytics` | product analytics and crash reporting |
| `firebase_remote_config` | remotely managed result limits |
| `firebase_messaging` | FCM topic notifications |
| `firebase_storage` | user-scoped PDF uploads |
| `pdf`, `path_provider`, `share_plus`, `url_launcher` | report generation, file/link sharing, and external opening |
| `shared_preferences` | bookmarks and local notification history |
| `patrol` | Android end-to-end testing |

---

## 10. Operational Notes

- New FCM campaigns only reach devices already subscribed to `journaltrend_updates`; completed campaigns are not replayed for later subscribers.
- Topic messaging broadcasts to all subscribed devices. Per-user targeting requires a trusted backend that stores/uses device tokens; clients should not subscribe themselves to sensitive user-ID topics.
- Remote Config defaults keep research usable when Firebase cannot be reached.
- PDF URLs are user-scoped by Firebase Storage rules, and the app opens the generated download URL only after a successful upload.
- The current iOS push/signing work remains a macOS/Xcode handoff item.

_End of Report_
