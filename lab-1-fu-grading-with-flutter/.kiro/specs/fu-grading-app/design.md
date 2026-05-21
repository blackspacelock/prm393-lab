# Design Document — FU Grading App

## Overview

FU Grading App is a Flutter desktop application (Windows-primary) that lets FPT University teachers import `.fg` grade files, view and edit student scores across multiple subject-class lists, export to Excel, copy score columns with optional bonuses, and save changes back to `.fg` format with full binary round-trip fidelity.

The most critical and complex component is the **FgParser** — a custom Dart binary reader that navigates the .NET BinaryFormatter stream to extract student data and record the exact byte offsets of every grade float, enabling in-place patching on save.

---

## Architecture

```
lib/
├── main.dart                    # App entry, theme, window setup
├── models/
│   ├── teacher_grade.dart       # TeacherGrade, SubjectClassGrade, Student, GradeComponent
│   └── fg_document.dart         # FgDocument: parsed model + BinaryBuffer + offset map
├── parser/
│   ├── fg_parser.dart           # FgParser: .NET BinaryFormatter reader
│   └── fg_writer.dart           # FgWriter: PatchSave (in-place float patching)
├── services/
│   ├── file_service.dart        # file_picker open/save wrappers
│   └── excel_service.dart       # Excel export using the excel package
├── providers/
│   └── app_state.dart           # ChangeNotifier: loaded document, dirty flag, active class
├── screens/
│   └── home_screen.dart         # Main layout: toolbar + sidebar + grade table
├── widgets/
│   ├── grade_table.dart         # Scrollable DataTable for one SubjectClassGrade
│   ├── student_detail_dialog.dart  # Popup: two-column score editor
│   ├── copy_columns_dialog.dart    # Copy columns with bonus + preview
│   ├── missing_scores_dialog.dart  # Missing score summary
│   └── confirm_dialog.dart         # Reusable confirmation dialog
└── utils/
    ├── component_labels.dart    # Human-readable label mapping
    └── score_utils.dart         # clamp, average, validation helpers
```

---

## Data Models

```dart
// models/teacher_grade.dart

class TeacherGrade {
  final String versio;       // "1.1"
  final String semester;     // e.g. "Spring2024"
  final String logi;         // username
  final String password;     // MD5 hash
  final List<SubjectClassGrade> subjectClassGrades;
}

class SubjectClassGrade {
  final String subject;      // e.g. "PRN221"
  final String classCode;    // e.g. "NET1710"
  final List<String> components;   // ordered component names
  final List<Student> students;
}

class Student {
  final String roll;         // e.g. "SE160367"
  final String name;         // Vietnamese UTF-8 name
  final List<GradeComponent> grades;
  final String comment;
}

class GradeComponent {
  final String component;    // e.g. "Final Exam"
  double? grade;             // null = missing; 0.0–10.0 when present
}
```

```dart
// models/fg_document.dart

class FgDocument {
  final Uint8List buffer;          // original file bytes (BinaryBuffer)
  final TeacherGrade data;
  // Map from (classIndex, studentIndex, componentIndex) → byte offset in buffer
  // where the 4-byte float starts
  final Map<(int, int, int), int> gradeOffsets;
  bool isDirty = false;
}
```

---

## FgParser — .NET BinaryFormatter Reader

### Binary Format Overview

The `.fg` file is a .NET BinaryFormatter stream. Key structural observations from the reference file:

- **Header**: `00 01 00 00 00 FF FF FF FF 01 00 00 00 00 00 00 00` (SerializationHeaderRecord)
- **Assembly record** (`0C`): declares `FuGradeLib, Version=1.0.0.0, ...`
- **Class records** (`05`, `04`): define field layouts for `TeacherGrade`, `SubjectClassGrade`, `Student`, `GradeComponent`
- **String values** (`06`): preceded by a 4-byte object ID and a length-prefixed UTF-8 string
- **Object references** (`09`): 4-byte reference to a previously defined object
- **List data** (`0D 02`): array/list contents with element count
- **Grade float records**: pattern `08 0B <4-byte-LE-float>` for a present grade; `0A` for a null/missing grade

### Parsing Strategy: Two-Pass Scan

Because the BinaryFormatter interleaves type definitions with data in a complex object graph, the parser uses a **two-pass approach**:

**Pass 1 — String extraction**: Scan the entire buffer for string records (`06` type tag) and build a map of `objectId → string value`. This captures all Roll numbers, Names, Component names, semester, username, etc.

**Pass 2 — Grade float extraction**: Scan for the grade data section. Grade records appear in the latter portion of the file in the pattern:
```
<index-byte> 15 00 00  0C 0B 00 00  09 <obj-ref 4 bytes>  08 0B <float 4 bytes>  01
```
or for null grades:
```
<index-byte> 15 00 00  0C 0B 00 00  09 <obj-ref 4 bytes>  0A  01
```

