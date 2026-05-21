import 'dart:typed_data';

import '../models/fg_document.dart';

/// Writes modified grade data back to the `.fg` file format.
///
/// The primary operation is [patchSave], which performs in-place patching:
/// it copies the original buffer and overwrites only the 4-byte grade float
/// values at their recorded byte offsets, preserving all other BinaryFormatter
/// structure and metadata.
class FgWriter {
  /// Patches grade float values in-place in the buffer.
  ///
  /// For each grade in [doc] where `grade != null` and an offset exists in
  /// [doc.gradeOffsets], this method writes the 4-byte little-endian IEEE 754
  /// float to the buffer at that offset. All other bytes remain unchanged.
  ///
  /// This preserves the entire BinaryFormatter structure and allows round-trip
  /// fidelity: grades can be edited and saved without losing or corrupting
  /// other metadata or object references in the binary stream.
  ///
  /// Returns a new [Uint8List] containing the patched buffer.
  static Uint8List patchSave(FgDocument doc) {
    // Start with a copy of the original buffer
    final out = Uint8List.fromList(doc.buffer);

    // Iterate through all subject-class grades
    doc.data.subjectClassGrades.asMap().forEach((classIndex, scg) {
      // Iterate through all students
      scg.students.asMap().forEach((studentIndex, student) {
        // Iterate through all grade components
        student.grades.asMap().forEach((componentIndex, gc) {
          // If there's a grade value and an offset for this position
          if (gc.grade != null) {
            final key = (classIndex, studentIndex, componentIndex);
            final offset = doc.gradeOffsets[key];

            if (offset != null && offset >= 0 && offset + 4 <= out.length) {
              // Create a ByteData view to write the float
              final bd = ByteData(4);
              bd.setFloat32(0, gc.grade!, Endian.little);

              // Copy the 4 bytes to the output buffer at the offset
              out.setRange(offset, offset + 4, bd.buffer.asUint8List());
            }
          }
        });
      });
    });

    return out;
  }
}
