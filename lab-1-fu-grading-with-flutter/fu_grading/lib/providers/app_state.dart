import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/fg_document.dart';
import '../models/teacher_grade.dart';
import '../parser/fg_parser.dart';
import '../parser/json_parser.dart';
import '../services/excel_service.dart';
import '../services/fg_deserializer_service.dart';
import '../utils/score_utils.dart';

/// Application state provider for the FU Grading app.
///
/// Manages the loaded `.fg` document, the currently active class, file path,
/// and provides methods for loading, saving, and editing grades.
class AppState extends ChangeNotifier {
  FgDocument? _document;
  List<dynamic>? _subjectConfigs;
  String? _subjectConfigPath;
  int _activeClassIndex = 0;
  String? _filePath;
  int? _focusedClassIndex;
  int? _focusedStudentIndex;
  // Persisted column selections for exporting: map classIndex -> list of component indices
  Map<int, List<int>> _savedExportColumns = {};

  FgDocument? get document => _document;
  List<dynamic>? get subjectConfigs => _subjectConfigs;
  String? get subjectConfigPath => _subjectConfigPath;
  int get activeClassIndex => _activeClassIndex;
  String? get filePath => _filePath;
  int? get focusedClassIndex => _focusedClassIndex;
  int? get focusedStudentIndex => _focusedStudentIndex;

  bool get isDirty => _document?.isDirty ?? false;

  /// Returns a copy of saved export column selections. If a class is not
  /// present, that means "all columns" should be exported for that class.
  Map<int, List<int>> get savedExportColumns =>
      _savedExportColumns.map((k, v) => MapEntry(k, List<int>.from(v)));

  /// Save the user's selection of columns to export. Overwrites previous
  /// selection map.
  void saveExportColumnSelection(Map<int, List<int>> sels) {
    _savedExportColumns = {};
    sels.forEach((k, v) {
      _savedExportColumns[k] = List<int>.from(v);
    });
    notifyListeners();
  }

  SubjectClassGrade? get activeSubjectClassGrade {
    if (_document == null ||
        _activeClassIndex >= _document!.data.subjectClassGrades.length) {
      return null;
    }
    return _document!.data.subjectClassGrades[_activeClassIndex];
  }

