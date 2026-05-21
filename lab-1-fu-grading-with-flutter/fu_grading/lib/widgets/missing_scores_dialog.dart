import 'package:flutter/material.dart';

import '../models/fg_document.dart';
import '../utils/component_labels.dart';
import '../utils/score_utils.dart';

/// A dialog showing all missing scores in the document.
///
/// Displays a scrollable list grouped by SubjectClassGrade. Shows "All scores
/// complete" when there are no missing scores.
class MissingScoresDialog extends StatelessWidget {
  final FgDocument document;

  const MissingScoresDialog({super.key, required this.document});

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
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => MissingScoresDialog(document: document),
  );
}
