import 'package:flutter/material.dart';
import '../models/teacher_grade.dart';

/// Dialog that allows selecting which components (columns) to export for a
/// set of classes. Returns a map from class index -> list of selected
/// component indices.
class SelectColumnsDialog extends StatefulWidget {
  final List<SubjectClassGrade> classes;
  final List<int> classIndices;
  final Map<int, List<int>>? initialSelection;

  const SelectColumnsDialog({
    super.key,
    required this.classes,
    required this.classIndices,
    this.initialSelection,
  });

  @override
  State<SelectColumnsDialog> createState() => _SelectColumnsDialogState();
}

class _SelectColumnsDialogState extends State<SelectColumnsDialog> {
  late List<List<bool>> _selected;
  late List<bool> _selectedClasses;
  late List<bool> _expandedClasses;

  @override
  void initState() {
    super.initState();
    _selectedClasses = List<bool>.filled(widget.classes.length, true);
    _expandedClasses = List<bool>.filled(widget.classes.length, true);
    _selected = widget.classes.asMap().entries.map((e) {
      final ci = e.key; // index in the passed classes list
      final scg = e.value;
      final originalClassIndex = widget.classIndices[ci];
      final initialForClass = widget.initialSelection?[originalClassIndex];

      if (initialForClass == null) {
        return List<bool>.filled(scg.components.length, true);
      }

      // Build boolean list based on whether each component index is in
      // the initial selection list. If a component index exceeds, default
      // to false.
      return List<bool>.generate(scg.components.length, (k) {
        return initialForClass.contains(k);
      });
    }).toList();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setAllExpanded(bool expanded) {
    setState(() {
      for (int i = 0; i < _expandedClasses.length; i++) {
        _expandedClasses[i] = expanded;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allExpanded =
        _expandedClasses.isNotEmpty &&
        _expandedClasses.every((expanded) => expanded);
    return AlertDialog(
      title: const Text('Select tables and columns to export'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (int i = 0; i < _selectedClasses.length; i++) {
                          _selectedClasses[i] = true;
                        }
                        for (int i = 0; i < _selected.length; i++) {
                          for (int j = 0; j < _selected[i].length; j++) {
                            _selected[i][j] = true;
                          }
                        }
                      });
                    },
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (int i = 0; i < _selectedClasses.length; i++) {
                          _selectedClasses[i] = false;
                        }
                        for (int i = 0; i < _selected.length; i++) {
                          for (int j = 0; j < _selected[i].length; j++) {
                            _selected[i][j] = false;
                          }
                        }
                      });
                    },
                    child: const Text('Clear all'),
                  ),
                  TextButton(
                    onPressed: () => _setAllExpanded(!allExpanded),
                    child: Text(allExpanded ? 'Unexpand all' : 'Expand all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(widget.classes.length, (ci) {
                final scg = widget.classes[ci];
                return Card(
                  child: ExpansionTile(
                    key: ValueKey(_expandedClasses[ci]),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _selectedClasses[ci],
                          onChanged: (v) {
                            setState(() {
                              _selectedClasses[ci] = v ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('${scg.subject} - ${scg.classCode}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    initiallyExpanded: _expandedClasses[ci],
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _expandedClasses[ci] = expanded;
                      });
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.start,
                            spacing: 8,
                            runSpacing: 6,
                            children: List.generate(scg.components.length, (k) {
                              return FilterChip(
                                label: Text(scg.components[k]),
                                selected: _selected[ci][k],
                                onSelected: (v) {
                                  setState(() => _selected[ci][k] = v);
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final result = <int, List<int>>{};
            for (int i = 0; i < widget.classIndices.length; i++) {
              if (!_selectedClasses[i]) continue;
              final idx = widget.classIndices[i];
              final sels = <int>[];
              for (int j = 0; j < _selected[i].length; j++) {
                if (_selected[i][j]) sels.add(j);
              }
              result[idx] = sels;
            }
            Navigator.of(context).pop(result);
          },
          child: const Text('Export'),
        ),
      ],
    );
  }
}

/// Helper to show the dialog.
Future<Map<int, List<int>>?> showSelectColumnsDialog(
  BuildContext context, {
  required List<SubjectClassGrade> classes,
  required List<int> classIndices,
  Map<int, List<int>>? initialSelection,
}) async {
  return showDialog<Map<int, List<int>>>(
    context: context,
    builder: (ctx) => SelectColumnsDialog(
      classes: classes,
      classIndices: classIndices,
      initialSelection: initialSelection,
    ),
  );
}
