import 'package:equatable/equatable.dart';

class Concept extends Equatable {
  final String displayName;
  final double score;
  final int level;

  const Concept({
    required this.displayName,
    required this.score,
    required this.level,
  });

  @override
  List<Object?> get props => [displayName];
}
