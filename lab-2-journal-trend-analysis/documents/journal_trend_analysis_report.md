# Journal Trend Analysis — Source Code Structure & Technical Report

**Project:** journal_trend_analysis  
**Framework:** Flutter (Dart SDK ^3.12.0)  
**Author:** PRM393 Lab  
**Date:** June 2026

---

## 1. Tổng quan ứng dụng

**Journal Trend Analyzer** là ứng dụng Flutter cross-platform phân tích xu hướng công bố nghiên cứu khoa học sử dụng OpenAlex API. Ứng dụng cho phép người dùng tìm kiếm, phân tích xu hướng theo năm, xem bảng điều khiển tổng quan (dashboard) và xếp hạng các bài báo có ảnh hưởng nhất.

### Các tính năng chính:

- Tìm kiếm bài báo khoa học theo chủ đề (keyword search)
- Biểu đồ xu hướng công bố theo năm (trend chart)
- Dashboard tổng hợp KPI (tổng bài, trích dẫn trung bình, năm hoạt động nhất, ...)
- Xếp hạng Top Papers theo số lượt trích dẫn
- Chi tiết từng bài báo (abstract, tác giả, DOI, concepts)
- Xếp hạng top tác giả và top tạp chí

---

## 2. Cấu trúc thư mục (Source Code Architecture)

```
lib/
├── main.dart                          # Entry point
├── core/                              # Shared utilities & config
│   ├── constants/
│   │   └── api_constants.dart         # API base URL, timeout, pagination
│   ├── router/
│   │   └── app_router.dart            # GoRouter configuration
│   ├── theme/
│   │   ├── app_colors.dart            # Color palette (Material 3)
│   │   ├── app_dimensions.dart        # Spacing & shape constants
│   │   ├── app_text_styles.dart       # Typography styles
│   │   └── app_theme.dart             # ThemeData definition
│   └── utils/
│       └── formatter.dart             # Formatting utilities
├── data/                              # Data layer (infrastructure)
│   ├── api/
│   │   └── openalex_api_client.dart   # Dio HTTP client wrapper
│   ├── datasources/
│   │   └── publication_remote_datasource.dart  # Remote API calls
│   ├── models/
│   │   ├── author_model.dart          # Author JSON model
│   │   ├── journal_model.dart         # Journal JSON model
│   │   └── publication_model.dart     # Publication JSON model
│   └── repositories/
│       └── publication_repository_impl.dart  # Repository implementation
├── domain/                            # Domain layer (business logic)
│   ├── entities/
│   │   ├── author.dart                # Author entity
│   │   ├── journal.dart               # Journal entity
│   │   └── publication.dart           # Publication entity
│   ├── repositories/
│   │   └── publication_repository.dart  # Repository interface (contract)
│   └── usecases/
│       ├── get_dashboard_summary.dart  # Dashboard KPIs computation
│       ├── get_top_authors.dart        # Top authors aggregation
│       ├── get_top_journals.dart       # Top journals aggregation
│       ├── get_trend_data.dart         # Year-by-year trend computation
│       └── search_publications.dart    # Search validation & delegation
└── presentation/                      # UI layer
    ├── providers/
    │   └── providers.dart             # Riverpod DI & state management
    ├── screens/
    │   ├── dashboard_screen.dart      # Dashboard with KPI metrics
    │   ├── publication_detail_screen.dart  # Publication detail page
    │   ├── search_screen.dart         # Search input & results list
    │   ├── top_papers_screen.dart     # Ranked papers with sorting
    │   └── trend_analysis_screen.dart # Trend chart & rankings
    └── widgets/
        ├── author_chip.dart           # Author avatar chip
        ├── empty_state.dart           # Empty state placeholder
        ├── error_state.dart           # Error state with retry
        ├── metric_card.dart           # KPI metric card widget
        ├── publication_card.dart      # Publication list item
        ├── ranked_list_tile.dart      # Ranked item with progress bar
        ├── shimmer_loader.dart        # Skeleton loading animation
        └── trend_chart.dart           # Line chart widget (fl_chart)
```

---

## 3. Kiến trúc phần mềm (Clean Architecture)

Ứng dụng tuân theo **Clean Architecture** chia làm 3 layer rõ ràng:

### 3.1. Domain Layer (Business Logic)

