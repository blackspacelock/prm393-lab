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

  const JournalModel({
    required this.id,
    required this.displayName,
    this.publisher,
    this.type,
    this.worksCount = 0,
    this.citedByCount = 0,
    this.issn,
    this.homepageUrl,
  });

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    final issnList = json['issn'] as List<dynamic>?;
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
  );
}
