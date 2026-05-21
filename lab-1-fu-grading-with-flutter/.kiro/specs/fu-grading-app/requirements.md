# Requirements Document

## Introduction

FU Grading App is a Flutter desktop application (Windows-primary) for FPT University teachers to manage student grades. Teachers import proprietary `.fg` files (serialized with .NET BinaryFormatter), view and edit scores across multiple subject-class lists, export to Excel, copy score columns with optional bonuses, and save changes back to `.fg` format with full round-trip fidelity.

## Glossary

- **FgFile**: A `.fg` binary file produced by the FuGrade tool, serialized using .NET BinaryFormatter.
- **TeacherGrade**: The root object in an FgFile containing metadata and a list of SubjectClassGrades.
- **SubjectClassGrade**: A subject+class pairing (e.g., "PRN221" + "NET1710") containing a student list and component names.
- **Student**: A student record with a roll number, Vietnamese name, a list of GradeComponents, and a comment.
- **GradeComponent**: A named score entry (e.g., "Final Exam", "Assignment 1") with a float grade value (0.0–10.0) or null (missing).
- **Component**: A grade category name string stored in SubjectClassGrade.Components (e.g., "Final Exam", "Progress Test 1").
- **Roll**: A student ID string (e.g., "SE160367").
- **App**: The FU Grading Flutter desktop application.
- **GradeTable**: The main data grid showing students as rows and grade components as columns.
- **ScoreColumn**: A single GradeComponent column in the GradeTable.
- **BinaryBuffer**: The raw byte array of the loaded FgFile, kept in memory for round-trip saving.
- **PatchSave**: The save strategy that modifies only the 4-byte float offsets in the BinaryBuffer rather than re-serializing the entire structure.

---

## Requirements

### Requirement 1: Import .fg File

**User Story:** As a teacher, I want to import a `.fg` file so that I can view and manage all student class lists it contains.

#### Acceptance Criteria

1. WHEN the user activates the "Open File" action, THE App SHALL open a native file picker filtered to `.fg` files.
2. WHEN a valid `.fg` file is selected, THE App SHALL parse the BinaryFormatter stream and load all TeacherGrade fields: `Versio`, `Semester`, `Logi`, `Password`, and `SubjectClassGrades`.
3. WHEN a valid `.fg` file is loaded, THE App SHALL display each SubjectClassGrade as a separate tab or panel, labeled with its subject code and class code.
4. WHEN a valid `.fg` file is loaded, THE App SHALL retain the original BinaryBuffer in memory for use during PatchSave.
5. WHEN a valid `.fg` file is loaded, THE App SHALL display each Student's Roll, Name, and all GradeComponent values in a GradeTable for that SubjectClassGrade.
6. IF the selected file cannot be parsed as a valid FgFile, THEN THE App SHALL display an error dialog with a human-readable message and leave the current state unchanged.
7. WHEN a `.fg` file is loaded, THE App SHALL parse each GradeComponent's Grade field as a 4-byte little-endian IEEE 754 single-precision float.
8. WHEN a GradeComponent's Grade field is absent or null in the binary stream, THE App SHALL represent that score as null (missing) in the in-memory model.

---

### Requirement 2: Save Changes to .fg File

**User Story:** As a teacher, I want to save my grade edits back to a `.fg` file so that changes are persisted in the original format.

#### Acceptance Criteria

1. WHEN the user activates "Save", THE App SHALL display a confirmation dialog before overwriting the currently loaded file.
2. WHEN the user confirms "Save", THE App SHALL write the modified BinaryBuffer to the original file path using PatchSave, replacing only the 4-byte float offsets of changed scores.
3. WHEN the user activates "Save As", THE App SHALL open a native file save dialog with a `.fg` extension filter.
4. WHEN the user confirms "Save As" with a new path, THE App SHALL write the modified BinaryBuffer to the new file path.
5. THE App SHALL preserve all original bytes in the BinaryBuffer that are not score float values, ensuring round-trip fidelity for all non-score fields.
6. WHEN a save operation completes successfully, THE App SHALL display a brief success notification.
7. IF a save operation fails due to a file system error, THEN THE App SHALL display an error dialog with the failure reason and leave the file unchanged.
8. WHEN a score value is written during PatchSave, THE App SHALL encode it as a 4-byte little-endian IEEE 754 single-precision float at the exact byte offset recorded during parsing.

---

### Requirement 3: Export to Excel

**User Story:** As a teacher, I want to export grade data to an Excel file so that I can share or archive student scores in a standard format.

#### Acceptance Criteria

1. WHEN the user activates "Export to Excel", THE App SHALL open a native file save dialog with an `.xlsx` extension filter.
2. WHEN the user confirms the export path, THE App SHALL create an Excel workbook where each SubjectClassGrade is written to a separate sheet.
3. THE App SHALL name each sheet using the pattern `<SubjectCode>_<ClassCode>` (e.g., `PRN221_NET1710`).
4. WHEN writing a sheet, THE App SHALL include a header row with "Roll", "Name", and one column per Component name.
5. WHEN writing a sheet, THE App SHALL write one data row per Student with Roll, Name, and each GradeComponent value in the corresponding column.
6. WHEN a GradeComponent value is null (missing), THE App SHALL write an empty cell for that score.
7. IF the export operation fails, THEN THE App SHALL display an error dialog with the failure reason.
8. WHEN the export completes successfully, THE App SHALL display a brief success notification.

