import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rebuilds [provider] and returns the new future, so callers can
/// `await` it and have the pull-to-refresh indicator wait for the
/// refetch to actually finish.
///
/// This is a thin wrapper around `ref.refresh(provider.future)` whose
/// only purpose is to put the `// ignore: unused_result` suppression
/// in exactly ONE place. The Riverpod analyzer flags the bare
/// `ref.refresh(...)` call as `unused_result` even when the result is
/// immediately awaited at the statement level — `await ref.refresh(p)`
/// is correct semantically but trips the lint. Wrapping it here lets
/// every screen call `await refreshFuture(ref, p.future)` cleanly.
///
/// ## Why not just `ref.read(provider.future)` after `ref.invalidate(...)`?
///
/// Because `ref.invalidate(...)` only marks the provider stale on the
/// next frame — calling `ref.read(provider.future)` immediately after
/// returns the OLD already-resolved future, which completes in
/// microseconds. The `RefreshIndicator` then dismisses before any new
/// data arrives.
///
/// `ref.refresh(provider.future)` is the canonical "rebuild
/// synchronously and return the new future" pattern.
Future<T> refreshFuture<T>(
  WidgetRef ref,
  Refreshable<Future<T>> refreshable,
) {
  // ignore: unused_result
  return ref.refresh(refreshable);
}
