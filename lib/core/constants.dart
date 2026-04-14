/// Time range for price/macro history charts.
enum ChartRange {
  oneDay,
  oneWeek,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  threeYears,
  fiveYears,
  all,
}

extension ChartRangeExtension on ChartRange {
  String get label {
    switch (this) {
      case ChartRange.oneDay:
        return '1D';
      case ChartRange.oneWeek:
        return '1W';
      case ChartRange.oneMonth:
        return '1M';
      case ChartRange.threeMonths:
        return '3M';
      case ChartRange.sixMonths:
        return '6M';
      case ChartRange.oneYear:
        return '1Y';
      case ChartRange.threeYears:
        return '3Y';
      case ChartRange.fiveYears:
        return '5Y';
      case ChartRange.all:
        return 'All';
    }
  }

  Duration get duration {
    switch (this) {
      case ChartRange.oneDay:
        return const Duration(days: 1);
      case ChartRange.oneWeek:
        return const Duration(days: 7);
      case ChartRange.oneMonth:
        return const Duration(days: 30);
      case ChartRange.threeMonths:
        return const Duration(days: 90);
      case ChartRange.sixMonths:
        return const Duration(days: 180);
      case ChartRange.oneYear:
        return const Duration(days: 365);
      case ChartRange.threeYears:
        return const Duration(days: 1095);
      case ChartRange.fiveYears:
        return const Duration(days: 365 * 5);
      case ChartRange.all:
        return const Duration(days: 365 * 50);
    }
  }

  /// True when this range uses intraday API (1D live when market open).
  bool get isIntradayRange => this == ChartRange.oneDay;
}

class AppConstants {
  AppConstants._();

  static const String appName = 'EconAtlas';
  static const String defaultBaseUrl = 'https://api.velqon.xyz';

  static const Duration marketRefreshInterval = Duration(seconds: 30);
  static const Duration newsRefreshInterval = Duration(minutes: 30);
  static const Duration macroRefreshInterval = Duration(minutes: 1);

  static const int defaultLimit = 50;

  /// Use -1 to request all entries (for chart history up to 50 years).
  static const int chartDataLimit = -1;
  static const int maxLimit = 2500;

  static const String prefBaseUrl = 'base_url';
  static const String prefThemeMode = 'theme_mode';
  static const String prefNotificationsEnabled = 'notifications_enabled';
  static const String prefDeveloperOptionsUnlocked =
      'developer_options_unlocked';
  static const String prefExpertMode = 'expert_mode';
  static const String prefUnitSystem = 'unit_system';
  static const String prefHasSeenWelcome = 'has_seen_welcome';
  static const String prefChartTimezone = 'chart_timezone';
  static const String prefDeviceId = 'device_id';
  static const String prefPreferredRegions = 'preferred_regions';
  static const String prefScreenerPreset = 'screener_preset';
  static const String prefScreenerMinQuality = 'screener_min_quality';
  static const String prefDiscoverSegment = 'discover_segment';
  static const String prefDiscoverStockPreset = 'discover_stock_preset';
  static const String prefDiscoverMutualFundPreset = 'discover_mf_preset';
  static const String prefDiscoverStockFilters = 'discover_stock_filters';
  static const String prefDiscoverMutualFundFilters = 'discover_mf_filters';
  static const String prefConverterFrom = 'converter_from_currency';
  static const String prefConverterTo = 'converter_to_currency';
  static const String prefConverterAmount = 'converter_amount';
  static const String prefConverterFxSnapshot = 'converter_fx_snapshot';
  static const String prefCacheLatestMarketAll = 'cache_latest_market_all';
  static const String prefCacheLatestIndices = 'cache_latest_indices';
  static const String prefCacheLatestCurrencies = 'cache_latest_currencies';
  static const String prefCacheLatestBonds = 'cache_latest_bonds';
  static const String prefCacheLatestCommodities = 'cache_latest_commodities';
  static const String prefCacheLatestCrypto = 'cache_latest_crypto';
  static const String prefCacheAssetCatalog = 'cache_asset_catalog';
  static const String prefCacheAssetCatalogTs = 'cache_asset_catalog_ts';
  static const String prefCacheWatchlist = 'cache_watchlist';
  static const String prefCacheLatestMarketAllTs = 'cache_latest_market_all_ts';
  static const String prefCacheLatestIndicesTs = 'cache_latest_indices_ts';
  static const String prefCacheLatestCurrenciesTs =
      'cache_latest_currencies_ts';
  static const String prefCacheLatestBondsTs = 'cache_latest_bonds_ts';
  static const String prefCacheLatestCommoditiesTs =
      'cache_latest_commodities_ts';
  static const String prefCacheLatestCryptoTs = 'cache_latest_crypto_ts';
  static const String prefDashboardWidgetSnapshot = 'dashboard_widget_snapshot';
  static const String prefDashboardWidgetSnapshotTs =
      'dashboard_widget_snapshot_ts';

