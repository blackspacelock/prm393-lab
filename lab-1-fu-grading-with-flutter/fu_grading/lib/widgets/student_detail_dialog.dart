import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/teacher_grade.dart';
import '../providers/app_state.dart';
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
      final appState = context.read<AppState>();
      // Try to find subject config for this class (if loaded)
      Map<String, dynamic>? classConfig;
      try {
        final scg = appState.document?.data.subjectClassGrades[classIndex];
        final configs = appState.subjectConfigs;
        if (scg != null && configs != null) {
          for (final c in configs) {
            if (c is Map && c['code'] == scg.subject) {
              classConfig = c as Map<String, dynamic>;
              break;
            }
          }
        }
      } catch (_) {}

      double computeTotal() {
        double total = 0.0;
        if (classConfig != null) {
          final assessments = classConfig!['assessment'] as List<dynamic>;
          for (int i = 0; i < student.grades.length; i++) {
            final g = student.grades[i];
            final compName = g.component;
            double weight = 0.0;
            for (final a in assessments) {
              if (a is Map &&
                  (a['name'] as String).toLowerCase() ==
                      compName.toLowerCase()) {
                weight = (a['weight'] is num)
                    ? (a['weight'] as num).toDouble()
                    : 0.0;
                break;
              }
            }
            final gradeVal = g.grade ?? 0.0;
            total += gradeVal * weight;
          }
        }
        return total;
      }

      final metaColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : Colors.black54;

      final screenWidth = MediaQuery.of(context).size.width;
      final dialogWidth = (screenWidth * 0.8).clamp(520.0, 900.0);

      // Reserve a consistent width for the name column so
      // the metadata/info column always starts at the same x.
      final double nameColWidth = () {
        final w = dialogWidth * 0.45;
        if (w < 160.0) return 160.0;
        if (w > 360.0) return 360.0;
        return w;
      }();

      return AlertDialog(
        title: Text('${student.roll} - ${student.name}'),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 24.0,
        ),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                ...List.generate(student.grades.length, (i) {
                  final g = student.grades[i];
                  final display = formatGrade(g);

                  // Find metadata for this component if available
                  String? type;
                  double? weight;
                  String? criteria;
                  if (classConfig != null) {
                    final assessments =
                        classConfig!['assessment'] as List<dynamic>;
                    for (final a in assessments) {
                      if (a is Map &&
                          (a['name'] as String).toLowerCase() ==
                              g.component.toLowerCase()) {
                        type = a['type']?.toString();
                        weight = (a['weight'] is num)
                            ? (a['weight'] as num).toDouble()
                            : null;
                        criteria = a['completion_criteria']?.toString();
                        break;
                      }
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: name column with fixed width
                        SizedBox(
                          width: nameColWidth,
                          child: Text(
                            labelFor(g.component),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Middle: metadata/info column that will always start
                        // at the same x because `nameColWidth` is fixed.
                        Expanded(
                          child: Text(
                            [
                              if (type != null) 'Type: $type',
                              if (weight != null)
                                'Weight: ${weight.toStringAsFixed(2)}',
                              if (criteria != null) 'Criteria: $criteria',
                            ].join('   '),
                            style: TextStyle(fontSize: 12, color: metaColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Right: value column (fixed width)
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 80,
                          child: Text(
                            display,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Show computed Total column if we have classConfig
                if (classConfig != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: metaColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          computeTotal().toStringAsFixed(1),
                          style: TextStyle(color: metaColor),
                        ),
                      ],
                    ),
                  ),
                ],
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
