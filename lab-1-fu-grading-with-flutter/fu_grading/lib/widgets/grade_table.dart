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

    return Consumer<AppState>(
      builder: (context, appState, _) {
        _maybeScrollToFocusedStudent(appState);

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
                              border:
                                  Border(bottom: BorderSide(color: Colors.grey)),
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
                                color: Colors.white),
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
                                color: Colors.white),
                            maxLines: 1,
                          ),
                        ),
                        ...widget.subjectClassGrade.components.asMap().entries.map((
                          e,
                        ) {
                          final componentIndex = e.key;
                          final component = e.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 8.0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    labelFor(component),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDarkMode ? null : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    iconSize: 18,
                                    tooltip: 'Clear column',
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.white.withOpacity(0.8),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final appState = context.read<AppState>();
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
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
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
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
                              final actualGradeIndex = student.grades.indexWhere(
                                (grade) => grade.component == componentName,
                              );
                              final grade = actualGradeIndex >= 0
                                  ? student.grades[actualGradeIndex]
                                  : GradeComponent(component: componentName);

                              final hasNumeric = grade.grade != null;
                              final hasRaw =
                                  grade.raw != null && grade.raw!.isNotEmpty;
                              final cellColor = (hasNumeric || hasRaw)
                                  ? Colors.transparent
                                  : (isDarkMode
                                      ? const Color(0xFF5C2A2A)
                                      : const Color(0xFFFFFBD7));

                              final displayText = hasRaw
                                  ? grade.raw!
                                  : (hasNumeric ? grade.grade!.toString() : '');

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