  /// USD/INR spot rate, cached separately from /market/latest so the
  /// commodities / crypto / dashboard screens can convert prices to INR
  /// instantly on cold start, without waiting for the full market
  /// snapshot provider (which can be slow or fail).
  static const String prefCacheUsdInrRate = 'cache_usd_inr_rate';
  static const String prefCacheUsdInrRateTs = 'cache_usd_inr_rate_ts';
  static const String dashboardWidgetProviderQualifiedName =
      'com.econatlas.econatlas_app.DashboardHomeWidgetProvider';
  static const String dashboardWidgetPeriodicTaskUniqueName =
      'dashboard_widget_periodic_refresh';
  static const String dashboardWidgetPeriodicTaskName =
      'dashboard_widget_periodic_refresh_task';
  static const String prefTaxSalary = 'tax_salary';
  static const String prefTaxDeductions = 'tax_deductions';
  static const String prefTaxRegime = 'tax_regime';
  static const String prefTaxAgeBucket = 'tax_age_bucket';
  static const String prefTaxResident = 'tax_resident';
  static const String prefTaxSelectedFy = 'tax_selected_fy';
  static const String prefTaxConfigCache = 'tax_config_cache';
  static const String prefTaxConfigVersion = 'tax_config_version';
  static const String prefTaxConfigHash = 'tax_config_hash';
  static const String prefTaxCapitalAssetType = 'tax_capital_asset_type';
  static const String prefTaxCapitalPurchaseAmount =
      'tax_capital_purchase_amount';
  static const String prefTaxCapitalSaleAmount = 'tax_capital_sale_amount';
  static const String prefTaxCapitalPurchaseDate = 'tax_capital_purchase_date';
  static const String prefTaxCapitalSaleDate = 'tax_capital_sale_date';
  static const String prefTaxAdvanceLiability = 'tax_advance_liability';
  static const String prefTaxAdvancePaid = 'tax_advance_paid';
  static const String prefTaxAdvancePaymentDate = 'tax_advance_payment_date';
  static const String prefTaxAdvanceInstallmentIndex =
      'tax_advance_installment_index';
  static const String prefTaxAdvanceManualInstallment =
      'tax_advance_manual_installment';
  static const String prefTaxTdsPerspective = 'tax_tds_perspective';
  static const String prefTaxTdsPaymentType = 'tax_tds_payment_type';
  static const String prefTaxTdsRecipient = 'tax_tds_recipient';
  static const String prefTaxTdsPan = 'tax_tds_pan';
  static const String prefTaxTdsSubtype = 'tax_tds_subtype';
  static const String prefTaxTdsAmount = 'tax_tds_amount';
  static const String prefTaxTdsShowOptions = 'tax_tds_show_options';
  static const String prefChargesSegment = 'charges_segment';
  static const String prefChargesBroker = 'charges_broker';
  static const String prefChargesExchange = 'charges_exchange';
  static const String prefChargesCustomBroker = 'charges_custom_broker';
  static const String prefChargesCustomBrokeragePct =
      'charges_custom_brokerage_pct';
  static const String prefChargesCustomCap = 'charges_custom_cap';
  static const String prefChargesBuyPrice = 'charges_buy_price';
  static const String prefChargesSellPrice = 'charges_sell_price';
  static const String prefChargesQuantity = 'charges_quantity';
  static const String prefChargesLotSize = 'charges_lot_size';

  // Broker charges API cache
  static const String prefCacheBrokerCharges = 'cache_broker_charges';
  static const String prefCacheBrokerChargesTs = 'cache_broker_charges_ts';
}

/// Chart axis timezone for 1D intraday labels. Device local is default.
enum ChartTimezone {
  deviceLocal('local', 'Local'),
  ist('Asia/Kolkata', 'IST'),
  americaNewYork('America/New_York', 'EST');

