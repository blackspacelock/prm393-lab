import 'dart:typed_data';

import 'teacher_grade.dart';

/// Represents a loaded `.fg` file — the parsed model, the original binary
/// buffer, and a map of byte offsets for every grade float.
///
/// [buffer] holds the raw file bytes so that [FgWriter.patchSave] can perform
/// in-place patching without re-serialising the entire .NET BinaryFormatter
/// stream.
///
/// [gradeOffsets] maps `(classIndex, studentIndex, componentIndex)` to the
/// byte offset in [buffer] where the 4-byte little-endian IEEE 754 float for
/// that grade starts.
///
/// [isDirty] is set to `true` whenever a grade is edited and back to `false`
/// after a successful save.
class FgDocument {
  /// The raw bytes of the original `.fg` file.
  final Uint8List buffer;

  /// The fully parsed teacher-grade model.
  final TeacherGrade data;

  /// Maps `(classIndex, studentIndex, componentIndex)` → byte offset in
  /// [buffer] where the 4-byte float for that grade starts.
  ///
  /// Only entries for *present* (non-null) grades are included; missing grades
  /// have no offset because there is no float to patch.
  final Map<(int, int, int), int> gradeOffsets;

  /// Tracks edited grade positions that cannot be patched back into the
  /// original binary buffer because the original file contained no float
  /// storage for that position (e.g., the grade was originally missing).
  ///
  /// These entries should be handled specially on save (export to JSON or
  /// full re-serialization) because `FgWriter.patchSave` cannot persist them.
  final Set<(int, int, int)> unsavableEdits;

  /// Whether the document has unsaved changes.
  ///
  /// Set to `true` when any grade is edited; reset to `false` after a
  /// successful save.
  bool isDirty;

  FgDocument({
    required this.buffer,
    required this.data,
    required this.gradeOffsets,
    this.isDirty = false,
    Set<(int, int, int)>? unsavableEdits,
  }) : unsavableEdits = unsavableEdits ?? {};
}
