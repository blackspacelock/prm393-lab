// Data layer — raw journal/source model deserialized from OpenAlex /sources endpoint.
import '../../domain/entities/journal.dart';

class JournalModel {
  final String id;
  final String displayName;
  final String? publisher;
  final String? type;
  final int worksCount;
  final int citedByCount;
  final String? issn;
  final String? homepageUrl;
  // Detailed fields
  final int? hIndex;
  final int? i10Index;
  final double? meanCitedness;
  final String? countryCode;
  final bool? isOa;
  final int? firstPublicationYear;
  final int? lastPublicationYear;
  final int? oaWorksCount;
  final List<JournalTopic> topTopics;

  const JournalModel({
    required this.id,
    required this.displayName,
    this.publisher,
    this.type,
    this.worksCount = 0,
    this.citedByCount = 0,
    this.issn,
    this.homepageUrl,
    this.hIndex,
    this.i10Index,
    this.meanCitedness,
    this.countryCode,
    this.isOa,
    this.firstPublicationYear,
    this.lastPublicationYear,
    this.oaWorksCount,
    this.topTopics = const [],
  });

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    final issnList = json['issn'] as List<dynamic>?;
    final summaryStats = json['summary_stats'] as Map<String, dynamic>?;
    final topicsRaw = json['topics'] as List<dynamic>? ?? [];

    final topics = topicsRaw.take(5).map((t) {
      final topic = t as Map<String, dynamic>;
      final field = topic['field'] as Map<String, dynamic>?;
      final domain = topic['domain'] as Map<String, dynamic>?;
      return JournalTopic(
        displayName: topic['display_name'] as String? ?? '',
        count: topic['count'] as int? ?? 0,
        fieldName: field?['display_name'] as String?,
        domainName: domain?['display_name'] as String?,
      );
    }).toList();

    return JournalModel(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Unknown Journal',
      publisher: json['host_organization_name'] as String?,
      type: json['type'] as String?,
      worksCount: json['works_count'] as int? ?? 0,
      citedByCount: json['cited_by_count'] as int? ?? 0,
      issn: issnList != null && issnList.isNotEmpty
          ? issnList.first as String?
          : null,
      homepageUrl: json['homepage_url'] as String?,
      hIndex: summaryStats?['h_index'] as int?,
      i10Index: summaryStats?['i10_index'] as int?,
      meanCitedness: (summaryStats?['2yr_mean_citedness'] as num?)?.toDouble(),
      countryCode: json['country_code'] as String?,
      isOa: json['is_oa'] as bool?,
      firstPublicationYear: json['first_publication_year'] as int?,
      lastPublicationYear: json['last_publication_year'] as int?,
      oaWorksCount: json['oa_works_count'] as int?,
      topTopics: topics,
    );
  }

  Journal toEntity() => Journal(
    id: id,
    displayName: displayName,
    publisher: publisher,
    type: type,
    worksCount: worksCount,
    citedByCount: citedByCount,
    issn: issn,
    homepageUrl: homepageUrl,
    hIndex: hIndex,
    i10Index: i10Index,
    meanCitedness: meanCitedness,
    countryCode: countryCode,
    isOa: isOa,
    firstPublicationYear: firstPublicationYear,
    lastPublicationYear: lastPublicationYear,
    oaWorksCount: oaWorksCount,
    topTopics: topTopics,
  );
}
