import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';

/// Base class for all dashboard widgets
/// Adapts content based on columnSpan (1-3) and rowSpan (1+)
abstract class BaseDashboardWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final VoidCallback? onTap;

  /// When true the widget body is replaced with a shimmering skeleton.
  final bool isLoading;

  const BaseDashboardWidget({
    required this.config,
    this.onTap,
    this.isLoading = false,
    super.key,
  });

  /// Build widget content based on available space
  /// Override this in child classes
  Widget buildContent(
    BuildContext context, {
    required int columnSpan,
    required int rowSpan,
    required double width,
    required double height,
  });

  /// Build header/title
  Widget buildHeader(BuildContext context, {bool compact = false}) {
    return Text(
      config.title,
      style: TextStyle(
        fontSize: compact ? 14 : 16,
        fontWeight: FontWeight.bold,
        color: AppStyles.getTextColor(context),
      ),
    );
  }

  /// Get layout mode based on size
  String getLayoutMode() {
    if (config.columnSpan == 1) return 'compact';
    if (config.columnSpan == 2) return 'medium';
    return 'full'; // 3 columns
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    buildHeader(
                      context,
                      compact: config.columnSpan == 1,
                    ),
                    SizedBox(height: config.columnSpan == 1 ? 8 : 12),
                    // Content — show skeleton while loading
                    Expanded(
                      child: isLoading
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonLoader(height: 28, width: 140),
                                const SizedBox(height: 10),
                                SkeletonLoader(height: 12, width: 100),
                                const SizedBox(height: 10),
                                SkeletonLoader(
                                    height: 12, width: double.infinity),
                              ],
                            )
                          : SingleChildScrollView(
                              child: buildContent(
                                context,
                                columnSpan: config.columnSpan,
                                rowSpan: config.rowSpan,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              // Tap indicator
              if (onTap != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    CupertinoIcons.arrow_up_right_circle,
                    size: 14,
                    color: AppStyles.getPrimaryColor(context)
                        .withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
