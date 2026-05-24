import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/excel_service.dart';
import '../services/file_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/copy_columns_dialog.dart';
import '../widgets/grade_table.dart';
import '../widgets/missing_scores_dialog.dart';
import '../widgets/student_detail_dialog.dart';
import 'package:fu_grading/widgets/theme_switcher.dart';
import '../widgets/chat_widget.dart';

/// The main home screen of the FU Grading app.
///
/// Layout:
/// - Top toolbar with action buttons (Open, Save, Save As, Export Excel, Check Missing, Copy Columns)
/// - Left sidebar with list of subject-class grades
/// - Main content area showing the grade table or placeholder
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  // Right-side chat panel state
  bool _isChatVisible = false;
  double _chatWidth = 360.0;
  final double _chatMinWidth = 260.0;
  final double _chatMaxWidth = 700.0;

  bool _isExcelPath(String? path) {
    if (path == null) return false;
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.xlsx') || lowerPath.endsWith('.xls');
  }

  Future<String?> _pickSavePathForCurrentFileType(AppState appState) async {
    if (_isExcelPath(appState.filePath)) {
      return FileService.pickExcelSavePath();
    }
    return FileService.pickSavePath();
  }

  Future<String?> _pickExportPathForOppositeFormat(AppState appState) async {
    if (_isExcelPath(appState.filePath)) {
      return FileService.pickSavePath();
    }
    return FileService.pickExcelSavePath();
  }

  Future<List<int>?> _showClassSelectionDialog(AppState appState) async {
    final document = appState.document;
    if (document == null) return null;

    final selected = List<bool>.filled(
      document.data.subjectClassGrades.length,
      false,
    );

    return showDialog<List<int>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Select classes to export'),
              content: SizedBox(
                width: 500,
                height: 420,
                child: Column(
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              for (int i = 0; i < selected.length; i++) {
                                selected[i] = true;
                              }
                            });
                          },
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              for (int i = 0; i < selected.length; i++) {
                                selected[i] = false;
                              }
                            });
                          },
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: document.data.subjectClassGrades.length,
                        itemBuilder: (context, index) {
                          final scg = document.data.subjectClassGrades[index];
                          return CheckboxListTile(
                            value: selected[index],
                            onChanged: (value) {
                              setDialogState(() {
                                selected[index] = value ?? false;
                              });
                            },
                            title: Text('${scg.subject} - ${scg.classCode}'),
                            subtitle: Text('${scg.students.length} students'),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final selectedIndices = <int>[];
                    for (int i = 0; i < selected.length; i++) {
                      if (selected[i]) {
                        selectedIndices.add(i);
                      }
                    }

                    if (selectedIndices.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Select at least one class'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop(selectedIndices);
                  },
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openFile() async {
    final appState = context.read<AppState>();

    // Check if current document has unsaved changes
    if (appState.isDirty) {
      final shouldDiscard = await showConfirmDialog(
        context,
        title: 'Unsaved Changes',
        message: 'You have unsaved changes. Do you want to discard them?',
        confirmText: 'Discard',
        cancelText: 'Cancel',
      );

      if (!shouldDiscard || !mounted) return;
    }

    setState(() => _isLoading = true);

    try {
      final (fileBytes, fileName, filePath) =
          await FileService.pickGradeFileBytes();
      if (fileBytes != null && fileName != null && mounted) {
        // Detect file type by extension
        if (fileName.toLowerCase().endsWith('.json')) {
          // Load as JSON
          await context.read<AppState>().loadJsonFromBytes(fileBytes);
        } else if (fileName.toLowerCase().endsWith('.xlsx') ||
            fileName.toLowerCase().endsWith('.xls')) {
          // Load from Excel workbook
          await context.read<AppState>().loadExcelFromBytes(
            fileBytes,
            filePath: filePath,
          );
        } else {
          // Load as binary .fg file
          await context.read<AppState>().loadFileFromBytes(
            fileBytes,
            filePath: filePath,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFile() async {
    final appState = context.read<AppState>();
    if (appState.filePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No file loaded')));
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Save File',
      message: 'Save changes to ${appState.filePath}?',
      confirmText: 'Save',
      cancelText: 'Cancel',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await appState.saveFile();
      if (mounted) {
        final skipped = appState.unsavableEditCount;
        if (skipped > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File saved. Note: $skipped grade(s) that were originally missing could not be written to the .fg format.',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File saved successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFileAs() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save As is not supported on web')),
      );
      return;
    }

    final savePath = await _pickSavePathForCurrentFileType(appState);
    if (savePath == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await appState.saveFileAs(savePath);
      if (mounted) {
        final skipped = appState.unsavableEditCount;
        if (skipped > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File saved. Note: $skipped grade(s) that were originally missing could not be written to the .fg format.',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File saved successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCurrentFormat() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is not supported on web')),
      );
      return;
    }

    final sourceWasExcel = _isExcelPath(appState.filePath);
    final savePath = await _pickExportPathForOppositeFormat(appState);
    if (savePath == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await appState.saveFileAs(savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sourceWasExcel
                  ? 'FG file exported successfully'
                  : 'Excel file exported successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting file: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportSelectedFormat() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is not supported on web')),
      );
      return;
    }

    final selectedIndices = await _showClassSelectionDialog(appState);
    if (selectedIndices == null || selectedIndices.isEmpty || !mounted) {
      return;
    }

    final sourceWasExcel = _isExcelPath(appState.filePath);
    final savePath = await _pickExportPathForOppositeFormat(appState);
    if (savePath == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await appState.exportSelectedClassesAs(savePath, selectedIndices);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sourceWasExcel
                  ? 'Selected classes exported to FG successfully'
                  : 'Selected classes exported to Excel successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting selected classes: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkMissingScores() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    if (!mounted) return;
    await showMissingScoresDialog(context, document: appState.document!);
  }

  Future<void> _openCopyColumnsDialog() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    final activeScg = appState.activeSubjectClassGrade;
    if (activeScg == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No class selected')));
      return;
    }

    if (!mounted) return;
    await showCopyColumnsDialog(
      context,
      subjectClassGrade: activeScg,
      classIndex: appState.activeClassIndex,
    );
  }

  Future<void> _exportExcel() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel export is not supported on web')),
      );
      return;
    }

    final savePath = await FileService.pickExcelSavePath();
    if (savePath == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await ExcelService.exportToExcel(appState.document!, savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel file exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting Excel: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidebarWidth = constraints.maxWidth < 1200 ? 220.0 : 250.0;
            final textColor =
                theme.textTheme.bodyMedium?.color ??
                theme.colorScheme.onSurface;
            final placeholderColor = textColor.withOpacity(0.75);

            return Column(
              children: [
                Container(
                  color: theme.cardColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Consumer<AppState>(
                    builder: (context, appState, _) {
                      final filePathLabel =
                          appState.filePath ?? 'No file loaded';
                      final sourceIsExcel = _isExcelPath(appState.filePath);
                      final exportSelectedLabel = sourceIsExcel
                          ? 'Export to FG'
                          : 'Export to Excel';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Tooltip(
                              message: filePathLabel,
                              child: Text(
                                filePathLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _openFile,
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('Open'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _saveFile,
                                    icon: const Icon(Icons.save),
                                    label: const Text('Save'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _saveFileAs,
                                    icon: const Icon(Icons.save_as),
                                    label: const Text('Save As'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _exportSelectedFormat,
                                    icon: const Icon(Icons.checklist),
                                    label: Text(exportSelectedLabel),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _checkMissingScores,
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: const Text('Check Missing'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _openCopyColumnsDialog,
                                    icon: const Icon(Icons.content_copy),
                                    label: const Text('Copy Columns'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isChatVisible = !_isChatVisible;
                                      });
                                    },
                                    icon: const Icon(Icons.chat),
                                    label: const Text('Chat'),
                                  ),
                                  const SizedBox(width: 8),
                                  const ThemeSwitcher(),
                                  const SizedBox(width: 16),
                                  if (_isLoading)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Consumer<AppState>(
                            builder: (context, appState, _) {
                              final document = appState.document;
                              if (document == null) {
                                return Container(
                                  width: sidebarWidth,
                                  color: theme.cardColor,
                                  child: Center(
                                    child: Text(
                                      'No file loaded',
                                      style: TextStyle(color: placeholderColor),
                                    ),
                                  ),
                                );
                              }

                              return Container(
                                width: sidebarWidth,
                                color: theme.cardColor,
                                child: ListView.builder(
                                  itemCount:
                                      document.data.subjectClassGrades.length,
                                  itemBuilder: (context, index) {
                                    final scg =
                                        document.data.subjectClassGrades[index];
                                    final isActive =
                                        appState.activeClassIndex == index;

                                    return ListTile(
                                      title: Text(
                                        '${scg.subject} - ${scg.classCode}',
                                        style: TextStyle(
                                          color: isActive
                                              ? theme.colorScheme.primary
                                              : textColor,
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${scg.students.length} students',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      selected: isActive,
                                      selectedTileColor:
                                          theme.scaffoldBackgroundColor,
                                      onTap: () {
                                        appState.setActiveClassIndex(index);
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          Expanded(
                            child: Consumer<AppState>(
                              builder: (context, appState, _) {
                                final document = appState.document;
                                if (document == null) {
                                  return Center(
                                    child: Text(
                                      'Select a class',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: placeholderColor,
                                      ),
                                    ),
                                  );
                                }

                                final activeScg =
                                    appState.activeSubjectClassGrade;
                                if (activeScg == null) {
                                  return Center(
                                    child: Text(
                                      'No class selected',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: placeholderColor,
                                      ),
                                    ),
                                  );
                                }

                                return GradeTable(
                                  subjectClassGrade: activeScg,
                                  classIndex: appState.activeClassIndex,
                                  onStudentTap: (studentIndex) {
                                    appState.focusStudent(
                                      appState.activeClassIndex,
                                      studentIndex,
                                    );
                                    showStudentDetailDialog(
                                      context,
                                      classIndex: appState.activeClassIndex,
                                      studentIndex: studentIndex,
                                      student: activeScg.students[studentIndex],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_isChatVisible)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: _chatWidth,
                          child: Material(
                            elevation: 12,
                            color: theme.scaffoldBackgroundColor,
                            child: Column(
                              children: [
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.chat_bubble_outline),
                                      const SizedBox(width: 8),
                                      const Text('Chat'),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () {
                                          setState(
                                            () => _isChatVisible = false,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(child: ChatWidget()),
                              ],
                            ),
                          ),
                        ),
                      if (_isChatVisible)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: _chatWidth - 6,
                          width: 12,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  _chatWidth = (_chatWidth - details.delta.dx)
                                      .clamp(_chatMinWidth, _chatMaxWidth);
                                });
                              },
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
