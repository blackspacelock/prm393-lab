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

  const Journal({
    required this.id,
    required this.displayName,
    this.publisher,
    this.type,
    this.worksCount = 0,
    this.citedByCount = 0,
    this.issn,
    this.homepageUrl,
  });

  @override
  List<Object?> get props => [id, displayName];
}
