// Data layer — concrete repository; converts data models to domain entities.
import '../../domain/entities/publication.dart';
import '../../domain/repositories/publication_repository.dart';
import '../datasources/publication_remote_datasource.dart';

class PublicationRepositoryImpl implements PublicationRepository {
  final PublicationRemoteDataSource _remoteDataSource;

  PublicationRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Publication>> searchPublications(String query) async {
    final models = await _remoteDataSource.searchPublications(query);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Publication>> getTopPapers({String? topic}) async {
    final models = await _remoteDataSource.getTopPapers(topic: topic);
    return models.map((m) => m.toEntity()).toList();
  }
}
