// Utility functions for formatting display values and reconstructing abstracts.
class Formatter {
  /// Converts an OpenAlex abstract_inverted_index map back into a readable string.
  /// The inverted index maps each word to its list of character positions.
  static String reconstructAbstract(Map<String, dynamic>? invertedIndex) {
    if (invertedIndex == null || invertedIndex.isEmpty) return '';

    int maxPos = 0;
    for (final positions in invertedIndex.values) {
      for (final pos in (positions as List).cast<int>()) {
        if (pos > maxPos) maxPos = pos;
      }
    }

    final words = List<String>.filled(maxPos + 1, '');
    invertedIndex.forEach((word, positions) {
      for (final pos in (positions as List).cast<int>()) {
        if (pos <= maxPos) words[pos] = word;
      }
    });

    return words.join(' ').trim();
  }

  /// Formats a citation count into a compact human-readable string.
  static String formatCitationCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  static String formatYear(int? year) => year?.toString() ?? 'Unknown';

  static String formatDouble(double value) => value.toStringAsFixed(1);
}