- **Entities:** Các đối tượng thuần Dart, không phụ thuộc framework (`Publication`, `Author`, `Journal`)
- **Repository Interface:** Contract trừu tượng (`PublicationRepository`) — đảm bảo nguyên tắc Open/Closed
- **Use Cases:** Mỗi class chỉ chịu 1 trách nhiệm (Single Responsibility):
  - `SearchPublications`: Validate query → gọi repository
  - `GetTrendData`: Nhóm publications theo năm
  - `GetDashboardSummary`: Tính toán KPI tổng hợp
  - `GetTopAuthors`: Xếp hạng tác giả
  - `GetTopJournals`: Xếp hạng tạp chí

### 3.2. Data Layer (Infrastructure)

- **API Client:** Wrapper Dio HTTP client với timeout, interceptor, logging
- **Remote DataSource:** Gọi API, trả về Model objects (không trả entity)
- **Models:** Parse JSON từ OpenAlex, có `toEntity()` để chuyển sang domain entity
- **Repository Implementation:** Convert model → entity, triển khai interface từ domain layer

### 3.3. Presentation Layer (UI)

- **Providers:** Riverpod dependency injection + reactive state
- **Screens:** 5 màn hình chính sử dụng `ConsumerWidget` / `ConsumerStatefulWidget`
- **Widgets:** 8 reusable widgets tái sử dụng

---

## 4. Các kỹ thuật và thư viện sử dụng

### 4.1. State Management — Flutter Riverpod (`flutter_riverpod: ^2.5.1`)

| Provider Type        | Mục đích                      | Ví dụ                                                |
| -------------------- | ----------------------------- | ---------------------------------------------------- |
| `Provider`           | Singleton DI (infrastructure) | `apiClientProvider`, `publicationRepositoryProvider` |
| `StateProvider`      | Mutable simple state          | `searchQueryProvider`, `paperSortOptionProvider`     |
| `FutureProvider`     | Async data fetching           | `publicationsProvider`                               |
| `Provider` (derived) | Computed/derived state        | `trendDataProvider`, `topAuthorsProvider`            |

**Reactive chain:** `searchQueryProvider` → `publicationsProvider` (auto-refetch) → derived providers tự động cập nhật.

### 4.2. Navigation — GoRouter (`go_router: ^13.2.4`)

- **Declarative routing** với `ShellRoute` cho bottom navigation
- Bottom `NavigationBar` persistent qua các tab
- Deep linking support (`/publication/:id` với `extra` parameter)
- Tab-based navigation: Search → Trends → Dashboard → Top Papers

### 4.3. Networking — Dio (`dio: ^5.4.0`)

- Custom `BaseOptions`: base URL, timeout (15s connect + 15s receive)
- `LogInterceptor` cho debug
- Custom error handler interceptor
- Polite pool header (`User-Agent`) theo yêu cầu OpenAlex API
- RESTful API calls: `GET /works` với query params (`search`, `per_page`, `sort`, `filter`)

### 4.4. Data Visualization — FL Chart (`fl_chart: ^0.68.0`)

- `LineChart` cho biểu đồ xu hướng (trend line + area fill)
- Touch tooltip hiển thị năm + số lượng papers
- Adaptive dot display (ẩn dots nếu >24 data points)
- Sparkline mini-chart trên dashboard
- Custom axis titles với interval logic

### 4.5. UI/UX Enhancements

| Thư viện                       | Kỹ thuật                                    |
| ------------------------------ | ------------------------------------------- |
| `shimmer: ^3.0.0`              | Skeleton loading animation (shimmer effect) |
| `google_fonts: ^6.2.1`         | Custom typography                           |
| `cached_network_image: ^3.3.1` | Image caching (sẵn sàng mở rộng)            |
| `url_launcher: ^6.2.5`         | Mở DOI link trong trình duyệt ngoài         |

### 4.6. Domain Modeling — Equatable & Freezed

| Thư viện                     | Mục đích                                  |
| ---------------------------- | ----------------------------------------- |
| `equatable: ^2.0.5`          | Value equality cho entities (props-based) |
| `freezed_annotation: ^2.4.1` | Immutable data classes (code generation)  |
| `json_annotation: ^4.9.0`    | JSON serialization annotations            |

