import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/dashboard_controller.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class DashboardSettingsModal extends StatefulWidget {
  const DashboardSettingsModal({super.key});

  @override
  State<DashboardSettingsModal> createState() => _DashboardSettingsModalState();
}

class _DashboardSettingsModalState extends State<DashboardSettingsModal> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Dashboard Settings'),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        trailing: Consumer<DashboardController>(
          builder: (context, dashboardController, child) {
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await dashboardController.saveConfig();
                if (context.mounted) {
                  toast.showSuccess('Settings saved!');
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppStyles.aetherTeal,
                ),
              ),
            );
          },
        ),
        border: null,
      ),
      child: SafeArea(
        child: Consumer<DashboardController>(
          builder: (context, dashboardController, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Widget Visibility',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Show or hide widgets on your dashboard',
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // Widget toggles
                  ...dashboardController.config.widgets.map((widget) {
                    return _buildWidgetToggle(
                        context, dashboardController, widget);
                  }),

                  const SizedBox(height: Spacing.xl),

                  // Reset button
                  CupertinoButton(
                    onPressed: () {
                      showCupertinoDialog(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('Reset Dashboard?'),
                          content: const Text(
                            'This will restore the default dashboard layout and widget settings.',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('Reset'),
                              onPressed: () async {
                                await dashboardController.resetToDefault();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  toast.showInfo('Dashboard reset to default');
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.refresh,
                          size: 16,
                          color: AppStyles.aetherTeal,
                        ),
                        SizedBox(width: Spacing.sm),
                        Text(
                          'Reset to Default',
                          style: TextStyle(
                            color: AppStyles.aetherTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWidgetToggle(
    BuildContext context,
    DashboardController controller,
    DashboardWidgetConfig widget,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: TypeScale.body,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  _getWidgetDescription(widget.type),
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          CupertinoSwitch(
            value: widget.isVisible,
            onChanged: (value) {
              controller.toggleWidgetVisibility(widget.id);
            },
          ),
        ],
      ),
    );
  }

  String _getWidgetDescription(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.actions:
        return 'Quick action buttons';
      case DashboardWidgetType.netWorth:
        return 'Your total net worth & breakdown';
      case DashboardWidgetType.transactionHistory:
        return 'Recent transactions';
      case DashboardWidgetType.notificationsAndActions:
        return 'Notifications and actions';
      case DashboardWidgetType.goalsOverview:
        return 'Track your goals progress';
      case DashboardWidgetType.budgetsOverview:
        return 'Monitor budget health';
      case DashboardWidgetType.savingsPlanners:
        return 'View savings planner progress';
      case DashboardWidgetType.aiPlanner:
        return 'Launch the AI monthly planner';
      case DashboardWidgetType.sipTracker:
        return 'Active SIPs with next due dates & amounts';
      default:
        return '';
    }
  }
}
