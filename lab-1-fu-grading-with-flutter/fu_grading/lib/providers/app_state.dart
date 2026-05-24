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
  int _activeClassIndex = 0;
  String? _filePath;
  int? _focusedClassIndex;
  int? _focusedStudentIndex;

  FgDocument? get document => _document;
  int get activeClassIndex => _activeClassIndex;
  String? get filePath => _filePath;
  int? get focusedClassIndex => _focusedClassIndex;
  int? get focusedStudentIndex => _focusedStudentIndex;

  bool get isDirty => _document?.isDirty ?? false;

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
