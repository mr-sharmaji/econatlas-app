import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Dynamic suggested prompt chips with staggered slide-up animation.
///
/// Two layouts are supported:
///   * `SuggestionChips` (default) — vertical list of full-width cards
///     with wrapping text. Used for the welcome screen where each
///     suggestion is shown in its entirety, no truncation.
///   * `SuggestionChips.horizontal` — single horizontally-scrollable
///     row of compact single-line chips. Used for follow-up
///     suggestions under a chat message so they never take more than
///     ~48px vertical space regardless of chip count or length.
class SuggestionChips extends StatefulWidget {
  final List<String> suggestions;
  final void Function(String) onTap;

  /// If true, chips lay out in a single horizontally-scrollable row
  /// with single-line truncation-free text. If false (default), chips
  /// are full-width stacked cards with wrapping text.
  final bool horizontal;

  const SuggestionChips({
    super.key,
    required this.suggestions,
    required this.onTap,
    this.horizontal = false,
  });

  /// Convenience constructor for the horizontal follow-up layout.
  const SuggestionChips.horizontal({
    super.key,
    required this.suggestions,
    required this.onTap,
  }) : horizontal = true;

  @override
  State<SuggestionChips> createState() => _SuggestionChipsState();
}

class _SuggestionChipsState extends State<SuggestionChips>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void didUpdateWidget(SuggestionChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions) {
      _disposeAnimations();
      _initAnimations();
    }
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.suggestions.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _fadeAnimations = _controllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();
    _slideAnimations = _controllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.4),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }).toList();

    // Stagger the animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: 80 * i), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  void _disposeAnimations() {
    for (final c in _controllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.horizontal) {
      return _buildHorizontal();
    }
    return _buildStackedCards();
  }

  /// Welcome-screen layout: vertical stack of full-width cards with
  /// wrapping text. No truncation — long suggestions wrap to multiple
  /// lines and the card expands vertically.
  Widget _buildStackedCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(widget.suggestions.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SlideTransition(
            position: _slideAnimations[i],
            child: FadeTransition(
              opacity: _fadeAnimations[i],
              child: _fullWidthCard(context, widget.suggestions[i]),
            ),
          ),
        );
      }),
    );
  }

  /// Follow-up layout: horizontally scrollable single-line chips.
  Widget _buildHorizontal() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => SlideTransition(
          position: _slideAnimations[i],
          child: FadeTransition(
            opacity: _fadeAnimations[i],
            child: _compactChip(context, widget.suggestions[i]),
          ),
        ),
      ),
    );
  }

  /// Full-width card used for welcome-screen stacked layout. Text wraps
  /// across lines instead of being truncated, and a leading icon hints
  /// that the card is tappable.
  Widget _fullWidthCard(BuildContext context, String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTap(text),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accentBlue.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppTheme.accentBlue.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  softWrap: true,
                  style: TextStyle(
                    color: AppTheme.accentBlue.withValues(alpha: 0.9),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppTheme.accentBlue.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact chip used for horizontal follow-up layout.
  Widget _compactChip(BuildContext context, String text) {
    return GestureDetector(
      onTap: () => widget.onTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accentBlue.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: AppTheme.accentBlue.withValues(alpha: 0.85),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
