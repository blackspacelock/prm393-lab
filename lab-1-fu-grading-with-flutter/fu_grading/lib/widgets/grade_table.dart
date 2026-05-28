import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/teacher_grade.dart';
import '../providers/app_state.dart';
import '../providers/theme_provider.dart';
import '../utils/component_labels.dart';
import 'confirm_dialog.dart';

class GradeTable extends StatefulWidget {
  final SubjectClassGrade subjectClassGrade;
  final int classIndex;
  final Function(int studentIndex)? onStudentTap;

  const GradeTable({
    super.key,
    required this.subjectClassGrade,
    required this.classIndex,
    this.onStudentTap,
  });

  @override
  State<GradeTable> createState() => _GradeTableState();
}

class _GradeTableState extends State<GradeTable> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  List<GlobalKey> _studentRowKeys = [];
  int? _lastAutoScrolledClassIndex;
  int? _lastAutoScrolledStudentIndex;

  String _formatGradeDisplay(GradeComponent grade) {
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

    return '';
  }

  @override
  void initState() {
    super.initState();
    _syncRowKeys();
  }

  @override
  void didUpdateWidget(covariant GradeTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectClassGrade.students.length !=
            widget.subjectClassGrade.students.length ||
        oldWidget.classIndex != widget.classIndex) {
      _syncRowKeys();
    }
  }

  void _syncRowKeys() {
    _studentRowKeys = List.generate(
      widget.subjectClassGrade.students.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _maybeScrollToFocusedStudent(AppState appState) {
    final focusedClassIndex = appState.focusedClassIndex;
    final focusedStudentIndex = appState.focusedStudentIndex;

    if (focusedClassIndex != widget.classIndex ||
        focusedStudentIndex == null ||
        focusedStudentIndex < 0 ||
        focusedStudentIndex >= _studentRowKeys.length) {
      return;
    }

    if (_lastAutoScrolledClassIndex == focusedClassIndex &&
        _lastAutoScrolledStudentIndex == focusedStudentIndex) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;

        final rowContext = _studentRowKeys[focusedStudentIndex].currentContext;
        if (rowContext == null) return;

        await Scrollable.ensureVisible(
          rowContext,
          alignment: 0.2,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );

        _lastAutoScrolledClassIndex = focusedClassIndex;
        _lastAutoScrolledStudentIndex = focusedStudentIndex;
      } finally {
        // No-op: keep the row highlighted until another row is selected.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final double rollWidth = 130;
    final double nameWidth = 200;

    final Map<int, TableColumnWidth> columnWidths = {
      0: FixedColumnWidth(rollWidth),
      1: FixedColumnWidth(nameWidth),
    };
    for (int i = 0; i < widget.subjectClassGrade.components.length; i++) {
      columnWidths[i + 2] = const IntrinsicColumnWidth();
    }
    // Ensure the Total column is always present and has a fixed width so
    // it shows even when there are no component columns or when table is
    // initially empty.
    final totalColIndex = widget.subjectClassGrade.components.length + 2;
    columnWidths[totalColIndex] = const FixedColumnWidth(80);

    return Consumer<AppState>(
      builder: (context, appState, _) {
        _maybeScrollToFocusedStudent(appState);

        // Helper to produce a normalized key for component matching.
        String _norm(String s) =>
            s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

        // Build a component -> full assessment info map from loaded subjectconfig (if any)
        final Map<String, Map<String, dynamic>> compInfoMap = {};
        final subjectConfigs = appState.subjectConfigs;
        // Keep ordered assessment list from subjectconfig when available
        List<Map<String, dynamic>>? subjectAssessmentList;
        if (subjectConfigs != null) {
          final code = widget.subjectClassGrade.subject;
          final codeNorm = _norm(code);
          final matched = subjectConfigs.firstWhere((c) {
            final cc = (c['code'] as String?) ?? '';
            final cn = _norm(cc);
            return cn == codeNorm ||
                codeNorm.startsWith(cn) ||
                cn.startsWith(codeNorm);
          }, orElse: () => null);
          if (matched != null && matched['assessment'] is List) {
            subjectAssessmentList = (matched['assessment'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            for (final a in subjectAssessmentList) {
              final rawName = (a['name'] as String?)?.trim() ?? '';
              final key = _norm(rawName);
              compInfoMap[key] = a;
            }
          }
        }

        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Table(
                  border: isDarkMode
                      ? const TableBorder(
                          verticalInside: BorderSide(color: Color(0xFF44444F)),
                        )
                      : TableBorder.all(
                          color: const Color(0xFFD0D7DE),
                          width: 1,
                        ),
                  columnWidths: columnWidths,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: isDarkMode
                          ? const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey),
                              ),
                            )
                          : BoxDecoration(
                              color: const Color(0xFF4A789C),
                              border: Border.all(
                                color: const Color(0xFFADCDE3),
                                width: 1,
                              ),
                            ),
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 16.0,
                          ),
                          child: Text(
                            'Roll',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 16.0,
                          ),
                          child: Text(
                            'Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        ...widget.subjectClassGrade.components.asMap().entries.map((
                          entry,
                        ) {
                          final componentIndex = entry.key;
                          final component = entry.value;
                          final normalized = _norm(labelFor(component));
                          final info = compInfoMap[normalized];

                          // Determine header background color when component info exists
                          Color? headerColor;
                          if (info != null) {
                            final type = (info['type'] as String?)
                                ?.toLowerCase();
                            if (type == 'on-going') {
                              headerColor = const Color(0xFFC99700);
                            } else if (type == 'practical exam' ||
                                type == 'final exam' ||
                                type == 'final exam') {
                              headerColor = const Color(0xFFE06A00);
                            } else {
                              headerColor = Colors.green.shade200;
                            }
                          }

                          return Container(
                            color: headerColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 8.0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () {
                                    showDialog<void>(
                                      context: context,
                                      builder: (dialogCtx) {
                                        return AlertDialog(
                                          title: const Text(
                                            'Component details',
                                          ),
                                          content: info == null
                                              ? const Text(
                                                  'No configuration found for this component.',
                                                )
                                              : Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Name: ${info['name'] ?? labelFor(component)}',
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Type: ${info['type'] ?? 'unknown'}',
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Weight: ${info['weight']?.toString() ?? 'n/a'}',
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Completion Criteria: ${info['completion_criteria'] ?? 'n/a'}',
                                                    ),
                                                  ],
                                                ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogCtx).pop(),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  onLongPress: () async {
                                    // Show quick actions for this column: Clear or Delete
                                    final appState = context.read<AppState>();
                                    final action = await showDialog<String?>(
                                      context: context,
                                      builder: (dctx) {
                                        return AlertDialog(
                                          title: Text(
                                            'Column "${labelFor(component)}"',
                                          ),
                                          content: const Text(
                                            'Choose action for this column',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                dctx,
                                              ).pop('clear'),
                                              child: const Text('Clear column'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                dctx,
                                              ).pop('delete'),
                                              child: const Text(
                                                'Delete column',
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (action == null) return;
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    if (action == 'clear') {
                                      final confirm = await showConfirmDialog(
                                        context,
                                        title: 'Clear Column',
                                        message:
                                            'Clear all values for "${labelFor(component)}" in this class? This cannot be undone.',
                                        confirmText: 'Clear',
                                        cancelText: 'Cancel',
                                      );
                                      if (!confirm) return;
                                      try {
                                        appState.clearColumn(
                                          widget.classIndex,
                                          componentIndex,
                                        );
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Column cleared'),
                                          ),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    } else if (action == 'delete') {
                                      final confirm = await showConfirmDialog(
                                        context,
                                        title: 'Delete Column',
                                        message:
                                            'Delete column "${labelFor(component)}" and remove it from this class? This will remove the column for all students and cannot be undone.',
                                        confirmText: 'Delete',
                                        cancelText: 'Cancel',
                                      );
                                      if (!confirm) return;
                                      try {
                                        appState.removeComponent(
                                          widget.classIndex,
                                          componentIndex,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Column deleted'),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: SizedBox(
                                    width: 120,
                                    child: Text(
                                      labelFor(component),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    color: isDarkMode ? null : Colors.white,
                                    tooltip: 'Column options',
                                    iconSize: 18,
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'clear',
                                        child: Text('Clear column'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete column'),
                                      ),
                                    ],
                                    onSelected: (val) async {
                                      final appState = context.read<AppState>();
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      if (val == 'clear') {
                                        final confirm = await showConfirmDialog(
                                          context,
                                          title: 'Clear Column',
                                          message:
                                              'Clear all values for "${labelFor(component)}" in this class? This cannot be undone.',
                                          confirmText: 'Clear',
                                          cancelText: 'Cancel',
                                        );
                                        if (!confirm) return;
                                        try {
                                          appState.clearColumn(
                                            widget.classIndex,
                                            componentIndex,
                                          );
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Column cleared'),
                                            ),
                                          );
                                        } catch (e) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      } else if (val == 'delete') {
                                        final confirm = await showConfirmDialog(
                                          context,
                                          title: 'Delete Column',
                                          message:
                                              'Delete column "${labelFor(component)}" and remove it from this class? This will remove the column for all students and cannot be undone.',
                                          confirmText: 'Delete',
                                          cancelText: 'Cancel',
                                        );
                                        if (!confirm) return;
                                        try {
                                          appState.removeComponent(
                                            widget.classIndex,
                                            componentIndex,
                                          );
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Column deleted'),
                                            ),
                                          );
                                        } catch (e) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // Total header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 8.0,
                          ),
                          child: Center(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? null : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...List.generate(widget.subjectClassGrade.students.length, (
                      studentIndex,
                    ) {
                      final student =
                          widget.subjectClassGrade.students[studentIndex];
                      final isEvenRow = studentIndex % 2 == 0;
                      final isFocusedRow =
                          appState.focusedClassIndex == widget.classIndex &&
                          appState.focusedStudentIndex == studentIndex;
                      final rowColor = isDarkMode
                          ? (isFocusedRow
                                ? const Color(0xFF365D3D)
                                : (isEvenRow
                                      ? Colors.transparent
                                      : const Color(0xFF2A2A3E)))
                          : (isFocusedRow
                                ? const Color(0xFFACD5F2)
                                : (isEvenRow
                                      ? Colors.white
                                      : const Color(0xFFEAF1F7)));

                      return TableRow(
                        decoration: isDarkMode
                            ? BoxDecoration(
                                color: rowColor,
                                border: isFocusedRow
                                    ? Border.all(
                                        color: const Color(0xFF8ED08E),
                                        width: 1,
                                      )
                                    : null,
                              )
                            : BoxDecoration(
                                color: rowColor,
                                border: Border.all(
                                  color: const Color(0xFFADCDE3),
                                  width: 1,
                                ),
                              ),
                        children: [
                          Container(
                            key: _studentRowKeys[studentIndex],
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 16.0,
                            ),
                            child: Text(
                              student.roll,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () =>
                                    widget.onStudentTap?.call(studentIndex),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDarkMode
                                      ? const Color(0xFF4A90D9)
                                      : const Color(0xFF0366D6),
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(student.name, maxLines: 1),
                              ),
                            ),
                          ),
                          ...List.generate(
                            widget.subjectClassGrade.components.length,
                            (componentIndex) {
                              final componentName = widget
                                  .subjectClassGrade
                                  .components[componentIndex];
                              final actualGradeIndex = student.grades
                                  .indexWhere(
                                    (grade) => grade.component == componentName,
                                  );
                              final grade = actualGradeIndex >= 0
                                  ? student.grades[actualGradeIndex]
                                  : GradeComponent(component: componentName);

                              final hasNumeric = grade.grade != null;
                              final hasRaw =
                                  grade.raw != null && grade.raw!.isNotEmpty;

                              // Determine component type from loaded config (if any)
                              final normalizedName = _norm(componentName);
                              final compType =
                                  compInfoMap.containsKey(normalizedName)
                                  ? (compInfoMap[normalizedName]?['type']
                                        as String?)
                                  : null;

                              Color? cellColor;

                              // on-going: if empty -> yellow
                              if (compType == 'on-going' &&
                                  !hasNumeric &&
                                  !hasRaw) {
                                cellColor = isDarkMode
                                    ? const Color(0xFF5C2A2A)
                                    : const Color(0xFFFFFBD7);
                              }

                              // practical/final exam: if user edited this cell -> red highlight
                              final isEdited = appState.isCellEdited(
                                widget.classIndex,
                                studentIndex,
                                componentIndex,
                              );
                              if ((compType == 'practical exam' ||
                                      compType == 'final exam') &&
                                  isEdited &&
                                  (hasNumeric || hasRaw)) {
                                cellColor = Colors.red.withOpacity(0.12);
                              }

                              // Default when not matched/colored
                              cellColor ??= Colors.transparent;

                              final displayText = _formatGradeDisplay(grade);

                              return Container(
                                color: cellColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 12.0,
                                ),
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    key: ValueKey(
                                      'grade-${widget.classIndex}-$studentIndex-$componentIndex-$componentName-$displayText',
                                    ),
                                    initialValue: displayText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(height: 1.1),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    keyboardType: TextInputType.text,
                                    onFieldSubmitted: (text) {
                                      final trimmed = text.trim();
                                      double? newValue;
                                      String? newRaw;

                                      if (trimmed.isEmpty) {
                                        newValue = null;
                                        newRaw = null;
                                      } else {
                                        final parsed = double.tryParse(
                                          trimmed.replaceAll(',', '.'),
                                        );
                                        if (parsed != null) {
                                          newValue = parsed;
                                          newRaw = null;
                                        } else {
                                          newValue = null;
                                          newRaw = trimmed;
                                        }
                                      }

                                      try {
                                        context.read<AppState>().updateGrade(
                                          widget.classIndex,
                                          studentIndex,
                                          actualGradeIndex >= 0
                                              ? actualGradeIndex
                                              : componentIndex,
                                          newValue,
                                          newRaw,
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                          // Total cell (read-only) computed from weights
                          Builder(
                            builder: (ctx) {
                              // Use the ordered assessment list from subjectconfig when available;
                              // otherwise fall back to the components present in the .fg file.
                              final assessments =
                                  (subjectAssessmentList ??
                                          widget.subjectClassGrade.components
                                              .map((c) => {'name': c})
                                              .toList())
                                      .map(
                                        (a) =>
                                            Map<String, dynamic>.from(a as Map),
                                      )
                                      .toList();

                              bool isFinalExamAssessment(
                                Map<String, dynamic> assessment,
                              ) {
                                final type = (assessment['type'] as String?)
                                    ?.trim()
                                    .toLowerCase();
                                return type == 'final exam';
                              }

                              bool isResitFinalAssessment(
                                Map<String, dynamic> assessment,
                              ) {
                                if (!isFinalExamAssessment(assessment)) {
                                  return false;
                                }
                                final name =
                                    (assessment['name'] as String?) ?? '';
                                return _norm(name).contains('resit');
                              }

                              String finalBaseKey(
                                Map<String, dynamic> assessment,
                              ) {
                                final name =
                                    (assessment['name'] as String?) ?? '';
                                return _norm(name).replaceAll('resit', '');
                              }

                              int findGradeIndexByAssessmentName(
                                String assessmentName,
                              ) {
                                final anorm = _norm(assessmentName);
                                return student.grades.indexWhere((g) {
                                  final gcomp = _norm(g.component);
                                  return gcomp == anorm ||
                                      g.component.trim() == assessmentName;
                                });
                              }

                              bool isAssessmentFilled(String assessmentName) {
                                final gradeIndex = findGradeIndexByAssessmentName(
                                  assessmentName,
                                );
                                if (gradeIndex < 0) return false;
                                final g = student.grades[gradeIndex];
                                return g.grade != null ||
                                    (g.raw != null && g.raw!.trim().isNotEmpty);
                              }

                              final baseHasOriginal = <String>{};
                              final baseHasResit = <String>{};
                              for (final a in assessments) {
                                if (!isFinalExamAssessment(a)) continue;
                                final baseKey = finalBaseKey(a);
                                if (isResitFinalAssessment(a)) {
                                  baseHasResit.add(baseKey);
                                } else {
                                  baseHasOriginal.add(baseKey);
                                }
                              }

                              final useResitByBase = <String, bool>{};
                              for (final base in baseHasOriginal) {
                                if (!baseHasResit.contains(base)) continue;
                                final hasFilledResit = assessments.any((a) {
                                  if (!isResitFinalAssessment(a)) return false;
                                  if (finalBaseKey(a) != base) return false;
                                  final name = (a['name'] as String?) ?? '';
                                  return isAssessmentFilled(name);
                                });
                                useResitByBase[base] = hasFilledResit;
                              }

                              bool shouldSkipAssessment(
                                Map<String, dynamic> assessment,
                              ) {
                                if (!isFinalExamAssessment(assessment)) {
                                  return false;
                                }
                                final baseKey = finalBaseKey(assessment);
                                final useResit = useResitByBase[baseKey];
                                if (useResit == null) return false;
                                final isResit = isResitFinalAssessment(
                                  assessment,
                                );
                                return useResit ? !isResit : isResit;
                              }

                              double total = 0.0;
                              for (final a in assessments) {
                                if (shouldSkipAssessment(a)) continue;

                                final aname = ((a['name'] as String?) ?? '')
                                    .trim();
                                final anorm = _norm(aname);

                                final gradeIndex = findGradeIndexByAssessmentName(
                                  aname,
                                );
                                double? value;
                                if (gradeIndex >= 0) {
                                  final g = student.grades[gradeIndex];
                                  if (g.grade != null) {
                                    value = g.grade!;
                                  } else if (g.raw != null &&
                                      g.raw!.isNotEmpty) {
                                    value = double.tryParse(
                                      g.raw!.replaceAll(',', '.'),
                                    );
                                  }
                                }

                                final weightVal =
                                    a['weight'] ??
                                    compInfoMap[anorm]?['weight'];
                                final weight = weightVal is num
                                    ? weightVal.toDouble()
                                    : 0.0;
                                total += (value ?? 0.0) * weight;
                              }

                              if (total > 10.0) total = 10.0;

                              final totalText = total.isFinite
                                  ? total.toStringAsFixed(1)
                                  : '0.0';

                              return InkWell(
                                onTap: () {
                                  // Build breakdown using only components defined in subjectconfig
                                  final rows = <Map<String, dynamic>>[];
                                  double sumWeights = 0.0;
                                  for (final a in assessments) {
                                    if (shouldSkipAssessment(a)) continue;

                                    final compName =
                                        ((a['name'] as String?) ?? '').trim();
                                    final normalized = _norm(compName);

                                    // skip components not defined in subjectconfig
                                    if (!compInfoMap.containsKey(normalized)) {
                                      continue;
                                    }

                                    final gradeIndex =
                                        findGradeIndexByAssessmentName(compName);
                                    double? value;
                                    if (gradeIndex >= 0) {
                                      final g = student.grades[gradeIndex];
                                      if (g.grade != null) {
                                        value = g.grade!;
                                      } else if (g.raw != null &&
                                          g.raw!.isNotEmpty) {
                                        value = double.tryParse(
                                          g.raw!.replaceAll(',', '.'),
                                        );
                                      }
                                    }

                                    final weightVal =
                                        a['weight'] ??
                                        compInfoMap[normalized]?['weight'];
                                    final weight = weightVal is num
                                        ? weightVal.toDouble()
                                        : 0.0;
                                    sumWeights += weight;

                                    rows.add({
                                      'name':
                                          compInfoMap[normalized]?['name'] ??
                                          compName,
                                      'weight': weight,
                                      'value': value ?? 0.0,
                                    });
                                  }

                                  showDialog<void>(
                                    context: context,
                                    builder: (dctx) {
                                      return AlertDialog(
                                        title: const Text('Total breakdown'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              ...rows.map((r) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4.0,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          r['name'].toString(),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          r['weight']
                                                              .toStringAsFixed(
                                                                2,
                                                              ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          r['value']
                                                              .toStringAsFixed(
                                                                1,
                                                              ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              const Divider(),
                                              Row(
                                                children: [
                                                  const Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      'Total',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      sumWeights
                                                          .toStringAsFixed(2),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      totalText,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 12.0,
                                  ),
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 80,
                                    child: Text(
                                      totalText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
