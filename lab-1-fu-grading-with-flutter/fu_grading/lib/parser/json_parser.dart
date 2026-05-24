// Parser for JSON files exported from the C# FG deserializer.
//
// Converts JSON format:
// {
//   "version": "1.1",
//   "semester": "Spring2024",
//   "login": "phuonglhk",
//   "components": [...],
//   "classes": [{subject, classCode, students: [{name, roll}, ...]}]
// }
//
// Into our FgDocument model structure.

import 'dart:convert';
import 'dart:typed_data';

import '../models/fg_document.dart';
import '../models/teacher_grade.dart';
import 'fg_parser.dart';

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

          for (final comp in resolvedComponents) {
            Map<String, dynamic>? matchedData;

            for (final g in gradesJson) {
              final gMap = g as Map<String, dynamic>;
              final gComp = _readString(gMap, const ['component', 'Component']);
              if (gComp != null &&
                  gComp.trim().toLowerCase() == comp.trim().toLowerCase()) {
                matchedData = gMap;
                break;
              }
            }

            if (matchedData != null) {
              final gradeValue = _readDouble(matchedData, const [
                'grade',
                'Grade',
              ]);
              String? rawValue;
              if (gradeValue == null) {
                final rawCandidate = matchedData['grade'];
                if (rawCandidate is String && rawCandidate.isNotEmpty) {
                  rawValue = rawCandidate;
                }
              }
              grades.add(
                GradeComponent(
                  component: comp,
                  grade: gradeValue,
                  raw: rawValue,
                ),
              );
            } else {
              grades.add(GradeComponent(component: comp, grade: null));
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

      // Build grade offsets using foolproof Value Sequence Matching
      Map<(int, int, int), int> gradeOffsets = {};

      if (buffer != null && buffer.isNotEmpty) {
        try {
          // BƯỚC 1: Lấy danh sách điểm "kỳ vọng" từ JSON theo đúng thứ tự
          // Mỗi item lưu: (classIndex, studentIndex, componentIndex, expectedGrade)
          final expectedGrades = <(int, int, int, double)>[];
          for (int ci = 0; ci < subjectClassGrades.length; ci++) {
            final classGrade = subjectClassGrades[ci];
            for (int si = 0; si < classGrade.students.length; si++) {
              final student = classGrade.students[si];
              for (int gi = 0; gi < student.grades.length; gi++) {
                final gc = student.grades[gi];
                if (gc.grade != null) {
                  expectedGrades.add((ci, si, gi, gc.grade!));
                }
              }
            }
          }

          // BƯỚC 2: Quét file nhị phân và đối chiếu giá trị
          int expectedIdx = 0;
          for (int i = 0; i < buffer.length - 5; i++) {
            // Nếu đã tìm đủ số lượng điểm, dừng quét
            if (expectedIdx >= expectedGrades.length) break;

            // Tìm marker của 4-byte float trong BinaryFormatter
            if (buffer[i] == 0x08 && buffer[i + 1] == 0x0B) {
              final floatOffset = i + 2;

              // Đọc thử 4 byte tiếp theo xem ra số thực bao nhiêu
              final floatVal = ByteData.sublistView(
                buffer,
                floatOffset,
                floatOffset + 4,
              ).getFloat32(0, Endian.little);

              final expectedVal = expectedGrades[expectedIdx].$4;

              // Đối chiếu giá trị nhị phân với JSON (cho phép sai số cực nhỏ do float precision)
              if ((floatVal - expectedVal).abs() < 0.005) {
                // TUYỆT ĐỐI CHÍNH XÁC: Đây đúng là tọa độ của con điểm này!
                final ci = expectedGrades[expectedIdx].$1;
                final si = expectedGrades[expectedIdx].$2;
                final gi = expectedGrades[expectedIdx].$3;

                gradeOffsets[(ci, si, gi)] = floatOffset;
                expectedIdx++; // Chuyển sang tìm con điểm tiếp theo
                i += 5; // Nhảy cóc qua 4 byte điểm để tránh quét trùng
              }
            }
          }
        } catch (e) {
          // Fallback an toàn, giữ file không bị ghi đè bậy
        }
      }

      return FgDocument(
        buffer: buffer ?? Uint8List(0),
        data: teacherGrade,
        gradeOffsets: gradeOffsets,
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
