/// AU3-01 — Centralised API URLs and app-wide constants.
/// Replace hardcoded strings throughout services with these constants.
class AppConfig {
  AppConfig._();

  // Gold price — Yahoo Finance COMEX futures (GC=F), no API key needed
  // Exchange rate used for USD→INR conversion
  // (URLs inlined in GoldPriceService to keep service self-contained)

  // MF (Mutual Fund) API
  static const String mfApiBaseUrl = 'https://api.mfapi.in';
  static const String mfSchemeLatestUrl = '$mfApiBaseUrl/mf'; // append /$schemeCode/latest
  static const String mfSearchUrl = '$mfApiBaseUrl/mf/search';

  // App
  static const String appName = 'VittaraFinOS';
  static const int backupVersion = 5;
  static const Duration goldPriceCacheTtl = Duration(hours: 1);
}
