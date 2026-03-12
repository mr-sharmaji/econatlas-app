import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/news_article.dart';
import 'repository_providers.dart';

class NewsFilter {
  final String? entity;
  final String? impact;

  const NewsFilter({this.entity, this.impact});

  @override
  bool operator ==(Object other) =>
      other is NewsFilter && other.entity == entity && other.impact == impact;

  @override
  int get hashCode => Object.hash(entity, impact);
}

final newsFilterProvider = StateProvider<NewsFilter>((ref) {
  return const NewsFilter();
});

final newsProvider = FutureProvider.autoDispose<List<NewsArticle>>((ref) async {
  final filter = ref.watch(newsFilterProvider);
  final repo = ref.watch(newsRepositoryProvider);
  final response = await repo.getNews(
    entity: filter.entity,
    impact: filter.impact,
    limit: 50,
  );
  return response.articles;
});
