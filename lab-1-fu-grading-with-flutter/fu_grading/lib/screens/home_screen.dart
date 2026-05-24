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
        if (fileName.endsWith('.json')) {
          // Load as JSON
          await context.read<AppState>().loadJsonFromBytes(fileBytes);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved successfully')),
        );
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

    final savePath = await FileService.pickSavePath();
    if (savePath == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await appState.saveFileAs(savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved successfully')),
        );
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
    return Scaffold(
      body: Column(
        children: [
          // --- Toolbar ---
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
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
                  onPressed: _isLoading ? null : _exportExcel,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Excel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkMissingScores,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Check Missing'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _openCopyColumnsDialog,
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
                const Spacer(),
                const ThemeSwitcher(),
                const SizedBox(width: 16),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          // Loading indicator
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          // --- Main Content Area ---
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                // --- Left Sidebar ---
                Consumer<AppState>(
                  builder: (context, appState, _) {
                    final document = appState.document;
                    if (document == null) {
                      return Container(
                        width: 250,
                        color: Theme.of(context).cardColor,
                        child: const Center(child: Text('No file loaded')),
                      );
                    }

                    return Container(
                      width: 250,
                      color: Theme.of(context).cardColor,
                      child: ListView.builder(
                        itemCount: document.data.subjectClassGrades.length,
                        itemBuilder: (context, index) {
                          final scg = document.data.subjectClassGrades[index];
                          final isActive = appState.activeClassIndex == index;

                          return ListTile(
                            title: Text(
                              '${scg.subject} - ${scg.classCode}',
                              style: TextStyle(
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${scg.students.length} students',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isActive,
                            selectedTileColor:
                                Theme.of(context).scaffoldBackgroundColor,
                            onTap: () {
                              appState.setActiveClassIndex(index);
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
                // --- Main Content Area ---
                Expanded(
                  child: Consumer<AppState>(
                    builder: (context, appState, _) {
                      final document = appState.document;
                      if (document == null) {
                        return const Center(
                          child: Text(
                            'Select a class',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white54,
                            ),
                          ),
                        );
                      }

                      final activeScg = appState.activeSubjectClassGrade;
                      if (activeScg == null) {
                        return const Center(
                          child: Text(
                            'No class selected',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white54,
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
                // Chat panel overlay
                if (_isChatVisible)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: _chatWidth,
                    child: Material(
                      elevation: 12,
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Column(
                        children: [
                          // Header
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
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
                                    setState(() => _isChatVisible = false);
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
                // Left-edge drag detector for resizing
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
      ),
    );
  }
}
