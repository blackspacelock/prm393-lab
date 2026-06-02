# DESIGN.md — Journal Trend Analyzer

> **Version:** 1.0.0  
> **Last updated:** 2026-06-02  
> **Platform:** Android (Flutter / Material Design 3)  
> **Design system:** Google Material Design 3 with custom academic palette

---

## 1. Design Philosophy

The Journal Trend Analyzer is a data-driven research tool. The design language prioritizes **clarity over decoration**, **data density over whitespace for its own sake**, and **progressive disclosure** — showing summary insights first, full detail on demand.

Core principles:
- **Information hierarchy first.** Every screen has one primary action and one primary insight. Everything else is secondary.
- **Consistent navigation shell.** The bottom navigation bar is the single persistent anchor across all screens. Users should never feel lost.
- **Accessible data.** Charts, rankings, and statistics must be readable at a glance without requiring interaction.
- **Material 3 compliance.** All components use M3 tokens, shapes, and motion specs. No custom shadow, border, or color that contradicts the M3 system.

---

## 2. Design Tokens

### 2.1 Color Palette

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#1A73E8` | Primary buttons, active nav, chart fills, accent icons, tappable links |
| `on-primary` | `#FFFFFF` | Text/icons on primary-colored surfaces |
| `primary-container` | `#D3E3FD` | Active chip bg, indicator pills, selected state surfaces |
| `on-primary-container` | `#1A3E8E` | Text/icons inside primary-container surfaces |
| `surface` | `#F8F9FA` | Page background, screen bg |
| `on-surface` | `#202124` | Primary body text, headlines |
| `surface-variant` | `#F1F3F4` | Input fills, unselected chip bg, shimmer base |
| `on-surface-variant` | `#5F6368` | Secondary text, captions, placeholder text |
| `outline` | `#DADCE0` | Card borders, dividers, unselected chip borders |
| `outline-variant` | `#80868B` | Inactive nav labels, tertiary meta text |
| `success` | `#1E8E3E` | Positive growth indicators, success states |
| `on-success` | `#FFFFFF` | Text on success surfaces |
| `error` | `#D93025` | Error states, decline indicators |
| `gold-rank` | `#FDD835` | Rank #1 medal badge |
| `silver-rank` | `#B0BEC5` | Rank #2 medal badge |
| `bronze-rank` | `#FFAB40` | Rank #3 medal badge |

### 2.2 Typography

All text uses **Roboto** (Google Fonts). No other typeface is used.

| Style name | Size | Weight | Line height | Usage |
|---|---|---|---|---|
| `headline-large` | 24sp | 500 | 32sp | Dashboard topic header |
| `headline-medium` | 20sp | 500 | 28sp | Paper title (detail screen hero) |
| `headline-small` | 18sp | 500 | 24sp | App bar title, screen headings |
| `title-large` | 16sp | 500 | 24sp | Card title, section headers, list primary text |
| `title-medium` | 14sp | 500 | 20sp | Metric values, ranked list names |
| `body-large` | 16sp | 400 | 24sp | Abstract body text |
| `body-medium` | 14sp | 400 | 20sp | Search result title (secondary read) |
| `body-small` | 13sp | 400 | 18sp | Journal name, author, card subtitles |
| `label-large` | 13sp | 500 | 18sp | Button labels, chip labels |
| `label-medium` | 12sp | 500 | 16sp | Nav labels, badge counts, filter chips |
| `label-small` | 11sp | 400 | 14sp | Axis labels, metadata tertiary |

### 2.3 Spacing Scale

All spacing values are multiples of **4dp**.

| Token | Value | Usage |
|---|---|---|
| `spacing-xs` | 4dp | Icon-to-text gap, internal chip padding vertical |
| `spacing-sm` | 8dp | Between chips, between metadata items, icon gap |
| `spacing-md` | 12dp | Card internal vertical gap, between list sub-rows |
| `spacing-base` | 16dp | **Horizontal page padding (global)**, card padding |
| `spacing-lg` | 20dp | Between card sections, between list items |
| `spacing-xl` | 24dp | Between major screen sections |
| `spacing-2xl` | 32dp | Above-fold breathing room, large section separation |

