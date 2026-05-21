import 'dart:io';

import 'package:excel/excel.dart';

import '../models/fg_document.dart';
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
}
