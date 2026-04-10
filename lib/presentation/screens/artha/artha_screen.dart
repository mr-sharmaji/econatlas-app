import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/connectivity.dart';
import '../../../core/theme.dart';
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
  final _autocompleteLayerLink = LayerLink();
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

  void _ensureInputFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });
  }

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
      final ds = ref.read(arthaDataSourceProvider);
      final sessions = await ds.listSessions(deviceId);
      await ChatLocalDatabase.syncFromServer(sessions);
    } catch (_) {}
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final offset = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(offset);
        }
      }
    });
  }

  bool _didStreamingContentChange(ArthaChatState? prev, ArthaChatState next) {
    if (prev == null || prev.messages.isEmpty || next.messages.isEmpty) {
      return false;
    }

    final prevLast = prev.messages.last;
    final nextLast = next.messages.last;

    if (nextLast.role != 'assistant' || !nextLast.isStreaming) {
      return false;
    }

    return prevLast.id == nextLast.id &&
        (prevLast.content != nextLast.content ||
            prevLast.thinkingText != nextLast.thinkingText ||
            prevLast.stockCards.length != nextLast.stockCards.length ||
            prevLast.mfCards.length != nextLast.mfCards.length);
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
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

  // --- Autocomplete (triggered by @) ---
  void _onTextChanged() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos > 0) {
      final beforeCursor = text.substring(0, cursorPos);
      final atIdx = beforeCursor.lastIndexOf('@');
      if (atIdx >= 0) {
        // Make sure there's no whitespace between @ and cursor (so @TCS triggers
        // but "@ hello world" doesn't keep triggering after the word)
        final query = beforeCursor.substring(atIdx + 1);
        if (!query.contains(' ') && !query.contains('\n') && query.isNotEmpty) {
          _autocompleteDebounce?.cancel();
          _autocompleteDebounce = Timer(const Duration(milliseconds: 250), () {
            _fetchAutocomplete(query);
          });
          _ensureInputFocus();
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
        if (results.isNotEmpty) {
          _ensureInputFocus();
        }
      }
    } catch (_) {}
  }

  void _insertAutocomplete(AutocompleteItem item) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx >= 0) {
      final name =
          item.type == 'stock' ? (item.symbol ?? item.name) : item.name;
      // Replace "@query" with the name and add a trailing space for convenience
      final newText =
          '${text.substring(0, atIdx)}$name ${text.substring(cursorPos)}';
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: atIdx + name.length + 1),
      );
    }
    setState(() {
      _showAutocomplete = false;
      _autocompleteResults = [];
    });
    _ensureInputFocus();
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
      if (_didStreamingContentChange(prev, next)) {
        _scrollToBottom(animated: false);
      }
      if (!next.isLoading &&
          prev?.isLoading == true &&
          next.sessionId != null) {
        _cacheMessagesLocally(next);
      }
    });

    if (_isOffline) {
      return _buildOfflineScreen(theme);
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldDark,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldDark,
        title: Row(
          children: [
            const Text('✨ ', style: TextStyle(fontSize: 20)),
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
      backgroundColor: AppTheme.scaffoldDark,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldDark,
        title: Row(
          children: [
            const Text('✨ ', style: TextStyle(fontSize: 20)),
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
                  foregroundColor: AppTheme.accentBlue,
                  side: BorderSide(color: AppTheme.accentBlue),
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
      await ChatLocalDatabase.upsertSession(ChatSession(
        id: state.sessionId!,
        deviceId: ref.read(deviceIdProvider),
        title: state.messages
            .firstWhere((m) => m.role == 'user',
                orElse: () => state.messages.first)
            .content
            .substring(0, state.messages.first.content.length.clamp(0, 80)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageCount: state.messages.length,
      ));
      for (final msg in state.messages) {
        if (!msg.id.startsWith('temp-')) {
          await ChatLocalDatabase.upsertMessage(msg);
        }
      }
    } catch (_) {}
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
                const Text('✨', style: TextStyle(fontSize: 48)),
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
                color: AppTheme.accentRed.withValues(alpha: 0.3),
                child: Icon(Icons.delete, color: AppTheme.accentRed),
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
                color: AppTheme.cardDark,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Text('✨', style: TextStyle(fontSize: 24)),
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
              color: AppTheme.cardDark,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Text('✨', style: TextStyle(fontSize: 24)),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Expanded(
              child: chatState.messages.isEmpty
                  ? _buildWelcomeView()
                  : _buildMessageList(chatState),
            ),
            if (chatState.thinkingStatus != null && chatState.isLoading)
              ThinkingIndicator(status: chatState.thinkingStatus!),
            // Retry banner — shown when the last stream aborted. Tapping
            // re-sends the last user message in the same session.
            if (chatState.lastResponseFailed && !chatState.isLoading)
              _buildRetryBanner(chatState),
            // Follow-up suggestion chips from LLM — horizontal scroll so they
            // never occupy more than ~48px vertical regardless of count/length.
            if (!chatState.isLoading &&
                !chatState.lastResponseFailed &&
                chatState.messages.isNotEmpty &&
                chatState.messages.last.role == 'assistant' &&
                chatState.followUpSuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: SuggestionChips.horizontal(
                  suggestions: chatState.followUpSuggestions,
                  onTap: _onSuggestionTap,
                ),
              ),
            _buildInputBar(chatState),
          ],
        ),
        if (_showAutocomplete)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: CompositedTransformFollower(
                  link: _autocompleteLayerLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.topCenter,
                  followerAnchor: Alignment.bottomCenter,
                  offset: const Offset(0, -8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildAutocompleteOverlay(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAutocompleteOverlay() {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 560),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
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
                    ? AppTheme.accentBlue
                    : AppTheme.accentTeal,
              ),
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                item.type == 'stock' ? item.symbol ?? '' : 'Mutual Fund',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              trailing: item.score != null
                  ? Text(
                      item.score!.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: item.score! >= 70
                            ? AppTheme.accentGreen
                            : item.score! >= 50
                                ? AppTheme.accentOrange
                                : AppTheme.accentRed,
                      ),
                    )
                  : null,
              onTap: () => _insertAutocomplete(item),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    // Single source of truth: the /chat/greeting response already
    // contains the suggestions, so we don't separately watch
    // arthaSuggestionsProvider here — that would double-hit the LLM.
    final greetingAsync = ref.watch(arthaGreetingProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text('✨', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          greetingAsync.when(
            loading: () => _buildGreetingShimmer(),
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
          greetingAsync.when(
            loading: () => _buildSuggestionsShimmer(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              final raw = data['suggestions'] as List<dynamic>? ?? const [];
              final suggestions = raw.map((e) => e.toString()).toList();
              if (suggestions.isEmpty) return const SizedBox.shrink();
              return SuggestionChips(
                suggestions: suggestions,
                onTap: _onSuggestionTap,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Retry banner shown above the input bar when the last stream aborted.
  /// Tapping fires retryLastMessage() which re-sends the last user text.
  Widget _buildRetryBanner(ArthaChatState chatState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref.read(arthaChatProvider.notifier).retryLastMessage(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentRed.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: AppTheme.accentRed,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    chatState.error ?? 'Something went wrong',
                    style: TextStyle(
                      color: AppTheme.accentRed.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppTheme.accentRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: TextStyle(
                          color: AppTheme.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shimmer placeholder for the suggestion card stack. Matches the
  /// new full-width multi-line layout so the welcome screen doesn't
  /// visually "jump" when suggestions finish loading.
  Widget _buildSuggestionsShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF21262D),
      highlightColor: const Color(0xFF30363D),
      child: Column(
        children: List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shimmer placeholder while greeting loads — prevents "Namaste" flash.
  Widget _buildGreetingShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF21262D),
      highlightColor: const Color(0xFF30363D),
      child: Column(
        children: [
          Container(
            width: 260,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ArthaChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final msg = chatState.messages[index];
        return _AnimatedMessageEntry(
          index: index,
          child: Column(
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
          ),
        );
      },
    );
  }

  Widget _buildInputBar(ArthaChatState chatState) {
    // CRITICAL: do NOT call setState() on every keystroke here. The
    // old code did `onChanged: (_) => setState(() {})` which rebuilt
    // the entire Artha screen (including the welcome view's suggestion
    // cards) on every letter typed, causing the animated chips to
    // flicker/reload. Instead, we use ValueListenableBuilder against
    // the TextEditingController so only the send button + mic icon
    // rebuild when text changes — nothing else.
    return CompositedTransformTarget(
      link: _autocompleteLayerLink,
      child: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
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
                      : 'Ask Artha anything... (@ to mention)',
                  hintStyle: TextStyle(
                    color: _isListening ? AppTheme.accentBlue : Colors.white30,
                  ),
                  filled: true,
                  fillColor: _isListening
                      ? AppTheme.accentBlue.withValues(alpha: 0.1)
                      : AppTheme.surfaceDark,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: _isListening
                        ? BorderSide(color: AppTheme.accentBlue, width: 1.5)
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: _isListening
                        ? BorderSide(color: AppTheme.accentBlue, width: 1.5)
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: AppTheme.accentBlue,
                      width: 1.5,
                    ),
                  ),
                  // Mic icon: rebuild only when text state changes from
                  // empty→non-empty or vice versa, via ValueListenableBuilder.
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      if (hasText) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: _speechAvailable ? _toggleVoiceInput : null,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening
                                ? AppTheme.accentBlue
                                : _speechAvailable
                                    ? Colors.white38
                                    : Colors.white12,
                            size: 22,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                onTap: _ensureInputFocus,
                onSubmitted: (_) => _sendMessage(),
                // Intentionally NO onChanged setState — see class docstring
                // on _buildInputBar for why.
              ),
            ),
            const SizedBox(width: 8),
            // Send button rebuilds only when text value changes.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                final disabled = chatState.isLoading || !hasText;
                return Container(
                  decoration: BoxDecoration(
                    gradient: disabled
                        ? null
                        : LinearGradient(
                            colors: [
                              AppTheme.accentBlue,
                              AppTheme.accentBlue.withValues(alpha: 0.7),
                            ],
                          ),
                    color: disabled ? Colors.white10 : null,
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
                    onPressed: disabled ? null : _sendMessage,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Staggered fade+slide animation for each message entry.
class _AnimatedMessageEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedMessageEntry({required this.index, required this.child});

  @override
  State<_AnimatedMessageEntry> createState() => _AnimatedMessageEntryState();
}

class _AnimatedMessageEntryState extends State<_AnimatedMessageEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}
