class SquareBadgeAssets {
  SquareBadgeAssets._();

  static const String globalCategoryPath =
      'assets/badge_svgs/categories/global.svg';

  static const Map<String, String> currencyLeadToCountryCode = {
    'USD': 'US',
    'EUR': 'EU',
    'GBP': 'GB',
    'JPY': 'JP',
    'AUD': 'AU',
    'CAD': 'CA',
    'CHF': 'CH',
    'NZD': 'NZ',
    'CNY': 'CN',
    'SGD': 'SG',
    'HKD': 'HK',
    'KRW': 'KR',
    'TWD': 'TW',
    'THB': 'TH',
    'MYR': 'MY',
    'IDR': 'ID',
    'PHP': 'PH',
    'VND': 'VN',
    'BDT': 'BD',
    'LKR': 'LK',
    'PKR': 'PK',
    'NPR': 'NP',
    'AED': 'AE',
    'SAR': 'SA',
    'QAR': 'QA',
    'KWD': 'KW',
    'BHD': 'BH',
    'OMR': 'OM',
    'ILS': 'IL',
    'SEK': 'SE',
    'NOK': 'NO',
    'DKK': 'DK',
    'PLN': 'PL',
    'TRY': 'TR',
    'BRL': 'BR',
    'MXN': 'MX',
    'ZAR': 'ZA',
  };

  static const Set<String> supportedCountryCodes = {
    'IN',
    'US',
    'EU',
    'GB',
    'JP',
    'AU',
    'CA',
    'CH',
    'NZ',
    'CN',
    'SG',
    'HK',
    'KR',
    'TW',
    'TH',
    'MY',
    'ID',
    'PH',
    'VN',
    'BD',
    'LK',
    'PK',
    'NP',
    'AE',
    'SA',
    'QA',
    'KW',
    'BH',
    'OM',
    'IL',
    'SE',
    'NO',
    'DK',
    'PL',
    'TR',
    'BR',
    'MX',
    'ZA',
  };

  static const Map<String, String> categoryPathByKey = {
    'global': 'assets/badge_svgs/categories/global.svg',
    'asia': 'assets/badge_svgs/categories/asia.svg',
    'middle_east': 'assets/badge_svgs/categories/middle_east.svg',
    'americas': 'assets/badge_svgs/categories/americas.svg',
    'africa': 'assets/badge_svgs/categories/africa.svg',
    'currencies_other': 'assets/badge_svgs/categories/currencies_other.svg',
    'metals': 'assets/badge_svgs/categories/metals.svg',
    'energy': 'assets/badge_svgs/categories/energy.svg',
    'crypto': 'assets/badge_svgs/categories/crypto.svg',
    'fallback': 'assets/badge_svgs/categories/fallback.svg',
  };

  static String flagPathForCountryCode(String? code) {
    final normalized = code?.trim().toUpperCase() ?? '';
    if (!supportedCountryCodes.contains(normalized)) {
      return globalCategoryPath;
    }
    return 'assets/badge_svgs/flags/${normalized.toLowerCase()}.svg';
  }

  static String flagPathForCurrencyLead(String? currencyLead) {
    final lead = currencyLead?.trim().toUpperCase() ?? '';
    final country = currencyLeadToCountryCode[lead] ?? lead;
    return flagPathForCountryCode(country);
  }

  static String categoryPathForKey(String key) {
    final normalized = key.trim().toLowerCase();
    return categoryPathByKey[normalized] ?? globalCategoryPath;
  }
}
