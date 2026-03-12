class AssetLogoMeta {
  final String assetKey;
  final String logoPath;
  final String sourceType;
  final String? attribution;

  const AssetLogoMeta({
    required this.assetKey,
    required this.logoPath,
    required this.sourceType,
    this.attribution,
  });
}

const Map<String, AssetLogoMeta> assetLogoManifest = {
  'aed_inr': AssetLogoMeta(
    assetKey: 'AED/INR',
    logoPath: 'assets/asset_logos/aed_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'aud_inr': AssetLogoMeta(
    assetKey: 'AUD/INR',
    logoPath: 'assets/asset_logos/aud_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'bdt_inr': AssetLogoMeta(
    assetKey: 'BDT/INR',
    logoPath: 'assets/asset_logos/bdt_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'bhd_inr': AssetLogoMeta(
    assetKey: 'BHD/INR',
    logoPath: 'assets/asset_logos/bhd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'brl_inr': AssetLogoMeta(
    assetKey: 'BRL/INR',
    logoPath: 'assets/asset_logos/brl_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'cac_40': AssetLogoMeta(
    assetKey: 'CAC 40',
    logoPath: 'assets/asset_logos/cac_40.svg',
    sourceType: 'custom_pictogram',
  ),
  'cad_inr': AssetLogoMeta(
    assetKey: 'CAD/INR',
    logoPath: 'assets/asset_logos/cad_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'cboe_vix': AssetLogoMeta(
    assetKey: 'CBOE VIX',
    logoPath: 'assets/asset_logos/cboe_vix.svg',
    sourceType: 'custom_pictogram',
  ),
  'chf_inr': AssetLogoMeta(
    assetKey: 'CHF/INR',
    logoPath: 'assets/asset_logos/chf_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'cny_inr': AssetLogoMeta(
    assetKey: 'CNY/INR',
    logoPath: 'assets/asset_logos/cny_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'dax': AssetLogoMeta(
    assetKey: 'DAX',
    logoPath: 'assets/asset_logos/dax.svg',
    sourceType: 'custom_pictogram',
  ),
  'dkk_inr': AssetLogoMeta(
    assetKey: 'DKK/INR',
    logoPath: 'assets/asset_logos/dkk_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'dow_jones': AssetLogoMeta(
    assetKey: 'Dow Jones',
    logoPath: 'assets/asset_logos/dow_jones.svg',
    sourceType: 'custom_pictogram',
  ),
  'eur_inr': AssetLogoMeta(
    assetKey: 'EUR/INR',
    logoPath: 'assets/asset_logos/eur_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'euro_stoxx_50': AssetLogoMeta(
    assetKey: 'Euro Stoxx 50',
    logoPath: 'assets/asset_logos/euro_stoxx_50.svg',
    sourceType: 'custom_pictogram',
  ),
  'ftse_100': AssetLogoMeta(
    assetKey: 'FTSE 100',
    logoPath: 'assets/asset_logos/ftse_100.svg',
    sourceType: 'custom_pictogram',
  ),
  'gbp_inr': AssetLogoMeta(
    assetKey: 'GBP/INR',
    logoPath: 'assets/asset_logos/gbp_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'germany_10y_bond_yield': AssetLogoMeta(
    assetKey: 'Germany 10Y Bond Yield',
    logoPath: 'assets/asset_logos/germany_10y_bond_yield.svg',
    sourceType: 'custom_pictogram',
  ),
  'gift_nifty': AssetLogoMeta(
    assetKey: 'Gift Nifty',
    logoPath: 'assets/asset_logos/gift_nifty.svg',
    sourceType: 'custom_pictogram',
  ),
  'hkd_inr': AssetLogoMeta(
    assetKey: 'HKD/INR',
    logoPath: 'assets/asset_logos/hkd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'idr_inr': AssetLogoMeta(
    assetKey: 'IDR/INR',
    logoPath: 'assets/asset_logos/idr_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'ils_inr': AssetLogoMeta(
    assetKey: 'ILS/INR',
    logoPath: 'assets/asset_logos/ils_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'india_10y_bond_yield': AssetLogoMeta(
    assetKey: 'India 10Y Bond Yield',
    logoPath: 'assets/asset_logos/india_10y_bond_yield.svg',
    sourceType: 'custom_pictogram',
  ),
  'india_vix': AssetLogoMeta(
    assetKey: 'India VIX',
    logoPath: 'assets/asset_logos/india_vix.svg',
    sourceType: 'custom_pictogram',
  ),
  'jpy_inr': AssetLogoMeta(
    assetKey: 'JPY/INR',
    logoPath: 'assets/asset_logos/jpy_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'japan_10y_bond_yield': AssetLogoMeta(
    assetKey: 'Japan 10Y Bond Yield',
    logoPath: 'assets/asset_logos/japan_10y_bond_yield.svg',
    sourceType: 'custom_pictogram',
  ),
  'krw_inr': AssetLogoMeta(
    assetKey: 'KRW/INR',
    logoPath: 'assets/asset_logos/krw_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'kwd_inr': AssetLogoMeta(
    assetKey: 'KWD/INR',
    logoPath: 'assets/asset_logos/kwd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'lkr_inr': AssetLogoMeta(
    assetKey: 'LKR/INR',
    logoPath: 'assets/asset_logos/lkr_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'mxn_inr': AssetLogoMeta(
    assetKey: 'MXN/INR',
    logoPath: 'assets/asset_logos/mxn_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'myr_inr': AssetLogoMeta(
    assetKey: 'MYR/INR',
    logoPath: 'assets/asset_logos/myr_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'nasdaq': AssetLogoMeta(
    assetKey: 'NASDAQ',
    logoPath: 'assets/asset_logos/nasdaq.svg',
    sourceType: 'custom_pictogram',
  ),
  'nok_inr': AssetLogoMeta(
    assetKey: 'NOK/INR',
    logoPath: 'assets/asset_logos/nok_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'npr_inr': AssetLogoMeta(
    assetKey: 'NPR/INR',
    logoPath: 'assets/asset_logos/npr_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'nzd_inr': AssetLogoMeta(
    assetKey: 'NZD/INR',
    logoPath: 'assets/asset_logos/nzd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'nasdaq_100': AssetLogoMeta(
    assetKey: 'Nasdaq 100',
    logoPath: 'assets/asset_logos/nasdaq_100.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_50': AssetLogoMeta(
    assetKey: 'Nifty 50',
    logoPath: 'assets/asset_logos/nifty_50.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_500': AssetLogoMeta(
    assetKey: 'Nifty 500',
    logoPath: 'assets/asset_logos/nifty_500.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_auto': AssetLogoMeta(
    assetKey: 'Nifty Auto',
    logoPath: 'assets/asset_logos/nifty_auto.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_bank': AssetLogoMeta(
    assetKey: 'Nifty Bank',
    logoPath: 'assets/asset_logos/nifty_bank.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_it': AssetLogoMeta(
    assetKey: 'Nifty IT',
    logoPath: 'assets/asset_logos/nifty_it.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_metal': AssetLogoMeta(
    assetKey: 'Nifty Metal',
    logoPath: 'assets/asset_logos/nifty_metal.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_midcap_150': AssetLogoMeta(
    assetKey: 'Nifty Midcap 150',
    logoPath: 'assets/asset_logos/nifty_midcap_150.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_pharma': AssetLogoMeta(
    assetKey: 'Nifty Pharma',
    logoPath: 'assets/asset_logos/nifty_pharma.svg',
    sourceType: 'custom_pictogram',
  ),
  'nifty_smallcap_250': AssetLogoMeta(
    assetKey: 'Nifty Smallcap 250',
    logoPath: 'assets/asset_logos/nifty_smallcap_250.svg',
    sourceType: 'custom_pictogram',
  ),
  'nikkei_225': AssetLogoMeta(
    assetKey: 'Nikkei 225',
    logoPath: 'assets/asset_logos/nikkei_225.svg',
    sourceType: 'custom_pictogram',
  ),
  'omr_inr': AssetLogoMeta(
    assetKey: 'OMR/INR',
    logoPath: 'assets/asset_logos/omr_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'php_inr': AssetLogoMeta(
    assetKey: 'PHP/INR',
    logoPath: 'assets/asset_logos/php_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'pkr_inr': AssetLogoMeta(
    assetKey: 'PKR/INR',
    logoPath: 'assets/asset_logos/pkr_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'pln_inr': AssetLogoMeta(
    assetKey: 'PLN/INR',
    logoPath: 'assets/asset_logos/pln_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'qar_inr': AssetLogoMeta(
    assetKey: 'QAR/INR',
    logoPath: 'assets/asset_logos/qar_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  's_p_500_energy': AssetLogoMeta(
    assetKey: 'S&P 500 Energy',
    logoPath: 'assets/asset_logos/s_p_500_energy.svg',
    sourceType: 'custom_pictogram',
  ),
  's_p_500_financials': AssetLogoMeta(
    assetKey: 'S&P 500 Financials',
    logoPath: 'assets/asset_logos/s_p_500_financials.svg',
    sourceType: 'custom_pictogram',
  ),
  's_p_500_tech': AssetLogoMeta(
    assetKey: 'S&P 500 Tech',
    logoPath: 'assets/asset_logos/s_p_500_tech.svg',
    sourceType: 'custom_pictogram',
  ),
  's_p500': AssetLogoMeta(
    assetKey: 'S&P500',
    logoPath: 'assets/asset_logos/s_p500.svg',
    sourceType: 'custom_pictogram',
  ),
  'sar_inr': AssetLogoMeta(
    assetKey: 'SAR/INR',
    logoPath: 'assets/asset_logos/sar_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'sek_inr': AssetLogoMeta(
    assetKey: 'SEK/INR',
    logoPath: 'assets/asset_logos/sek_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'sgd_inr': AssetLogoMeta(
    assetKey: 'SGD/INR',
    logoPath: 'assets/asset_logos/sgd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'sensex': AssetLogoMeta(
    assetKey: 'Sensex',
    logoPath: 'assets/asset_logos/sensex.svg',
    sourceType: 'custom_pictogram',
  ),
  'thb_inr': AssetLogoMeta(
    assetKey: 'THB/INR',
    logoPath: 'assets/asset_logos/thb_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'topix': AssetLogoMeta(
    assetKey: 'TOPIX',
    logoPath: 'assets/asset_logos/topix.svg',
    sourceType: 'custom_pictogram',
  ),
  'try_inr': AssetLogoMeta(
    assetKey: 'TRY/INR',
    logoPath: 'assets/asset_logos/try_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'twd_inr': AssetLogoMeta(
    assetKey: 'TWD/INR',
    logoPath: 'assets/asset_logos/twd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'us_10y_treasury_yield': AssetLogoMeta(
    assetKey: 'US 10Y Treasury Yield',
    logoPath: 'assets/asset_logos/us_10y_treasury_yield.svg',
    sourceType: 'custom_pictogram',
  ),
  'us_2y_treasury_yield': AssetLogoMeta(
    assetKey: 'US 2Y Treasury Yield',
    logoPath: 'assets/asset_logos/us_2y_treasury_yield.svg',
    sourceType: 'custom_pictogram',
  ),
  'usd_inr': AssetLogoMeta(
    assetKey: 'USD/INR',
    logoPath: 'assets/asset_logos/usd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'vnd_inr': AssetLogoMeta(
    assetKey: 'VND/INR',
    logoPath: 'assets/asset_logos/vnd_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'zar_inr': AssetLogoMeta(
    assetKey: 'ZAR/INR',
    logoPath: 'assets/asset_logos/zar_inr.svg',
    sourceType: 'custom_pictogram',
  ),
  'copper': AssetLogoMeta(
    assetKey: 'copper',
    logoPath: 'assets/asset_logos/copper.svg',
    sourceType: 'custom_pictogram',
  ),
  'crude_oil': AssetLogoMeta(
    assetKey: 'crude oil',
    logoPath: 'assets/asset_logos/crude_oil.svg',
    sourceType: 'custom_pictogram',
  ),
  'gold': AssetLogoMeta(
    assetKey: 'gold',
    logoPath: 'assets/asset_logos/gold.svg',
    sourceType: 'custom_pictogram',
  ),
  'natural_gas': AssetLogoMeta(
    assetKey: 'natural gas',
    logoPath: 'assets/asset_logos/natural_gas.svg',
    sourceType: 'custom_pictogram',
  ),
  'palladium': AssetLogoMeta(
    assetKey: 'palladium',
    logoPath: 'assets/asset_logos/palladium.svg',
    sourceType: 'custom_pictogram',
  ),
  'platinum': AssetLogoMeta(
    assetKey: 'platinum',
    logoPath: 'assets/asset_logos/platinum.svg',
    sourceType: 'custom_pictogram',
  ),
  'silver': AssetLogoMeta(
    assetKey: 'silver',
    logoPath: 'assets/asset_logos/silver.svg',
    sourceType: 'custom_pictogram',
  ),
};
