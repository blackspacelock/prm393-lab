// Domain layer — clean entity with no JSON or framework dependencies.
import 'package:equatable/equatable.dart';

class Author extends Equatable {
  final String id;
  final String displayName;

  const Author({required this.id, required this.displayName});

  @override
  List<Object?> get props => [id, displayName];
}
