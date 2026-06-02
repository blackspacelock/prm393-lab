// Data layer — raw journal/source model deserialized from OpenAlex primary_location.source.
import '../../domain/entities/journal.dart';

class JournalModel {
  final String id;
  final String displayName;

  const JournalModel({required this.id, required this.displayName});

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    return JournalModel(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Unknown Journal',
    );
  }

  Journal toEntity() => Journal(id: id, displayName: displayName);
}
