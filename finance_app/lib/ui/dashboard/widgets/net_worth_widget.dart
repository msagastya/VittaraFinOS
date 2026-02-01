import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class NetWorthWidget extends BaseDashboardWidget {
  const NetWorthWidget({
    required DashboardWidgetConfig config,
    VoidCallback? onTap,
    super.key,
  }) : super(config: config, onTap: onTap);

  @override
  Widget buildHeader(BuildContext context, {bool compact = false}) {
    return Row(
      children: [
        Icon(
          CupertinoIcons.chart_bar_fill,
          size: compact ? 16 : 18,
          color: AppStyles.getPrimaryColor(context),
        ),
        SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            config.title,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: AppStyles.getTextColor(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget buildContent(
    BuildContext context, {
    required int columnSpan,
    required int rowSpan,
    required double width,
    required double height,
  }) {
    return Consumer2<AccountsController, InvestmentsController>(
      builder: (context, accountsController, investmentsController, child) {
        // Calculate totals
        double totalAccounts = 0;
        int accountCount = 0;
        for (var account in accountsController.accounts) {
          totalAccounts += account.balance;
          accountCount++;
        }

        double totalInvestments = 0;
        int investmentCount = 0;
        for (var investment in investmentsController.investments) {
          totalInvestments += investment.amount;
          investmentCount++;
        }

        final totalNetWorth = totalAccounts + totalInvestments;
        final investmentPercentage = totalNetWorth > 0 ? (totalInvestments / totalNetWorth * 100).toDouble() : 0.0;
        final accountPercentage = totalNetWorth > 0 ? (totalAccounts / totalNetWorth * 100).toDouble() : 0.0;

        // Determine layout based on size
        bool showCompact = columnSpan == 1;
        bool showBreakdown = rowSpan > 1 || columnSpan > 1;

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main amount with gradient effect
            Container(
              padding: EdgeInsets.all(showCompact ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppStyles.getPrimaryColor(context).withOpacity(0.1),
                    AppStyles.getPrimaryColor(context).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppStyles.getPrimaryColor(context).withOpacity(0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Net Worth',
                    style: TextStyle(
                      fontSize: showCompact ? 12 : 13,
                      color: AppStyles.getSecondaryTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: showCompact ? 6 : Spacing.sm),
                  Text(
                    '₹${totalNetWorth.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: showCompact ? 20 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),

            if (showCompact)
              SizedBox(height: Spacing.sm)
            else
              SizedBox(height: Spacing.lg),

            // Breakdown (if space allows)
            if (showBreakdown)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Accounts Section
                  _buildDetailedBreakdownItem(
                    context,
                    'Bank Accounts',
                    totalAccounts,
                    accountCount,
                    CupertinoIcons.creditcard_fill,
                    Colors.blue,
                    percentage: accountPercentage,
                    compact: showCompact,
                  ),
                  SizedBox(height: showCompact ? 12 : Spacing.md),

                  // Investments Section
                  _buildDetailedBreakdownItem(
                    context,
                    'Investments',
                    totalInvestments,
                    investmentCount,
                    CupertinoIcons.chart_bar_fill,
                    Colors.green,
                    percentage: investmentPercentage,
                    compact: showCompact,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetailedBreakdownItem(
    BuildContext context,
    String label,
    double amount,
    int count,
    IconData icon,
    Color color, {
    double percentage = 0,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: compact ? 14 : 16,
                  color: color,
                ),
              ),
              SizedBox(width: compact ? 8 : Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!compact)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '$count item${count != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppStyles.getSecondaryTextColor(context).withOpacity(0.7),
                          ),
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
                    '₹${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (!compact)
            Padding(
              padding: EdgeInsets.only(top: Spacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 6,
                  backgroundColor: AppStyles.getBackground(context),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color, {
    bool compact = false,
  }) {
    if (compact) {
      // Vertical layout
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppStyles.getSecondaryTextColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppStyles.getTextColor(context),
            ),
          ),
        ],
      );
    }

    // Horizontal layout
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: Spacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppStyles.getSecondaryTextColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppStyles.getTextColor(context),
          ),
        ),
      ],
    );
  }
}
