import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fg_document.dart';
import '../utils/component_labels.dart';
import '../utils/score_utils.dart';
import '../providers/app_state.dart';

/// A dialog showing all missing scores in the document.
///
/// Displays a scrollable list grouped by SubjectClassGrade. Shows "All scores
/// complete" when there are no missing scores.
class MissingScoresDialog extends StatelessWidget {
  final FgDocument document;
  final AppState appState;

  const MissingScoresDialog({
    super.key,
    required this.document,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final missingScores = ScoreUtils.findMissingScores(document);

    return AlertDialog(
      title: const Text('Missing Scores'),
      content: SizedBox(
        width: 600,
        child: missingScores.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'All scores complete',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: missingScores.length,
                itemBuilder: (context, index) {
                  final missing = missingScores[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: InkWell(
                      onTap: () async {
                        // Find indices for class, student, and component
                        final doc = document;
                        int classIndex = -1;
                        for (
                          int ci = 0;
                          ci < doc.data.subjectClassGrades.length;
                          ci++
                        ) {
                          final scg = doc.data.subjectClassGrades[ci];
                          if (scg.subject == missing.subject &&
                              scg.classCode == missing.classCode) {
                            classIndex = ci;
                            break;
                          }
                        }

                        if (classIndex == -1) return;

                        final scg = doc.data.subjectClassGrades[classIndex];

                        int studentIndex = -1;
                        for (int si = 0; si < scg.students.length; si++) {
                          if (scg.students[si].roll == missing.roll ||
                              scg.students[si].name == missing.name) {
                            studentIndex = si;
                            break;
                          }
                        }

                        if (studentIndex == -1) return;

                        final navigator = Navigator.of(
                          context,
                          rootNavigator: true,
                        );

                        // Close dialog first, then focus the row on the next frame
                        navigator.pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          try {
                            appState.setActiveClassIndex(classIndex);
                            appState.focusStudent(classIndex, studentIndex);
                          } catch (_) {}
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3E),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF5C2A2A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${missing.subject} - ${missing.classCode}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A90D9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${missing.roll} - ${missing.name}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labelFor(missing.component),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Helper function to show the missing scores dialog.
Future<void> showMissingScoresDialog(
  BuildContext context, {
  required FgDocument document,
}) async {
  final appState = context.read<AppState>();
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => MissingScoresDialog(
      document: document,
      appState: appState,
    ),
  );
}