The parser records the byte offset of each `<float 4 bytes>` block for use in PatchSave.

### String Record Format

```
06                    // type tag: BinaryObjectString
<id: 4 bytes LE>      // object ID
<length: 1–4 bytes>   // 7-bit encoded length (BinaryFormatter LEB128)
<utf8 bytes>          // string content
```

### Grade Float Record Format

In the grade data section (latter ~70% of file), each GradeComponent value appears as:
```
08 0B <b0> <b1> <b2> <b3>   // present grade: Single field, 4-byte LE float
0A                            // null/missing grade
```

The parser records the offset of `<b0>` for each present grade.

### Dart Implementation Sketch

```dart
// parser/fg_parser.dart

class FgParser {
  final Uint8List _buf;
  int _pos = 0;

  FgParser(this._buf);

  FgDocument parse() {
    // Pass 1: extract all string objects
    final strings = _extractStrings();

    // Pass 2: extract grade floats and their offsets
    final gradeData = _extractGrades();

    // Assemble model from extracted data
    final teacherGrade = _assembleModel(strings, gradeData);

    return FgDocument(
      buffer: Uint8List.fromList(_buf),
      data: teacherGrade,
      gradeOffsets: gradeData.offsets,
    );
  }

  Map<int, String> _extractStrings() {
    final result = <int, String>{};
    for (int i = 0; i < _buf.length - 6; i++) {
      if (_buf[i] == 0x06) {
        // Attempt to read string record at position i
        try {
          final id = _readInt32LE(i + 1);
          final (len, advance) = _read7BitEncodedInt(i + 5);
          if (len > 0 && len < 1000 && i + 5 + advance + len <= _buf.length) {
            final str = utf8.decode(_buf.sublist(i + 5 + advance, i + 5 + advance + len));
            result[id] = str;
          }
        } catch (_) {}
      }
    }
    return result;
  }

  ({List<_GradeEntry> entries, Map<(int,int,int), int> offsets}) _extractGrades() {
    // Scan for "08 0B" pattern (Single field marker) in grade data section
    // Record offset of the 4-byte float that follows
    final entries = <_GradeEntry>[];
    final offsets = <(int,int,int), int>{};
    // ... implementation details
    return (entries: entries, offsets: offsets);
  }

  int _readInt32LE(int pos) =>
      _buf[pos] | (_buf[pos+1] << 8) | (_buf[pos+2] << 16) | (_buf[pos+3] << 24);

  double _readFloat32LE(int pos) =>
      ByteData.sublistView(_buf, pos, pos + 4).getFloat32(0, Endian.little);

  (int value, int bytesRead) _read7BitEncodedInt(int pos) {
    int result = 0, shift = 0, bytesRead = 0;
    while (true) {
      final b = _buf[pos + bytesRead++];
      result |= (b & 0x7F) << shift;
      shift += 7;
      if ((b & 0x80) == 0) break;
    }
    return (result, bytesRead);
  }
}
```

---

## FgWriter — PatchSave

```dart
// parser/fg_writer.dart

class FgWriter {
  /// Patches grade float values in-place in the buffer.
  /// Only modifies the 4 bytes at each recorded offset.
  static Uint8List patchSave(FgDocument doc) {
    final out = Uint8List.fromList(doc.buffer);
    doc.data.subjectClassGrades.asMap().forEach((ci, scg) {
      scg.students.asMap().forEach((si, student) {
        student.grades.asMap().forEach((gi, gc) {
          if (gc.grade != null) {
            final offset = doc.gradeOffsets[(ci, si, gi)];
            if (offset != null) {
              final bd = ByteData(4);
              bd.setFloat32(0, gc.grade!.toDouble(), Endian.little);
              out.setRange(offset, offset + 4, bd.buffer.asUint8List());
            }
          }
        });
      });
    });
    return out;
  }
}
```

---

## Score Utilities

```dart
// utils/score_utils.dart

class ScoreUtils {
  static const double minScore = 0.0;
  static const double maxScore = 10.0;

  /// Clamps a score to [0.0, 10.0].
  static double clamp(double value) => value.clamp(minScore, maxScore);

  /// Computes the average of non-null source values, adds bonus, then clamps.
  /// Returns null if all source values are null.
  static double? computeCopyScore(List<double?> sources, double bonus) {
    final nonNull = sources.whereType<double>().toList();
    if (nonNull.isEmpty) return null;
    final avg = nonNull.reduce((a, b) => a + b) / nonNull.length;
    return clamp(avg + bonus);
  }

  /// Returns true if value is a valid score (0.0 ≤ value ≤ 10.0).
  static bool isValid(double value) => value >= minScore && value <= maxScore;
}
```

---

## Component Label Mapping