  const ChartTimezone(this.id, this.displayName);
  final String id;
  final String displayName;

  static ChartTimezone fromId(String? id) {
    if (id == deviceLocal.id) return ChartTimezone.deviceLocal;
    if (id == americaNewYork.id) return ChartTimezone.americaNewYork;
    if (id == ist.id) return ChartTimezone.ist;
    return ChartTimezone.deviceLocal;
  }
}

class Entities {
  Entities._();

  static const List<String> indicesUS = [
    'S&P500',
    'NASDAQ',
    'Nasdaq 100',
    'Dow Jones',
    'S&P 500 Tech',
    'S&P 500 Financials',
    'S&P 500 Energy',
  ];

  static const List<String> indicesEurope = [
    'FTSE 100',
    'DAX',
    'CAC 40',
    'Euro Stoxx 50',
  ];

  static const List<String> indicesJapan = [
    'Nikkei 225',
    'TOPIX',
  ];

  static const List<String> indicesIndia = [
    'Sensex',
    'Nifty 50',
    'Gift Nifty',
    'Nifty 500',
    'Nifty Bank',
    'Nifty IT',
    'Nifty Midcap 150',
    'Nifty Smallcap 250',
    'Nifty Auto',
    'Nifty Pharma',
    'Nifty Metal',
  ];

  static const List<String> fx = [
    'USD/INR',
    'EUR/INR',
    'GBP/INR',
    'JPY/INR',
    'AUD/INR',
    'CAD/INR',
    'CHF/INR',
    'NZD/INR',
    'CNY/INR',
    'SGD/INR',
    'HKD/INR',
    'KRW/INR',
    'TWD/INR',
    'THB/INR',
    'MYR/INR',
    'IDR/INR',
    'PHP/INR',
    'VND/INR',
    'BDT/INR',
    'LKR/INR',
    'PKR/INR',
    'NPR/INR',
    'AED/INR',
    'SAR/INR',
    'QAR/INR',
    'KWD/INR',
    'BHD/INR',
    'OMR/INR',
    'ILS/INR',
    'SEK/INR',
    'NOK/INR',
    'DKK/INR',
    'PLN/INR',
    'TRY/INR',
    'BRL/INR',
    'MXN/INR',
    'ZAR/INR',
  ];

  static const List<String> fxMajor = [
    'USD/INR',
    'EUR/INR',
    'GBP/INR',
    'JPY/INR',
    'AUD/INR',
    'CAD/INR',
    'CHF/INR',
    'NZD/INR',
  ];

  static const List<String> fxAsiaPacific = [
    'CNY/INR',
    'SGD/INR',
    'HKD/INR',
    'KRW/INR',
    'TWD/INR',
    'THB/INR',
    'MYR/INR',
    'IDR/INR',
    'PHP/INR',
    'VND/INR',
    'BDT/INR',
    'LKR/INR',
    'PKR/INR',
    'NPR/INR',
  ];

  static const List<String> fxMiddleEast = [
    'AED/INR',
    'SAR/INR',
    'QAR/INR',
    'KWD/INR',
    'BHD/INR',
    'OMR/INR',
    'ILS/INR',
  ];

  static const List<String> fxEurope = [
    'SEK/INR',
    'NOK/INR',
    'DKK/INR',
    'PLN/INR',
    'TRY/INR',
  ];

  static const List<String> fxAmericas = [
    'BRL/INR',
    'MXN/INR',
  ];

  static const List<String> fxAfrica = [
    'ZAR/INR',
  ];

  static const List<String> bonds = [
    'India 10Y Bond Yield',
    'US 10Y Treasury Yield',
    'US 2Y Treasury Yield',
    'Germany 10Y Bond Yield',
    'Japan 10Y Bond Yield',
  ];

  static const List<String> commodities = [
    'gold',
    'silver',
    'copper',
    'crude oil',
    'natural gas',
    'platinum',
    'palladium',
    'wheat',
    'corn',
    'soybeans',
    'rice',
    'oats',
    'cotton',
    'sugar',
    'coffee',
    'cocoa',
    'aluminum',
    'brent crude',
    'gasoline',
    'heating oil',
    'urea',
    'dap fertilizer',
    'potash',
    'tsp fertilizer',
    'iron ore',
    'coal',
    'palm oil',
    'rubber',
    'zinc',
  ];

