import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
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
                    _buildDematAccountsSection(context, accountsController),
                    SizedBox(height: Spacing.lg),
                    _buildCreditLiabilitiesSection(context, accountsController),
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
    // Calculate Savings (all non-credit accounts)
    double totalSavings = 0;
    for (var account in accountsController.accounts) {
      if (account.type != AccountType.credit && account.type != AccountType.payLater) {
        totalSavings += account.balance;
      }
    }

    // Calculate Total Investment
    double totalInvestments = 0;
    for (var investment in investmentsController.investments) {
      totalInvestments += investment.amount;
    }

    // Calculate Total Credit Limit
    double totalCreditLimit = 0;
    double totalCreditUsed = 0;
    for (var account in accountsController.accounts) {
      if (account.type == AccountType.credit || account.type == AccountType.payLater) {
        totalCreditLimit += (account.creditLimit ?? 0.0);
        final used = (account.creditLimit ?? 0.0) - account.balance;
        totalCreditUsed += used;
      }
    }

    // Net Worth = Savings + Investment - Credit Used
    final totalNetWorth = totalSavings + totalInvestments - totalCreditUsed;

    // Determine color based on positive/negative
    final netWorthColor = totalNetWorth >= 0 ? SemanticColors.primary : Colors.red;

    return Container(
      padding: EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            netWorthColor.withOpacity(0.12),
            netWorthColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: netWorthColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Net Worth',
            style: TextStyle(
              fontSize: 14,
              color: AppStyles.getSecondaryTextColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: Spacing.md),
          Text(
            '₹${totalNetWorth.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: netWorthColor,
            ),
          ),
          SizedBox(height: Spacing.xl),

          // Breakdown
          Container(
            padding: EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Savings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Savings',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${totalSavings.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Spacing.sm),

                // Investments
                if (totalInvestments > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Investments',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${totalInvestments.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                // Credit Limit (informational)
                if (totalCreditLimit > 0) ...[
                  SizedBox(height: Spacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Credit Limit',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${totalCreditLimit.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ],

                // Credit Used (liability)
                if (totalCreditUsed > 0) ...[
                  SizedBox(height: Spacing.sm),
                  Divider(height: 1),
                  SizedBox(height: Spacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Credit Used',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${totalCreditUsed.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountsSection(
    BuildContext context,
    AccountsController accountsController,
  ) {
    // Filter for regular bank accounts only (exclude investment, credit, and BNPL accounts)
    final bankAccounts = accountsController.accounts
        .where((a) => a.type != AccountType.investment &&
                      a.type != AccountType.credit &&
                      a.type != AccountType.payLater)
        .toList();

    if (bankAccounts.isEmpty) {
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
    for (var account in bankAccounts) {
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
                        '${bankAccounts.length} account${bankAccounts.length != 1 ? 's' : ''}',
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
              children: bankAccounts
                  .asMap()
                  .entries
                  .map((entry) {
                    final isLast = entry.key == bankAccounts.length - 1;
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

  Widget _buildDematAccountsSection(
    BuildContext context,
    AccountsController accountsController,
  ) {
    // Filter for investment/demat accounts only
    final dematAccounts = accountsController.accounts
        .where((a) => a.type == AccountType.investment)
        .toList();

    if (dematAccounts.isEmpty) {
      return SizedBox.shrink();
    }

    double total = 0;
    for (var account in dematAccounts) {
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
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.chart_bar_fill, size: 20, color: Colors.orange),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demat / Investment Accounts',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${dematAccounts.length} account${dematAccounts.length != 1 ? 's' : ''}',
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
              children: dematAccounts
                  .asMap()
                  .entries
                  .map((entry) {
                    final isLast = entry.key == dematAccounts.length - 1;
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

  Widget _buildCreditLiabilitiesSection(
    BuildContext context,
    AccountsController accountsController,
  ) {
    // Filter for credit cards and BNPL accounts
    final creditAccounts = accountsController.accounts
        .where((a) => a.type == AccountType.credit || a.type == AccountType.payLater)
        .toList();

    if (creditAccounts.isEmpty) {
      return SizedBox.shrink();
    }

    double totalCreditLimit = 0;
    double totalUsed = 0;
    for (var account in creditAccounts) {
      totalCreditLimit += (account.creditLimit ?? 0.0);
      totalUsed += ((account.creditLimit ?? 0.0) - account.balance);
    }
    final totalAvailable = totalCreditLimit - totalUsed;

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
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.creditcard_fill, size: 20, color: Colors.red),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit & BNPL Liabilities',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${creditAccounts.length} account${creditAccounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${totalUsed.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
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
              children: creditAccounts
                  .asMap()
                  .entries
                  .map((entry) {
                    final isLast = entry.key == creditAccounts.length - 1;
                    final account = entry.value;
                    final used = (account.creditLimit ?? 0.0) - account.balance;
                    final available = account.balance;
                    final utilization = (account.creditLimit ?? 0.0) > 0
                        ? (used / (account.creditLimit ?? 1.0) * 100)
                        : 0.0;

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
                          ],
                        ),
                        SizedBox(height: Spacing.md),
                        // Credit details row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Limit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.getSecondaryTextColor(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '₹${(account.creditLimit ?? 0.0).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Used',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '₹${used.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Available',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '₹${available.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Spacing.md),
                        // Utilization progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: utilization / 100,
                            minHeight: 6,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              utilization > 80 ? Colors.red : Colors.orange,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Utilization',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                            Text(
                              '${utilization.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: utilization > 80 ? Colors.red : Colors.orange,
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
