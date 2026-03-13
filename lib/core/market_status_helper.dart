String normalizeMarketPhase(String? phase) {
  final p = (phase ?? '').trim().toLowerCase();
  if (p == 'live') return 'live';
  if (p == 'stale') return 'stale';
  return 'closed';
}
