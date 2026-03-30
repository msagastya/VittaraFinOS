import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

class TransactionFeedBuilder {
  const TransactionFeedBuilder._();

  static const String derivedInvestmentFlag = 'isDerivedInvestmentEvent';

  static List<Transaction> buildUnifiedFeed({
    required List<Transaction> transactions,
    required List<Investment> investments,
  }) {
    final merged = <Transaction>[
      ...transactions,
      ..._buildInvestmentTransactions(investments),
    ];

    final uniqueById = <String, Transaction>{};
    for (final transaction in merged) {
      uniqueById.putIfAbsent(transaction.id, () => transaction);
    }

    final unified = uniqueById.values.toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return unified;
  }

  static bool isDerivedInvestmentEvent(Transaction transaction) =>
      transaction.metadata?[derivedInvestmentFlag] == true;

  static List<Transaction> _buildInvestmentTransactions(
    List<Investment> investments,
  ) {
    final derived = <Transaction>[];

    for (final investment in investments) {
      final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
      final activityLog = _readActivityLog(metadata);

      if (activityLog.isEmpty) {
        final initialDate = _resolveInitialDate(metadata);
        final amount =
            _asDouble(metadata['investmentAmount']) ?? investment.amount;
        if (initialDate != null && amount > 0) {
          final fallbackExtraMeta = <String, dynamic>{};
          void addFallbackIfPresent(String key, dynamic value) {
            if (value != null) fallbackExtraMeta[key] = value;
          }

          // Common snapshot fields
          addFallbackIfPresent('sourceBalanceAfter', metadata['sourceBalanceAfter']);
          addFallbackIfPresent('sourceCreditLimit', metadata['sourceCreditLimit']);
          addFallbackIfPresent('currentValue', metadata['currentValue']);
          addFallbackIfPresent('currentNAV', metadata['currentNAV']);

          // Stocks/ETF: qty → quantity, pricePerShare → pricePerUnit, extraCharges → charges
          addFallbackIfPresent('quantity',
              metadata['qty'] ?? metadata['quantity']);
          addFallbackIfPresent('pricePerUnit',
              metadata['pricePerShare'] ?? metadata['pricePerUnit']);
          addFallbackIfPresent('charges',
              metadata['extraCharges'] ?? metadata['charges']);

          // MF: units, investmentNAV → navValue
          addFallbackIfPresent('units', metadata['units']);
          addFallbackIfPresent('navValue',
              metadata['investmentNAV'] ?? metadata['navValue'] ?? metadata['purchaseNAV']);

          // FD / RD: interest rate, maturity info
          addFallbackIfPresent('interestRate', metadata['interestRate']);
          addFallbackIfPresent('maturityDate', metadata['maturityDate']);
          addFallbackIfPresent('maturityValue', metadata['maturityValue']);
          addFallbackIfPresent('tenure', metadata['tenure'] ?? metadata['tenureMonths']);

          derived.add(
            Transaction(
              id: 'inv_${investment.id}_initial',
              type: TransactionType.investment,
              description:
                  '${investment.getTypeLabel()} added: ${investment.name}',
              dateTime: initialDate,
              amount: amount,
              sourceAccountId: _asString(
                metadata['accountId'] ?? metadata['deductionAccountId'],
              ),
              sourceAccountName: _asString(
                metadata['accountName'] ?? metadata['deductionAccountName'],
              ),
              metadata: {
                'categoryName': investment.getTypeLabel(),
                'investmentId': investment.id,
                'investmentName': investment.name,
                'investmentType': investment.type.name,
                'investmentEventType': 'create',
                derivedInvestmentFlag: true,
                ...fallbackExtraMeta,
              },
            ),
          );
        }
        continue;
      }

      for (var i = 0; i < activityLog.length; i++) {
        final event = activityLog[i];
        final eventType = _normalizeEventType(event['type'] as String?);
        final amount = _asDouble(event['amount']);
        if (amount == null || amount <= 0) continue;

        final date = _parseDate(event['date']) ??
            _parseDate(event['timestamp']) ??
            _resolveInitialDate(metadata) ??
            DateTime.now();

        final description = _asString(event['description'])?.trim();

        final transactionType = _mapEventTypeToTransactionType(eventType);
        final accountId = _asString(
          event['accountId'] ??
              event['sourceAccountId'] ??
              metadata['accountId'] ??
              metadata['deductionAccountId'],
        );
        final accountName = _asString(
          event['accountName'] ??
              event['sourceAccountName'] ??
              metadata['accountName'] ??
              metadata['deductionAccountName'],
        );

        final extraMeta = <String, dynamic>{};
        void addIfPresent(String key, dynamic value) {
          if (value != null) extraMeta[key] = value;
        }
        addIfPresent('currentValue', metadata['currentValue']);
        addIfPresent('currentNAV', metadata['currentNAV']);
        // Balance snapshot — prefer per-event value, fall back to investment-level
        addIfPresent('sourceBalanceAfter',
            event['sourceBalanceAfter'] ?? metadata['sourceBalanceAfter']);
        addIfPresent('sourceCreditLimit',
            event['sourceCreditLimit'] ?? metadata['sourceCreditLimit']);
        // Quantity: event key first, then stocks key mapping
        addIfPresent('quantity',
            event['quantity'] ?? event['qty']);
        addIfPresent('units', event['units']);
        // Price / NAV: event key first, then stocks key mapping
        addIfPresent('pricePerUnit',
            event['price'] ?? event['pricePerUnit'] ?? event['pricePerShare']);
        addIfPresent('navValue',
            event['nav'] ?? event['navValue'] ?? event['investmentNAV'] ?? event['purchaseNAV']);
        // Charges: event key first, then stocks key mapping
        addIfPresent('charges',
            event['charges'] ?? event['extraCharges']);

        derived.add(
          Transaction(
            id: 'inv_${investment.id}_${event['id'] ?? i}',
            type: transactionType,
            description: description != null && description.isNotEmpty
                ? description
                : _buildDefaultDescription(investment, eventType),
            dateTime: date,
            amount: amount,
            sourceAccountId: accountId,
            sourceAccountName: accountName,
            metadata: {
              'categoryName': investment.getTypeLabel(),
              'investmentId': investment.id,
              'investmentName': investment.name,
              'investmentType': investment.type.name,
              'investmentEventType': eventType,
              derivedInvestmentFlag: true,
              ...extraMeta,
            },
          ),
        );
      }
    }

    derived.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return derived;
  }