  Future<void> loadFile(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      await loadFileFromBytes(bytes, filePath: path);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadFileFromBytes(List<int> bytes, {String? filePath}) async {
    try {
      final uint8bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      late final FgDocument doc;

      if (!kIsWeb && filePath != null) {
        try {
          final jsonString = await FgDeserializerService.deserializeToJson(
            filePath,
          );
          doc = JsonParser(jsonString).parse(buffer: uint8bytes);
        } catch (_) {
          final parser = FgParser(uint8bytes);
          doc = parser.parse();
        }
      } else {
        final parser = FgParser(uint8bytes);
        doc = parser.parse();
      }

      _document = doc;
      _filePath = filePath;
      _activeClassIndex = 0;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadJsonFromBytes(List<int> bytes) async {
    try {
      final jsonString = utf8.decode(bytes);
      final parser = JsonParser(jsonString);
      final doc = parser.parse();

      _document = doc;
      _filePath = null;
      _activeClassIndex = 0;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadExcelFromBytes(List<int> bytes, {String? filePath}) async {
    try {
      final uint8bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final doc = await ExcelService.importFromExcel(uint8bytes);

      _document = doc;
      _filePath = filePath;
      _activeClassIndex = 0;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Load a `subjectconfig.json` content from bytes and store it in state.
  Future<void> loadSubjectConfigFromBytes(
    List<int> bytes, {
    String? filePath,
  }) async {
    try {
      final jsonString = utf8.decode(bytes);
      final parsed = jsonDecode(jsonString);

      if (parsed is List) {
        _subjectConfigs = parsed;
      } else {
        _subjectConfigs = [parsed];
      }

      // Remember the path of the loaded subject config if provided.
      _subjectConfigPath = filePath;

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveFile() async {
    if (_document == null || _filePath == null) {
      throw Exception('No document loaded or file path not set');
    }

    try {
      final lowerPath = _filePath!.toLowerCase();
      if (lowerPath.endsWith('.xlsx') || lowerPath.endsWith('.xls')) {
        await ExcelService.exportToExcel(_document!, _filePath!);
        _document!.isDirty = false;
        notifyListeners();
      } else {
        final jsonMap = _document!.data.toJson();
        final jsonString = jsonEncode(jsonMap);

        final tempDir = await Directory.systemTemp.createTemp('fugrade');
        final tempJsonFile = File('${tempDir.path}/temp_export.json');
        await tempJsonFile.writeAsString(jsonString);

        final result = await Process.run('dotnet', [
          'run',
          '--project',
          '../DeserializeFGFile/DeserializeFGFile',
          'save',
          tempJsonFile.path,
          _filePath!,
        ]);

        if (result.stdout.toString().contains('SAVE_SUCCESS')) {
          _document!.isDirty = false;
          notifyListeners();
        } else {
          throw Exception('${result.stdout} ${result.stderr}');
        }

        if (await tempJsonFile.exists()) {
          await tempJsonFile.delete();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  int get unsavableEditCount => _document?.unsavableEdits.length ?? 0;

  // Tracks cells edited during this session so UI can highlight them.
  final Set<(int, int, int)> _editedCells = {};

  Future<void> saveFileAs(String newPath) async {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    try {
      await _writeDocumentToPath(_document!, newPath);
      _filePath = newPath;
      _document!.isDirty = false;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> exportSelectedClassesAs(
    String newPath,
    List<int> classIndices,
  ) async {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    if (classIndices.isEmpty) {
      throw Exception('No classes selected');
    }

    try {
      final filteredDocument = _buildFilteredDocument(classIndices);
      await _writeDocumentToPath(filteredDocument, newPath);
    } catch (e) {
      rethrow;
    }
  }

  /// Returns true if the given cell was edited by the user during this session.
  bool isCellEdited(int classIndex, int studentIndex, int componentIndex) {
    return _editedCells.contains((classIndex, studentIndex, componentIndex));
  }

  /// Exports selected classes with only the selected component columns.
  ///
  /// [selectedColsByClass] maps original class index -> list of component indices
  /// to include for that class.
  Future<void> exportSelectedClassesAndColumnsAs(
    String newPath,
    List<int> classIndices,
    Map<int, List<int>> selectedColsByClass,
  ) async {
    if (_document == null) throw Exception('No document loaded');

    final uniqueIndices = classIndices.toSet().toList()..sort();
    final selectedClasses = <SubjectClassGrade>[];

    for (final classIndex in uniqueIndices) {
      if (classIndex < 0 ||
          classIndex >= _document!.data.subjectClassGrades.length)
        continue;

      final scg = _document!.data.subjectClassGrades[classIndex];
      final selectedCols = selectedColsByClass[classIndex] ?? [];

      final newComponents = <String>[];
      final newStudents = <Student>[];

      for (final ci in selectedCols) {
        if (ci >= 0 && ci < scg.components.length)
          newComponents.add(scg.components[ci]);
      }

      for (final s in scg.students) {
        final newGrades = <GradeComponent>[];
        for (final ci in selectedCols) {
          if (ci >= 0 && ci < s.grades.length) {
            final g = s.grades[ci];
            newGrades.add(
              GradeComponent(
                component: g.component,
                grade: g.grade,
                raw: g.raw,
              ),
            );
          } else {
            // Missing component index -> add empty placeholder
            newGrades.add(GradeComponent(component: ''));
          }
        }

        newStudents.add(
          Student(
            roll: s.roll,
            name: s.name,
            grades: newGrades,
            comment: s.comment,
          ),
        );
      }

      selectedClasses.add(
        SubjectClassGrade(
          subject: scg.subject,
          classCode: scg.classCode,
          components: newComponents,
          students: newStudents,
        ),
      );
    }

    final teacherGrade = TeacherGrade(
      versio: _document!.data.versio,
      semester: _document!.data.semester,
      logi: _document!.data.logi,
      password: _document!.data.password,
      subjectClassGrades: selectedClasses,
    );

    final exportDoc = FgDocument(
      buffer: Uint8List(0),
      data: teacherGrade,
      gradeOffsets: {},
      unsavableEdits: {},
      isDirty: _document!.isDirty,
    );

    await _writeDocumentToPath(exportDoc, newPath);
  }

  Future<void> _writeDocumentToPath(FgDocument document, String path) async {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.xlsx') || lowerPath.endsWith('.xls')) {
      await ExcelService.exportToExcel(document, path);
      return;
    }

    final jsonMap = document.data.toJson();
    final jsonString = jsonEncode(jsonMap);

    final tempDir = await Directory.systemTemp.createTemp('fugrade');
    final tempJsonFile = File('${tempDir.path}/temp_export.json');
    await tempJsonFile.writeAsString(jsonString);

    final result = await Process.run('dotnet', [
      'run',
      '--project',
      '../DeserializeFGFile/DeserializeFGFile',
      'save',
      tempJsonFile.path,
      path,
    ]);

    if (!result.stdout.toString().contains('SAVE_SUCCESS')) {
      throw Exception('${result.stdout} ${result.stderr}');
    }

    if (await tempJsonFile.exists()) {
      await tempJsonFile.delete();
    }
  }

  FgDocument _buildFilteredDocument(List<int> classIndices) {
    final uniqueIndices = classIndices.toSet().toList()..sort();
    final selectedClasses = <SubjectClassGrade>[];
    final selectedOffsets = <(int, int, int), int>{};
    final selectedUnsavable = <(int, int, int)>{};

    for (final classIndex in uniqueIndices) {
      if (classIndex < 0 ||
          classIndex >= _document!.data.subjectClassGrades.length) {
        continue;
      }

      final scg = _document!.data.subjectClassGrades[classIndex];
      final newClassIndex = selectedClasses.length;
      selectedClasses.add(scg);

      for (
        int studentIndex = 0;
        studentIndex < scg.students.length;
        studentIndex++
      ) {
        for (
          int componentIndex = 0;
          componentIndex < scg.students[studentIndex].grades.length;
          componentIndex++
        ) {
          final originalKey = (classIndex, studentIndex, componentIndex);
          final newKey = (newClassIndex, studentIndex, componentIndex);

          final offset = _document!.gradeOffsets[originalKey];
          if (offset != null) {
            selectedOffsets[newKey] = offset;
          }

          if (_document!.unsavableEdits.contains(originalKey)) {
            selectedUnsavable.add(newKey);
          }
        }
      }
    }

    final teacherGrade = TeacherGrade(
      versio: _document!.data.versio,
      semester: _document!.data.semester,
      logi: _document!.data.logi,
      password: _document!.data.password,
      subjectClassGrades: selectedClasses,
    );

    return FgDocument(
      buffer: _document!.buffer,
      data: teacherGrade,
      gradeOffsets: selectedOffsets,
      unsavableEdits: selectedUnsavable,
      isDirty: _document!.isDirty,
    );
  }

  void updateGrade(
    int classIndex,
    int studentIndex,
    int componentIndex,
    double? value,
    String? raw,
  ) {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    if (classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $classIndex');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];
    if (studentIndex >= scg.students.length) {
      throw Exception('Invalid student index: $studentIndex');
    }

    final student = scg.students[studentIndex];
    if (componentIndex >= student.grades.length) {
      throw Exception('Invalid component index: $componentIndex');
    }

    final key = (classIndex, studentIndex, componentIndex);
    if (raw != null && raw.isNotEmpty) {
      _document!.unsavableEdits.add(key);
    } else {
      _document!.unsavableEdits.remove(key);
    }

    // Track that this cell was edited by the user so UI can show warnings
    _editedCells.add(key);

    student.grades[componentIndex] = student.grades[componentIndex].copyWith(
      grade: value,
      raw: raw,
    );

    _document!.isDirty = true;
    notifyListeners();
  }

  void clearColumn(int classIndex, int componentIndex) {
    if (_document == null) throw Exception('No document loaded');
    if (classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $classIndex');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];
    for (int si = 0; si < scg.students.length; si++) {
      final key = (classIndex, si, componentIndex);
      _document!.unsavableEdits.remove(key);
      scg.students[si].grades[componentIndex] = scg
          .students[si]
          .grades[componentIndex]
          .copyWith(grade: null, raw: null);
    }

    _document!.isDirty = true;
    notifyListeners();
  }

  void applyColumnCopy(
    int classIndex,
    List<int> srcCols,
    int dstCol,
    double bonus,
  ) {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    if (classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $classIndex');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];

    if (dstCol >= scg.components.length) {
      throw Exception('Invalid destination column index: $dstCol');
    }

    for (final srcCol in srcCols) {
      if (srcCol >= scg.components.length) {
        throw Exception('Invalid source column index: $srcCol');
      }
    }

    for (int si = 0; si < scg.students.length; si++) {
      final student = scg.students[si];
      final sourceGrades = srcCols
          .map((ci) => student.grades[ci].grade)
          .toList();
      final newValue = ScoreUtils.computeCopyScore(sourceGrades, bonus);

      if (newValue != null) {
        student.grades[dstCol] = student.grades[dstCol].copyWith(
          grade: newValue,
        );
        final key = (classIndex, si, dstCol);
        _document!.unsavableEdits.remove(key);
      }
    }

    _document!.isDirty = true;
    notifyListeners();
  }

  /// Add a new grading component (column) to the specified class.
  ///
  /// This appends the component name to the class' component list and adds a
  /// blank `GradeComponent` for every student in that class.
  void addComponent(int classIndex, String componentName) {
    if (_document == null) throw Exception('No document loaded');
    if (classIndex < 0 ||
        classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];

    // Prevent adding duplicate component names (normalize for robust comparison)
    String _norm(String s) =>
        s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final newNorm = _norm(componentName);
    for (final existing in scg.components) {
      if (_norm(existing) == newNorm) {
        throw Exception('Component name already exists');
      }
    }

    // Append component name
    scg.components.add(componentName);

    // Add empty GradeComponent for each student
    for (int si = 0; si < scg.students.length; si++) {
      scg.students[si].grades.add(GradeComponent(component: componentName));
    }

    _document!.isDirty = true;
    notifyListeners();
  }

  /// Remove a grading component (column) from the specified class.
  ///
  /// This removes the component name and the corresponding grade entry for
  /// every student. It also updates internal maps/sets that reference
  /// (classIndex, studentIndex, componentIndex) keys so offsets and edit
  /// markers remain consistent.
  void removeComponent(int classIndex, int componentIndex) {
    if (_document == null) throw Exception('No document loaded');
    if (classIndex < 0 ||
        classIndex >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index');
    }

    final scg = _document!.data.subjectClassGrades[classIndex];
    if (componentIndex < 0 || componentIndex >= scg.components.length) {
      throw Exception('Invalid component index');
    }

    // Remove component name
    scg.components.removeAt(componentIndex);

    // Remove grade entries for each student (if present)
    for (int si = 0; si < scg.students.length; si++) {
      final grades = scg.students[si].grades;
      if (componentIndex < grades.length) {
        grades.removeAt(componentIndex);
      }
    }

    // Rebuild gradeOffsets with adjusted component indices for this class
    final newOffsets = <(int, int, int), int>{};
    _document!.gradeOffsets.forEach((key, off) {
      final (ci, si, comp) = key;
      if (ci != classIndex) {
        newOffsets[key] = off;
      } else {
        if (comp == componentIndex) {
          // removed entry -> skip
          return;
        }
        final newComp = comp > componentIndex ? comp - 1 : comp;
        newOffsets[(ci, si, newComp)] = off;
      }
    });
    _document!.gradeOffsets.clear();
    _document!.gradeOffsets.addAll(newOffsets);

    // Update unsavableEdits set
    final newUnsavable = <(int, int, int)>{};
    for (final k in _document!.unsavableEdits) {
      final (ci, si, comp) = k;
      if (ci != classIndex) {
        newUnsavable.add(k);
      } else {
        if (comp == componentIndex) continue;
        final newComp = comp > componentIndex ? comp - 1 : comp;
        newUnsavable.add((ci, si, newComp));
      }
    }
    _document!.unsavableEdits.clear();
    _document!.unsavableEdits.addAll(newUnsavable);

    // Update edited cells tracking
    final newEdited = <(int, int, int)>{};
    for (final k in _editedCells) {
      final (ci, si, comp) = k;
      if (ci != classIndex) {
        newEdited.add(k);
      } else {
        if (comp == componentIndex) continue;
        final newComp = comp > componentIndex ? comp - 1 : comp;
        newEdited.add((ci, si, newComp));
      }
    }
    _editedCells.clear();
    _editedCells.addAll(newEdited);

    _document!.isDirty = true;
    notifyListeners();
  }

  void setActiveClassIndex(int index) {
    if (_document == null) {
      throw Exception('No document loaded');
    }

    if (index >= _document!.data.subjectClassGrades.length) {
      throw Exception('Invalid class index: $index');
    }

    _activeClassIndex = index;
    notifyListeners();
  }

  void focusStudent(int classIndex, int studentIndex) {
    _focusedClassIndex = classIndex;
    _focusedStudentIndex = studentIndex;
    notifyListeners();
  }

  void clearFocusedStudent() {
    if (_focusedClassIndex == null && _focusedStudentIndex == null) return;
    _focusedClassIndex = null;
    _focusedStudentIndex = null;
    notifyListeners();
  }

  void reset() {
    _document = null;
    _filePath = null;
    _activeClassIndex = 0;
    _focusedClassIndex = null;
    _focusedStudentIndex = null;
    notifyListeners();
  }
}