```dart
// utils/component_labels.dart

const Map<String, String> kComponentLabels = {
  'Final Exam': 'Final Exam',
  'Final Exam Resit': 'Final Exam (Resit)',
  'Assignment 1': 'Assignment 1',
  'Assignment 2': 'Assignment 2',
  'Progress Test 1': 'Progress Test 1',
  'Progress Test 2': 'Progress Test 2',
  'Lab 1': 'Lab 1',
  'Lab 2': 'Lab 2',
  'Quiz 1': 'Quiz 1',
  'Quiz 2': 'Quiz 2',
  'Quiz 3': 'Quiz 3',
  // Unmapped names fall through to display as-is
};

String labelFor(String component) => kComponentLabels[component] ?? component;
```

---

## UI Layout

### Home Screen

```
┌─────────────────────────────────────────────────────────────────┐
│  Toolbar: [Open] [Save] [Save As] [Export Excel] [Check Missing] │
├──────────────┬──────────────────────────────────────────────────┤
│  Sidebar     │  GradeTable (scrollable)                         │
│  ─────────── │  ┌──────┬──────────────────┬──────┬──────┬────┐ │
│  PRN221      │  │ Roll │ Name             │ Fin. │ Asgn │ …  │ │
│  NET1710  ◄  │  ├──────┼──────────────────┼──────┼──────┼────┤ │
│  ─────────── │  │SE160 │ Lê Vũ Đình Duy   │ 7.7  │ 8.1  │ …  │ │
│  SWD392      │  │SE160 │ Lê Ngô Hiệp Quốc │ 7.8  │  —   │ …  │ │
│  SAP1702     │  └──────┴──────────────────┴──────┴──────┴────┘ │
│  …           │                                                   │
└──────────────┴──────────────────────────────────────────────────┘
```

### Theme

- **Color scheme**: Dark Material 3 theme with `ColorScheme.dark(primary: Color(0xFF4A90D9), surface: Color(0xFF1E1E2E))`
- **Background**: `Color(0xFF1E1E2E)` (dark navy)
- **Surface**: `Color(0xFF2A2A3E)`
- **Table row alternating**: `Color(0xFF252535)` / `Color(0xFF2A2A3E)`
- **Missing score cell**: `Color(0xFF5C2A2A)` (muted red tint)
- **Font**: System default sans-serif, 13sp table content, 15sp headers

### Student Detail Dialog

```
┌─────────────────────────────────────────┐
│  SE160367 — Lê Vũ Đình Duy              │
│  ─────────────────────────────────────  │
│  Final Exam          │  [  7.7  ]        │
│  Final Exam (Resit)  │  [  —   ]         │
│  Assignment 1        │  [  8.1  ]        │
│  Progress Test 1     │  [  7.8  ]        │
│  …                                       │
│                          [Close]         │
└─────────────────────────────────────────┘
```

### Copy Columns Dialog

```
┌──────────────────────────────────────────────┐
│  Copy Score Columns                           │
│  Source columns: [✓] Final Exam  [✓] Asgn 1  │
│  Destination:    [ Assignment 2 ▼]            │
│  Bonus:          [ +0.5 ]                     │
│  [Preview]                                    │
│  ┌──────────────┬──────────┬──────────┐       │
│  │ Name         │ Current  │ New      │       │
│  │ Lê Vũ…      │  8.1     │  8.4     │       │
│  └──────────────┴──────────┴──────────┘       │
│                    [Cancel]  [Apply]           │
└──────────────────────────────────────────────┘
```

---

## Excel Export

Uses the `excel` Dart package. For each `SubjectClassGrade`:

1. Create a sheet named `<subject>_<classCode>` (truncated to 31 chars for Excel limit).
2. Write header row: `["Roll", "Name", ...components]`.
3. Write one row per student: `[roll, name, grade1, grade2, ...]` where null grades become empty cells.

---

## State Management

`AppState` (ChangeNotifier) holds:
- `FgDocument? document` — currently loaded document
- `int activeClassIndex` — which SubjectClassGrade tab is selected
- `String? filePath` — path of the loaded file

Key methods:
- `loadFile(String path)` — parse and set document
- `saveFile()` — PatchSave to `filePath`
- `saveFileAs(String path)` — PatchSave to new path
- `updateGrade(int ci, int si, int gi, double? value)` — update grade in model, mark dirty
- `applyColumnCopy(int ci, List<int> srcCols, int dstCol, double bonus)` — bulk update

---

## Components and Interfaces

