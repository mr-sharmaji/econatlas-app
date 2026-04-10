import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// SSE event types from the Artha chat backend.
enum ArthaEventType {
  thinking, // status pings ("Artha is thinking...", "Querying data...")
  thinkingText, // live content of the <thinking>...</thinking> reasoning block
  token, // answer text chunks
  stockCard,
  mfCard,
  suggestions,
  done,
  error,
}

/// A single SSE event from the chat stream.
class ArthaEvent {
  final ArthaEventType type;
  final Map<String, dynamic> data;

  ArthaEvent({required this.type, required this.data});
}

/// Chat session model.
class ChatSession {
  final String id;
  final String deviceId;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  ChatSession({
    required this.id,
    required this.deviceId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        deviceId: json['device_id'] as String,
        title: json['title'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        messageCount: (json['message_count'] as int?) ?? 0,
      );
}

/// Chat message model.
class ChatMessage {
  final String id;
  final String sessionId;
  final String role; // 'user' or 'assistant'
  String content;
  // Live-streamed reasoning from <thinking>...</thinking>. Displayed in a
  // collapsible pill above the answer bubble — not part of the main
  // content. Null for user messages and for old messages that pre-date
  // the thinking channel.
  String? thinkingText;
  final List<Map<String, dynamic>> stockCards;
  final List<Map<String, dynamic>> mfCards;
  int? feedback;
  final DateTime createdAt;

  // Streaming state
  bool isStreaming;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.thinkingText,
    this.stockCards = const [],
    this.mfCards = const [],
    this.feedback,
    required this.createdAt,
    this.isStreaming = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        thinkingText: json['thinking_text'] as String?,
        stockCards: (json['stock_cards'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        mfCards: (json['mf_cards'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        feedback: json['feedback'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Autocomplete item model.
class AutocompleteItem {
  final String? symbol;
  final String? schemeCode;
  final String name;
  final String type; // 'stock' or 'mf'
  final double? score;

  AutocompleteItem({
    this.symbol,
    this.schemeCode,
    required this.name,
    required this.type,
    this.score,
  });

  factory AutocompleteItem.fromJson(Map<String, dynamic> json) =>
      AutocompleteItem(
        symbol: json['symbol'] as String?,
        schemeCode: json['scheme_code'] as String?,
        name: json['name'] as String,
        type: json['type'] as String,
        score: (json['score'] as num?)?.toDouble(),
      );
}

/// Data source for Artha AI chat — handles SSE streaming + REST.
class ArthaDataSource {
  final Dio _dio;

  ArthaDataSource(this._dio);

  /// Stream a chat response via SSE.
  Stream<ArthaEvent> streamChat({
    required String deviceId,
    required String message,
    String? sessionId,
    List<Map<String, dynamic>> starredItems = const [],
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/chat/stream',
      data: {
        'device_id': deviceId,
        'message': message,
        if (sessionId != null) 'session_id': sessionId,
        if (starredItems.isNotEmpty) 'starred_items': starredItems,
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    final stream = response.data!.stream;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);

      // Parse SSE events from buffer
      while (buffer.contains('\n\n')) {
        final eventEnd = buffer.indexOf('\n\n');
        final eventBlock = buffer.substring(0, eventEnd);
        buffer = buffer.substring(eventEnd + 2);

        String? eventType;
        String? eventData;

        for (final line in eventBlock.split('\n')) {
          if (line.startsWith('event: ')) {
            eventType = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            eventData = line.substring(6).trim();
          }
        }

        if (eventType != null && eventData != null) {
          try {
            final data = json.decode(eventData) as Map<String, dynamic>;
            final type = switch (eventType) {
              'thinking' => ArthaEventType.thinking,
              'thinking_text' => ArthaEventType.thinkingText,
              'token' => ArthaEventType.token,
              'stock_card' => ArthaEventType.stockCard,
              'mf_card' => ArthaEventType.mfCard,
              'suggestions' => ArthaEventType.suggestions,
              'done' => ArthaEventType.done,
              'error' => ArthaEventType.error,
              _ => null,
            };
            if (type != null) {
              yield ArthaEvent(type: type, data: data);
            }
          } catch (_) {
            // Skip malformed events
          }
        }
      }
    }
  }

  /// Get context-aware greeting.
  Future<Map<String, dynamic>> getGreeting() async {
    final response = await _dio.get('/chat/greeting');
    return response.data as Map<String, dynamic>;
  }

  /// Get suggested prompts (watchlist-aware when device_id provided).
  Future<List<String>> getSuggestions({String? deviceId}) async {
    final response = await _dio.get(
      '/chat/suggestions',
      queryParameters: {if (deviceId != null) 'device_id': deviceId},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['suggestions'] as List<dynamic>)
        .map((e) => e as String)
        .toList();
  }

  /// List chat sessions.
  Future<List<ChatSession>> listSessions(String deviceId) async {
    final response = await _dio.get(
      '/chat/sessions',
      queryParameters: {'device_id': deviceId},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['sessions'] as List<dynamic>)
        .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get session with messages.
  Future<List<ChatMessage>> getSessionMessages(
    String sessionId,
    String deviceId,
  ) async {
    final response = await _dio.get(
      '/chat/sessions/$sessionId',
      queryParameters: {'device_id': deviceId},
    );
    final data = response.data as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>? ?? [];
    return messages
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Delete a session.
  Future<void> deleteSession(String sessionId, String deviceId) async {
    await _dio.delete(
      '/chat/sessions/$sessionId',
      queryParameters: {'device_id': deviceId},
    );
  }

  /// Submit feedback.
  Future<void> submitFeedback(
    String messageId,
    String deviceId,
    int feedback,
  ) async {
    await _dio.post('/chat/feedback', data: {
      'message_id': messageId,
      'device_id': deviceId,
      'feedback': feedback,
    });
  }

  /// Autocomplete search.
  Future<List<AutocompleteItem>> autocomplete(String query) async {
    final response = await _dio.get(
      '/chat/autocomplete',
      queryParameters: {'q': query},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => AutocompleteItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
