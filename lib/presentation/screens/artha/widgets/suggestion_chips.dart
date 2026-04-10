import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Dynamic suggested prompt chips with staggered slide-up animation.
///
/// Two layouts are supported:
///   * `SuggestionChips.wrap` (default) — multi-line `Wrap`, used for
///     the welcome screen where space is abundant.
///   * `SuggestionChips.horizontal` — single horizontally-scrollable row,
///     used for follow-up suggestions under a chat message so they never
///     take more than ~48px vertical space regardless of how long each
///     suggestion is.
class SuggestionChips extends StatefulWidget {
  final List<String> suggestions;
  final void Function(String) onTap;

  /// If true, chips lay out in a single horizontally-scrollable row.
  /// If false (default), chips wrap across multiple lines.
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
    return _buildWrap();
  }

  Widget _buildWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(widget.suggestions.length, (i) {
        return SlideTransition(
          position: _slideAnimations[i],
          child: FadeTransition(
            opacity: _fadeAnimations[i],
            child: _chip(context, widget.suggestions[i]),
          ),
        );
      }),
    );
  }

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
            child: _chip(context, widget.suggestions[i], compact: true),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, {bool compact = false}) {
    return GestureDetector(
      onTap: () => widget.onTap(text),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 8 : 10,
        ),
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
