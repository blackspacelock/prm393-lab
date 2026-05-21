import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/fg_document.dart';
import '../models/teacher_grade.dart';
import '../parser/fg_parser.dart';
import '../parser/json_parser.dart';
import '../parser/fg_writer.dart';
import '../services/fg_deserializer_service.dart';
import '../utils/score_utils.dart';

/// Application state provider for the FU Grading app.
///
/// Manages the loaded `.fg` document, the currently active class, file path,
/// and provides methods for loading, saving, and editing grades.
class AppState extends ChangeNotifier {
  /// The loaded `.fg` file document, or null if no file is loaded.
  FgDocument? _document;

  /// The index of the currently selected subject-class grade.
  int _activeClassIndex = 0;

  /// The file path of the currently loaded document, or null if not saved yet.
  String? _filePath;

  // Getters

  FgDocument? get document => _document;
  int get activeClassIndex => _activeClassIndex;
  String? get filePath => _filePath;

  /// Returns true if the document has unsaved changes.
  bool get isDirty => _document?.isDirty ?? false;

  /// Returns the currently active [SubjectClassGrade], or null if no document is loaded.
  SubjectClassGrade? get activeSubjectClassGrade {
    if (_document == null ||
        _activeClassIndex >= _document!.data.subjectClassGrades.length) {
      return null;
    }
    return _document!.data.subjectClassGrades[_activeClassIndex];
  }

  // --- File Operations ---

