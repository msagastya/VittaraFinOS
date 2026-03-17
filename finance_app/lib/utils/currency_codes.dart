class CurrencyCodes {
  CurrencyCodes._();
  static const List<String> common = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'SGD',
    'AED',
    'JPY',
    'AUD',
    'CAD',
  ];
  static const Map<String, String> symbols = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'SGD': 'S\$',
    'AED': 'د.إ',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
  };
  static String symbolFor(String code) => symbols[code] ?? code;
}
