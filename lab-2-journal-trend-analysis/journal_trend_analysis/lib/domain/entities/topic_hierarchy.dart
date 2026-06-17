/// Represents an item in the OpenAlex topic hierarchy.
/// Can be a Domain, Field, Subfield, Topic, or a Journal/Author filter.
enum TopicLevel { domain, field, subfield, topic, journal, author }

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
    TopicLevel.journal => 'Journal',
    TopicLevel.author => 'Author',
  };

  /// The filter key used in the OpenAlex works endpoint.
  String get filterKey => switch (level) {
    TopicLevel.domain => 'primary_topic.domain.id',
    TopicLevel.field => 'primary_topic.field.id',
    TopicLevel.subfield => 'primary_topic.subfield.id',
    TopicLevel.topic => 'primary_topic.id',
    TopicLevel.journal => 'default.search',
    TopicLevel.author => 'default.search',
  };
}
