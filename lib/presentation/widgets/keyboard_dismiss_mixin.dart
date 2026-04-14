import 'dart:async';

import 'package:flutter/material.dart';

/// State mixin that clears focus from the active TextField whenever the
/// soft keyboard is dismissed by any means (system back button, IME
/// hide action, predictive back gesture), without breaking typing.
///
/// ## Why this needs the debounce
///
/// A naive `didChangeMetrics` listener that unfocuses on
/// `viewInsets.bottom == 0` introduces a notorious bug: during the
/// keyboard OPEN animation, `viewInsets.bottom` can transiently report
/// 0 for one frame, which causes the listener to immediately unfocus
/// and dismiss the just-opened keyboard, making it impossible to type.
/// Several tool screens in this app removed their `didChangeMetrics`
/// for exactly this reason (see the `// didChangeMetrics removed`
/// comments in capital_gains_screen, income_tax_screen, etc.).
///
/// This mixin works around the bug with a debounced re-check:
///
///   1. When `viewInsets.bottom` becomes 0, schedule a 220 ms timer.
///   2. When the timer fires, re-read `viewInsets.bottom`. If it is
///      STILL 0, the keyboard is genuinely gone — call unfocus. If it
///      isn't, a transient open-animation 0 has been overtaken by real
///      keyboard height — do nothing.
///   3. Cancel any pending timer the moment a non-zero inset is
///      observed, so a quick close→open sequence won't trigger.
///
/// 220 ms is comfortably longer than any single-frame transient glitch
/// during the open animation and shorter than the user's natural
/// reaction time, so a real dismiss feels instant.
///
/// ## How to use
///
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with WidgetsBindingObserver, KeyboardDismissMixin<MyScreen> {
///   // ... your existing code
/// }
/// ```
///
/// Both mixin declarations are required: `WidgetsBindingObserver` so
/// `didChangeMetrics` actually fires, and `KeyboardDismissMixin` for
/// the debounced unfocus logic. The mixin handles its own
/// `addObserver` / `removeObserver` registration in initState/dispose;
/// just remember to call `super.initState()` and `super.dispose()`.
///
/// To also handle "user tapped on empty area while keyboard is open",
/// wrap your `Scaffold` in [DismissKeyboardOnTap]. The two patterns are
/// complementary — the mixin handles back-button / IME, the wrapper
/// handles tap-outside.
mixin KeyboardDismissMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _kbDismissTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kbDismissTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final inset = View.of(context).viewInsets.bottom;
    if (inset > 0) {
      _kbDismissTimer?.cancel();
      return;
    }
    _kbDismissTimer?.cancel();
    _kbDismissTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      if (View.of(context).viewInsets.bottom != 0) return;
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}

/// Widget helper: wraps [child] in a [GestureDetector] that dismisses
/// the keyboard and clears focus when the user taps on an empty area.
///
/// TextField, dropdown, button, switch and other interactive widgets
/// consume their own taps first, so [GestureDetector.onTap] only fires
/// for taps on genuinely empty regions (margins between cards, blank
/// background).
///
/// Pair this with [KeyboardDismissMixin] for full coverage:
///
///   - [KeyboardDismissMixin] handles dismiss-by-back-button / IME.
///   - [DismissKeyboardOnTap] handles dismiss-by-tap-outside.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
