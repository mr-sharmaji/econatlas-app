import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/connectivity.dart';
import '../../../data/datasources/artha_data_source.dart';
import '../../../data/local/chat_database.dart';
import '../../providers/artha_providers.dart';
import '../../providers/settings_providers.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/stock_mini_card.dart';
import 'widgets/mf_mini_card.dart';
import 'widgets/suggestion_chips.dart';
import 'widgets/thinking_indicator.dart';
import 'widgets/share_card.dart';

class ArthaScreen extends ConsumerStatefulWidget {
  const ArthaScreen({super.key});

  @override
  ConsumerState<ArthaScreen> createState() => _ArthaScreenState();
}

class _ArthaScreenState extends ConsumerState<ArthaScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _showHistory = false;
  bool _isOffline = false;

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  // Autocomplete
  List<AutocompleteItem> _autocompleteResults = [];
  bool _showAutocomplete = false;
  Timer? _autocompleteDebounce;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _checkConnectivity();
    _syncLocalHistory();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _autocompleteDebounce?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _checkConnectivity() async {
    final offline = await isOffline();
    if (mounted) setState(() => _isOffline = offline);
  }

  Future<void> _syncLocalHistory() async {
    try {
      final deviceId = ref.read(deviceIdProvider);
      // Load from server and cache locally
      final ds = ref.read(arthaDataSourceProvider);
      final sessions = await ds.listSessions(deviceId);
      await ChatLocalDatabase.syncFromServer(sessions);
    } catch (_) {
      // Silent — local cache still available
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _showAutocomplete = false);
    ref.read(arthaChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _sendMessage();
  }

  // --- Voice input ---
  void _toggleVoiceInput() async {
    if (!_speechAvailable) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  // --- Autocomplete ---
  void _onTextChanged() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    // Check if user just typed '$' or is typing after '$'
    if (cursorPos > 0) {
      // Find the last '$' before cursor
      final beforeCursor = text.substring(0, cursorPos);
      final dollarIdx = beforeCursor.lastIndexOf('\$');
      if (dollarIdx >= 0) {
        final query = beforeCursor.substring(dollarIdx + 1).trim();
        if (query.length >= 2) {
          _autocompleteDebounce?.cancel();
          _autocompleteDebounce = Timer(const Duration(milliseconds: 300), () {
            _fetchAutocomplete(query);
          });
          return;
        }
      }
    }

    if (_showAutocomplete) {
      setState(() {
        _showAutocomplete = false;
        _autocompleteResults = [];
      });
    }
  }

  Future<void> _fetchAutocomplete(String query) async {
    try {
      final ds = ref.read(arthaDataSourceProvider);
      final results = await ds.autocomplete(query);
      if (mounted) {
        setState(() {
          _autocompleteResults = results;
          _showAutocomplete = results.isNotEmpty;
        });
      }
    } catch (_) {
      // Silent
    }
  }

  void _insertAutocomplete(AutocompleteItem item) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final dollarIdx = beforeCursor.lastIndexOf('\$');
    if (dollarIdx >= 0) {
      final name = item.type == 'stock'
          ? (item.symbol ?? item.name)
          : item.name;
      final newText = text.substring(0, dollarIdx) + name + text.substring(cursorPos);
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: dollarIdx + name.length),
      );
    }
    setState(() {
      _showAutocomplete = false;
      _autocompleteResults = [];
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(arthaChatProvider);
    final theme = Theme.of(context);

    // Auto-scroll when new messages arrive
    ref.listen(arthaChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          next.isLoading != (prev?.isLoading ?? false)) {
        _scrollToBottom();
      }
      // Cache completed messages locally
      if (!next.isLoading && prev?.isLoading == true && next.sessionId != null) {
        _cacheMessagesLocally(next);
      }
    });

    // Offline check
    if (_isOffline) {
      return _buildOfflineScreen(theme);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: Row(
          children: [
            const Text('\u2728 ', style: TextStyle(fontSize: 20)),
            Text(
              'Artha',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showHistory ? Icons.chat_bubble : Icons.history,
              size: 22,
            ),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            tooltip: _showHistory ? 'Back to chat' : 'Chat history',
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 22),
            onPressed: () {
              ref.read(arthaChatProvider.notifier).newChat();
              setState(() => _showHistory = false);
            },
            tooltip: 'New chat',
          ),
        ],
      ),
      body: _showHistory ? _buildHistoryView() : _buildChatView(chatState),
    );
  }

  Widget _buildOfflineScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: Row(
          children: [
            const Text('\u2728 ', style: TextStyle(fontSize: 20)),
            Text(
              'Artha',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 56, color: Colors.white24),
              const SizedBox(height: 20),
              Text(
                'Artha needs internet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to the internet to chat with Artha.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final offline = await isOffline();
                  setState(() => _isOffline = offline);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cacheMessagesLocally(ArthaChatState state) async {
    if (state.sessionId == null) return;
    try {
      // Cache the session
      await ChatLocalDatabase.upsertSession(ChatSession(
        id: state.sessionId!,
        deviceId: ref.read(deviceIdProvider),
        title: state.messages.firstWhere((m) => m.role == 'user', orElse: () => state.messages.first).content.substring(0, state.messages.first.content.length.clamp(0, 80)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageCount: state.messages.length,
      ));
      // Cache messages
      for (final msg in state.messages) {
        if (!msg.id.startsWith('temp-')) {
          await ChatLocalDatabase.upsertMessage(msg);
        }
      }
    } catch (_) {
      // Silent
    }
  }

  Widget _buildHistoryView() {
    final sessionsAsync = ref.watch(arthaSessionsProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildLocalHistoryFallback(),
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u2728', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start chatting with Artha!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Dismissible(
              key: Key(session.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red.withValues(alpha: 0.3),
                child: const Icon(Icons.delete, color: Colors.red),
              ),
              onDismissed: (_) async {
                final deviceId = ref.read(deviceIdProvider);
                ref.read(arthaDataSourceProvider).deleteSession(
                      session.id,
                      deviceId,
                    );
                await ChatLocalDatabase.deleteSession(session.id);
                ref.invalidate(arthaSessionsProvider);
              },
              child: Card(
                color: const Color(0xFF141829),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Text('\u2728', style: TextStyle(fontSize: 24)),
                  title: Text(
                    session.title ?? 'New chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${session.messageCount} messages \u2022 ${_formatDate(session.updatedAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  onTap: () {
                    ref
                        .read(arthaChatProvider.notifier)
                        .loadSession(session.id);
                    setState(() => _showHistory = false);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Fall back to local SQLite when server is unreachable.
  Widget _buildLocalHistoryFallback() {
    return FutureBuilder<List<ChatSession>>(
      future: ChatLocalDatabase.getSessions(ref.read(deviceIdProvider)),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Failed to load history',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        final sessions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Card(
              color: const Color(0xFF141829),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Text('\u2728', style: TextStyle(fontSize: 24)),
                title: Text(
                  session.title ?? 'New chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${session.messageCount} messages (cached)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () {
                  ref.read(arthaChatProvider.notifier).loadSession(session.id);
                  setState(() => _showHistory = false);
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildChatView(ArthaChatState chatState) {
    return Column(
      children: [
        Expanded(
          child: chatState.messages.isEmpty
              ? _buildWelcomeView()
              : _buildMessageList(chatState),
        ),
        if (chatState.thinkingStatus != null && chatState.isLoading)
          ThinkingIndicator(status: chatState.thinkingStatus!),
        // Suggestion chips after response
        if (!chatState.isLoading &&
            chatState.messages.isNotEmpty &&
            chatState.messages.last.role == 'assistant')
          _buildFollowUpSuggestions(),
        // Autocomplete dropdown
        if (_showAutocomplete) _buildAutocompleteOverlay(),
        _buildInputBar(chatState),
      ],
    );
  }

  Widget _buildFollowUpSuggestions() {
    final suggestionsAsync = ref.watch(arthaSuggestionsProvider);
    return suggestionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SuggestionChips(
          suggestions: suggestions.take(3).toList(),
          onTap: _onSuggestionTap,
        ),
      ),
    );
  }

  Widget _buildAutocompleteOverlay() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _autocompleteResults.length,
        itemBuilder: (context, index) {
          final item = _autocompleteResults[index];
          return ListTile(
            dense: true,
            leading: Icon(
              item.type == 'stock' ? Icons.show_chart : Icons.account_balance,
              size: 18,
              color: item.type == 'stock'
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF8B5CF6),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              item.type == 'stock'
                  ? item.symbol ?? ''
                  : 'Mutual Fund',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
            trailing: item.score != null
                ? Text(
                    item.score!.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.score! >= 70
                          ? Colors.green[400]
                          : item.score! >= 50
                              ? Colors.amber[400]
                              : Colors.red[400],
                    ),
                  )
                : null,
            onTap: () => _insertAutocomplete(item),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeView() {
    final greetingAsync = ref.watch(arthaGreetingProvider);
    final suggestionsAsync = ref.watch(arthaSuggestionsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text('\u2728', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          greetingAsync.when(
            loading: () => const Text(
              'Namaste! I\'m Artha, your market analyst.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            error: (_, __) => const Text(
              'Namaste! I\'m Artha. Ask me anything about Indian markets.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            data: (data) => Text(
              data['greeting'] as String? ??
                  'Namaste! I\'m Artha, your market analyst.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          suggestionsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (suggestions) => SuggestionChips(
              suggestions: suggestions,
              onTap: _onSuggestionTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ArthaChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final msg = chatState.messages[index];
        return Column(
          crossAxisAlignment: msg.role == 'user'
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            ChatBubble(
              message: msg,
              onFeedback: msg.role == 'assistant' && !msg.isStreaming
                  ? (feedback) {
                      ref
                          .read(arthaChatProvider.notifier)
                          .submitFeedback(msg.id, feedback);
                      // Cache feedback locally
                      ChatLocalDatabase.updateFeedback(msg.id, feedback);
                    }
                  : null,
              onShare: msg.role == 'assistant' &&
                      !msg.isStreaming &&
                      msg.content.isNotEmpty
                  ? () => ShareCardHelper.shareMessage(context, msg)
                  : null,
            ),
            // Stock cards below assistant messages
            if (msg.role == 'assistant' && msg.stockCards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Column(
                  children: msg.stockCards
                      .map((card) => StockMiniCard(data: card))
                      .toList(),
                ),
              ),
            // MF cards below assistant messages
            if (msg.role == 'assistant' && msg.mfCards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Column(
                  children: msg.mfCards
                      .map((card) => MfMiniCard(data: card))
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInputBar(ArthaChatState chatState) {
    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1322),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: _isListening
                    ? 'Listening...'
                    : 'Ask Artha anything...',
                hintStyle: TextStyle(
                  color: _isListening
                      ? const Color(0xFF6366F1)
                      : Colors.white30,
                ),
                filled: true,
                fillColor: _isListening
                    ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                    : const Color(0xFF1A1F36),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: _isListening
                      ? const BorderSide(color: Color(0xFF6366F1), width: 1.5)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: _isListening
                      ? const BorderSide(color: Color(0xFF6366F1), width: 1.5)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF6366F1),
                    width: 1.5,
                  ),
                ),
                // Mic button inside the text field (when empty)
                suffixIcon: hasText
                    ? null
                    : GestureDetector(
                        onTap: _speechAvailable ? _toggleVoiceInput : null,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening
                                ? const Color(0xFF6366F1)
                                : _speechAvailable
                                    ? Colors.white38
                                    : Colors.white12,
                            size: 22,
                          ),
                        ),
                      ),
              ),
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: chatState.isLoading || !hasText
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
              color: chatState.isLoading || !hasText ? Colors.white10 : null,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: chatState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  : const Icon(Icons.arrow_upward, size: 22),
              color: Colors.white,
              onPressed: chatState.isLoading || !hasText ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