  static const List<String> crypto = [
    'bitcoin',
    'ethereum',
    'bnb',
    'solana',
    'xrp',
    'cardano',
    'dogecoin',
    'polkadot',
    'avalanche',
    'chainlink',
  ];

  static const List<String> dashboardAssets = [
    'Nifty 50',
    'Nasdaq 100',
    'Gift Nifty',
    'USD/INR',
    'gold',
    'silver',
    'crude oil',
  ];

  static const Map<String, String> displayNames = {
    'S&P500': 'S&P 500',
    'NASDAQ': 'NASDAQ Composite',
    'Nasdaq 100': 'Nasdaq 100',
    'Dow Jones': 'Dow Jones',
    'Nifty 50': 'Nifty 50',
    'Sensex': 'Sensex',
    'Nifty 500': 'Nifty 500',
    'Nifty Midcap 150': 'Nifty Midcap 150',
    'Nifty Smallcap 250': 'Nifty Smallcap 250',
    'Nifty Auto': 'Nifty Auto',
    'Nifty Pharma': 'Nifty Pharma',
    'Nifty Metal': 'Nifty Metal',
    'Nifty Bank': 'Nifty Bank',
    'Nifty IT': 'Nifty IT',
    'India VIX': 'India VIX',
    'Gift Nifty': 'Gift Nifty',
    'FTSE 100': 'FTSE 100',
    'DAX': 'DAX',
    'CAC 40': 'CAC 40',
    'Euro Stoxx 50': 'Euro Stoxx 50',
    'Nikkei 225': 'Nikkei 225',
    'TOPIX': 'TOPIX',
    'CBOE VIX': 'CBOE VIX',
    'S&P 500 Tech': 'S&P 500 Tech',
    'S&P 500 Financials': 'S&P 500 Financials',
    'S&P 500 Energy': 'S&P 500 Energy',
    'USD/INR': '🇺🇸 US Dollar',
    'EUR/INR': '🇪🇺 Euro',
    'GBP/INR': '🇬🇧 British Pound',
    'JPY/INR': '🇯🇵 Japanese Yen',
    'AUD/INR': '🇦🇺 Australian Dollar',
    'CAD/INR': '🇨🇦 Canadian Dollar',
    'CHF/INR': '🇨🇭 Swiss Franc',
    'CNY/INR': '🇨🇳 Chinese Yuan',
    'SGD/INR': '🇸🇬 Singapore Dollar',
    'HKD/INR': '🇭🇰 Hong Kong Dollar',
    'KRW/INR': '🇰🇷 South Korean Won',
    'AED/INR': '🇦🇪 UAE Dirham',
    'NZD/INR': '🇳🇿 New Zealand Dollar',
    'SAR/INR': '🇸🇦 Saudi Riyal',
    'QAR/INR': '🇶🇦 Qatari Riyal',
    'KWD/INR': '🇰🇼 Kuwaiti Dinar',
    'BHD/INR': '🇧🇭 Bahraini Dinar',
    'OMR/INR': '🇴🇲 Omani Rial',
    'ILS/INR': '🇮🇱 Israeli Shekel',
    'THB/INR': '🇹🇭 Thai Baht',
    'MYR/INR': '🇲🇾 Malaysian Ringgit',
    'IDR/INR': '🇮🇩 Indonesian Rupiah',
    'PHP/INR': '🇵🇭 Philippine Peso',
    'TWD/INR': '🇹🇼 Taiwan Dollar',
    'VND/INR': '🇻🇳 Vietnamese Dong',
    'BDT/INR': '🇧🇩 Bangladeshi Taka',
    'LKR/INR': '🇱🇰 Sri Lankan Rupee',
    'PKR/INR': '🇵🇰 Pakistani Rupee',
    'NPR/INR': '🇳🇵 Nepalese Rupee',
    'SEK/INR': '🇸🇪 Swedish Krona',
    'NOK/INR': '🇳🇴 Norwegian Krone',
    'DKK/INR': '🇩🇰 Danish Krone',
    'PLN/INR': '🇵🇱 Polish Zloty',
    'TRY/INR': '🇹🇷 Turkish Lira',
    'BRL/INR': '🇧🇷 Brazilian Real',
    'MXN/INR': '🇲🇽 Mexican Peso',
    'ZAR/INR': '🇿🇦 South African Rand',
    'India 10Y Bond Yield': 'India 10Y Bond',
    'US 10Y Treasury Yield': 'US 10Y Treasury',
    'US 2Y Treasury Yield': 'US 2Y Treasury',
    'Germany 10Y Bond Yield': 'Germany 10Y Bond',
    'Japan 10Y Bond Yield': 'Japan 10Y Bond',
    'gold': 'Gold',
    'silver': 'Silver',
    'crude oil': 'Crude Oil',
    'natural gas': 'Natural Gas',
    'copper': 'Copper',
    'platinum': 'Platinum',
    'palladium': 'Palladium',
    'wheat': 'Wheat',
    'corn': 'Corn',
    'soybeans': 'Soybeans',
    'rice': 'Rice',
    'oats': 'Oats',
    'cotton': 'Cotton',
    'sugar': 'Sugar',
    'coffee': 'Coffee',
    'cocoa': 'Cocoa',
    'aluminum': 'Aluminum',
    'brent crude': 'Brent Crude',
    'gasoline': 'Gasoline',
    'heating oil': 'Heating Oil',
    'urea': 'Urea',
    'dap fertilizer': 'DAP Fertilizer',
    'potash': 'Potash',
    'tsp fertilizer': 'TSP Fertilizer',
    'iron ore': 'Iron Ore',
    'coal': 'Coal',
    'palm oil': 'Palm Oil',
    'rubber': 'Rubber',
    'zinc': 'Zinc',
    'bitcoin': 'Bitcoin',
    'ethereum': 'Ethereum',
    'bnb': 'BNB',
    'solana': 'Solana',
    'xrp': 'XRP',
    'cardano': 'Cardano',
    'dogecoin': 'Dogecoin',
    'polkadot': 'Polkadot',
    'avalanche': 'Avalanche',
    'chainlink': 'Chainlink',
    'inflation_cpi': 'Inflation (CPI)',
    'inflation': 'Inflation (CPI)',
    'core_inflation': 'Core Inflation',
    'gdp_growth': 'GDP Growth',
    'unemployment': 'Unemployment',
    'repo_rate': 'Policy Rate',
    'pmi_manufacturing': 'PMI Manufacturing',
    'pmi_services': 'PMI Services',
    'iip': 'Industrial Production',
    'forex_reserves': 'Forex Reserves',
    'trade_balance': 'Trade Balance',
    'current_account_deficit': 'Current Account',
    'fiscal_deficit': 'Fiscal Deficit',
    'gst_collection': 'GST Collection',
    'bank_credit_growth': 'Bank Credit Growth',
  };

