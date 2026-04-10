import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dio_client.dart';
import '../../data/datasources/artha_data_source.dart';
import 'settings_providers.dart';

/// Artha data source provider.
final arthaDataSourceProvider = Provider<ArthaDataSource>((ref) {
  return ArthaDataSource(ref.read(dioProvider));
});

/// Greeting provider — fetches context-aware greeting on load.
final arthaGreetingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ds = ref.read(arthaDataSourceProvider);
  return ds.getGreeting();
});

/// Suggestions provider — passes device_id for watchlist-aware suggestions.
final arthaSuggestionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final ds = ref.read(arthaDataSourceProvider);
  final deviceId = ref.read(deviceIdProvider);
  return ds.getSuggestions(deviceId: deviceId);
});

/// Sessions list provider.
final arthaSessionsProvider =
    FutureProvider.autoDispose<List<ChatSession>>((ref) async {
  final ds = ref.read(arthaDataSourceProvider);
  final deviceId = ref.read(deviceIdProvider);
  return ds.listSessions(deviceId);
});

/// Current active chat state.
class ArthaChatState {
  final String? sessionId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? thinkingStatus;
  final String? error;
  final List<String> followUpSuggestions;

  const ArthaChatState({
    this.sessionId,
    this.messages = const [],
    this.isLoading = false,
    this.thinkingStatus,
    this.error,
    this.followUpSuggestions = const [],
  });

  ArthaChatState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? thinkingStatus,
    String? error,
    List<String>? followUpSuggestions,
  }) {
    return ArthaChatState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      thinkingStatus: thinkingStatus,
      error: error,
      followUpSuggestions: followUpSuggestions ?? this.followUpSuggestions,
    );
  }
}

/// Main chat state notifier.
class ArthaChatNotifier extends StateNotifier<ArthaChatState> {
  final ArthaDataSource _ds;
  final String _deviceId;
  StreamSubscription<ArthaEvent>? _streamSub;

  ArthaChatNotifier(this._ds, this._deviceId)
      : super(const ArthaChatState());

  /// Start a new chat session.
  void newChat() {
    _streamSub?.cancel();
    state = const ArthaChatState();
  }

  /// Load an existing session's messages.
  Future<void> loadSession(String sessionId) async {
    state = state.copyWith(isLoading: true, sessionId: sessionId);
    try {
      final messages = await _ds.getSessionMessages(sessionId, _deviceId);
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        sessionId: sessionId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load chat history.',
      );
    }
  }

  /// Send a message and stream the response.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (state.isLoading) return;

    // Add user message immediately
    final userMsg = ChatMessage(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      sessionId: state.sessionId ?? '',
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );

    // Add placeholder assistant message for streaming
    final assistantMsg = ChatMessage(
      id: 'temp-assistant-${DateTime.now().millisecondsSinceEpoch}',
      sessionId: state.sessionId ?? '',
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isLoading: true,
      thinkingStatus: 'Artha is thinking...',
      followUpSuggestions: [],
    );

    try {
      final stream = _ds.streamChat(
        deviceId: _deviceId,
        message: text.trim(),
        sessionId: state.sessionId,
      );

      String fullContent = '';
      String? finalSessionId = state.sessionId;
      String? finalMessageId;
      final stockCards = <Map<String, dynamic>>[];
      final mfCards = <Map<String, dynamic>>[];

      _streamSub = stream.listen(
        (event) {
          switch (event.type) {
            case ArthaEventType.thinking:
              state = state.copyWith(
                thinkingStatus: event.data['status'] as String?,
              );
              break;

            case ArthaEventType.token:
              fullContent += event.data['text'] as String? ?? '';
              _updateAssistantMessage(fullContent, stockCards, mfCards, true);
              break;

            case ArthaEventType.stockCard:
              stockCards.add(event.data);
              _updateAssistantMessage(fullContent, stockCards, mfCards, true);
              break;

            case ArthaEventType.mfCard:
              mfCards.add(event.data);
              _updateAssistantMessage(fullContent, stockCards, mfCards, true);
              break;

            case ArthaEventType.suggestions:
              final rawSuggestions = event.data['suggestions'] as List<dynamic>?;
              if (rawSuggestions != null) {
                state = state.copyWith(
                  followUpSuggestions: rawSuggestions
                      .map((e) => e.toString())
                      .where((s) => s.isNotEmpty)
                      .take(4)
                      .toList(),
                );
              }
              break;

            case ArthaEventType.done:
              finalSessionId = event.data['session_id'] as String?;
              finalMessageId = event.data['message_id'] as String?;
              _updateAssistantMessage(
                  fullContent, stockCards, mfCards, false,
                  messageId: finalMessageId);
              state = state.copyWith(
                isLoading: false,
                sessionId: finalSessionId,
              );
              break;

            case ArthaEventType.error:
              final errorMsg = event.data['message'] as String? ??
                  'Something went wrong.';
              _updateAssistantMessage(errorMsg, [], [], false);
              state = state.copyWith(
                isLoading: false,
                error: errorMsg,
              );
              break;
          }
        },
        onError: (e) {
          _updateAssistantMessage(
              'Something went wrong. Please try again.', [], [], false);
          state = state.copyWith(
            isLoading: false,
            error: 'Connection error.',
          );
        },
        onDone: () {
          if (state.isLoading) {
            state = state.copyWith(isLoading: false);
          }
        },
      );
    } catch (e) {
      _updateAssistantMessage(
          'Failed to connect. Please try again.', [], [], false);
      state = state.copyWith(
        isLoading: false,
        error: 'Connection failed.',
      );
    }
  }

  void _updateAssistantMessage(
    String content,
    List<Map<String, dynamic>> stockCards,
    List<Map<String, dynamic>> mfCards,
    bool isStreaming, {
    String? messageId,
  }) {
    final msgs = [...state.messages];
    if (msgs.isNotEmpty && msgs.last.role == 'assistant') {
      final last = msgs.last;
      last.content = content;
      last.isStreaming = isStreaming;
      // Update stock/mf cards
      if (messageId != null) {
        msgs[msgs.length - 1] = ChatMessage(
          id: messageId,
          sessionId: last.sessionId,
          role: 'assistant',
          content: content,
          stockCards: stockCards,
          mfCards: mfCards,
          createdAt: last.createdAt,
          isStreaming: isStreaming,
        );
      }
    }
    state = state.copyWith(messages: msgs);
  }

  /// Submit feedback on a message.
  Future<void> submitFeedback(String messageId, int feedback) async {
    try {
      await _ds.submitFeedback(messageId, _deviceId, feedback);
      final msgs = state.messages.map((m) {
        if (m.id == messageId) {
          m.feedback = feedback;
        }
        return m;
      }).toList();
      state = state.copyWith(messages: msgs);
    } catch (_) {
      // Silent fail
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

/// Chat state provider.
final arthaChatProvider =
    StateNotifierProvider.autoDispose<ArthaChatNotifier, ArthaChatState>(
        (ref) {
  final ds = ref.read(arthaDataSourceProvider);
  final deviceId = ref.read(deviceIdProvider);
  return ArthaChatNotifier(ds, deviceId);
});

/// Autocomplete provider.
final arthaAutocompleteProvider = FutureProvider.autoDispose
    .family<List<AutocompleteItem>, String>((ref, query) async {
  if (query.length < 2) return [];
  final ds = ref.read(arthaDataSourceProvider);
  return ds.autocomplete(query);
});
