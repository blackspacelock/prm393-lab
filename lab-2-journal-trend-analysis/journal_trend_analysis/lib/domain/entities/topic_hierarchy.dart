/// Represents an item in the OpenAlex topic hierarchy.
/// Can be a Domain, Field, Subfield, or Topic.
enum TopicLevel { domain, field, subfield, topic }

class TopicHierarchyItem {
  final String id;
  final String displayName;
  final TopicLevel level;
  final int? worksCount;

  const TopicHierarchyItem({
    required this.id,
    required this.displayName,
    required this.level,
    this.worksCount,
  });

  /// Label shown in autocomplete results.
  String get levelLabel => switch (level) {
    TopicLevel.domain => 'Domain',
    TopicLevel.field => 'Field',
    TopicLevel.subfield => 'Subfield',
    TopicLevel.topic => 'Topic',
  };

  /// The filter key used in the OpenAlex works endpoint.
  String get filterKey => switch (level) {
    TopicLevel.domain => 'topics.domain.id',
    TopicLevel.field => 'topics.field.id',
    TopicLevel.subfield => 'topics.subfield.id',
    TopicLevel.topic => 'topics.id',
  };
}
