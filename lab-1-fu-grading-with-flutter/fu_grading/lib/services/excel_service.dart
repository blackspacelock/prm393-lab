import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/fg_document.dart';
import '../models/teacher_grade.dart';
import '../utils/component_labels.dart';

/// Service for exporting FgDocument grades to Excel (.xlsx) files.
class ExcelService {
  /// Export the document to an Excel workbook.
  ///
  /// Creates one sheet per SubjectClassGrade.
  /// Each sheet is named `<subject>_<classCode>` (truncated to 31 chars if needed).
  /// Header row: ["Roll", "Name", ...component labels]
  /// Data rows: one per student; null grades become empty cells.
  static Future<void> exportToExcel(FgDocument document, String path) async {
    final excel = Excel.createExcel();
    // Create one sheet per SubjectClassGrade. Ensure valid, unique sheet names
    final usedNames = <String>{};

    String makeSheetName(String subject, String classCode, int suffix) {
      var base = '${subject}_$classCode';
      // Replace characters invalid for Excel sheet names
      base = base.replaceAll(RegExp(r'[\\/:*?\[\]]'), '_');
      // Trim whitespace
      base = base.trim();
      if (base.isEmpty) base = 'Sheet';
      // Truncate to 31 chars (Excel limit)
      if (base.length > 31) base = base.substring(0, 31);
      if (suffix > 0) {
        final suf = '_$suffix';
        // Ensure suffix fits within 31 chars
        final avail = 31 - suf.length;
        final trimmed = base.length > avail ? base.substring(0, avail) : base;
        return '$trimmed$suf';
      }
      return base;
    }

    for (
      int classIdx = 0;
      classIdx < document.data.subjectClassGrades.length;
      classIdx++
    ) {
      final scg = document.data.subjectClassGrades[classIdx];

      // Generate a unique, valid sheet name
      int suffix = 0;
      String sheetName;
      do {
        sheetName = makeSheetName(scg.subject, scg.classCode, suffix);
        suffix++;
      } while (usedNames.contains(sheetName));
      usedNames.add(sheetName);

      final sheet = excel[sheetName];

      // Build header row: ["Roll", "Name", ...component labels]
      final headerRow = <CellValue>[
        TextCellValue('Roll'),
        TextCellValue('Name'),
        ...scg.components.map((c) => TextCellValue(labelFor(c))),
      ];

      // Write header
      sheet.appendRow(headerRow);

      // Write data rows: one per student
      for (final student in scg.students) {
        final dataRow = <CellValue>[
          TextCellValue(student.roll),
          TextCellValue(student.name),
          ...student.grades.map((g) {
            if (g.raw != null && g.raw!.isNotEmpty) {
              return TextCellValue(g.raw!);
            } else if (g.grade == null) {
              return TextCellValue('');
            } else {
              return DoubleCellValue(g.grade!);
            }
          }),
        ];

        sheet.appendRow(dataRow);
      }
    }

    // Remove default empty sheet 'Sheet1' if it wasn't used
    if (excel.sheets.containsKey('Sheet1') && !usedNames.contains('Sheet1')) {
      try {
        excel.delete('Sheet1');
      } catch (_) {
        // ignore if deletion not supported by package version
      }
    }

    // Save workbook to file
    final bytes = excel.encode();
    if (bytes != null) {
      await File(path).writeAsBytes(bytes);
    }
  }

  /// Import an Excel workbook (bytes) into an `FgDocument`.
  ///
  /// Reads each sheet as a separate SubjectClassGrade. The first row is
  /// interpreted as header: first two columns should be Roll/Name (case
  /// insensitive) and the remaining columns are component labels.
  static Future<FgDocument> importFromExcel(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);

    final scgs = <SubjectClassGrade>[];

    for (final entry in excel.sheets.entries) {
      final sheetName = entry.key;
      final sheet = entry.value;

      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      // Header processing: normalize any cell value to String? to avoid
      // casting issues (some cells yield TextCellValue objects).
      final List<String?> header = rows.first.map<String?>((c) {
        final raw = c?.value;
        if (raw == null) return null;
        // Normalize any cell value to String using toString(). This avoids
        // type-specific casting problems (TextCellValue etc.).
        return raw.toString();
      }).toList();

      // Find roll and name columns (case-insensitive match)
      int rollIdx = -1;
      int nameIdx = -1;
      for (int i = 0; i < header.length; i++) {
        final String? h = header[i];
        if (h != null) {
          final low = h.toLowerCase();
          if (rollIdx == -1 &&
              (low == 'roll' || low == 'mã' || low == 'mssv')) {
            rollIdx = i;
          }
          if (nameIdx == -1 && (low == 'name' || low == 'tên')) {
            nameIdx = i;
          }
        }
      }

      // Default to first two columns if not found
      if (rollIdx == -1) rollIdx = 0;
      if (nameIdx == -1) nameIdx = 1 < header.length ? 1 : 0;

      // Component labels are remaining header cells excluding roll/name
      final components = <String>[];
      for (int i = 0; i < header.length; i++) {
        if (i == rollIdx || i == nameIdx) continue;
        final val = header[i];
        components.add(val?.toString() ?? 'Col${i + 1}');
      }

      final students = <Student>[];

      for (int r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.every(
          (c) =>
              c == null || c.value == null || c.value.toString().trim().isEmpty,
        )) {
          continue; // skip empty rows
        }

        final roll = (rollIdx < row.length && row[rollIdx] != null)
            ? (row[rollIdx]!.value?.toString() ?? '')
            : '';
        final name = (nameIdx < row.length && row[nameIdx] != null)
            ? (row[nameIdx]!.value?.toString() ?? '')
            : '';

        final grades = <GradeComponent>[];
        int compCellIdx = 0;
        for (int c = 0; c < header.length; c++) {
          if (c == rollIdx || c == nameIdx) continue;

          final cell = c < row.length ? row[c] : null;
          double? gradeVal;
          String? raw;
          if (cell != null && cell.value != null) {
            final v = cell.value;
            if (v is num) {
              gradeVal = (v as num).toDouble();
            } else if (v is String) {
              final s = v as String;
              final parsed = double.tryParse(s.replaceAll(',', '.'));
              if (parsed != null) {
                gradeVal = parsed;
              } else if (s.trim().isNotEmpty) {
                raw = s;
              }
            } else {
              final s = v.toString();
              final parsed = double.tryParse(s.replaceAll(',', '.'));
              if (parsed != null) {
                gradeVal = parsed;
              } else if (s.trim().isNotEmpty) {
                raw = s;
              }
            }
          }

          final compName = components[compCellIdx++];
          grades.add(
            GradeComponent(component: compName, grade: gradeVal, raw: raw),
          );
        }

        students.add(Student(roll: roll, name: name, grades: grades));
      }

      // Parse sheetName into subject and classCode if possible
      String subject = sheetName;
      String classCode = '';
      final parts = sheetName.split(RegExp(r'[_\-]'));
      if (parts.length >= 2) {
        subject = parts.first;
        classCode = parts.sublist(1).join('_');
      }

      scgs.add(
        SubjectClassGrade(
          subject: subject,
          classCode: classCode,
          components: components,
          students: students,
        ),
      );
    }

    final teacherGrade = TeacherGrade(
      versio: '1.0',
      semester: '',
      logi: '',
      password: '',
      subjectClassGrades: scgs,
    );

    return FgDocument(
      buffer: Uint8List(0),
      data: teacherGrade,
      gradeOffsets: {},
      unsavableEdits: {},
      isDirty: false,
    );
  }
}
