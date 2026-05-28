import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/file_service.dart';
import '../widgets/grade_table.dart';
import '../widgets/student_detail_dialog.dart';
import '../widgets/copy_columns_dialog.dart';
import '../widgets/select_columns_dialog.dart';
import 'package:fu_grading/widgets/theme_switcher.dart';
import '../widgets/chat_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  bool _isChatVisible = false;
  final double _chatWidth = 360.0;

  bool _isExcelPath(String? path) {
    if (path == null) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.xlsx') || lower.endsWith('.xls');
  }

  Future<void> _openFile() async {
    final appState = context.read<AppState>();
    if (appState.isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Discard unsaved changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }

    setState(() => _isLoading = true);
    try {
      final (bytes, name, path) = await FileService.pickGradeFileBytes();
      if (bytes == null || name == null) return;

      final lower = name.toLowerCase();
      if (lower.endsWith('.json')) {
        await context.read<AppState>().loadJsonFromBytes(bytes);
      } else if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
        await context.read<AppState>().loadExcelFromBytes(
          bytes,
          filePath: path,
        );
      } else {
        await context.read<AppState>().loadFileFromBytes(bytes, filePath: path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openConfig() async {
    setState(() => _isLoading = true);
    try {
      final (bytes, name, path) = await FileService.pickConfigFileBytes();
      if (bytes != null && name != null) {
        await context.read<AppState>().loadSubjectConfigFromBytes(
          bytes,
          filePath: path,
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Config loaded')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading config: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFile() async {
    final appState = context.read<AppState>();
    if (appState.filePath == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No file loaded')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await appState.saveFile();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File saved')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFileAs() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }
    if (kIsWeb) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save As is not supported on web')),
        );
      return;
    }
    final savePath = await (_isExcelPath(appState.filePath)
        ? FileService.pickExcelSavePath()
        : FileService.pickSavePath());
    if (savePath == null) return;
    setState(() => _isLoading = true);
    try {
      await appState.saveFileAs(savePath);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File saved')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToFg() async {
    final appState = context.read<AppState>();
    if (appState.document == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    if (kIsWeb) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export to FG not supported on web')),
        );
      return;
    }

    final savePath = await FileService.pickSavePath();
    if (savePath == null) return;

    setState(() => _isLoading = true);
    try {
      await appState.saveFileAs(savePath);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Exported to .fg')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportActiveClassAsExcel() async {
    final appState = context.read<AppState>();
    final doc = appState.document;
    if (doc == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No document loaded')));
      return;
    }

    final classes = doc.data.subjectClassGrades;
    final classIndices = List<int>.generate(classes.length, (i) => i);

    // Ask user to select both tables and columns in one dialog.
    final selected = await showSelectColumnsDialog(
      context,
      classes: classes,
      classIndices: classIndices,
      initialSelection: appState.savedExportColumns,
    );
    if (selected == null || selected.isEmpty) return;

    final selectedClassIndices = selected.keys.toList()..sort();
    final savePath = await FileService.pickExcelSavePath();
    if (savePath == null) return;

    try {
      await appState.exportSelectedClassesAndColumnsAs(
        savePath,
        selectedClassIndices,
        selected,
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Export successful')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  /// Shows a dialog to input a new component name. Returns the entered
  /// component name or null if cancelled.
  Future<String?> showAddComponentDialog(BuildContext context) async {
    final controller = TextEditingController();
    String? error;
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (c, setState) {
            return AlertDialog(
              title: const Text('Add grading component'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Component name',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final v = controller.text.trim();
                    if (v.isEmpty) {
                      setState(() => error = 'Name cannot be empty');
                      return;
                    }
                    Navigator.of(ctx).pop(v);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return res;
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sidebarWidth = MediaQuery.of(context).size.width < 1200
        ? 220.0
        : 250.0;
    final placeholderColor =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.75) ?? Colors.white70;

    final appState = context.watch<AppState>();
    final openedPath = appState.filePath;
    final configPath = appState.subjectConfigPath;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Simple top bar
            Container(
              color: theme.cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top-left file/config path display
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Tooltip(
                            message: openedPath ?? 'No file loaded',
                            child: Text(
                              openedPath ?? 'No file loaded',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: Tooltip(
                            message: configPath ?? 'No config loaded',
                            child: Text(
                              configPath ?? 'No config',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _openFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _openConfig,
                        icon: const Icon(Icons.settings),
                        label: const Text('Open Config'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveFile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveFileAs,
                        icon: const Icon(Icons.save_as),
                        label: const Text('Save As'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _exportActiveClassAsExcel,
                        icon: const Icon(Icons.grid_on),
                        label: const Text('Export Excel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _exportToFg,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Export to FG'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final appState = context.read<AppState>();
                                final doc = appState.document;
                                if (doc == null) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No document loaded'),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final name = await showAddComponentDialog(
                                  context,
                                );
                                if (name == null || name.trim().isEmpty) return;

                                try {
                                  appState.addComponent(
                                    appState.activeClassIndex,
                                    name.trim(),
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added component "$name"',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Component'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final appState = context.read<AppState>();
                          final doc = appState.document;
                          if (doc == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No document loaded'),
                                ),
                              );
                            }
                            return;
                          }
                          showCopyColumnsDialog(
                            context,
                            subjectClassGrade: doc
                                .data
                                .subjectClassGrades[appState.activeClassIndex],
                            classIndex: appState.activeClassIndex,
                          );
                        },
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Copy Columns'),
                      ),
                      // "Missing Scores" feature removed from UI
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _legendItem(Colors.yellow.shade700, 'On-going'),
                              const SizedBox(width: 8),
                              _legendItem(Colors.deepOrange.shade700, 'PE/FE'),
                              const SizedBox(width: 8),
                              _legendItem(Colors.redAccent.shade200, 'Caution'),
                            ],
                          ),
                        ),
                      ),
                      const ThemeSwitcher(),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () =>
                            setState(() => _isChatVisible = !_isChatVisible),
                        icon: const Icon(Icons.chat),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Sidebar
                      Container(
                        width: sidebarWidth,
                        color: theme.cardColor,
                        child: Consumer<AppState>(
                          builder: (context, appState, _) {
                            final doc = appState.document;
                            if (doc == null) {
                              return const Center(
                                child: Text('No file loaded'),
                              );
                            }
                            return ListView.builder(
                              itemCount: doc.data.subjectClassGrades.length,
                              itemBuilder: (context, index) {
                                final scg = doc.data.subjectClassGrades[index];
                                final isActive =
                                    appState.activeClassIndex == index;
                                return ListTile(
                                  title: Text(
                                    '${scg.subject} - ${scg.classCode}',
                                    style: TextStyle(
                                      color: isActive
                                          ? theme.colorScheme.primary
                                          : null,
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
                                  onTap: () =>
                                      appState.setActiveClassIndex(index),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // Main
                      Expanded(
                        child: Consumer<AppState>(
                          builder: (context, appState, _) {
                            final doc = appState.document;
                            if (doc == null)
                              return Center(
                                child: Text(
                                  'Select a class',
                                  style: TextStyle(color: placeholderColor),
                                ),
                              );
                            final active = appState.activeSubjectClassGrade;
                            if (active == null)
                              return Center(
                                child: Text(
                                  'No class selected',
                                  style: TextStyle(color: placeholderColor),
                                ),
                              );
                            return GradeTable(
                              subjectClassGrade: active,
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
                                  student: active.students[studentIndex],
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
                              decoration: BoxDecoration(color: theme.cardColor),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline),
                                  const SizedBox(width: 8),
                                  const Text('Chat'),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        setState(() => _isChatVisible = false),
                                  ),
                                ],
                              ),
                            ),
                            const Expanded(child: ChatWidget()),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
