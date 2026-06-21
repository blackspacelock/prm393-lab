import 'package:equatable/equatable.dart';

class KeywordItem extends Equatable {
  final String name;
  final int frequency;
  final double avgScore;
  final double trendRatio;
  final int level;

  const KeywordItem({
    required this.name,
    required this.frequency,
    required this.avgScore,
    required this.trendRatio,
    required this.level,
  });

  @override
  List<Object?> get props => [name];
}
