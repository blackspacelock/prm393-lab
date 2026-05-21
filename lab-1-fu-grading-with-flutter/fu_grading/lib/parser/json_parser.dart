/// Parser for JSON files exported from Python FG parser
///
/// Converts JSON format:
/// {
///   "version": "1.1",
///   "semester": "Spring2024",
///   "login": "phuonglhk",
///   "components": [...],
///   "classes": [{subject, classCode, students: [{name, roll}, ...]}]
/// }
///
/// Into our FgDocument model structure.

import 'dart:convert';
import 'dart:typed_data';

import '../models/fg_document.dart';
import '../models/teacher_grade.dart';

class JsonParser {
  final String jsonString;

  JsonParser(this.jsonString);

  /// Parses JSON string and returns an FgDocument
  FgDocument parse({Uint8List? buffer}) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // Extract metadata
      final version = _readString(json, const ['version', 'Version']) ?? '1.0';
      final semester =
          _readString(json, const ['semester', 'Semester']) ?? 'Unknown';
      final login = _readString(json, const ['login', 'Login']) ?? 'user';
      final password = _readString(json, const ['password', 'Password']) ?? '';

      final componentsList = _readStringList(json, const [
        'components',
        'Components',
      ]);

      // Extract classes and students
      final subjectClassGrades = <SubjectClassGrade>[];
      final classesList = _readList(json, const [
        'classes',
        'subjectClassGrades',
        'SubjectClassGrades',
      ]);

      for (final classJson in classesList) {
        final classData = classJson as Map<String, dynamic>;
        final subject =
            _readString(classData, const ['subject', 'Subject']) ?? 'Unknown';
        final classCode =
            _readString(classData, const [
              'classCode',
              'ClassCode',
              'class',
              'Class',
            ]) ??
            'Unknown';

        final classComponents = _readStringList(classData, const [
          'components',
          'Components',
        ]);

        // Extract students for this class
        final studentsList = <Student>[];
        final studentsJson = _readList(classData, const [
          'students',
          'Students',
        ]);

        final resolvedComponents = classComponents.isNotEmpty
            ? classComponents
            : _deriveComponentsFromStudents(studentsJson, componentsList);

        for (final studentJson in studentsJson) {
          final studentData = studentJson as Map<String, dynamic>;
          final name =
              _readString(studentData, const ['name', 'Name']) ?? 'Unknown';
          final roll = _readString(studentData, const ['roll', 'Roll']) ?? '';
          final comment =
              _readString(studentData, const ['comment', 'Comment']) ?? '';

          final gradesJson = _readList(studentData, const ['grades', 'Grades']);
          final grades = <GradeComponent>[];

          if (gradesJson.isNotEmpty) {
            for (int i = 0; i < gradesJson.length; i++) {
              final gradeData = gradesJson[i] as Map<String, dynamic>;
              final component =
                  _readString(gradeData, const ['component', 'Component']) ??
                  (i < resolvedComponents.length
                      ? resolvedComponents[i]
                      : 'Component${i + 1}');
              // Try to read numeric grade first; if absent but a textual
              // value exists, store it in `raw` so the UI/export preserves it.
              final gradeValue = _readDouble(gradeData, const [
                'grade',
                'Grade',
              ]);
              String? rawValue;
              if (gradeValue == null) {
                final rawCandidate = gradeData['grade'];
                if (rawCandidate is String && rawCandidate.isNotEmpty) {
                  rawValue = rawCandidate;
                }
              }

              grades.add(
                GradeComponent(
                  component: component,
                  grade: gradeValue,
                  raw: rawValue,
                ),
              );
            }
          } else {
            for (final component in resolvedComponents) {
              grades.add(GradeComponent(component: component, grade: null));
            }
          }

          studentsList.add(
            Student(roll: roll, name: name, grades: grades, comment: comment),
          );
        }

        subjectClassGrades.add(
          SubjectClassGrade(
            subject: subject,
            classCode: classCode,
            components: resolvedComponents,
            students: studentsList,
          ),
        );
      }

      // Create TeacherGrade
      final teacherGrade = TeacherGrade(
        versio: version,
        semester: semester,
        logi: login,
        password: password,
        subjectClassGrades: subjectClassGrades,
      );

      // Create FgDocument
      // For JSON files, we don't have the original binary buffer or grade offsets
      // (grades are null in the JSON export)
      return FgDocument(
        buffer: buffer ?? Uint8List(0),
        data: teacherGrade,
        gradeOffsets: {}, // No offsets for JSON
        unsavableEdits: {},
        isDirty: false,
      );
    } catch (e) {
      throw Exception('Failed to parse JSON: $e');
    }
  }

  List<dynamic> _readList(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) return value;
    }
    return const [];
  }

  List<String> _readStringList(Map<String, dynamic> json, List<String> keys) {
    final rawList = _readList(json, keys);
    return rawList.whereType<String>().toList();
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String) return value;
    }
    return null;
  }

  double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value);
      }
    }
    return null;
  }

  List<String> _deriveComponentsFromStudents(
    List<dynamic> studentsJson,
    List<String> fallbackComponents,
  ) {
    if (fallbackComponents.isNotEmpty) {
      return fallbackComponents;
    }

    for (final studentJson in studentsJson) {
      final studentData = studentJson as Map<String, dynamic>;
      final gradesJson = _readList(studentData, const ['grades', 'Grades']);
      if (gradesJson.isEmpty) continue;

      final derived = <String>[];
      for (final gradeJson in gradesJson) {
        final gradeData = gradeJson as Map<String, dynamic>;
        final component = _readString(gradeData, const [
          'component',
          'Component',
        ]);
        if (component != null && component.isNotEmpty) {
          derived.add(component);
        }
      }

      if (derived.isNotEmpty) {
        return derived;
      }
    }

    return fallbackComponents;
  }
}
