// Data models for the FU Grading App.
//
// These classes represent the in-memory structure parsed from a `.fg` file
// (a .NET BinaryFormatter stream). The hierarchy is:
//   TeacherGrade → SubjectClassGrade → Student → GradeComponent

/// Root object in an FgFile containing metadata and all subject-class grades.
class TeacherGrade {
  final String versio;
  final String semester;
  final String logi;
  final String password;
  final List<SubjectClassGrade> subjectClassGrades;

  const TeacherGrade({
    required this.versio,
    required this.semester,
    required this.logi,
    required this.password,
    required this.subjectClassGrades,
  });
}

/// A subject + class pairing (e.g., "PRN221" + "NET1710") with its student list
/// and ordered component names.
class SubjectClassGrade {
  final String subject;
  final String classCode;

  /// Ordered list of component names (e.g., ["Final Exam", "Assignment 1"]).
  final List<String> components;

  final List<Student> students;

  const SubjectClassGrade({
    required this.subject,
    required this.classCode,
    required this.components,
    required this.students,
  });
}

/// A student record with roll number, Vietnamese name, grade components, and
/// an optional comment.
class Student {
  final String roll;
  final String name;
  final List<GradeComponent> grades;
  final String comment;

  const Student({
    required this.roll,
    required this.name,
    required this.grades,
    this.comment = '',
  });

  /// Returns a copy of this [Student] with the given fields replaced.
  Student copyWith({
    String? roll,
    String? name,
    List<GradeComponent>? grades,
    String? comment,
  }) {
    return Student(
      roll: roll ?? this.roll,
      name: name ?? this.name,
      grades: grades ?? this.grades,
      comment: comment ?? this.comment,
    );
  }
}

/// A named score entry for a single grade component.
///
/// [grade] is `null` when the score is missing; otherwise it is in [0.0, 10.0].
class GradeComponent {
  final String component;

  /// The numeric grade value. `null` means no numeric score is stored.
  final double? grade;

  /// Raw textual value entered for this component (status, comment, or any
  /// non-numeric cell content). When present, this takes precedence for
  /// display/export and indicates the value cannot be patched back into
  /// the original binary `.fg` float storage.
  final String? raw;

  const GradeComponent({required this.component, this.grade, this.raw});

  /// Returns a copy of this [GradeComponent] with the given fields replaced.
  GradeComponent copyWith({
    String? component,
    // Use a sentinel to distinguish "pass null explicitly" from "keep existing".
    Object? grade = _keepGrade,
    Object? raw = _keepRaw,
  }) {
    return GradeComponent(
      component: component ?? this.component,
      grade: identical(grade, _keepGrade) ? this.grade : grade as double?,
      raw: identical(raw, _keepRaw) ? this.raw : raw as String?,
    );
  }
}

/// Sentinel object used by [GradeComponent.copyWith] to detect when [grade]
/// was not supplied (so the existing value is preserved).
const Object _keepGrade = Object();
const Object _keepRaw = Object();
