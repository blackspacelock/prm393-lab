// Domain layer — abstract contract; data layer provides the implementation.
// Open/closed: new data sources can be wired in without changing use cases.
import '../entities/publication.dart';

abstract class PublicationRepository {
  Future<List<Publication>> searchPublications(String query);
  Future<List<Publication>> getTopPapers({String? topic});
}
