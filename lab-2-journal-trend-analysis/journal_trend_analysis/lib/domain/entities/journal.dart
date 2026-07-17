// Domain layer — clean entity with no JSON or framework dependencies.
import 'package:equatable/equatable.dart';

class Journal extends Equatable {
  final String id;
  final String displayName;
  final String? publisher;
  final String? type;
  final int worksCount;
  final int citedByCount;
  final String? issn;
  final String? homepageUrl;
  // Detailed fields (from single-source API)
  final int? hIndex;
  final int? i10Index;
  final double? meanCitedness;
  final String? countryCode;
  final bool? isOa;
  final int? firstPublicationYear;
  final int? lastPublicationYear;
  final int? oaWorksCount;
  final List<JournalTopic> topTopics;

  const Journal({
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

  @override
  List<Object?> get props => [id, displayName];
}

/// A topic associated with a journal.
class JournalTopic {
  final String displayName;
  final int count;
  final String? fieldName;
  final String? domainName;

  const JournalTopic({
    required this.displayName,
    required this.count,
    this.fieldName,
    this.domainName,
  });
}
