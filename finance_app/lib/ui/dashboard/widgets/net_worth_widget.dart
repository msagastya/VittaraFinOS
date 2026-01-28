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
        for (var account in accountsController.accounts) {
          totalAccounts += account.balance;
        }

        double totalInvestments = 0;
        for (var investment in investmentsController.investments) {
          totalInvestments += investment.amount;
        }

        final totalNetWorth = totalAccounts + totalInvestments;

        // Determine layout based on size
        bool showCompact = columnSpan == 1;
        bool showBreakdown = rowSpan > 1 || columnSpan > 1;

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main amount
            Text(
              '₹${totalNetWorth.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: showCompact ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: AppStyles.getPrimaryColor(context),
              ),
            ),
            if (showCompact)
              SizedBox(height: 8)
            else
              SizedBox(height: Spacing.md),

            // Breakdown (if space allows)
            if (showBreakdown)
              Container(
                padding: EdgeInsets.all(showCompact ? 8 : 12),
                decoration: BoxDecoration(
                  color: AppStyles.getBackground(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBreakdownItem(
                      context,
                      'Accounts',
                      totalAccounts,
                      CupertinoIcons.creditcard_fill,
                      Colors.blue,
                      compact: showCompact,
                    ),
                    SizedBox(height: showCompact ? 6 : Spacing.sm),
                    _buildBreakdownItem(
                      context,
                      'Investments',
                      totalInvestments,
                      CupertinoIcons.chart_bar_fill,
                      Colors.green,
                      compact: showCompact,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
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
