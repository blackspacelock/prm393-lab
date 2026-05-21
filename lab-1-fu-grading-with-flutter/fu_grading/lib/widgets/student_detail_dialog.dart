import 'package:flutter/material.dart';

import '../models/teacher_grade.dart';
import '../utils/component_labels.dart';

Future<void> showStudentDetailDialog(
  BuildContext context, {
  required int classIndex,
  required int studentIndex,
  required Student student,
}) async {
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
                final display = (g.raw != null && g.raw!.isNotEmpty)
                    ? g.raw!
                    : (g.grade != null ? g.grade!.toString() : '-');
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