| Component | Responsibility | Key Interface |
|---|---|---|
| `FgParser` | Parse .NET BinaryFormatter binary stream into `FgDocument` | `FgDocument parse()` |
| `FgWriter` | PatchSave: write modified grade floats in-place | `static Uint8List patchSave(FgDocument)` |
| `AppState` | Central ChangeNotifier; owns document, dirty flag, active class | `loadFile`, `saveFile`, `updateGrade`, `applyColumnCopy` |
| `FileService` | Wraps `file_picker` for open/save dialogs | `pickFgFile()`, `saveFgFile()`, `pickSavePath()` |
| `ExcelService` | Exports `FgDocument` to `.xlsx` using `excel` package | `exportToExcel(FgDocument, String path)` |
| `GradeTable` | Scrollable DataTable widget for one SubjectClassGrade | `Widget build(context)` |
| `StudentDetailDialog` | Popup editor for a single student's scores | `showDialog(...)` |
| `CopyColumnsDialog` | Multi-source column copy with bonus and preview | `showDialog(...)` |
| `MissingScoresDialog` | Summary of null-grade entries | `showDialog(...)` |
| `ConfirmDialog` | Reusable confirmation prompt | `Future<bool> show(context, message)` |
| `ScoreUtils` | Pure score computation helpers | `clamp`, `computeCopyScore`, `isValid` |
| `componentLabels` | Human-readable label mapping | `String labelFor(String component)` |

---

## Error Handling

| Scenario | Handling |
|---|---|
| File cannot be parsed as valid FgFile | Show `AlertDialog` with error message; leave current state unchanged |
| File system error during save | Show `AlertDialog` with OS error message; leave file unchanged |
| File system error during export | Show `AlertDialog` with OS error message |
| Score input outside [0.0, 10.0] | Inline `TextFormField` error text; prevent dialog close with invalid value |
| Bonus input outside [-10.0, 10.0] | Inline validation error in Copy Columns dialog |
| Empty source column selection | Disable "Apply" button in Copy Columns dialog |
| File picker cancelled | No-op; leave current state unchanged |

---

## Testing Strategy

**Unit tests** (in `test/` directory):
- `fg_parser_test.dart`: parse reference `.fg` file, verify field counts and values
- `fg_writer_test.dart`: load → no-edit save → byte-for-byte equality; load → edit one grade → only 4 bytes differ
- `score_utils_test.dart`: property tests for `computeCopyScore` and `isValid` with randomized inputs
- `excel_service_test.dart`: property tests for sheet count and row count

**Widget tests**:
- `student_detail_dialog_test.dart`: validation boundary tests
- `copy_columns_dialog_test.dart`: preview computation correctness

**Integration**:
- Manual smoke test: open `phuonglhkSpring2024.fg`, edit a grade, save, re-open, verify change persisted

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Float Round-Trip Fidelity

For any float value `v` in the range [0.0, 10.0], encoding `v` as a 4-byte little-endian IEEE 754 single and then decoding those 4 bytes must produce a value equal to `v` (within single-precision tolerance).

**Validates: Requirements 1.7, 2.8**

---

### Property 2: PatchSave Preserves Non-Grade Bytes

For any loaded FgDocument and any set of grade edits, the output of PatchSave must differ from the original BinaryBuffer only at the 4-byte offsets recorded in `gradeOffsets` for the edited grades. All other bytes must be identical.

**Validates: Requirements 2.2, 2.5**

---

### Property 3: No-Edit Round-Trip Identity

For any valid FgFile, loading it into an FgDocument and immediately calling PatchSave (with no edits) must produce a byte buffer identical to the original file bytes.

**Validates: Requirements 2.5**

---

### Property 4: Score Clamping Invariant

For any list of source score values and any bonus amount, `ScoreUtils.computeCopyScore` must return a value in [0.0, 10.0] (or null if all sources are null).

**Validates: Requirements 4.4, 4.5, 4.6**

---

### Property 5: Missing Score Detection Completeness

For any student list, `findMissingScores(students)` must return exactly the set of (student, component) pairs where `grade == null` — no more, no fewer.

**Validates: Requirements 5.1, 5.2**

---

### Property 6: Score Validation Boundary

For any numeric input `x`, `ScoreUtils.isValid(x)` must return `true` if and only if `0.0 ≤ x ≤ 10.0`.

**Validates: Requirements 7.4, 7.5**

---

### Property 7: Excel Sheet Count Matches Class Count

For any FgDocument with N SubjectClassGrades, the exported Excel workbook must contain exactly N sheets, each named `<subject>_<classCode>`.

**Validates: Requirements 3.2, 3.3**

---

### Property 8: Excel Row Count Matches Student Count

For any SubjectClassGrade with M students, the corresponding Excel sheet must contain exactly M + 1 rows (1 header + M data rows).

**Validates: Requirements 3.4, 3.5**

---

### Property 9: Parser Extracts All Students

For any valid FgFile containing a SubjectClassGrade with N students, the parsed FgDocument must contain exactly N Student records in that SubjectClassGrade.

**Validates: Requirements 1.2, 1.5**