### 2.4 Shape (Border Radius)

| Token | Value | Usage |
|---|---|---|
| `shape-xs` | 4dp | Chips (compact), year badges, progress bar fills |
| `shape-sm` | 8dp | Chips (standard), filter chips, keyword tags |
| `shape-md` | 12dp | Cards, metric tiles, chart containers |
| `shape-full` | 100dp | Buttons (pill), search bar, FAB |

### 2.5 Elevation & Shadow

Material 3 tonal surface elevation — no colored shadows.

| Level | CSS / Flutter | Usage |
|---|---|---|
| Level 0 | No shadow | Flat list rows, divider-separated items |
| Level 1 | `0 1px 2px rgba(60,64,67,0.3), 0 1px 3px 1px rgba(60,64,67,0.15)` | Standard cards, app bar, bottom nav, FAB |
| Level 2 | `0 1px 2px rgba(60,64,67,0.3), 0 2px 6px 2px rgba(60,64,67,0.15)` | Tooltip bubbles, focused search bar |

### 2.6 Iconography

- **Library:** Material Icons (outline style preferred; filled only for active nav tab icon)
- **Size:** 24dp interactive, 20dp inline, 16dp inline-label, 32dp decorative section headers

---

## 3. Layout System

### 3.1 Screen Anatomy

Every screen follows this vertical stacking order:

```
┌─────────────────────────────┐
│  Status bar         (24dp)  │
├─────────────────────────────┤
│  App bar            (56dp)  │
├─────────────────────────────┤
│  [Optional sticky sub-bar]  │
│  Topic context / sort bar   │
│                  (44dp)     │
├─────────────────────────────┤
│                             │
│  Scrollable content         │
│  (flex / expands)           │
│                             │
├─────────────────────────────┤
│  [Optional sticky CTA bar]  │
│                  (72dp)     │
├─────────────────────────────┤
│  Bottom navigation  (64dp)  │
└─────────────────────────────┘
```

### 3.2 Grid & Padding

- **Horizontal page margin:** 16dp on all screens (applied to all direct children)
- **Card grid (2-col):** `16dp outer margin + 10dp gap + equal columns`
  - Column width = `(360 - 32 - 10) / 2 = 159dp`
- **Card grid (3-col):** Not used (too narrow at 360dp)
- **List items:** Full bleed to screen edges with 16dp internal horizontal padding

### 3.3 Viewport

- **Base viewport:** 360 × 800dp (Android standard)
- **Minimum support:** 320dp width
- **Content safe area bottom:** 16dp padding above bottom nav bar for scrollable content

---

## 4. Component Library

### 4.1 Bottom Navigation Bar

```
Height:       64dp
Background:   #FFFFFF
Top border:   0.5px solid #DADCE0
Tabs:         4 (Search, Trends, Dashboard, Top Papers)
```

**Active tab state:**
- Indicator pill: `width 64dp, height 32dp, bg #D3E3FD, radius 16dp` centered behind icon
- Icon: filled variant, color `#1A73E8`
- Label: `label-medium`, color `#1A73E8`

**Inactive tab state:**
- No indicator
- Icon: outline variant, color `#80868B`
- Label: `label-medium`, color `#80868B`

**Tab definitions:**

| Index | Label | Icon (inactive) | Icon (active) | Route |
|---|---|---|---|---|
| 0 | Search | `search` outline | `search` filled | `/search` |
| 1 | Trends | `show_chart` outline | `show_chart` filled | `/trends` |
| 2 | Dashboard | `dashboard` outline | `dashboard` filled | `/dashboard` |
| 3 | Top Papers | `emoji_events` outline | `emoji_events` filled | `/top-papers` |

### 4.2 App Bar

```
Height:         56dp
Background:     #FFFFFF
Elevation:      Level 1 shadow
Title style:    headline-small (#202124)
Icon buttons:   24dp, color #5F6368, 48dp touch target
```

