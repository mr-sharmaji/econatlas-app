import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
// The `markdown` package ships as a transitive dep of flutter_markdown.
// We need ExtensionSet.gitHubFlavored to enable table / strikethrough /
// task-list / autolink parsing — the default CommonMark parser renders
// pipe-tables as plain text (visible symptom: tables show as raw pipes
// and dashes in the chat bubble).
import 'package:markdown/markdown.dart' as md;

import '../../../../core/theme.dart';
import '../../../../data/datasources/artha_data_source.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final void Function(int feedback)? onFeedback;
  final VoidCallback? onShare;

  const ChatBubble({
    super.key,
    required this.message,
    this.onFeedback,
    this.onShare,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _thinkingExpanded = false;

  ChatMessage get message => widget.message;
  VoidCallback? get onShare => widget.onShare;
  void Function(int feedback)? get onFeedback => widget.onFeedback;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final hasThinking = !isUser &&
        (message.thinkingText?.isNotEmpty ?? false);
    // Auto-expand the thinking pill while the message is streaming so
    // the user can watch the reasoning live. Collapse it automatically
    // once the final answer starts flowing in (content > 0).
    final autoExpand = message.isStreaming &&
        hasThinking &&
        (message.content.isEmpty);
    final showThinkingBody = _thinkingExpanded || autoExpand;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    'Artha',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          // Collapsible "Thinking" pill — shown above the answer bubble
          // whenever we have reasoning content for this message.
          if (hasThinking)
            _buildThinkingPill(context, showThinkingBody),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isUser
                  ? LinearGradient(
                      colors: [
                        AppTheme.accentBlue.withValues(alpha: 0.7),
                        AppTheme.accentBlue.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        AppTheme.cardDark,
                        AppTheme.surfaceDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: isUser
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.content.isEmpty && message.isStreaming)
                  _buildStreamingDots()
                else if (isUser)
                  // User messages: plain text
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  )
                else
                  // Assistant messages: markdown rendered with GitHub
                  // Flavored extensions so tables / strikethrough / task
                  // lists / autolinks all parse correctly.
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    extensionSet: md.ExtensionSet.gitHubFlavored,
                    onTapLink: (text, href, title) {
                      if (href != null && href.startsWith('/discover/stock/')) {
                        // Rebuild the path with a properly URL-encoded
                        // symbol segment. Raw symbols containing `&`
                        // (e.g. `M&M`) would otherwise get truncated
                        // by go_router's query parser.
                        final rawSym =
                            href.substring('/discover/stock/'.length);
                        context.push(
                          '/discover/stock/${Uri.encodeComponent(rawSym)}',
                        );
                      }
                    },
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14.5,
                        height: 1.6,
                      ),
                      strong: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      em: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14.5,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14.5,
                      ),
                      h1: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      h2: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      h3: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      code: TextStyle(
                        color: AppTheme.accentTeal,
                        fontSize: 13,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppTheme.accentBlue.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.only(left: 12),
                      tableBorder: TableBorder.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                      tableHead: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      tableBody: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                      tableCellsPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (message.isStreaming && message.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _buildStreamingCursor(),
                  ),
              ],
            ),
          ),
          // Feedback + share buttons
          if (!isUser && !message.isStreaming && (onFeedback != null || onShare != null))
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onFeedback != null) ...[
                    _feedbackButton(
                      icon: Icons.thumb_up_outlined,
                      activeIcon: Icons.thumb_up,
                      isActive: message.feedback == 1,
                      onTap: () => onFeedback!(1),
                    ),
                    const SizedBox(width: 4),
                    _feedbackButton(
                      icon: Icons.thumb_down_outlined,
                      activeIcon: Icons.thumb_down,
                      isActive: message.feedback == -1,
                      onTap: () => onFeedback!(-1),
                    ),
                  ],
                  if (onShare != null) ...[
                    const SizedBox(width: 8),
                    _feedbackButton(
                      icon: Icons.share_outlined,
                      activeIcon: Icons.share,
                      isActive: false,
                      onTap: onShare!,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _feedbackButton({
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          isActive ? activeIcon : icon,
          size: 16,
          color: isActive ? AppTheme.accentBlue : Colors.white30,
        ),
      ),
    );
  }

  Widget _buildStreamingDots() {
    return const SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(delay: Duration.zero),
          SizedBox(width: 4),
          _PulseDot(delay: Duration(milliseconds: 200)),
          SizedBox(width: 4),
          _PulseDot(delay: Duration(milliseconds: 400)),
        ],
      ),
    );
  }

  Widget _buildStreamingCursor() {
    return const _BlinkingCursor();
  }

  /// Collapsible pill shown above the assistant bubble. While the
  /// message is still streaming and has no content yet, the pill is
  /// auto-expanded so the user can watch the reasoning flow live.
  /// Once the actual answer starts, the pill auto-collapses to a
  /// small tappable chip.
  Widget _buildThinkingPill(BuildContext context, bool expanded) {
    final thinking = message.thinkingText ?? "";
    final isLive = message.isStreaming && message.content.isEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _thinkingExpanded = !_thinkingExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pill header row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      _PulseDot(
                        delay: Duration.zero,
                        color: AppTheme.accentBlue,
                      ),
                      const SizedBox(width: 6),
                    ] else
                      Icon(
                        Icons.psychology_outlined,
                        size: 14,
                        color: AppTheme.accentBlue.withValues(alpha: 0.8),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      isLive ? 'Thinking…' : 'Reasoning',
                      style: TextStyle(
                        color: AppTheme.accentBlue.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppTheme.accentBlue.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                // Expanded body — reasoning text
                if (expanded && thinking.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        thinking,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12.5,
                          height: 1.45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Duration delay;
  final Color? color;
  const _PulseDot({required this.delay, this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color ?? AppTheme.accentBlue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 14,
        color: AppTheme.accentBlue,
      ),
    );
  }
}
