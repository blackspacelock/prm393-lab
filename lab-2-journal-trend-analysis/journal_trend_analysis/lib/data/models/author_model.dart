// Data layer — raw author model deserialized from the OpenAlex authorships array.
import '../../domain/entities/author.dart';

class AuthorModel {
  final String id;
  final String displayName;

  const AuthorModel({required this.id, required this.displayName});

  /// Parses a single element from the `authorships` array.
  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? {};
    return AuthorModel(
      id: author['id'] as String? ?? '',
      displayName: author['display_name'] as String? ?? 'Unknown Author',
    );
  }

  Author toEntity() => Author(id: id, displayName: displayName);
}
