import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class ActionsWidget extends BaseDashboardWidget {
  const ActionsWidget({
    required DashboardWidgetConfig config,
    VoidCallback? onTap,
    super.key,
  }) : super(config: config, onTap: onTap);

  @override
  Widget buildHeader(BuildContext context, {bool compact = false}) {
    return Row(
      children: [
        Icon(
          CupertinoIcons.bolt_fill,
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
    // Compact (1 col): Show 1 action
    // Medium (2 cols): Show 2 actions
    // Full (3 cols): Show 3 actions or more if rows allow

    int actionCount = columnSpan;
    if (rowSpan > 1) actionCount = columnSpan * rowSpan;

    final actions = [
      ('Send Payment', '₹0', CupertinoIcons.paperplane_fill, Colors.blue),
      ('Request Money', 'Quick', CupertinoIcons.arrow_down_circle_fill, Colors.green),
      ('View All', 'More', CupertinoIcons.ellipsis, Colors.orange),
    ].take(actionCount).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .asMap()
          .entries
          .map((entry) {
            final isLast = entry.key == actions.length - 1;
            return Column(
              children: [
                _buildActionItem(
                  context,
                  entry.value.$1,
                  entry.value.$2,
                  entry.value.$3,
                  entry.value.$4,
                  compact: columnSpan == 1,
                ),
                if (!isLast) SizedBox(height: columnSpan == 1 ? 8 : 12),
              ],
            );
          })
          .toList(),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool compact = false,
  }) {
    if (compact) {
      // Vertical layout for compact
      return Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppStyles.getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Horizontal layout for medium/full
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
