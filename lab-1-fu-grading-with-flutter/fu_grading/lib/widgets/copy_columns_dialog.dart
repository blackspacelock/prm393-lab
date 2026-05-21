import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/teacher_grade.dart';
import '../providers/app_state.dart';
import '../utils/component_labels.dart';
import '../utils/score_utils.dart';
import 'confirm_dialog.dart';

/// A dialog for copying grade columns with optional bonus.
///
/// Allows user to select source columns, destination column, and bonus amount.
/// Provides preview of results before applying changes.
class CopyColumnsDialog extends StatefulWidget {
  final SubjectClassGrade subjectClassGrade;
  final int classIndex;

  const CopyColumnsDialog({
    super.key,
    required this.subjectClassGrade,
    required this.classIndex,
  });

  @override
  State<CopyColumnsDialog> createState() => _CopyColumnsDialogState();
}

class _CopyColumnsDialogState extends State<CopyColumnsDialog> {
  late int _destinationColumn;
  late TextEditingController _bonusController;
  late Map<int, double?> _previewResults;
  int? _selectedSource;
  bool _showPreview = false;
  String? _bonusError;

  @override
  void initState() {
    super.initState();
    _selectedSource = null;
    _destinationColumn = 0;
    _bonusController = TextEditingController(text: '0.0');
    _previewResults = {};
  }

  @override
  void dispose() {
    _bonusController.dispose();
    super.dispose();
  }

  /// Validates and updates bonus value.
  void _onBonusChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _bonusError = 'Bonus cannot be empty';
      } else {
        try {
          final bonus = double.parse(value);
          if (bonus < -10.0 || bonus > 10.0) {
            _bonusError = 'Bonus must be -10.0 to 10.0';
          } else {
            _bonusError = null;
          }
        } catch (e) {
          _bonusError = 'Invalid number';
        }
      }
    });
  }

  /// Generates preview results.
  void _generatePreview() {
    if (_selectedSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one source column')),
      );
      return;
    }

    if (_bonusError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid bonus: $_bonusError')));
      return;
    }

    final bonus = double.parse(_bonusController.text);
    _previewResults.clear();

    for (int si = 0; si < widget.subjectClassGrade.students.length; si++) {
      final student = widget.subjectClassGrade.students[si];
      final sourceGrades = [student.grades[_selectedSource!].grade];

      final newValue = ScoreUtils.computeCopyScore(sourceGrades, bonus);
      _previewResults[si] = newValue;
    }

    setState(() => _showPreview = true);
  }

  /// Applies the column copy operation.
  Future<void> _applyChanges() async {
    if (_selectedSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one source column')),
      );
      return;
    }

    if (_bonusError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid bonus: $_bonusError')));
      return;
    }

    final sourceLabels = labelFor(
      widget.subjectClassGrade.components[_selectedSource!],
    );
    final destLabel = labelFor(
      widget.subjectClassGrade.components[_destinationColumn],
    );
    final bonus = double.parse(_bonusController.text);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Copy Columns',
      message:
          'Copy from [$sourceLabels] to [$destLabel] with bonus $bonus?\n\nThis will update ${widget.subjectClassGrade.students.length} students.',
      confirmText: 'Apply',
      cancelText: 'Cancel',
    );

    if (!confirmed || !mounted) return;

    try {
      context.read<AppState>().applyColumnCopy(
        widget.classIndex,
        [_selectedSource!],
        _destinationColumn,
        bonus,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Columns copied successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Copy Columns'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Source columns selector
              const Text(
                'Source Columns:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.subjectClassGrade.components.length,
                  itemBuilder: (context, index) {
                    final component =
                        widget.subjectClassGrade.components[index];
                    return RadioListTile<int>(
                      dense: true,
                      title: Text(labelFor(component)),
                      value: index,
                      groupValue: _selectedSource,
                      onChanged: (value) {
                        setState(() => _selectedSource = value);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Destination column selector
              const Text(
                'Destination Column:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButton<int>(
                value: _destinationColumn,
                isExpanded: true,
                items: List.generate(
                  widget.subjectClassGrade.components.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(
                      labelFor(widget.subjectClassGrade.components[index]),
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _destinationColumn = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Bonus input
              const Text(
                'Bonus Amount (-10.0 to 10.0):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bonusController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter bonus amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  errorText: _bonusError,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: _onBonusChanged,
              ),
              const SizedBox(height: 16),

              // Preview section
              if (_showPreview)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Preview:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('Name')),
                          DataColumn(
                            label: Text(
                              'Current ${labelFor(widget.subjectClassGrade.components[_destinationColumn])}',
                            ),
                          ),
                          const DataColumn(label: Text('New Score')),
                        ],
                        rows: List.generate(
                          widget.subjectClassGrade.students.length,
                          (index) {
                            final student =
                                widget.subjectClassGrade.students[index];
                            final current =
                                student.grades[_destinationColumn].grade;
                            final newValue = _previewResults[index];

                            return DataRow(
                              cells: [
                                DataCell(Text(student.name)),
                                DataCell(
                                  Text(
                                    current != null
                                        ? current.toStringAsFixed(1)
                                        : '-',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    newValue != null
                                        ? newValue.toStringAsFixed(1)
                                        : '-',
                                    style: TextStyle(
                                      color: newValue != null
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _generatePreview, child: const Text('Preview')),
        TextButton(onPressed: _applyChanges, child: const Text('Apply')),
      ],
    );
  }
}

/// Helper function to show the copy columns dialog.
Future<void> showCopyColumnsDialog(
  BuildContext context, {
  required SubjectClassGrade subjectClassGrade,
  required int classIndex,
}) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => CopyColumnsDialog(
      subjectClassGrade: subjectClassGrade,
      classIndex: classIndex,
    ),
  );
}