  static List<Map<String, dynamic>> _readActivityLog(
    Map<String, dynamic> metadata,
  ) {
    final raw = metadata['activityLog'];
    if (raw is! List) return const [];

    final entries = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        entries.add(item.map((key, value) => MapEntry('$key', value)));
      }
    }
    return entries;
  }

  static DateTime? _resolveInitialDate(Map<String, dynamic> metadata) {
    const keys = [
      'investmentDate',
      'purchaseDate',
      'startDate',
      'createdAt',
      'openedAt',
      'date',
    ];

    for (final key in keys) {
      final parsed = _parseDate(metadata[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _normalizeEventType(String? value) =>
      (value ?? 'activity').trim().toLowerCase();

  static TransactionType _mapEventTypeToTransactionType(String type) {
    switch (type) {
      case 'dividend':
      case 'sell':
      case 'decrease':
      case 'redeem':
      case 'redemption':
      case 'withdrawal':
      case 'payout':
      case 'maturity':
        return TransactionType.income;
      default:
        return TransactionType.investment;
    }
  }

  static String _buildDefaultDescription(Investment investment, String type) {
    switch (type) {
      case 'create':
        return '${investment.getTypeLabel()} added: ${investment.name}';
      case 'buy':
      case 'increase':
      case 'sip':
        return 'Invested in ${investment.name}';
      case 'sell':
      case 'decrease':
      case 'redeem':
      case 'redemption':
      case 'withdrawal':
      case 'maturity':
      case 'payout':
        return 'Returned from ${investment.name}';
      case 'dividend':
        return 'Dividend from ${investment.name}';
      default:
        return '${investment.getTypeLabel()} activity: ${investment.name}';
    }
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.trim().isEmpty ? null : text;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
