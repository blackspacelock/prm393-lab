import 'package:equatable/equatable.dart';

class KeywordItem extends Equatable {
  final String name;
  final int frequency;
  final double avgScore;
  final double trendRatio;

  const KeywordItem({
    required this.name,
    required this.frequency,
    required this.avgScore,
    required this.trendRatio,
  });

  @override
  List<Object?> get props => [name];
}
