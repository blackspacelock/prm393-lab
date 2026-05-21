import '../models/fg_document.dart';

/// Utility class for score computation and validation.
class ScoreUtils {
  static const double minScore = 0.0;
  static const double maxScore = 10.0;

  /// Clamps a score to [0.0, 10.0].
  static double clamp(double value) => value.clamp(minScore, maxScore);

  /// Computes the average of non-null source values, adds bonus, then clamps.
  /// Returns null if all source values are null.
  static double? computeCopyScore(List<double?> sources, double bonus) {
    final nonNull = sources.whereType<double>().toList();
    if (nonNull.isEmpty) return null;
    final avg = nonNull.reduce((a, b) => a + b) / nonNull.length;
    return clamp(avg + bonus);
  }

  /// Returns true if value is a valid score (0.0 ≤ value ≤ 10.0).
  static bool isValid(double value) => value >= minScore && value <= maxScore;

  /// Finds all missing scores in the document.
  ///
  /// Returns a list of missing score records, each containing:
  /// - subject: Subject code
  /// - classCode: Class code
  /// - roll: Student roll number
  /// - name: Student name
  /// - component: Grade component name
  ///
  /// The list is sorted by subject, classCode, roll, and component name.
  static List<
    ({
      String subject,
      String classCode,
      String roll,
      String name,
      String component,
    })
  >
  findMissingScores(FgDocument doc) {
    final missing =
        <
          ({
            String subject,
            String classCode,
            String roll,
            String name,
            String component,
          })
        >[];

    for (final scg in doc.data.subjectClassGrades) {
      for (final student in scg.students) {
        for (final grade in student.grades) {
          if (grade.grade == null) {
            missing.add((
              subject: scg.subject,
              classCode: scg.classCode,
              roll: student.roll,
              name: student.name,
              component: grade.component,
            ));
          }
        }
      }
    }

    // Sort by subject, classCode, roll, then component
    missing.sort((a, b) {
      int cmp = a.subject.compareTo(b.subject);
      if (cmp != 0) return cmp;
      cmp = a.classCode.compareTo(b.classCode);
      if (cmp != 0) return cmp;
      cmp = a.roll.compareTo(b.roll);
      if (cmp != 0) return cmp;
      return a.component.compareTo(b.component);
    });

    return missing;
  }
}
