import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  bool _expandInvestments = false;
  List<_NetWorthSnapshot> _historySnapshots = [];
  bool _snapshotSavedThisSession = false;

  @override
  void initState() {
    super.initState();
    _loadNetWorthHistory();
  }

  Future<void> _loadNetWorthHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('nw_history_'))
        .toList()
      ..sort();
    final snapshots = <_NetWorthSnapshot>[];
    for (final key in keys) {
      final value = prefs.getDouble(key);
      if (value == null) continue;
      // key format: nw_history_YYYY_MM
      final datePart = key.substring('nw_history_'.length);
      final parts = datePart.split('_');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null) {
          snapshots.add(
              _NetWorthSnapshot(date: DateTime(year, month), value: value));
        }
      }
    }
    // Keep last 12 months
    final trimmed = snapshots.length > 12
        ? snapshots.sublist(snapshots.length - 12)
        : snapshots;
    if (mounted) setState(() => _historySnapshots = trimmed);
  }

  void _maybeSaveSnapshot(double netWorth) {
    if (_snapshotSavedThisSession) return;
    _snapshotSavedThisSession = true;
    final now = DateTime.now();
    final key =
        'nw_history_${now.year}_${now.month.toString().padLeft(2, '0')}';
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(key, netWorth);
      _loadNetWorthHistory();
    });
  }

  double _calculateNetWorth(AccountsController ac, InvestmentsController ic) {
    double savings = 0;
    for (final a in ac.accounts) {
      if (a.type != AccountType.credit && a.type != AccountType.payLater) {
        savings += a.balance;
      }
    }
    double investments = 0;
    for (final inv in ic.investments) {
      final metadata = inv.metadata ?? {};
      final cv = (metadata['currentValue'] as num?)?.toDouble();
      investments += cv ?? inv.amount;
    }
    double creditUsed = 0;
    for (final a in ac.accounts) {
      if (a.type == AccountType.credit || a.type == AccountType.payLater) {
        creditUsed += (a.creditLimit ?? 0.0) - a.balance;
      }
    }
    return savings + investments - creditUsed;
  }

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
            // Show skeleton while data is loading from storage
            if (!accountsController.isLoaded ||
                !investmentsController.isLoaded) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(Spacing.lg),
                child: Column(
                  children: [
                    const SkeletonSummaryCard(),
                    SizedBox(height: Spacing.xl),
                    const SkeletonListView(itemCount: 4),
                  ],
                ),
              );
            }

            // Empty state — no data yet
            if (accountsController.accounts.isEmpty &&
                investmentsController.investments.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(Spacing.xxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.chart_pie_fill,
                        size: 72,
                        color: SemanticColors.primary.withValues(alpha: 0.3),
                      ),
                      SizedBox(height: Spacing.xl),
                      Text(
                        'Your Net Worth Awaits',
                        style: TextStyle(
                          fontSize: TypeScale.title1,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: Spacing.md),
                      Text(
                        'Add your first account or investment to see your net worth here.',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: Spacing.xxl),
                      CupertinoButton.filled(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go to Manage'),
                      ),
                    ],
                  ),
                ),
              );
            }

            try {
              final totalNetWorth =
                  _calculateNetWorth(accountsController, investmentsController);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _maybeSaveSnapshot(totalNetWorth);
              });

              return SingleChildScrollView(
                padding: EdgeInsets.all(Spacing.lg),
                child: Column(
                  children: [
                    _buildTotalNetWorthCard(
                        context, accountsController, investmentsController),
                    if (_historySnapshots.length >= 2) ...[
                      SizedBox(height: Spacing.xl),
                      _buildNetWorthTrendCard(context),
                    ],
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
                      color: CupertinoColors.systemRed.withValues(alpha: 0.7),
                    ),
                    SizedBox(height: Spacing.lg),
                    Text(
                      'Error Loading Net Worth',
                      style: TextStyle(
                        fontSize: TypeScale.headline,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    SizedBox(height: Spacing.md),
                    Text(
                      e.toString(),
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
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
      if (account.type != AccountType.credit &&
          account.type != AccountType.payLater) {
        totalSavings += account.balance;
      }
    }

    // Calculate Total Investment
    double totalInvestments = 0;
    for (var investment in investmentsController.investments) {
      final metadata = investment.metadata ?? {};
      final currentValue = (metadata['currentValue'] as num?)?.toDouble();
      totalInvestments += currentValue ?? investment.amount;
    }

    // Calculate Total Credit Limit
    double totalCreditLimit = 0;
    double totalCreditUsed = 0;
    for (var account in accountsController.accounts) {
      if (account.type == AccountType.credit ||
          account.type == AccountType.payLater) {
        totalCreditLimit += (account.creditLimit ?? 0.0);
        final used = (account.creditLimit ?? 0.0) - account.balance;
        totalCreditUsed += used;
      }
    }

    // Net Worth = Savings + Investment - Credit Used
    final totalNetWorth = totalSavings + totalInvestments - totalCreditUsed;

    // Determine color based on positive/negative
    final netWorthColor =
        totalNetWorth >= 0 ? SemanticColors.primary : CupertinoColors.systemRed;

    return Container(
      padding: EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            netWorthColor.withValues(alpha: 0.12),
            netWorthColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: netWorthColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Net Worth',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: Spacing.md),
          Text(
            CurrencyFormatter.compact(totalNetWorth, decimals: 2),
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
              border: Border.all(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
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
                        fontSize: TypeScale.subhead,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.compact(totalSavings),
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGreen,
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
                          fontSize: TypeScale.subhead,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.compact(totalInvestments),
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.activeBlue,
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
                          fontSize: TypeScale.subhead,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.compact(totalCreditLimit),
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
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
                          fontSize: TypeScale.subhead,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.compact(totalCreditUsed),
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemRed,
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
        .where((a) =>
            a.type != AccountType.investment &&
            a.type != AccountType.credit &&
            a.type != AccountType.payLater)
        .toList();

    if (bankAccounts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            'No bank accounts added',
            style: TextStyle(
              fontSize: TypeScale.subhead,
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
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
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
                    color: CupertinoColors.activeBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.creditcard_fill,
                      size: 20, color: CupertinoColors.activeBlue),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Accounts',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${bankAccounts.length} account${bankAccounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: TypeScale.callout,
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
              children: bankAccounts.asMap().entries.map((entry) {
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
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                account.bankName,
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${account.balance.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
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
              }).toList(),
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
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
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
                    color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.chart_bar_fill,
                      size: 20, color: CupertinoColors.systemOrange),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demat / Investment Accounts',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${dematAccounts.length} account${dematAccounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: TypeScale.callout,
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
              children: dematAccounts.asMap().entries.map((entry) {
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
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                account.bankName,
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${account.balance.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
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
              }).toList(),
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
        .where((a) =>
            a.type == AccountType.credit || a.type == AccountType.payLater)
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
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
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
                    color: CupertinoColors.systemRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.creditcard_fill,
                      size: 20, color: CupertinoColors.systemRed),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit & BNPL Liabilities',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${creditAccounts.length} account${creditAccounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${totalUsed.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: TypeScale.callout,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.systemRed,
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
              children: creditAccounts.asMap().entries.map((entry) {
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
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                account.bankName,
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
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
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: Spacing.xs),
                              Text(
                                '₹${(account.creditLimit ?? 0.0).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
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
                                  fontSize: TypeScale.caption,
                                  color: CupertinoColors.systemRed,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: Spacing.xs),
                              Text(
                                '₹${used.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.systemRed,
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
                                  fontSize: TypeScale.caption,
                                  color: CupertinoColors.systemGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: Spacing.xs),
                              Text(
                                '₹${available.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.systemGreen,
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
                        backgroundColor:
                            CupertinoColors.systemGrey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          utilization > 80
                              ? CupertinoColors.systemRed
                              : CupertinoColors.systemOrange,
                        ),
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
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
                            color: utilization > 80
                                ? CupertinoColors.systemRed
                                : CupertinoColors.systemOrange,
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
              }).toList(),
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
          border: Border.all(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            'No investments yet',
            style: TextStyle(
              fontSize: TypeScale.subhead,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ),
      );
    }

    // Group by type
    final investmentsByType = <String, List<Investment>>{};
    double totalInvested = 0;
    double totalCurrent = 0;

    for (var inv in investmentsController.investments) {
      final type = inv.type.toString().split('.').last;
      if (!investmentsByType.containsKey(type)) {
        investmentsByType[type] = [];
      }
      investmentsByType[type]!.add(inv);
      totalInvested += inv.amount;
      totalCurrent += _currentValueForInvestment(inv);
    }

    // Sort by total amount
    final sortedEntries = investmentsByType.entries.toList();
    sortedEntries.sort((a, b) {
      double totalA = 0, totalB = 0;
      for (var inv in a.value) {
        totalA += inv.amount;
      }
      for (var inv in b.value) {
        totalB += inv.amount;
      }
      return totalB.compareTo(totalA);
    });

    final displayEntries =
        _expandInvestments ? sortedEntries : sortedEntries.take(3).toList();
    final hasMore = sortedEntries.length > 3;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
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
                    color: CupertinoColors.systemGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.chart_bar_fill,
                      size: 20, color: CupertinoColors.systemGreen),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Investments',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${investmentsByType.length} type${investmentsByType.length != 1 ? 's' : ''} • ${investmentsController.investments.length} total',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
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
                      '₹${totalCurrent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Invested ₹${totalInvested.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
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
                ...displayEntries.asMap().entries.map((entry) {
                  final isLast = entry.key == displayEntries.length - 1;
                  final type = entry.value.key;
                  final investments = entry.value.value;

                  double typeInvested = 0;
                  double typeCurrent = 0;
                  for (var inv in investments) {
                    typeInvested += inv.amount;
                    typeCurrent += _currentValueForInvestment(inv);
                  }
                  final percentage = totalCurrent > 0
                      ? (typeCurrent / totalCurrent * 100)
                      : 0.0;

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
                                    fontSize: TypeScale.subhead,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                                Text(
                                  '${investments.length} item${investments.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Current ₹${typeCurrent.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                'Invested ₹${typeInvested.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: CupertinoColors.systemGreen,
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
                }),
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
                              fontSize: TypeScale.subhead,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemGreen,
                            ),
                          ),
                          SizedBox(width: Spacing.xs),
                          Icon(
                            _expandInvestments
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            size: 14,
                            color: CupertinoColors.systemGreen,
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

  Widget _buildNetWorthTrendCard(BuildContext context) {
    final snapshots = _historySnapshots;
    final first = snapshots.first.value;
    final last = snapshots.last.value;
    final change = last - first;
    final changePct = first != 0 ? (change / first.abs()) * 100 : 0.0;
    final isPositive = change >= 0;
    final trendColor =
        isPositive ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
    final monthCount = snapshots.length;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Worth Trend',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? CupertinoIcons.arrow_up_right
                          : CupertinoIcons.arrow_down_right,
                      size: 12,
                      color: trendColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${changePct.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.xs),
          Text(
            'Last $monthCount month${monthCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          SizedBox(height: Spacing.lg),
          // Sparkline chart
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _NetWorthSparklinePainter(
                snapshots: snapshots,
                lineColor: trendColor,
                gridColor: AppStyles.getSecondaryTextColor(context),
              ),
              size: Size.infinite,
            ),
          ),
          SizedBox(height: Spacing.sm),
          // X-axis month labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                months[snapshots.first.date.month - 1],
                style: TextStyle(
                  fontSize: 10,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              if (monthCount > 2)
                Text(
                  months[snapshots[monthCount ~/ 2].date.month - 1],
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              Text(
                months[snapshots.last.date.month - 1],
                style: TextStyle(
                  fontSize: 10,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _currentValueForInvestment(Investment investment) {
    final metadata = investment.metadata ?? {};
    final currentValue = (metadata['currentValue'] as num?)?.toDouble();
    if (currentValue != null && currentValue > 0) return currentValue;
    final units = (metadata['units'] as num?)?.toDouble();
    final currentNav = (metadata['currentNAV'] as num?)?.toDouble();
    if (units != null && currentNav != null) return units * currentNav;
    final pricePerUnit = (metadata['pricePerShare'] as num?)?.toDouble();
    final quantity = (metadata['qty'] as num?)?.toDouble();
    if (pricePerUnit != null && quantity != null) {
      return pricePerUnit * quantity;
    }
    return investment.amount;
  }
}

// ---------------------------------------------------------------------------
// Net Worth History data model
// ---------------------------------------------------------------------------

class _NetWorthSnapshot {
  final DateTime date;
  final double value;
  const _NetWorthSnapshot({required this.date, required this.value});
}

// ---------------------------------------------------------------------------
// Sparkline painter for net worth trend chart
// ---------------------------------------------------------------------------

class _NetWorthSparklinePainter extends CustomPainter {
  final List<_NetWorthSnapshot> snapshots;
  final Color lineColor;
  final Color gridColor;

  const _NetWorthSparklinePainter({
    required this.snapshots,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.length < 2) return;

    const leftPad = 4.0;
    const rightPad = 4.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final values = snapshots.map((s) => s.value).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs();
    final adjustedMin = range == 0 ? minV - 1 : minV;
    final adjustedMax = range == 0 ? maxV + 1 : maxV;
    final adjustedRange = adjustedMax - adjustedMin;

    double xOf(int i) => leftPad + (i / (snapshots.length - 1)) * w;
    double yOf(double v) =>
        topPad + h - ((v - adjustedMin) / adjustedRange * h);

    // Draw horizontal grid lines (3 lines)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 2; i++) {
      final y = topPad + (i / 2) * h;
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + w, y), gridPaint);
    }

    // Build path for line
    final path = Path();
    for (int i = 0; i < snapshots.length; i++) {
      final x = xOf(i);
      final y = yOf(snapshots[i].value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient fill below the line
    final fillPath = Path.from(path);
    fillPath.lineTo(xOf(snapshots.length - 1), topPad + h);
    fillPath.lineTo(leftPad, topPad + h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.20),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw dots at each point
    final dotPaint = Paint()..color = lineColor;
    final dotRadius = snapshots.length <= 6 ? 3.5 : 2.5;
    for (int i = 0; i < snapshots.length; i++) {
      canvas.drawCircle(
          Offset(xOf(i), yOf(snapshots[i].value)), dotRadius, dotPaint);
    }

    // Highlight last point
    final lastX = xOf(snapshots.length - 1);
    final lastY = yOf(snapshots.last.value);
    canvas.drawCircle(
      Offset(lastX, lastY),
      5.0,
      Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(lastX, lastY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _NetWorthSparklinePainter old) =>
      old.snapshots != snapshots || old.lineColor != lineColor;
}
