import 'package:flutter/material.dart';

import '../models/teacher_grade.dart';
import '../utils/component_labels.dart';

Future<void> showStudentDetailDialog(
  BuildContext context, {
  required int classIndex,
  required int studentIndex,
  required Student student,
}) async {
  String formatGrade(GradeComponent grade) {
    if (grade.raw != null && grade.raw!.isNotEmpty) {
      final parsedRaw = double.tryParse(grade.raw!);
      if (parsedRaw != null) {
        return parsedRaw.toStringAsFixed(1);
      }
      return grade.raw!;
    }

    if (grade.grade != null) {
      return grade.grade!.toStringAsFixed(1);
    }

    return '-';
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('${student.roll} - ${student.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              ...List.generate(student.grades.length, (i) {
                final g = student.grades[i];
                final display = formatGrade(g);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          labelFor(g.component),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(display),
                    ],
                  ),
                );
              }),
              if (student.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Comment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(student.comment),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