**Dev tools:** `build_runner`, `freezed`, `json_serializable`, `riverpod_generator`

### 4.7. Theming — Material Design 3

- Full `ColorScheme` definition với custom palette
- Centralized `AppColors`, `AppDimensions`, `AppTextStyles`
- Dark/light ready architecture (hiện tại triển khai light theme)
- Consistent spacing system (xs=4, sm=8, md=12, base=16, lg=20, xl=24, xxl=32)
- Border radius tokens (shapeXs=4, shapeSm=8, shapeMd=12, shapeFull=100)

---

## 5. API Integration — OpenAlex

| Endpoint             | Mục đích              | Parameters                                                   |
| -------------------- | --------------------- | ------------------------------------------------------------ |
| `GET /works?search=` | Tìm kiếm publications | `search`, `per_page=50`, `sort=cited_by_count:desc`          |
| `GET /works?filter=` | Top papers theo topic | `filter=concepts.display_name:X`, `sort=cited_by_count:desc` |

**Response parsing:**

- `results[]` → `PublicationModel.fromJson()`
- Nested: `primary_location.source.display_name` → journal name
- Nested: `authorships[].author` → author info
- `abstract_inverted_index` → reconstruct plaintext via `Formatter.reconstructAbstract()`

---

## 6. Design Patterns áp dụng

| Pattern                   | Áp dụng                                             |
| ------------------------- | --------------------------------------------------- |
| **Clean Architecture**    | 3-layer separation (domain / data / presentation)   |
| **Repository Pattern**    | Abstract interface + concrete implementation        |
| **Dependency Injection**  | Riverpod Provider tree                              |
| **Observer Pattern**      | Riverpod reactive state (watch/listen)              |
| **Single Responsibility** | Mỗi UseCase 1 nhiệm vụ duy nhất                     |
| **Open/Closed Principle** | Repository interface cho phép thay đổi data source  |
| **Composition**           | Reusable widgets compose thành screens              |
| **Factory Method**        | `fromJson()` factory constructors trong models      |
| **Strategy Pattern**      | `PaperSortOption` enum cho multiple sort algorithms |

---

## 7. Screens & Navigation Flow

```
┌─────────────────────────────────────────────────────┐
│                  ShellRoute (NavigationBar)         │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌─────┐ │
│  │  Search  │  │  Trends  │  │ Dashboard │  │ Top │ │
│  │  Screen  │  │  Screen  │  │  Screen   │  │Paper│ │
│  └──────────┘  └──────────┘  └───────────┘  └─────┘ │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
         ┌──────────────────────────┐
         │  Publication Detail      │
         │  (push route, no nav)    │
         └──────────────────────────┘
```

---

## 8. Error Handling & UX States

Ứng dụng xử lý đầy đủ 3 trạng thái của async data:

| State   | Widget          | Mô tả                            |
| ------- | --------------- | -------------------------------- |
| Loading | `ShimmerLoader` | Skeleton placeholder animation   |
| Error   | `ErrorState`    | Thông báo lỗi + nút Retry        |
| Empty   | `EmptyState`    | Icon + message + optional action |
| Data    | Screen content  | Hiển thị dữ liệu bình thường     |

Pattern sử dụng: `pubAsync.when(loading: ..., error: ..., data: ...)`

---

## 9. Tóm tắt công nghệ

| Hạng mục         | Công nghệ                                    |
| ---------------- | -------------------------------------------- |
| Framework        | Flutter 3.x (Dart SDK ^3.12.0)               |
| State Management | Riverpod 2.x                                 |
| Navigation       | GoRouter 13.x                                |
| HTTP Client      | Dio 5.x                                      |
| Charts           | FL Chart 0.68.x                              |
| Loading UX       | Shimmer 3.x                                  |
| External Links   | url_launcher 6.x                             |
| Typography       | Google Fonts 6.x                             |
| Value Equality   | Equatable 2.x                                |
| Code Generation  | Freezed + json_serializable + build_runner   |
| Architecture     | Clean Architecture (Domain-Driven)           |
| Design System    | Material Design 3 (M3)                       |
| API              | OpenAlex REST API (https://api.openalex.org) |
| Platforms        | Android, iOS, Web, Windows, Linux, macOS     |

---

_End of Report_
