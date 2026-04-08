import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdaptiveSplitView
//
// On phones: shows only the [body] widget (sidebar accessible via push nav).
// On tablets / fold inner: shows [sidebar] (left, fixed width) + [body] (right,
// expanded) side-by-side with a thin divider between them.
//
// Usage:
//   AdaptiveSplitView(
//     sidebar: MyListWidget(),
//     body: MyDetailWidget(),
//   )
//
// The [sidebarWidth] defaults to 300 on tablet and 260 on fold inner.
// ─────────────────────────────────────────────────────────────────────────────

class AdaptiveSplitView extends StatelessWidget {
  /// The navigation list / master panel shown on the left on large screens.
  final Widget sidebar;

  /// The main content / detail panel. Shown full-screen on phones.
  final Widget body;

  /// Optional fixed width for the sidebar (tablet). Defaults are applied if null.
  final double? sidebarWidth;

  /// Color of the divider between panels. Defaults to theme divider color.
  final Color? dividerColor;

  const AdaptiveSplitView({
    super.key,
    required this.sidebar,
    required this.body,
    this.sidebarWidth,
    this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isTabletOrLarger(context)) {
      // Phone — just show the body
      return body;
    }

    final isFold = Breakpoints.isFoldInner(context);
    final panelWidth = sidebarWidth ?? (isFold ? 260.0 : 300.0);
    final divColor = dividerColor ??
        Theme.of(context).dividerColor.withValues(alpha: 0.3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar panel
        SizedBox(
          width: panelWidth,
          child: sidebar,
        ),
        // Vertical divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: divColor,
        ),
        // Body panel
        Expanded(child: body),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AdaptiveSidebarItem — used inside the sidebar for consistent item styling
// ─────────────────────────────────────────────────────────────────────────────

class AdaptiveSidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const AdaptiveSidebarItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = selected
        ? color.withValues(alpha: isDark ? 0.18 : 0.12)
        : Colors.transparent;
    final textColor = selected
        ? color
        : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: RT.callout(context),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: RT.caption(context),
                        color: (isDark ? Colors.white54 : Colors.black54),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
