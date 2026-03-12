import '../data/models/market_status.dart';
import 'constants.dart';

/// Returns true if the given asset is currently "live" (exchange/session in market status).
bool isLiveForAsset(
  String asset,
  String instrumentType,
  MarketStatus status, {
  DateTime? lastUpdate,
}) {
  final now = DateTime.now();
  final liveMaxAgeSeconds =
      (instrumentType == 'commodity' || instrumentType == 'currency')
          ? 900
          : 300;
  final tickAgeSeconds =
      lastUpdate != null ? now.difference(lastUpdate.toLocal()).inSeconds : 0;
  final staleByAge = tickAgeSeconds > liveMaxAgeSeconds;
  switch (instrumentType) {
    case 'commodity':
      return (status.commoditiesOpen || status.nyseOpen) && !staleByAge;
    case 'currency':
      return (status.fxOpen || status.nyseOpen || status.nseOpen) &&
          !staleByAge;
    case 'bond_yield':
      return asset == 'India 10Y Bond Yield'
          ? (status.indiaOpen || status.nseOpen) && !staleByAge
          : asset == 'Germany 10Y Bond Yield'
              ? (status.europeOpen || status.nyseOpen) && !staleByAge
              : asset == 'Japan 10Y Bond Yield'
                  ? (status.japanOpen || status.nyseOpen) && !staleByAge
                  : (status.usOpen || status.nyseOpen) && !staleByAge;
    case 'index':
      if (asset == 'Gift Nifty') {
        return status.giftNiftyOpen && !staleByAge;
      }
      if (Entities.indicesIndia.contains(asset)) {
        return (status.indiaOpen || status.nseOpen) && !staleByAge;
      }
      if (Entities.indicesEurope.contains(asset)) {
        return (status.europeOpen || status.nyseOpen) && !staleByAge;
      }
      if (Entities.indicesJapan.contains(asset)) {
        return (status.japanOpen || status.nyseOpen) && !staleByAge;
      }
      if (Entities.indicesUS.contains(asset)) {
        return (status.usOpen || status.nyseOpen) && !staleByAge;
      }
      return status.nyseOpen && !staleByAge;
    default:
      return status.nyseOpen && !staleByAge;
  }
}

String normalizeMarketPhase(String? phase) {
  final p = (phase ?? '').trim().toLowerCase();
  if (p == 'live') return 'live';
  if (p == 'stale') return 'stale';
  return 'closed';
}