---

### Requirement 4: Copy Score Columns with Bonus

**User Story:** As a teacher, I want to copy one or more score columns to another column with an optional bonus so that I can adjust grades efficiently.

#### Acceptance Criteria

1. WHEN the user activates the "Copy Columns" action, THE App SHALL display a dialog to select one or more source ScoreColumns and one destination ScoreColumn.
2. WHEN the user specifies a bonus amount in the Copy Columns dialog, THE App SHALL accept a numeric value between -10.0 and 10.0.
3. WHEN the user requests a preview in the Copy Columns dialog, THE App SHALL display a preview table showing each student's current destination score and the computed new score before applying.
4. WHEN multiple source columns are selected, THE App SHALL compute the new destination score as the average of the selected source columns' values plus the bonus amount.
5. WHEN the computed score exceeds 10.0, THE App SHALL clamp it to 10.0.
6. WHEN the computed score is below 0.0, THE App SHALL clamp it to 0.0.
7. WHEN the user confirms the copy operation, THE App SHALL display a confirmation dialog before applying changes.
8. WHEN the user confirms the copy operation, THE App SHALL update the destination ScoreColumn for all students in the active SubjectClassGrade.
9. WHEN a source GradeComponent value is null for a student, THE App SHALL treat that student's source value as null and leave the destination score unchanged for that student.

---

### Requirement 5: Missing Score Check

**User Story:** As a teacher, I want to check for missing scores so that I can identify students with incomplete grade records.

#### Acceptance Criteria

1. WHEN the user activates "Check Missing Scores", THE App SHALL scan all GradeComponent values across all SubjectClassGrades in the loaded FgFile.
2. WHEN missing scores are found, THE App SHALL display a summary listing each SubjectClassGrade, the affected Student Roll and Name, and the Component name with the missing score.
3. WHEN no missing scores are found, THE App SHALL display a message confirming that all scores are complete.
4. THE App SHALL highlight rows with missing scores in the GradeTable using a distinct visual indicator (e.g., a warning color on the cell).

---

### Requirement 6: Eye-Friendly UI

**User Story:** As a teacher, I want a simple, visually comfortable UI so that I can work with grade data for extended periods without eye strain.

#### Acceptance Criteria

1. THE App SHALL apply a dark or neutral-dark Material Design theme with low-contrast background colors (surface brightness ≤ 30% on a 0–100% scale).
2. THE App SHALL use a desktop-appropriate layout with a wide GradeTable, a sidebar or tab panel for SubjectClassGrade navigation, and a top toolbar for primary actions.
3. THE App SHALL use a readable sans-serif font at a minimum size of 13sp for table content.
4. THE App SHALL provide horizontal and vertical scrolling for the GradeTable when content exceeds the visible area.
5. WHILE a file operation (open, save, export) is in progress, THE App SHALL display a loading indicator and disable interactive controls.

---

### Requirement 7: Student Detail Popup

**User Story:** As a teacher, I want to view and edit a student's scores in a popup so that I can review and correct individual grade records quickly.

#### Acceptance Criteria

1. WHEN the user clicks a student's Name cell in the GradeTable, THE App SHALL open a Student Detail dialog for that student.
2. THE Student Detail dialog SHALL display the student's Roll and Name as a header.
3. THE Student Detail dialog SHALL list all GradeComponents in a two-column layout: the left column shows a human-readable label mapped from the Component name, and the right column shows an editable score field.
4. WHEN a score field in the Student Detail dialog is edited, THE App SHALL validate that the entered value is a number between 0.0 and 10.0.
5. IF an entered score value is outside the range 0.0–10.0, THEN THE App SHALL display an inline validation error and prevent saving that value.
6. WHEN the user closes the Student Detail dialog, THE App SHALL apply all valid edits to the in-memory model and mark the file as having unsaved changes.
7. THE App SHALL map Component names to human-readable labels using a predefined mapping (e.g., "Final Exam" → "Final Exam", "Assignment 1" → "Assignment 1", "Progress Test 1" → "Progress Test 1"); unmapped names SHALL be displayed as-is.

---

### Requirement 8: Confirmation Dialogs

**User Story:** As a teacher, I want confirmation prompts for important actions so that I do not accidentally overwrite or lose data.

#### Acceptance Criteria

1. WHEN the user initiates a "Save" (overwrite) action, THE App SHALL display a confirmation dialog with the target file path before writing.
2. WHEN the user initiates a "Copy Columns" apply action, THE App SHALL display a confirmation dialog summarizing the source columns, destination column, and bonus amount before applying.
3. WHEN the user attempts to open a new file while there are unsaved changes, THE App SHALL display a confirmation dialog warning about unsaved changes before proceeding.
4. WHEN the user closes the Student Detail dialog after making edits, THE App SHALL apply changes without a separate confirmation (inline save-on-close behavior).
5. THE App SHALL provide "Confirm" and "Cancel" options in every confirmation dialog.
6. WHEN the user selects "Cancel" in any confirmation dialog, THE App SHALL abort the action and leave all state unchanged.
