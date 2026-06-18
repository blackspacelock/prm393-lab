// Domain layer — entities for research trend heatmap by country/institution.
import 'package:equatable/equatable.dart';

/// Research output data for a single country.
class CountryHeatmapData extends Equatable {
  final String countryCode; // ISO 3166-1 alpha-2
  final String countryName;
  final int worksCount;

  const CountryHeatmapData({
    required this.countryCode,
    required this.countryName,
    required this.worksCount,
  });

  @override
  List<Object?> get props => [countryCode, countryName, worksCount];
}

/// Research output data for a single institution.
class InstitutionHeatmapData extends Equatable {
  final String id;
  final String displayName;
  final String countryCode;
  final int worksCount;

  const InstitutionHeatmapData({
    required this.id,
    required this.displayName,
    required this.countryCode,
    required this.worksCount,
  });

  @override
  List<Object?> get props => [id, displayName, countryCode, worksCount];
}
