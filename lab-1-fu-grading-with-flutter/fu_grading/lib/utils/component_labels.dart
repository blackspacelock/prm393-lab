const Map<String, String> kComponentLabels = {
  'Final Exam': 'Final Exam',
  'Final Exam Resit': 'Final Exam (Resit)',
  'Assignment 1': 'Assignment 1',
  'Assignment 2': 'Assignment 2',
  'Progress Test 1': 'Progress Test 1',
  'Progress Test 2': 'Progress Test 2',
  'Lab 1': 'Lab 1',
  'Lab 2': 'Lab 2',
  'Quiz 1': 'Quiz 1',
  'Quiz 2': 'Quiz 2',
  'Quiz 3': 'Quiz 3',
};

String labelFor(String component) => kComponentLabels[component] ?? component;