Detail screen app bar adds a leading back arrow in `#1A73E8`.

### 4.3 Search Bar

```
Height:         48dp
Shape:          radius 28dp (pill)
Background:     #F1F3F4
Border:         none (resting), none (focused — elevation only)
Focus shadow:   Level 2
Left icon:      search, 20dp, #5F6368, 12dp left padding
Right icon:     mic (resting) / clear (typing), 20dp, #5F6368
Placeholder:    body-large, #80868B
Input text:     body-large, #202124
Margin:         12dp top, 16dp horizontal
```

### 4.4 Cards

**Standard card (list detail / metric):**
```
Background:   #FFFFFF
Border:       0.5px solid #DADCE0
Radius:       12dp
Padding:      16dp
Shadow:       Level 1
```

**Colored accent card (dashboard hero, top journal):**
```
Background:   #1A73E8
Radius:       12dp
Padding:      16dp
Shadow:       none
Text:         #FFFFFF (primary), #D3E3FD (secondary/muted)
```

**Left-accent card (most influential paper):**
```
Background:   #FFFFFF
Border:       0.5px solid #DADCE0
Radius:       12dp
Padding:      16dp
Left accent:  4dp wide bar, #1A73E8, radius 0 (left-flush inside card)
```

**Metric mini-card (KPI grid):**
```
Background:   #FFFFFF
Border:       0.5px solid #DADCE0
Radius:       12dp
Padding:      14dp
Icon:         20dp, #1A73E8
Value text:   22sp/500, #202124
Label text:   12sp/400, #5F6368
```

### 4.5 Chips

**Selected filter chip:**
```
Background:   #D3E3FD
Label:        #1A3E8E, label-large
Border:       1px solid #1A73E8
Radius:       8dp
Height:       32dp
Padding:      4dp 12dp
Leading icon: checkmark 16dp (filter chips only)
```

**Unselected filter chip:**
```
Background:   #FFFFFF
Label:        #3C4043, label-large
Border:       1px solid #DADCE0
Radius:       8dp
Height:       32dp
Padding:      4dp 12dp
```

**Info chip (citations, year):**
```
Citation:   bg #E8F0FE, label #1A3E8E, 11sp
Year:       bg #F1F3F4, label #5F6368, 11sp
Radius:     4dp
Padding:    2dp 8dp
Height:     20dp
```

**Author chip (avatar + name):**
```
Height:       40dp
Radius:       20dp (pill)
Background:   #FFFFFF
Border:       1px solid #DADCE0
Padding:      4dp 12dp 4dp 4dp
Avatar:       32dp circle, bg #E8F0FE, initials #1A3E8E, 13sp/500
Name label:   body-small, #202124
Gap (avatar–name): 8dp
```

### 4.6 Buttons

**Primary filled (pill):**
```
Height:       48dp
Radius:       100dp
Background:   #1A73E8
Label:        #FFFFFF, label-large (15sp/500)
Ripple:       white at 12% opacity
```

**Outlined (pill):**
```
Height:       36dp
Radius:       100dp
Background:   transparent
Border:       1px solid #1A73E8
Label:        #1A73E8, label-large
```

### 4.7 Rank Badges

| Rank | Bg color | Text color | Size |
|---|---|---|---|
| #1 | `#FDD835` (gold) | `#4A3900` | 36dp circle |
| #2 | `#B0BEC5` (silver) | `#2C3A40` | 36dp circle |
| #3 | `#FFAB40` (bronze) | `#4E2900` | 36dp circle |
| 4+ | `#F1F3F4` | `#5F6368` | 36dp circle |

Badge font: `title-medium` (14sp/500), centered.

### 4.8 Avatar / Initials Circle

```
Size:         32dp (list) / 44dp (detail hero)
Shape:        circle
Background:   #E8F0FE
Initials:     #1A3E8E, 13sp/500 (32dp) or 16sp/500 (44dp)
Max initials: 2 characters
```

### 4.9 Shimmer Loader

Animated placeholder for loading states.

