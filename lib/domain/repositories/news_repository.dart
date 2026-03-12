import '../../data/models/news_article.dart';

abstract class NewsRepository {
  Future<NewsResponse> getNews({
    String? entity,
    String? impact,
    String? source,
    int limit = 50,
    int offset = 0,
  });
}
