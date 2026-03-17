/// AU3-01 — Centralised API URLs and app-wide constants.
/// Replace hardcoded strings throughout services with these constants.
class AppConfig {
  AppConfig._();

  // Gold price API
  static const String goldPriceBaseUrl =
      'https://data-asg.goldprice.org/dbXRates';
  static const String goldPriceInrUrl = '$goldPriceBaseUrl/INR';
  static const String goldPriceUsdUrl = '$goldPriceBaseUrl/USD';

  // Exchange rate APIs
  static const String exchangeRateBaseUrl =
      'https://api.exchangerate-api.com/v4/latest/USD';
  static const String exchangeRateFallbackUrl =
      'https://open.er-api.com/v6/latest/USD';

  // MF (Mutual Fund) API
  static const String mfApiBaseUrl = 'https://api.mfapi.in';
  static const String mfSchemeLatestUrl = '$mfApiBaseUrl/mf'; // append /$schemeCode/latest
  static const String mfSearchUrl = '$mfApiBaseUrl/mf/search';

  // App
  static const String appName = 'VittaraFinOS';
  static const int backupVersion = 5;
  static const Duration goldPriceCacheTtl = Duration(hours: 1);
}