```
Base color:   #F1F3F4
Shimmer:      #E8EAED (sweeps left to right, ~1.2s loop)
Shape:        matches the element it replaces
Items:        2 skeleton cards minimum
```

Skeleton card anatomy:
- Title bar: `140dp × 14dp, radius 4dp`
- Journal bar: `100dp × 12dp, radius 4dp`, 8dp below title
- Chip bars: `60dp + 80dp × 10dp, radius 4dp`, 8dp below journal

### 4.10 FAB (Floating Action Button)

```
Size:         48dp circle
Background:   #1A73E8
Icon:         keyboard_arrow_up, 20dp, #FFFFFF
Shadow:       Level 1
Position:     16dp from right, 16dp above bottom nav
```

### 4.11 Bar Chart (Publications Per Year)

```
Bar color:          #1A73E8
Bar radius (top):   4dp
Bar width:          ~22dp
Bar gap:            6dp
Selected bar:       #1557B0 (darker shade)
X-axis labels:      label-small (11sp), #80868B
Y-axis labels:      label-small (11sp), #80868B
Guide lines:        0.5px dotted, #F1F3F4 (horizontal only)
Trend line:         2dp dashed, #EA4335
Tooltip:            bg #202124, white text 12sp, radius 6dp, pointer triangle below
Chart height:       180dp inside card
```

### 4.12 Area / Sparkline Chart (Dashboard)

```
Line stroke:    2dp, #1A73E8
Area fill:      #E8F0FE
Data points:    4dp filled circle, #1A73E8
No axis labels  (decorative sparkline only)
Height:         80dp (dashboard mini) / 180dp (full trend)
```

### 4.13 Ranked Progress Bar (Top Journals)

```
Track:    80dp × 6dp, bg #F1F3F4, radius 3dp
Fill:     #1A73E8, proportional to max value
Gap:      8dp between bar and count label
Label:    label-medium (12sp), #1A73E8, right-aligned
```

---

## 5. Screen-by-Screen Design Specifications

### Screen 1 — Search Screen

**Route:** `/search` | **Nav tab:** Search (index 0)

| Zone | Spec |
|---|---|
| App bar | Title "Journal Trend Analyzer", right: filter icon |
| Search bar | Pill, 48dp, #F1F3F4, placeholder "Search research topics…" |
| Topic chips | Horizontal scroll, 8dp gap, 12dp top margin |
| Results label | "Results for [topic] · N papers", body-small, #5F6368 |
| Result card | Flat (no shadow), divider-separated, title + journal + chips row |
| Loading state | 2 shimmer skeleton cards |
| Empty state | Centered icon + message + clear button |

**Result card detail:**
- Title: `title-large`, #202124, max 2 lines
- Journal: `body-small`, #5F6368, 1 line, 8dp below title
- Chips row: year chip + citation chip + spacer + chevron-right icon

### Screen 2 — Publication Detail Screen

**Route:** `/publication/:id` | **Nav tab:** none (pushed route)

