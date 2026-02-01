import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  bool _expandInvestments = false;
  bool _expandLiabilities = false;
  List<String> _investmentTypeOrder = [];
  List<String> _accountOrder = [];
  bool _orderInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedInvestmentOrder = prefs.getStringList('investmentTypeOrder') ?? [];
      final savedAccountOrder = prefs.getStringList('accountOrder') ?? [];
      if (mounted) {
        setState(() {
          _investmentTypeOrder = savedInvestmentOrder;
          _accountOrder = savedAccountOrder;
          _orderInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading orders: $e');
      }
      if (mounted) {
        setState(() {
          _orderInitialized = true;
        });
      }
    }
  }

  Future<void> _saveInvestmentTypeOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('investmentTypeOrder', _investmentTypeOrder);
  }

  Future<void> _saveAccountOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('accountOrder', _accountOrder);
  }

  void _moveInvestmentTypeUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _investmentTypeOrder[index];
        _investmentTypeOrder[index] = _investmentTypeOrder[index - 1];
        _investmentTypeOrder[index - 1] = temp;
      });
      _saveInvestmentTypeOrder();
    }
  }

  void _moveInvestmentTypeDown(int index) {
    if (index < _investmentTypeOrder.length - 1) {
      setState(() {
        final temp = _investmentTypeOrder[index];
        _investmentTypeOrder[index] = _investmentTypeOrder[index + 1];
        _investmentTypeOrder[index + 1] = temp;
      });
      _saveInvestmentTypeOrder();
    }
  }

  void _moveAccountUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _accountOrder[index];
        _accountOrder[index] = _accountOrder[index - 1];
        _accountOrder[index - 1] = temp;
      });
      _saveAccountOrder();
    }
  }

  void _moveAccountDown(int index) {
    if (index < _accountOrder.length - 1) {
      setState(() {
        final temp = _accountOrder[index];
        _accountOrder[index] = _accountOrder[index + 1];
        _accountOrder[index + 1] = temp;
      });
      _saveAccountOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Net Worth'),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: Consumer2<AccountsController, InvestmentsController>(
          builder: (context, accountsController, investmentsController, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(Spacing.lg),
              child: Column(
                children: [
                  // TOTAL NET WORTH CARD
                  _buildTotalNetWorthCard(
                    context,
                    accountsController,
                    investmentsController,
                  ),
                  SizedBox(height: Spacing.xl),

                  // ASSETS SECTION
                  _buildAssetsSection(context, accountsController, investmentsController),
                  SizedBox(height: Spacing.xl),

                  // LIABILITIES & CREDIT SECTION
                  _buildLiabilitiesSection(context),
                  SizedBox(height: Spacing.xl),

                  // NET WORTH BREAKDOWN PIE CHART
                  _buildNetWorthBreakdown(context, accountsController, investmentsController),
                  SizedBox(height: Spacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTotalNetWorthCard(
    BuildContext context,
    AccountsController accountsController,
    InvestmentsController investmentsController,
  ) {
    // Calculate all values
    double totalAccounts = 0;
    for (var account in accountsController.accounts) {
      totalAccounts += account.balance;
    }

    double totalInvestments = 0;
    for (var investment in investmentsController.investments) {
      totalInvestments += investment.amount;
    }

    final totalAssets = totalAccounts + totalInvestments;
    final totalNetWorth = totalAssets; // For now, will subtract liabilities later

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SemanticColors.primary.withOpacity(0.12),
            SemanticColors.primary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SemanticColors.primary.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: SemanticColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total Net Worth',
            style: TextStyle(
              fontSize: 14,
              color: AppStyles.getSecondaryTextColor(context),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: Spacing.md),
          Text(
            '₹${totalNetWorth.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: SemanticColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: Spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNetWorthMetric(
                context,
                'Total Assets',
                totalAssets,
                CupertinoIcons.checkmark_seal_fill,
                Colors.green,
              ),
              _buildNetWorthMetric(
                context,
                'Liabilities',
                0,
                CupertinoIcons.minus_circle_fill,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetWorthMetric(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(height: Spacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppStyles.getSecondaryTextColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: Spacing.xs),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsSection(
    BuildContext context,
    AccountsController accountsController,
    InvestmentsController investmentsController,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: EdgeInsets.only(bottom: Spacing.md),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.checkmark_seal_fill,
                size: 20,
                color: Colors.green,
              ),
              SizedBox(width: Spacing.sm),
              Text(
                'Assets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
            ],
          ),
        ),

        // BANK ACCOUNTS SUBSECTION
        _buildAssetSubsection(
          context,
          'Bank Accounts',
          accountsController.accounts,
          CupertinoIcons.creditcard_fill,
          Colors.blue,
          (item) => {
            'name': item.name,
            'bankName': item.bankName,
            'balance': item.balance.toDouble(),
            'id': item.id,
            'type': 'account',
          },
          accountOrderList: _accountOrder,
          onMoveUp: _moveAccountUp,
          onMoveDown: _moveAccountDown,
          itemIdGetter: (item) => item.id,
        ),
        SizedBox(height: Spacing.lg),

        // INVESTMENTS SUBSECTION - Type Wise
        _buildInvestmentsTypeWise(context, investmentsController),
      ],
    );
  }

  Widget _buildAssetSubsection(
    BuildContext context,
    String title,
    List<dynamic> items,
    IconData icon,
    Color color,
    Map<String, dynamic> Function(dynamic) itemBuilder, {
    List<String>? accountOrderList,
    Function(int)? onMoveUp,
    Function(int)? onMoveDown,
    String Function(dynamic)? itemIdGetter,
  }) {
    // Initialize account order if empty (first time only)
    if (accountOrderList != null && accountOrderList.isEmpty && itemIdGetter != null && _orderInitialized) {
      final newOrder = items.map((item) => itemIdGetter(item) as String).toList();
      accountOrderList.addAll(newOrder);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveAccountOrder();
      });
    }

    // Apply custom ordering if provided
    List<dynamic> orderedItems = items;
    if (accountOrderList != null && itemIdGetter != null && accountOrderList.isNotEmpty) {
      orderedItems = [];
      for (var id in accountOrderList) {
        final item = items.firstWhere(
          (item) => itemIdGetter(item) == id,
          orElse: () => null,
        );
        if (item != null) {
          orderedItems.add(item);
        }
      }
      // Add any new items not in the saved order
      for (var item in items) {
        if (!accountOrderList.contains(itemIdGetter(item))) {
          orderedItems.add(item);
        }
      }
    }

    double total = 0;
    for (var item in orderedItems) {
      final data = itemBuilder(item);
      total += data['balance'] as double;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${orderedItems.length} item${orderedItems.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1),

          // Items list
          Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: orderedItems
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final isLast = index == orderedItems.length - 1;
                    final item = entry.value;
                    final data = itemBuilder(item);

                    final canMoveUp = onMoveUp != null && index > 0;
                    final canMoveDown = onMoveDown != null && index < orderedItems.length - 1;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    data['name'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    data['bankName'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.getSecondaryTextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${(data['balance'] as double).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                            if (onMoveUp != null && onMoveDown != null)
                              SizedBox(width: Spacing.md),
                            if (onMoveUp != null && onMoveDown != null)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: canMoveUp ? () => onMoveUp(index) : null,
                                      child: Icon(
                                        CupertinoIcons.chevron_up,
                                        size: 14,
                                        color: canMoveUp ? Colors.blue : Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: canMoveDown ? () => onMoveDown(index) : null,
                                      child: Icon(
                                        CupertinoIcons.chevron_down,
                                        size: 14,
                                        color: canMoveDown ? Colors.blue : Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (!isLast)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: Spacing.md),
                            child: Divider(height: 1),
                          ),
                      ],
                    );
                  })
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentsTypeWise(
    BuildContext context,
    InvestmentsController investmentsController,
  ) {
    // Group investments by type
    final investmentsByType = <String, List<Investment>>{};
    for (var inv in investmentsController.investments) {
      final type = inv.type.toString().split('.').last;
      if (!investmentsByType.containsKey(type)) {
        investmentsByType[type] = [];
      }
      investmentsByType[type]!.add(inv);
    }

    if (investmentsByType.isEmpty) {
      return Container(
        padding: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            'No investments yet',
            style: TextStyle(
              fontSize: 13,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ),
      );
    }

    double totalInvestments = 0;
    for (var inv in investmentsController.investments) {
      totalInvestments += inv.amount;
    }

    // Sort investment types by total amount (descending)
    final sortedEntries = investmentsByType.entries.toList();
    sortedEntries.sort((a, b) {
      double totalA = 0, totalB = 0;
      for (var inv in a.value) totalA += inv.amount;
      for (var inv in b.value) totalB += inv.amount;
      return totalB.compareTo(totalA);
    });

    // Initialize investment type order if empty (first time only)
    if (_orderInitialized && _investmentTypeOrder.isEmpty) {
      _investmentTypeOrder = sortedEntries.map((e) => e.key).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveInvestmentTypeOrder();
      });
    }

    // Apply custom order - use sortedEntries as default if not initialized
    final orderedEntries = <MapEntry<String, List<Investment>>>[];
    final orderToUse = _investmentTypeOrder.isNotEmpty ? _investmentTypeOrder : sortedEntries.map((e) => e.key).toList();

    for (var type in orderToUse) {
      final entry = sortedEntries.firstWhere(
        (e) => e.key == type,
        orElse: () => MapEntry('', []),
      );
      if (entry.value.isNotEmpty) {
        orderedEntries.add(entry);
      }
    }
    // Add any new types not in the saved order
    for (var entry in sortedEntries) {
      if (!orderToUse.contains(entry.key)) {
        orderedEntries.add(entry);
      }
    }

    // Determine which entries to show (top 3 or all)
    final entriesToShow = _expandInvestments ? orderedEntries : orderedEntries.take(3).toList();
    final hasMoreItems = orderedEntries.length > 3;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.chart_bar_fill, size: 20, color: Colors.green),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Investments',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${investmentsByType.length} type${investmentsByType.length != 1 ? 's' : ''} • ${investmentsController.investments.length} total',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${totalInvestments.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1),

          // Investment types breakdown
          Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...entriesToShow
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final isLast = index == entriesToShow.length - 1;
                      final type = entry.value.key;
                      final investments = entry.value.value;

                      double typeTotal = 0;
                      for (var inv in investments) {
                        typeTotal += inv.amount;
                      }
                      final percentage = totalInvestments > 0 ? (typeTotal / totalInvestments * 100) : 0.0;

                      // Find actual position in full list for up/down buttons
                      final actualIndex = orderedEntries.indexWhere((e) => e.key == type);
                      final canMoveUp = actualIndex > 0;
                      final canMoveDown = actualIndex < orderedEntries.length - 1;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getInvestmentTypeLabel(type),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.getTextColor(context),
                                      ),
                                    ),
                                    Text(
                                      '${investments.length} item${investments.length != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppStyles.getSecondaryTextColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${typeTotal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: Spacing.md),
                              // Reorder buttons
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: canMoveUp ? () => _moveInvestmentTypeUp(actualIndex) : null,
                                      child: Icon(
                                        CupertinoIcons.chevron_up,
                                        size: 14,
                                        color: canMoveUp ? Colors.blue : Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: canMoveDown ? () => _moveInvestmentTypeDown(actualIndex) : null,
                                      child: Icon(
                                        CupertinoIcons.chevron_down,
                                        size: 14,
                                        color: canMoveDown ? Colors.blue : Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!isLast)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: Spacing.md),
                              child: Divider(height: 1),
                            ),
                        ],
                      );
                    })
                    .toList(),
                // Expand button if more items exist
                if (hasMoreItems)
                  Padding(
                    padding: EdgeInsets.only(top: Spacing.md),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _expandInvestments = !_expandInvestments;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _expandInvestments ? 'Show Less' : 'Show All',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          SizedBox(width: Spacing.xs),
                          Icon(
                            _expandInvestments
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            size: 14,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiabilitiesSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: EdgeInsets.only(bottom: Spacing.md),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.minus_circle_fill,
                size: 20,
                color: Colors.red,
              ),
              SizedBox(width: Spacing.sm),
              Text(
                'Credit & Liabilities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
            ],
          ),
        ),

        // No liabilities message (placeholder for when no data exists)
        Container(
          padding: EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.check_mark_circled,
                  size: 40,
                  color: Colors.green.withOpacity(0.5),
                ),
                SizedBox(height: Spacing.md),
                Text(
                  'No Liabilities Added',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Add credit cards or loans to track your liabilities',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildNetWorthBreakdown(
    BuildContext context,
    AccountsController accountsController,
    InvestmentsController investmentsController,
  ) {
    double totalAccounts = 0;
    for (var account in accountsController.accounts) {
      totalAccounts += account.balance;
    }

    double totalInvestments = 0;
    for (var investment in investmentsController.investments) {
      totalInvestments += investment.amount;
    }

    final total = totalAccounts + totalInvestments;

    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asset Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppStyles.getTextColor(context),
            ),
          ),
          SizedBox(height: Spacing.lg),
          _buildBreakdownRow(
            context,
            'Bank Accounts',
            totalAccounts,
            total,
            Colors.blue,
          ),
          SizedBox(height: Spacing.md),
          _buildBreakdownRow(
            context,
            'Investments',
            totalInvestments,
            total,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    double amount,
    double total,
    Color color,
  ) {
    final percentage = total > 0 ? (amount / total * 100) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: Spacing.sm),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
            Text(
              '₹${amount.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ],
        ),
        SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: AppStyles.getBackground(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  String _getInvestmentTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'stocks':
        return 'Stocks';
      case 'bonds':
        return 'Bonds';
      case 'fixeddeposit':
        return 'Fixed Deposits';
      case 'recurringdeposit':
        return 'Recurring Deposits';
      case 'mutualfunds':
        return 'Mutual Funds';
      case 'digitaldeposit':
        return 'Digital Gold';
      case 'crypto':
        return 'Cryptocurrency';
      case 'nps':
        return 'NPS';
      case 'pension':
        return 'Pension Plans';
      case 'commodities':
        return 'Commodities';
      case 'forex':
        return 'Forex';
      case 'forwardcontracts':
        return 'Forward Contracts';
      default:
        return type;
    }
  }
}
