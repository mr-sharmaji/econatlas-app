import 'package:flutter/foundation.dart';

@immutable
class NewsArticle {
  final String id;
  final String title;
  final String? summary;
  final String? body;
  final DateTime timestamp;
  final String source;
  final String? url;
  final String? primaryEntity;
  final String? impact;
  final double? confidence;

  const NewsArticle({
    required this.id,
    required this.title,
    this.summary,
    this.body,
    required this.timestamp,
    required this.source,
    this.url,
    this.primaryEntity,
    this.impact,
    this.confidence,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String?,
        body: json['body'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        source: json['source'] as String,
        url: json['url'] as String?,
        primaryEntity: json['primary_entity'] as String?,
        impact: json['impact'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'url': url,
        'primary_entity': primaryEntity,
        'impact': impact,
        'confidence': confidence,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NewsArticle(title: $title, source: $source)';
}

@immutable
class NewsResponse {
  final List<NewsArticle> articles;
  final int count;

  const NewsResponse({required this.articles, required this.count});

  factory NewsResponse.fromJson(Map<String, dynamic> json) => NewsResponse(
        articles: (json['articles'] as List<dynamic>)
            .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );
}
