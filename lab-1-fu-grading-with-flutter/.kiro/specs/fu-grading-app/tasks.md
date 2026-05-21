# Implementation Plan: FU Grading App

## Overview

Build the FU Grading Flutter desktop app incrementally, starting with the binary parser (the most critical piece), then the data model and state, then the UI layer, and finally the export and utility features. Each task builds directly on the previous ones with no orphaned code.

All code goes inside `d:\6_repositories\prm393-lab\lab-1-fu-grading-with-flutter\fu_grading\`.

---

## Tasks

- [x] 1. Project setup — dependencies, theme, and window configuration
  - Add dependencies to `pubspec.yaml`: `file_picker: ^8.1.2`, `excel: ^4.0.6`, `path_provider: ^2.1.4`, `provider: ^6.1.2`
  - Enable Windows desktop support: verify `windows/` folder exists and `flutter config --enable-windows-desktop` is set
  - Replace `main.dart` with app entry that sets window title to "FU Grading", minimum size 1024×600, and applies the dark Material 3 theme (`ColorScheme.dark`, surface `Color(0xFF1E1E2E)`, primary `Color(0xFF4A90D9)`)
  - Create `lib/utils/component_labels.dart` with the `kComponentLabels` map and `labelFor()` function as specified in the design
  - _Requirements: 6.1, 6.2_

- [x] 2. Data models
  - [x] 2.1 Create `lib/models/teacher_grade.dart` with `TeacherGrade`, `SubjectClassGrade`, `Student`, `GradeComponent` classes
    - All fields as specified in the design; `GradeComponent.grade` is `double?` (null = missing)
    - Add `copyWith` methods to `Student` and `GradeComponent` for immutable updates
    - _Requirements: 1.2, 1.7, 1.8_
  - [x] 2.2 Create `lib/models/fg_document.dart` with `FgDocument` class
    - Fields: `Uint8List buffer`, `TeacherGrade data`, `Map<(int,int,int), int> gradeOffsets`, `bool isDirty`
    - _Requirements: 1.4, 2.2_

- [x] 3. Score utilities
  - [x] 3.1 Create `lib/utils/score_utils.dart` with `ScoreUtils` class
    - Implement `clamp(double)`, `computeCopyScore(List<double?>, double)`, `isValid(double)` as specified in the design
    - _Requirements: 4.4, 4.5, 4.6, 7.4_
  - [ ]* 3.2 Write property test for score utilities
    - **Property 4: Score Clamping Invariant** — for any list of source values and bonus, `computeCopyScore` returns a value in [0.0, 10.0] or null
    - **Property 6: Score Validation Boundary** — `isValid(x)` returns true iff `0.0 ≤ x ≤ 10.0`
    - Use `test` package with randomized inputs (generate 1000 random float combinations)
    - **Validates: Requirements 4.4, 4.5, 4.6, 7.4, 7.5**

- [x] 4. FgParser — binary reader (Phase 1: string extraction)
  - [x] 4.1 Create `lib/parser/fg_parser.dart` — skeleton and helper methods
    - Implement `_readInt32LE(int pos)`, `_readFloat32LE(int pos)`, `_read7BitEncodedInt(int pos)` helpers
    - Implement `_extractStrings()`: scan buffer for `0x06` type tags, read 4-byte object ID, 7-bit-encoded length, UTF-8 string; return `Map<int, String>`
    - _Requirements: 1.2_
  - [ ]* 4.2 Write unit test for string extraction
    - Construct a minimal synthetic buffer containing known string records and verify `_extractStrings()` returns the correct map
    - Test with multi-byte UTF-8 strings (Vietnamese names)
    - _Requirements: 1.2_

- [ ] 5. FgParser — binary reader (Phase 2: grade float extraction)
  - [x] 5.1 Implement `_extractGrades()` in `fg_parser.dart`
    - Scan buffer for `0x08 0x0B` pattern (Single field marker) in the grade data section (latter portion of file)
    - For each match, record the byte offset of the 4-byte float that follows
    - For `0x0A` (null grade marker), record null for that grade slot
    - Associate each grade offset with its (classIndex, studentIndex, componentIndex) triple using the ordering established by the string extraction pass
    - _Requirements: 1.7, 1.8_
  - [x] 5.2 Implement `parse()` method to assemble `FgDocument` from extracted strings and grades
    - Map extracted strings to `TeacherGrade` fields: `Versio`, `Semester`, `Logi`, `Password`
    - Map subject/class string pairs to `SubjectClassGrade` instances
    - Map Roll/Name strings and grade values to `Student` and `GradeComponent` instances
    - Populate `gradeOffsets` map with recorded byte offsets
    - _Requirements: 1.2, 1.3, 1.5_
  - [ ]* 5.3 Write property test for parser
    - **Property 9: Parser Extracts All Students** — load the reference file `phuonglhkSpring2024.fg`, verify the parsed document contains the expected number of SubjectClassGrades and students
    - **Property 1: Float Round-Trip Fidelity** — for any float in [0.0, 10.0], encode as 4-byte LE then decode; result must equal original within single-precision tolerance
    - **Validates: Requirements 1.2, 1.5, 1.7**

- [x] 6. FgWriter — PatchSave
  - [x] 6.1 Create `lib/parser/fg_writer.dart` with `FgWriter.patchSave(FgDocument)` static method
    - Copy `doc.buffer` to a new `Uint8List`
    - For each grade in the document where `grade != null` and an offset exists in `gradeOffsets`, write the 4-byte LE float at that offset
    - Return the patched buffer
    - _Requirements: 2.2, 2.8_
  - [ ]* 6.2 Write property test for PatchSave
    - **Property 2: PatchSave Preserves Non-Grade Bytes** — load reference file, edit one grade, call patchSave; verify only the 4 bytes at the recorded offset differ
    - **Property 3: No-Edit Round-Trip Identity** — load reference file, call patchSave with no edits; verify output buffer equals input buffer byte-for-byte
    - **Validates: Requirements 2.2, 2.5**

- [] 7. Checkpoint — parser and writer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. AppState provider
  - Create `lib/providers/app_state.dart` as a `ChangeNotifier`
  - Fields: `FgDocument? document`, `int activeClassIndex`, `String? filePath`
  - Methods: `loadFile(String path)`, `saveFile()`, `saveFileAs(String path)`, `updateGrade(int ci, int si, int gi, double? value)`, `applyColumnCopy(int ci, List<int> srcCols, int dstCol, double bonus)`
  - `updateGrade` sets `isDirty = true` and calls `notifyListeners()`
  - Wire `Provider<AppState>` into `main.dart`
  - _Requirements: 1.4, 2.2, 4.8_

- [x] 9. File service
  - Create `lib/services/file_service.dart`
  - `pickFgFile()` → uses `file_picker` to open a `.fg` file, returns path or null
  - `saveFgFile(String path, Uint8List bytes)` → writes bytes to path
  - `pickSavePath()` → opens save dialog with `.fg` filter, returns path or null
  - _Requirements: 1.1, 2.3, 2.4_

- [x] 10. Home screen — layout skeleton
  - Create `lib/screens/home_screen.dart` with the three-panel layout: top toolbar, left sidebar, main content area
  - Toolbar buttons: Open, Save, Save As, Export Excel, Check Missing, Copy Columns
  - Sidebar: `ListView` of `SubjectClassGrade` labels; tapping sets `activeClassIndex` in `AppState`
  - Main area: placeholder `Text("Select a class")` when no document loaded
  - Wire toolbar "Open" button to `FileService.pickFgFile()` → `AppState.loadFile()`
  - _Requirements: 1.1, 1.3, 6.2_

- [x] 11. GradeTable widget
  - [x] 11.1 Create `lib/widgets/grade_table.dart`
    - Accept `SubjectClassGrade scg` and `int classIndex` as parameters
    - Use `SingleChildScrollView` (both axes) wrapping a `DataTable`
    - Columns: Roll, Name (clickable), one column per component
    - Rows: one per student; alternating row colors; missing score cells use warning background `Color(0xFF5C2A2A)`
    - Name cell is a `TextButton` that opens `StudentDetailDialog`
    - _Requirements: 1.5, 5.4, 6.3, 6.4, 7.1_
  - [x] 11.2 Wire GradeTable into HomeScreen main area
    - Use `Consumer<AppState>` to rebuild when `activeClassIndex` or `document` changes
    - Show `GradeTable` for the active `SubjectClassGrade`
    - _Requirements: 1.3, 1.5_

- [x] 12. Confirm dialog widget
  - Create `lib/widgets/confirm_dialog.dart` — a reusable `AlertDialog` with a message, "Confirm" and "Cancel" buttons
  - Returns `bool` from `showDialog`
  - _Requirements: 8.1, 8.2, 8.3, 8.5, 8.6_

- [x] 13. Save and Save As actions
  - Wire toolbar "Save" button: show `ConfirmDialog` with file path → call `AppState.saveFile()` → show `SnackBar` success or error dialog
  - Wire toolbar "Save As" button: call `FileService.pickSavePath()` → call `AppState.saveFileAs(path)` → show success or error
  - Show confirmation dialog when opening a new file while `isDirty == true`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 2.7, 8.1, 8.3_

- [x] 14. Student Detail dialog
  - [x] 14.1 Create `lib/widgets/student_detail_dialog.dart`
    - Header: Roll + Name
    - Body: `ListView` of rows, each row has label (from `labelFor()`) and a `TextFormField` for the score
    - Pre-populate fields with current grade values; empty field for null grades
    - Validate on change: reject non-numeric or out-of-range [0.0, 10.0] values with inline error text
    - On dialog close (`WillPopScope` or `onClose`): collect all valid edits and call `AppState.updateGrade()` for each changed value
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_
  - [ ]* 14.2 Write unit test for Student Detail dialog validation
    - Test that values outside [0.0, 10.0] are rejected
    - Test that valid values are accepted and applied to AppState
    - _Requirements: 7.4, 7.5_

- [] 15. Checkpoint — UI and save flow working end-to-end
  - Ensure all tests pass, ask the user if questions arise.

- [x] 16. Missing scores feature
  - [x] 16.1 Create `lib/utils/score_utils.dart` addition: `findMissingScores(FgDocument)` function
    - Returns `List<({String subject, String classCode, String roll, String name, String component})>`
    - Iterates all SubjectClassGrades → Students → GradeComponents where `grade == null`
    - _Requirements: 5.1, 5.2_
  - [x] 16.3 Create `lib/widgets/missing_scores_dialog.dart`
    - Shows a scrollable list grouped by SubjectClassGrade
    - Each entry shows: subject+class, Roll, Name, Component name
    - Shows "All scores complete" message when list is empty
    - _Requirements: 5.2, 5.3_
  - [x] 16.4 Wire "Check Missing" toolbar button to open `MissingScoresDialog`
    - _Requirements: 5.1_

- [x] 17. Copy Columns dialog
  - [x] 17.1 Create `lib/widgets/copy_columns_dialog.dart`
    - Source column multi-select checkboxes (one per component in active class)
    - Destination column dropdown
    - Bonus amount `TextFormField` (numeric, range -10.0 to 10.0)
    - "Preview" button: computes new scores using `ScoreUtils.computeCopyScore` and shows a preview `DataTable` with columns: Name, Current Destination, New Score
    - "Apply" button: shows `ConfirmDialog` summarizing the operation, then calls `AppState.applyColumnCopy()`
    - _Requirements: 4.1, 4.2, 4.3, 4.7, 4.8, 8.2_
  - [x] 17.3 Wire "Copy Columns" toolbar button to open `CopyColumnsDialog`
    - _Requirements: 4.1_

- [x] 18. Excel export
  - [x] 18.1 Create `lib/services/excel_service.dart`
    - `exportToExcel(FgDocument doc, String path)` method
    - For each `SubjectClassGrade`: create a sheet named `<subject>_<classCode>` (max 31 chars)
    - Write header row: `["Roll", "Name", ...components]`
    - Write one data row per student; null grades become empty cells
    - Save workbook to `path`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
  - [x] 18.3 Wire "Export Excel" toolbar button
    - Call `FileService.pickExcelSavePath()` → `ExcelService.exportToExcel()` → show success `SnackBar` or error dialog
    - `pickExcelSavePath()` already added to `FileService` (`.xlsx` filter)
    - _Requirements: 3.1, 3.7, 3.8_

- [x] 19. Loading indicator and disabled controls during file operations
  - Wrap file open, save, and export operations in `setState` that sets a `_loading` flag
  - Show `LinearProgressIndicator` in toolbar area while `_loading == true`
  - Disable all toolbar buttons while `_loading == true`
  - _Requirements: 6.5_

- [] 20. Final checkpoint — all features integrated and tests pass
  - Ensure all tests pass, ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- The reference file `subject-1/phuonglhkSpring2024.fg` should be used as the primary test fixture for parser tests
- Grade floats in the binary are 4-byte little-endian IEEE 754 singles; the `08 0B` prefix marks a present grade, `0A` marks a null/missing grade
- PatchSave only modifies the 4 bytes at recorded offsets — never re-serializes the BinaryFormatter structure
- All file paths in tests should use relative paths or be configurable to avoid hardcoded machine paths
- The `excel` package sheet name limit is 31 characters; truncate `<subject>_<classCode>` if needed

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2"] },
    { "wave": 3, "tasks": ["3", "4"] },
    { "wave": 4, "tasks": ["5"] },
    { "wave": 5, "tasks": ["6"] },
    { "wave": 6, "tasks": ["7"] },
    { "wave": 7, "tasks": ["8", "9"] },
    { "wave": 8, "tasks": ["10"] },
    { "wave": 9, "tasks": ["11", "12"] },
    { "wave": 10, "tasks": ["13", "14"] },
    { "wave": 11, "tasks": ["15"] },
    { "wave": 12, "tasks": ["16", "17", "18"] },
    { "wave": 13, "tasks": ["19"] },
    { "wave": 14, "tasks": ["20"] }
  ]
}
```
