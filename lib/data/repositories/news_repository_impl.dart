import '../../domain/repositories/news_repository.dart';
import '../datasources/remote_data_source.dart';
import '../models/news_article.dart';

class NewsRepositoryImpl implements NewsRepository {
  final RemoteDataSource _remote;

  NewsRepositoryImpl(this._remote);

  @override
  Future<NewsResponse> getNews({
    String? entity,
    String? impact,
    String? source,
    int limit = 50,
    int offset = 0,
  }) {
    return _remote.getNews(
      entity: entity,
      impact: impact,
      source: source,
      limit: limit,
      offset: offset,
    );
  }
}
