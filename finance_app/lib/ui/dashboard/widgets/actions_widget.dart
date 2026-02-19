import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class ActionsWidget extends BaseDashboardWidget {
  const ActionsWidget({
    required super.config,
    super.onTap,
    super.key,
  });

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
      (
        'Request Money',
        'Quick',
        CupertinoIcons.arrow_down_circle_fill,
        Colors.green
      ),
      ('View All', 'More', CupertinoIcons.ellipsis, Colors.orange),
    ].take(actionCount).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: actions.asMap().entries.map((entry) {
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
      }).toList(),
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
      // Vertical layout for compact - Enhanced with better styling
      return Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Horizontal layout for medium/full - Enhanced
    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.03),
          ],
        ),
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container with gradient
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: Spacing.md),

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Arrow indicator
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: color.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