  static const Map<String, String> unitLabelsIntl = {
    'usd_per_troy_ounce': '/oz',
    'usd_per_barrel': '/bbl',
    'usd_per_mmbtu': '/MMBtu',
    'usd_per_pound': '/lb',
    'usd_per_bushel': '/bu',
    'usd_per_hundredweight': '/cwt',
    'usd_per_gallon': '/gal',
    'usd_per_metric_ton': '/MT',
    'usd_per_dry_metric_ton': '/dmt',
    'usd_per_kg': '/kg',
  };

  static const Map<String, String> unitLabelsIndian = {
    'gold': '/10g',
    'silver': '/kg',
    'copper': '/kg',
    'crude oil': '/bbl',
    'natural gas': '/MMBtu',
    'platinum': '/10g',
    'palladium': '/10g',
  };
}

class MarketRegions {
  MarketRegions._();

  static const String india = 'India';
  static const String us = 'US';
  static const String europe = 'Europe';
  static const String japan = 'Japan';
  static const String fx = 'FX';
  static const String commodities = 'Commodities';
  static const String crypto = 'Crypto';
  static const String all = 'All';

  static const List<String> allValues = [
    all,
    india,
    us,
    europe,
    japan,
    fx,
    commodities,
    crypto,
  ];
}

class ScreenerPresets {
  ScreenerPresets._();

  static const String momentum = 'momentum';
  static const String reversal = 'reversal';
  static const String volatility = 'volatility';
  static const String macroSensitive = 'macro-sensitive';

  static const List<String> all = [
    momentum,
    reversal,
    volatility,
    macroSensitive,
  ];
}

class Impacts {
  Impacts._();

  static const Map<String, String> friendlyLabels = {
    'risk_on': 'Positive',
    'risk_off': 'Negative',
    'inflation_signal': 'Inflation',
    'growth_signal': 'Growth',
    'policy_signal': 'Policy',
    'market_signal': 'Market',
    'macro_signal': 'Macro',
  };
}