  /// Loads a `.fg` file from the given [path].
  ///
  /// Reads the file and updates the state using the C# bridge on desktop when
  /// available, falling back to the Dart parser if needed.
  /// Throws an exception if the file cannot be read or parsed.
  Future<void> loadFile(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      await loadFileFromBytes(bytes, filePath: path);
    } catch (e) {
      rethrow;
    }
  }

  /// Loads a `.fg` file from bytes (used for web).
  ///
  /// Parses the provided bytes using the C# bridge on desktop when a file
  /// path is available, otherwise falls back to [FgParser].
  /// Throws an exception if the bytes cannot be parsed.
  Future<void> loadFileFromBytes(List<int> bytes, {String? filePath}) async {
    try {
      // Convert to Uint8List if needed
      final uint8bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      late final FgDocument doc;

      if (!kIsWeb && filePath != null) {
        try {
          final jsonString = await FgDeserializerService.deserializeToJson(
            filePath,
          );
          doc = JsonParser(jsonString).parse(buffer: uint8bytes);
        } catch (_) {
          final parser = FgParser(uint8bytes);
          doc = parser.parse();
        }
      } else {
        final parser = FgParser(uint8bytes);
        doc = parser.parse();
      }

      // Update state
      _document = doc;
      _filePath = filePath;
      _activeClassIndex = 0;

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Loads a JSON file from bytes (exported grade data).
  ///
  /// Parses the provided bytes as JSON using [JsonParser] and updates the state.
  /// Throws an exception if the JSON cannot be parsed.
  Future<void> loadJsonFromBytes(List<int> bytes) async {
    try {
      // Decode bytes to string
      final jsonString = utf8.decode(bytes);

      // Parse the JSON
      final parser = JsonParser(jsonString);
      final doc = parser.parse();

      // Update state
      _document = doc;
      _filePath = null; // No file path on web
      _activeClassIndex = 0;

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Saves the current document to the current file path.
  ///
  /// Uses [FgWriter.patchSave] to patch the original buffer with edited grades
  /// and writes the result to [filePath].
  ///
  /// Throws an exception if [filePath] is null or the file cannot be written.
  Future<void> saveFile() async {
    if (_document == null || _filePath == null) {
      throw Exception('No document loaded or file path not set');
    }

    // If there are edits that cannot be patched back into the original
    // binary buffer, fail save and inform the caller so the UI can offer
    // alternatives (export JSON, save-as, or full re-serialization).
    if (_document!.unsavableEdits.isNotEmpty) {
      throw Exception(
        'Save blocked: some edits cannot be written to the original .fg file. Export to JSON or Save As to persist these changes.',
      );
    }

    try {
      // Patch the buffer with current grades
      final patchedBytes = FgWriter.patchSave(_document!);

      // Write to file
      final file = File(_filePath!);
      await file.writeAsBytes(patchedBytes);

      // Mark as saved (not dirty)
      _document!.isDirty = false;

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Saves the current document to a new file path.
  ///
  /// Similar to [saveFile], but writes to [newPath] and updates [filePath].
  Future<void> saveFileAs(String newPath) async {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    try {
      // Patch the buffer with current grades
      final patchedBytes = FgWriter.patchSave(_document!);

      // Write to new file
      final file = File(newPath);
      await file.writeAsBytes(patchedBytes);

      // Update file path and mark as saved
      _filePath = newPath;
      _document!.isDirty = false;

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // --- Grade Operations ---

  /// Updates a single grade value.
  ///
  /// Parameters:
  /// - [classIndex]: Index of the subject-class grade
  /// - [studentIndex]: Index of the student within the class
  /// - [componentIndex]: Index of the grade component
  /// - [value]: New grade value (or null for missing grade)
  ///
  /// Sets [isDirty] to true and notifies listeners.
  /// Throws an exception if indices are out of bounds.
  void updateGrade(
    int classIndex,
    int studentIndex,
    int componentIndex,
    double? value,
    String? raw,
  ) {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    if (classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $classIndex');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];
    if (studentIndex >= scg.students.length) {
      throw Exception('Invalid student index: $studentIndex');
    }

    final student = scg.students[studentIndex];
    if (componentIndex >= student.grades.length) {
      throw Exception('Invalid component index: $componentIndex');
    }

    // Update in-memory without numeric validation; if `raw` is provided or
    // there is no binary offset for a numeric value, mark as unsavable so
    // the UI can prompt the user at save time.
    final key = (classIndex, studentIndex, componentIndex);
    if (raw != null && raw.isNotEmpty) {
      // textual entry cannot be patched into original binary floats
      _document!.unsavableEdits.add(key);
    } else if (value != null &&
        _document!.buffer.isNotEmpty &&
        !_document!.gradeOffsets.containsKey(key)) {
      _document!.unsavableEdits.add(key);
    }

    // Update the grade in-memory (store both numeric and raw)
    student.grades[componentIndex] = student.grades[componentIndex].copyWith(
      grade: value,
      raw: raw,
    );

    // Mark as dirty and notify
    _document!.isDirty = true;
    notifyListeners();
  }

  /// Clears all grades (numeric and raw) in a specific component column for
  /// the given class index. Marks edits as unsavable when the original
  /// document had float storage for those positions (cannot be patched back
  /// to represent 'missing' in-place).
  void clearColumn(int classIndex, int componentIndex) {
    if (_document == null) throw Exception('No document loaded');
    if (classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $classIndex');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];
    for (int si = 0; si < scg.students.length; si++) {
      final key = (classIndex, si, componentIndex);

      // If original file had a float for this position, we cannot convert it
      // to missing via patching; record as unsavable so save will warn.
      if (_document!.gradeOffsets.containsKey(key)) {
        _document!.unsavableEdits.add(key);
      } else {
        _document!.unsavableEdits.remove(key);
      }

      scg.students[si].grades[componentIndex] = scg
          .students[si]
          .grades[componentIndex]
          .copyWith(grade: null, raw: null);
    }

    _document!.isDirty = true;
    notifyListeners();
  }

  /// Copies one or more source columns to a destination column with a bonus.
  ///
  /// For each student in the active class:
  /// - Extracts grades from source component indices [srcCols]
  /// - Computes average and adds [bonus]
  /// - Clamps result to [0.0, 10.0]
  /// - Updates the destination component [dstCol]
  ///
  /// Parameters:
  /// - [classIndex]: Index of the subject-class grade
  /// - [srcCols]: List of source component indices
  /// - [dstCol]: Destination component index
  /// - [bonus]: Bonus score to add (can be negative)
  ///
  /// Throws an exception if indices are invalid or no active class is set.
  void applyColumnCopy(
    int classIndex,
    List<int> srcCols,
    int dstCol,
    double bonus,
  ) {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    if (classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $classIndex');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];

    // Validate destination column index
    if (dstCol >= scg.components.length) {
      throw Exception('Invalid destination column index: $dstCol');
    }

    // Validate all source column indices
    for (final srcCol in srcCols) {
      if (srcCol >= scg.components.length) {
        throw Exception('Invalid source column index: $srcCol');
      }
    }

    // Apply copy to each student
    for (int si = 0; si < scg.students.length; si++) {
      final student = scg.students[si];

      // Extract source grades
      final sourceGrades = srcCols
          .map((ci) => student.grades[ci].grade)
          .toList();

      // Compute new value using score utilities
      final newValue = ScoreUtils.computeCopyScore(sourceGrades, bonus);

      // Update destination grade
      if (newValue != null) {
        student.grades[dstCol] = student.grades[dstCol].copyWith(
          grade: newValue,
        );
      }
    }

    // Mark as dirty and notify
    _document!.isDirty = true;
    notifyListeners();
  }

  /// Sets the active class index.
  ///
  /// Throws an exception if the index is out of bounds.
  void setActiveClassIndex(int index) {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    if (index >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $index');
    }

    _activeClassIndex = index;
    notifyListeners();
  }

  /// Resets the state (e.g., when closing a file).
  void reset() {
    _document = null;
    _filePath = null;
    _activeClassIndex = 0;
    notifyListeners();
  }
}
