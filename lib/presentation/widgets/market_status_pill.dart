import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/theme.dart';

/// Small colored status dot.
/// Live = green with pumping animation; stale = amber; closed = grey.
class MarketStatusPill extends StatefulWidget {
  final String phase;
  final bool isLive;

  /// Kept for backward compatibility; label text is intentionally not rendered.
  final bool showLabel;

  const MarketStatusPill({
    super.key,
    this.phase = 'closed',
    bool? isLive,
    this.showLabel = false,
  }) : isLive = isLive ?? false;

  @override
  State<MarketStatusPill> createState() => _MarketStatusPillState();
}

class _MarketStatusPillState extends State<MarketStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _isLivePhase(MarketStatusPill w) {
    final p = w.phase.toLowerCase();
    return p == 'live' || (p != 'stale' && w.isLive);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_isLivePhase(widget)) _controller.repeat();
  }

  @override
  void didUpdateWidget(MarketStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasLive = _isLivePhase(oldWidget);
    final isLive = _isLivePhase(widget);
    if (isLive != wasLive) {
      if (isLive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = widget.phase.toLowerCase();
    final isLive = phase == 'live' || (phase != 'stale' && widget.isLive);
    final isStale = phase == 'stale';
    const coreDotSize = 7.0;
    const dotSlotSize = coreDotSize;
    final color = isLive
        ? AppTheme.accentGreen
        : isStale
            ? Colors.amber
            : theme.colorScheme.outline;

    Widget dot = Container(
      width: coreDotSize,
      height: coreDotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (isLive) {
      dot = AnimatedBuilder(
        animation: _controller,
        child: dot,
        builder: (context, child) {
          final t = _controller.value;
          final t2 = (t + 0.5) % 1.0;
          final pulseScale = 0.95 + ((math.sin(t * math.pi * 2) + 1) * 0.10);

          Widget ring(double phase) {
            final opacity = (1.0 - phase) * 0.38;
            final scale = 1.0 + (phase * 1.6);
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: coreDotSize,
                  height: coreDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.95),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
            );
          }

          return SizedBox(
            width: dotSlotSize,
            height: dotSlotSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ring(t),
                ring(t2),
                Transform.scale(
                  scale: pulseScale,
                  child: child,
                ),
              ],
            ),
          );
        },
      );
    } else {
      dot = SizedBox(
        width: dotSlotSize,
        height: dotSlotSize,
        child: Center(child: dot),
      );
    }

    final backgroundColor = isLive
        ? AppTheme.accentGreen.withValues(alpha: 0.16)
        : isStale
            ? Colors.amber.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: dot,
    );
  }
}
