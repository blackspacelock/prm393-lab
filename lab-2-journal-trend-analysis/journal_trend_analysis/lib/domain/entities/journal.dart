// Domain layer — clean entity with no JSON or framework dependencies.
import 'package:equatable/equatable.dart';

class Journal extends Equatable {
  final String id;
  final String displayName;

  const Journal({required this.id, required this.displayName});

  @override
  List<Object?> get props => [id, displayName];
}