| Zone | Spec |
|---|---|
| App bar | Back arrow (#1A73E8), "Publication Details", share + bookmark |
| Hero title | `headline-medium`, #202124, max 3 lines |
| Metadata pills | Year chip + journal chip + DOI tappable chip, wrap row |
| Citation card | Full-width #E8F0FE card, trophy icon + "12,847" number + label |
| Authors | Section header + horizontal scroll of author chips |
| Abstract | Section header + body text, fade after 4 lines + "Show more" |
| Keywords | Wrap row of flat topic chips |
| Stats row | 3 equal mini-cards: year, authors, journal |
| Sticky CTA | "Open paper (DOI)" full-width pill button + DOI url label |

### Screen 3 — Trend Analysis Screen

**Route:** `/trends` | **Nav tab:** Trends (index 1)

| Zone | Spec |
|---|---|
| App bar | "Trend Analysis", date-range + share icons |
| Topic context bar | Sticky 44dp bar: "Topic:" label + active chip + paper count |
| Bar chart card | "Publications per year", BarChart 180dp, year tooltips |
| Top Journals list | Ranked flat list, 5 items, rank circle + name + progress bar |
| Top Authors list | Ranked flat list, 5 items, rank circle + name + avatar + count |

### Screen 4 — Research Dashboard Screen

**Route:** `/dashboard` | **Nav tab:** Dashboard (index 2)

| Zone | Spec |
|---|---|
| App bar | "Research Dashboard", refresh + more-vert icons |
| Hero card | Full-width blue card, topic name + sparkline + growth % |
| KPI grid | 2×2 grid, 159dp wide cells, icon + value + label |
| Influential paper | Left-accent card, trophy icon + title + citation chip |
| Top journal + author | Side-by-side 50% cards |
| Trend mini-chart | Area chart 80dp, "View full →" link |

### Screen 5 — Top Papers Screen

**Route:** `/top-papers` | **Nav tab:** Top Papers (index 3)

| Zone | Spec |
|---|---|
| App bar | "Most Influential Papers", filter icon |
| Subtitle | "Ranked by citation count · [topic]", body-small |
| Sort filter bar | Sticky 44dp, horizontal chip row: Citation count (active), Year, Relevance, A–Z |
| Papers list | Ranked flat list, gold/silver/bronze + numbered badges, title + journal + author + count |
| FAB | Scroll-to-top, 48dp, blue, up-arrow |

---

## 6. Motion & Interaction

### 6.1 Transitions

| Transition | Spec |
|---|---|
| Screen push (Search → Detail) | Shared element hero: paper title scales up + fades in |
| Bottom nav switch | Fade cross-dissolve, 200ms, ease-in-out |
| Card tap ripple | Material ripple, primary color at 12% opacity |
| Chip selection | Color fill crossfade, 150ms |
| FAB appear/disappear | Scale + fade, 200ms |

### 6.2 Loading

| State | Behavior |
|---|---|
| API call in progress | Shimmer skeleton replaces content area |
| Pull-to-refresh | Material circular progress indicator, #1A73E8 |
| Chart rendering | Bars animate in from y=0 upward, 300ms stagger |

### 6.3 Scroll Behaviors

| Element | Behavior |
|---|---|
| App bar | Elevates (adds shadow) on scroll, stays fixed |
| Topic context bar (Trends) | Sticks below app bar on scroll |
| Sort filter bar (Top Papers) | Sticks below app bar on scroll |
| Sticky CTA (Detail) | Always pinned above bottom nav, content scrolls under |
| FAB (Top Papers) | Appears after user scrolls past fold |

---

## 7. Accessibility

- All interactive elements have minimum **48dp touch target**
- Color is never the sole differentiator — rank badges use both color and number
- Chart bars include data point labels (tooltip) for screen reader support
- Contrast ratios: all text combinations meet **WCAG AA (4.5:1 minimum)**
- Chip selected state uses both color and border change (not color alone)
- Shimmer loaders include `semanticsLabel` for screen readers

---

## 8. Dark Mode

The app supports system dark mode via Flutter's `ThemeData` dark variant. All tokens map as follows:

| Light | Dark |
|---|---|
| Surface `#F8F9FA` | `#1C1C1E` |
| On-Surface `#202124` | `#E8EAED` |
| Surface-variant `#F1F3F4` | `#2C2C2E` |
| Card bg `#FFFFFF` | `#2A2A2C` |
| Outline `#DADCE0` | `#3C4043` |
| Primary `#1A73E8` | `#7BAAF7` |
| Primary container `#D3E3FD` | `#1A3563` |

---

## 9. File & Asset Conventions

```
lib/
├── core/
│   └── theme/
│       ├── app_theme.dart         # ThemeData light + dark
│       ├── app_colors.dart        # All color constants
│       ├── app_text_styles.dart   # All TextStyle definitions
│       └── app_dimensions.dart    # Spacing + shape tokens
assets/
├── icons/                         # Any custom SVG icons
└── images/                        # Placeholder/empty state illustrations
```

All color values, text styles, and spacing values must be consumed from their token files. No hardcoded hex values or magic numbers in widget code.