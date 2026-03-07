/// Bank-specific SMS regex patterns for Indian banks.
/// Each BankPattern maps a bank's senderIds to debit/credit regex patterns.
/// The bank's senderIds here are defaults — the user can override them
/// in Manage → Banks → Edit Sender IDs.

class BankSmsPatterns {
  BankSmsPatterns._();

  /// Returns a map of bank-id → BankPattern for all supported banks.
  /// The keys match the slugified bank names used in BanksController.
  static final Map<String, BankPattern> all = {
    'state_bank_of_india_(sbi)': BankPattern(
      bankId: 'state_bank_of_india_(sbi)',
      defaultSenderIds: ['SBIINB', 'SBICRD', 'SBMSMS', 'SBIACCT', 'SBI'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+debited\s+from\s+(?:a/?c|account)\s+[xX*]{0,4}(\d{4})',
            desc: 'SBI debit'),
        _p(r'debited\s+by\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'SBI debit by'),
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+withdrawn',
            desc: 'SBI withdrawal'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+credited\s+to\s+(?:a/?c|account)\s+[xX*]{0,4}(\d{4})',
            desc: 'SBI credit'),
        _p(r'credited\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'SBI credit plain'),
      ],
    ),
    'hdfc_bank': BankPattern(
      bankId: 'hdfc_bank',
      defaultSenderIds: ['HDFCBK', 'HDFC'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)\s+debited\s+from\s+(?:a/?c|account)\s+[xX*]{0,4}(\d{4})',
            desc: 'HDFC debit ac'),
        _p(r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)\s+spent\s+on\s+(?:hdfc\s+)?(?:bank\s+)?card\s+[xX*]{0,4}(\d{4})',
            desc: 'HDFC card spend', cardGroup: 2),
        _p(r'(?:a/?c|account)\s+[xX*]{0,4}(\d{4})\s+is\s+debited\s+with\s+(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'HDFC debited with', amtGroup: 2, acctGroup: 1),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)\s+credited\s+to\s+(?:a/?c|account)\s+[xX*]{0,4}(\d{4})',
            desc: 'HDFC credit'),
        _p(r'(?:a/?c|account)\s+[xX*]{0,4}(\d{4})\s+is\s+credited\s+with\s+(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'HDFC credited with', amtGroup: 2, acctGroup: 1),
      ],
    ),
    'icici_bank': BankPattern(
      bankId: 'icici_bank',
      defaultSenderIds: ['ICICI', 'ICICIB'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)\s+dr\.?\s+from\s+(?:a/?c|account)\s+[xX*]{0,4}(\d{4})',
            desc: 'ICICI Dr'),
        _p(r'(?:a/?c|account)\s+[xX*]{0,4}(\d{4})\s+debited\s+for\s+(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'ICICI debited for', amtGroup: 2, acctGroup: 1),
        _p(r'card\s+[xX*]{0,4}(\d{4})\s+used\s+for\s+(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'ICICI card used', amtGroup: 2, cardGroup: 1),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)\s+cr\.?\s+to\s+(?:a/?c|account)\s+[xX*]{0,4}(\d{4})',
            desc: 'ICICI Cr'),
        _p(r'(?:a/?c|account)\s+[xX*]{0,4}(\d{4})\s+credited\s+(?:with\s+)?(?:rs\.?|inr)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'ICICI credited', amtGroup: 2, acctGroup: 1),
      ],
    ),
    'axis_bank': BankPattern(
      bankId: 'axis_bank',
      defaultSenderIds: ['AXISBK', 'AXIS'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited\s+(?:from\s+)?(?:a/?c|account|ac)[\s*xX]*(\d{4})',
            desc: 'Axis debit'),
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+spent\s+using\s+(?:axis\s+)?(?:bank\s+)?(?:debit|credit)?\s*card\s+[xX*]{0,4}(\d{4})',
            desc: 'Axis card', cardGroup: 2),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited\s+(?:to\s+)?(?:a/?c|account|ac)[\s*xX]*(\d{4})',
            desc: 'Axis credit'),
      ],
    ),
    'kotak_mahindra_bank': BankPattern(
      bankId: 'kotak_mahindra_bank',
      defaultSenderIds: ['KOTAK'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+debited\s+from\s+(?:kotak\s+)?(?:a/?c|account)\s+[xX*]{0,4}(\d{4})',
            desc: 'Kotak debit'),
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?deducted',
            desc: 'Kotak deducted'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'Kotak credited'),
      ],
    ),
    'punjab_national_bank_(pnb)': BankPattern(
      bankId: 'punjab_national_bank_(pnb)',
      defaultSenderIds: ['PNBSMS', 'PNB'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'PNB debit'),
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+dr\.?\b',
            desc: 'PNB Dr'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'PNB credit'),
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+cr\.?\b',
            desc: 'PNB Cr'),
      ],
    ),
    'bank_of_baroda': BankPattern(
      bankId: 'bank_of_baroda',
      defaultSenderIds: ['BOBBK', 'BARODA', 'BOB', 'BOBSMS', 'BOBTXN'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited\s+from\s+(?:a/?c|account|ac)\s+[xX*]{0,4}(\d{4})',
            desc: 'BOB debit'),
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+dr', desc: 'BOB Dr'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited\s+to\s+(?:a/?c|account|ac)\s+[xX*]{0,4}(\d{4})',
            desc: 'BOB credit'),
      ],
    ),
    'canara_bank': BankPattern(
      bankId: 'canara_bank',
      defaultSenderIds: ['CANARA', 'CANAR', 'CNRBNK'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'Canara debit'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'Canara credit'),
      ],
    ),
    'union_bank_of_india': BankPattern(
      bankId: 'union_bank_of_india',
      defaultSenderIds: ['UNIONB', 'UNION', 'UBISMS'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:is\s+)?debited',
            desc: 'Union debit'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:is\s+)?credited',
            desc: 'Union credit'),
      ],
    ),
    'indusind_bank': BankPattern(
      bankId: 'indusind_bank',
      defaultSenderIds: ['INDBK', 'INDUS', 'INDUSB'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'IndusInd debit'),
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+dr\.?\b',
            desc: 'IndusInd Dr'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'IndusInd credit'),
      ],
    ),
    'idbi_bank': BankPattern(
      bankId: 'idbi_bank',
      defaultSenderIds: ['IDBI'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'IDBI debit'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'IDBI credit'),
      ],
    ),
    'yes_bank': BankPattern(
      bankId: 'yes_bank',
      defaultSenderIds: ['YESBK', 'YES'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'Yes debit'),
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+dr\.?\b', desc: 'Yes Dr'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'Yes credit'),
      ],
    ),
    'idfc_first_bank': BankPattern(
      bankId: 'idfc_first_bank',
      defaultSenderIds: ['IDFCFB', 'IDFC'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'IDFC debit'),
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+spent',
            desc: 'IDFC spent'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'IDFC credit'),
      ],
    ),
    'federal_bank': BankPattern(
      bankId: 'federal_bank',
      defaultSenderIds: ['FEDBNK', 'FED', 'FEDBK'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'Federal debit'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\.?\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'Federal credit'),
      ],
    ),
    'paytm_payments_bank': BankPattern(
      bankId: 'paytm_payments_bank',
      defaultSenderIds: ['PAYTM', 'PYTMSB'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'Paytm debit'),
        _p(r'paid\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'Paytm paid'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'Paytm credit'),
        _p(r'received\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'Paytm received'),
      ],
    ),
    'airtel_payments_bank': BankPattern(
      bankId: 'airtel_payments_bank',
      defaultSenderIds: ['AIRTEL', 'AIRTLB'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?debited',
            desc: 'Airtel debit'),
        _p(r'paid\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'Airtel paid'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?credited',
            desc: 'Airtel credit'),
      ],
    ),
    'google_pay': BankPattern(
      bankId: 'google_pay',
      defaultSenderIds: ['GPAY', 'GOOGLEPAY', 'GPAYIN'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?(?:paid|debited|sent)',
            desc: 'GPay debit'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?(?:received|credited)',
            desc: 'GPay credit'),
      ],
    ),
    'phonepe': BankPattern(
      bankId: 'phonepe',
      defaultSenderIds: ['PHONEPE', 'PHNEPE', 'PHNPE'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?(?:paid|debited|sent)',
            desc: 'PhonePe debit'),
        _p(r'paid\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)',
            desc: 'PhonePe paid'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?received',
            desc: 'PhonePe received'),
      ],
    ),
    'amazon_pay': BankPattern(
      bankId: 'amazon_pay',
      defaultSenderIds: ['AMAZON', 'AMZPAY', 'AMZNPAY'],
      debitPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?(?:paid|debited|charged)',
            desc: 'Amazon debit'),
      ],
      creditPatterns: [
        _p(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:has been\s+)?(?:added|credited|refunded)',
            desc: 'Amazon credit'),
      ],
    ),
  };

  static SmsPattern _p(
    String regex, {
    required String desc,
    int amtGroup = 1,
    int? acctGroup,
    int? cardGroup,
  }) =>
      SmsPattern(
        regex: regex,
        description: desc,
        amountGroup: amtGroup,
        accountGroup: acctGroup ?? (amtGroup == 1 ? 2 : null),
        cardGroup: cardGroup,
      );
}

class BankPattern {
  final String bankId;
  final List<String> defaultSenderIds;
  final List<SmsPattern> debitPatterns;
  final List<SmsPattern> creditPatterns;

  const BankPattern({
    required this.bankId,
    required this.defaultSenderIds,
    required this.debitPatterns,
    required this.creditPatterns,
  });

  bool matchesSender(String sender) {
    final s = sender.toUpperCase();
    return defaultSenderIds.any((id) => s.contains(id));
  }
}

class SmsPattern {
  final String regex;
  final String description;
  final int amountGroup;
  final int? accountGroup;
  final int? cardGroup;
  late final RegExp _compiled;

  SmsPattern({
    required this.regex,
    required this.description,
    this.amountGroup = 1,
    this.accountGroup,
    this.cardGroup,
  }) {
    _compiled = RegExp(regex, caseSensitive: false);
  }

  RegExpMatch? match(String body) => _compiled.firstMatch(body);
}
