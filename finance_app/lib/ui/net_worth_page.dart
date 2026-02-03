import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
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
            try {
              return SingleChildScrollView(
                padding: EdgeInsets.all(Spacing.lg),
                child: Column(
                  children: [
                    _buildTotalNetWorthCard(context, accountsController, investmentsController),
                    SizedBox(height: Spacing.xl),
                    _buildBankAccountsSection(context, accountsController),
                    SizedBox(height: Spacing.lg),
                    _buildInvestmentsSection(context, investmentsController),
                    SizedBox(height: Spacing.xl),
                  ],
                ),
              );
            } catch (e) {
              if (kDebugMode) {
                print('Error building Net Worth page: $e');
                print(StackTrace.current);
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 50,
                      color: Colors.red.withOpacity(0.7),
                    ),
                    SizedBox(height: Spacing.lg),
                    Text(
                      'Error Loading Net Worth',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    SizedBox(height: Spacing.md),
                    Text(
                      e.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
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
    double totalAccounts = 0;
    for (var account in accountsController.accounts) {
      totalAccounts += account.balance;
    }

    double totalInvestments = 0;
    for (var investment in investmentsController.investments) {
      totalInvestments += investment.amount;
    }

    final totalNetWorth = totalAccounts + totalInvestments;

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
            ),
          ),
          SizedBox(height: Spacing.md),
          Text(
            '₹${totalNetWorth.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: SemanticColors.primary,
            ),
          ),
          SizedBox(height: Spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.checkmark_seal_fill, size: 20, color: Colors.green),
                      SizedBox(height: Spacing.sm),
                      Text(
                        'Assets',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: Spacing.xs),
                      Text(
                        '₹${(totalAccounts + totalInvestments).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountsSection(
    BuildContext context,
    AccountsController accountsController,
  ) {
    if (accountsController.accounts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            'No bank accounts added',
            style: TextStyle(
              fontSize: 13,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ),
      );
    }

    double total = 0;
    for (var account in accountsController.accounts) {
      total += account.balance;
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
          Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.creditcard_fill, size: 20, color: Colors.blue),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Accounts',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${accountsController.accounts.length} account${accountsController.accounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
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
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: accountsController.accounts
                  .asMap()
                  .entries
                  .map((entry) {
                    final isLast = entry.key == accountsController.accounts.length - 1;
                    final account = entry.value;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    account.bankName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.getSecondaryTextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${account.balance.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.getTextColor(context),
                              ),
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

  Widget _buildInvestmentsSection(
    BuildContext context,
    InvestmentsController investmentsController,
  ) {
    if (investmentsController.investments.isEmpty) {
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

    // Group by type
    final investmentsByType = <String, List<Investment>>{};
    double totalInvestments = 0;

    for (var inv in investmentsController.investments) {
      final type = inv.type.toString().split('.').last;
      if (!investmentsByType.containsKey(type)) {
        investmentsByType[type] = [];
      }
      investmentsByType[type]!.add(inv);
      totalInvestments += inv.amount;
    }

    // Sort by total amount
    final sortedEntries = investmentsByType.entries.toList();
    sortedEntries.sort((a, b) {
      double totalA = 0, totalB = 0;
      for (var inv in a.value) totalA += inv.amount;
      for (var inv in b.value) totalB += inv.amount;
      return totalB.compareTo(totalA);
    });

    final displayEntries = _expandInvestments ? sortedEntries : sortedEntries.take(3).toList();
    final hasMore = sortedEntries.length > 3;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...displayEntries
                    .asMap()
                    .entries
                    .map((entry) {
                      final isLast = entry.key == displayEntries.length - 1;
                      final type = entry.value.key;
                      final investments = entry.value.value;

                      double typeTotal = 0;
                      for (var inv in investments) {
                        typeTotal += inv.amount;
                      }
                      final percentage = totalInvestments > 0 ? (typeTotal / totalInvestments * 100) : 0.0;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                if (hasMore)
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
