import 'dart:convert';
import 'dart:typed_data';

import '../models/fg_document.dart';
import '../models/teacher_grade.dart';
import '../utils/component_labels.dart';

/// Parses a `.fg` file (a .NET BinaryFormatter stream) into an [FgDocument].
///
/// The parser uses a two-pass approach:
///   - Pass 1 ([_extractStrings]): scans the entire buffer for string records
///     (`0x06` type tag) and builds a map of `objectId → string value`.
///   - Pass 2 ([_extractGrades]): scans for grade float records and records
///     the byte offset of each 4-byte LE float.
///
/// The assembled [FgDocument] contains the parsed [TeacherGrade] model, the
/// original buffer bytes, and the grade-offset map needed by [FgWriter].
class FgParser {
  final Uint8List _buf;
  final List<(int, int)> _forbiddenRanges = [];
  FgParser(this._buf);

  /// Parses the buffer and returns a fully populated [FgDocument].
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
      unsavableEdits: {},
    );
  }

  // ---------------------------------------------------------------------------
  // Pass 1 — String extraction
  // ---------------------------------------------------------------------------

  /// Scans the entire buffer for BinaryObjectString records (`0x06` type tag)
  /// and returns a map of `objectId → string value`.
  ///
  /// String record format:
  /// ```
  /// 06                    // type tag
  /// <id: 4 bytes LE>      // object ID (signed int32)
  /// <length: 1–4 bytes>   // 7-bit encoded length (LEB128)
  /// <utf8 bytes>          // string content
  /// ```
  ///
  /// False positives (bytes that happen to be `0x06` but are not string
  /// records) are silently skipped via try/catch.
  Map<int, String> _extractStrings() {
    final result = <int, String>{};
    _forbiddenRanges.clear();
    _forbiddenRanges.add((0, 50));

    for (int i = 0; i < _buf.length - 6; i++) {
      if (_buf[i] == 0x06) {
        try {
          final id = _readInt32LE(i + 1);
          final (len, advance) = _read7BitEncodedInt(i + 5);
          if (len > 0 && len < 1000 && i + 5 + advance + len <= _buf.length) {
            final startStr = i + 5 + advance;
            final endStr = startStr + len;
            final str = utf8.decode(_buf.sublist(startStr, endStr));
            result[id] = str;
            _forbiddenRanges.add((i, endStr));
          }
        } catch (_) {}
      }
    }
    return result;
  }

  bool _isForbidden(int index) {
    for (final range in _forbiddenRanges) {
      if (index >= range.$1 && index <= range.$2) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Pass 2 — Grade float extraction
  // ---------------------------------------------------------------------------

  /// Scans the buffer for grade float records and returns the extracted grade
  /// entries together with their byte offsets.
  ///
  /// Grade record format (present grade):
  /// ```
  /// 08 0B <b0> <b1> <b2> <b3>   // Single field, 4-byte LE IEEE 754 float
  /// ```
  /// Null/missing grade:
  /// ```
  /// 0A
  /// ```
  ///
  /// This is a preparatory pass — it returns a flat list of [_GradeEntry]
  /// objects in file order with `classIndex`, `studentIndex`, and
  /// `componentIndex` all set to 0. The [_assembleModel] method is responsible
  /// for assigning the correct indices based on the structure derived from the
  /// string extraction pass.
  ///
  /// The returned `offsets` map is empty at this stage and will be populated
  /// by [_assembleModel] once the index assignment is complete.
  ({List<_GradeEntry> entries, Map<(int, int, int), int> offsets})
  _extractGrades() {
    final entries = <_GradeEntry>[];
    final offsets = <(int, int, int), int>{};

    // Scan the entire buffer for the 0x08 0x0B two-byte marker that precedes
    // a 4-byte little-endian IEEE 754 float grade value.
    // We need at least 6 bytes remaining: 08 0B + 4 float bytes.
    for (int i = 0; i < _buf.length - 5; i++) {
      if (_buf[i] == 0x08 && _buf[i + 1] == 0x0B) {
        if (_isForbidden(i)) continue;

        final floatOffset = i + 2;
        final value = _readFloat32LE(floatOffset);

        entries.add(
          _GradeEntry(
            classIndex: 0,
            studentIndex: 0,
            componentIndex: 0,
            value: value,
            byteOffset: floatOffset,
          ),
        );

        i += 5;
      }
    }

    return (entries: entries, offsets: offsets);
  }

  // ---------------------------------------------------------------------------
  // Model assembly
  // ---------------------------------------------------------------------------

  /// Assembles a [TeacherGrade] from the extracted strings and grade data.
  ///
  /// Strategy:
  /// 1. Extract metadata and string collections from the extracted strings map
  /// 2. Analyze grade entries to determine structure dimensions
  /// 3. Reconstruct SubjectClassGrade objects with Students and GradeComponents
  /// 4. Map grade values and byte offsets to the correct positions
  TeacherGrade _assembleModel(
    Map<int, String> strings,
    ({List<_GradeEntry> entries, Map<(int, int, int), int> offsets}) gradeData,
  ) {
    // --- Step 1: Extract metadata fields ---
    String versio = '1.0';
    String semester = 'Unknown';
    String logi = 'user';
    String password = '';

    // Make a second pass through strings to find metadata
    // These are typically found as early strings or with specific patterns
    for (final entry in strings.entries) {
      final str = entry.value;
      // Try to identify version strings (e.g., "1.0", "1.1")
      if (str.contains(RegExp(r'^\d+\.\d+$')) && str.length <= 5) {
        versio = str;
      }
    }

    // --- Step 2: Reconstruct blocks using the same ordered string stream ---
    // Sort by object id to preserve the source order used by BinaryFormatter.
    final orderedStrings = strings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final tokens = orderedStrings.map((e) => e.value).toList();

    bool isRoll(String value) => RegExp(r'^[A-Z]{2}\d{5,6}$').hasMatch(value);
    bool isSubjectCandidate(String value) {
      return RegExp(r'^[A-Z]{2,5}\d{2,4}[a-z]?$').hasMatch(value) &&
          !isRoll(value);
    }

    final subjectClassGrades = <SubjectClassGrade>[];
    var tokenIndex = 0;

    while (tokenIndex < tokens.length) {
      final token = tokens[tokenIndex];

      if (token.isEmpty) {
        tokenIndex++;
        continue;
      }

      if (!isSubjectCandidate(token)) {
        tokenIndex++;
        continue;
      }

      final subject = token;
      tokenIndex++;

      // Next meaningful token is treated as the class name/code, matching the
      // C# deserializer output order.
      while (tokenIndex < tokens.length && tokens[tokenIndex].isEmpty) {
        tokenIndex++;
      }
      if (tokenIndex >= tokens.length) {
        break;
      }
      final classCode = tokens[tokenIndex];
      tokenIndex++;

      // Collect component labels in sequence.
      final components = <String>[];
      while (tokenIndex < tokens.length &&
          kComponentLabels.containsKey(tokens[tokenIndex])) {
        components.add(tokens[tokenIndex]);
        tokenIndex++;
      }

      // Collect roll/name pairs until the next subject block.
      final students = <Student>[];
      while (tokenIndex < tokens.length &&
          !isSubjectCandidate(tokens[tokenIndex])) {
        final current = tokens[tokenIndex];
        if (!isRoll(current)) {
          tokenIndex++;
          continue;
        }

        final roll = current;
        tokenIndex++;

        String name = '';
        if (tokenIndex < tokens.length) {
          final candidate = tokens[tokenIndex];
          if (candidate.isNotEmpty &&
              !isRoll(candidate) &&
              !isSubjectCandidate(candidate) &&
              !kComponentLabels.containsKey(candidate)) {
            name = candidate;
            tokenIndex++;
          }
        }

        final grades = <GradeComponent>[];
        for (final component in components) {
          grades.add(GradeComponent(component: component, grade: null));
        }
        students.add(Student(roll: roll, name: name, grades: grades));
      }

      subjectClassGrades.add(
        SubjectClassGrade(
          subject: subject,
          classCode: classCode,
          components: components,
          students: students,
        ),
      );
    }

    // If we could not detect any blocks from strings, fall back to an empty
    // document rather than inventing incorrect class/roll mappings.
    if (subjectClassGrades.isEmpty) {
      return TeacherGrade(
        versio: versio,
        semester: semester,
        logi: logi,
        password: password,
        subjectClassGrades: [],
      );
    }

    // --- Step 3: Populate grades from gradeData ---
    // Assign the flat list of grade values in the same nested order used by
    // the C# object graph: class -> student -> component.
    var gradeIdx = 0;
    for (
      var ci = 0;
      ci < subjectClassGrades.length && gradeIdx < gradeData.entries.length;
      ci++
    ) {
      final classGrade = subjectClassGrades[ci];
      for (
        var si = 0;
        si < classGrade.students.length && gradeIdx < gradeData.entries.length;
        si++
      ) {
        for (
          var gi = 0;
          gi < classGrade.students[si].grades.length &&
              gradeIdx < gradeData.entries.length;
          gi++
        ) {
          final entry = gradeData.entries[gradeIdx];
          if (entry.value != null) {
            classGrade.students[si].grades[gi] = GradeComponent(
              component: classGrade.components[gi],
              grade: entry.value,
            );
            gradeData.offsets[(ci, si, gi)] = entry.byteOffset;
          }
          gradeIdx++;
        }
      }
    }

    return TeacherGrade(
      versio: versio,
      semester: semester,
      logi: logi,
      password: password,
      subjectClassGrades: subjectClassGrades,
    );
  }

  // ---------------------------------------------------------------------------
  // Binary helper methods
  // ---------------------------------------------------------------------------

  /// Reads a signed 32-bit little-endian integer from [pos].
  int _readInt32LE(int pos) =>
      _buf[pos] |
      (_buf[pos + 1] << 8) |
      (_buf[pos + 2] << 16) |
      (_buf[pos + 3] << 24);

  /// Reads a 4-byte little-endian IEEE 754 single-precision float from [pos].
  double _readFloat32LE(int pos) =>
      ByteData.sublistView(_buf, pos, pos + 4).getFloat32(0, Endian.little);

  /// Reads a .NET BinaryFormatter 7-bit encoded integer (LEB128) from [pos].
  ///
  /// Returns a record of `(value, bytesRead)` so the caller can advance its
  /// position past the encoded integer.
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

// ---------------------------------------------------------------------------
// Internal data transfer objects
// ---------------------------------------------------------------------------

/// Holds a single extracted grade value and its position in the object graph.
class _GradeEntry {
  final int classIndex;
  final int studentIndex;
  final int componentIndex;
  final double? value;
  final int byteOffset; // Byte offset of the 4-byte float in the buffer

  const _GradeEntry({
    required this.classIndex,
    required this.studentIndex,
    required this.componentIndex,
    required this.value,
    required this.byteOffset,
  });
}
