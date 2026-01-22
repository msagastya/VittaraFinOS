import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ============================================================
// SHIMMER LOADING TEMPLATES - VittaraFinOS
// ============================================================
// Pre-built shimmer skeletons for consistent loading states
// across the application.
// ============================================================

/// Base shimmer wrapper with theme-aware colors
class ShimmerWrapper extends StatelessWidget {
  final Widget child;

  const ShimmerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: child,
    );
  }
}

/// Basic shimmer box - building block for all templates
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(Radii.sm),
      ),
    );
  }
}

/// Shimmer skeleton for list card items
class ShimmerListCard extends StatelessWidget {
  final bool showTrailing;
  final double height;

  const ShimmerListCard({
    super.key,
    this.showTrailing = true,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        height: height,
        margin: EdgeInsets.only(bottom: Spacing.lg),
        padding: Spacing.cardPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.cardRadius,
        ),
        child: Row(
          children: [
            // Icon placeholder
            ShimmerBox(
              width: ComponentSizes.iconBoxMedium,
              height: ComponentSizes.iconBoxMedium,
              borderRadius: Radii.iconBoxRadius,
            ),
            SizedBox(width: Spacing.lg),
            // Content placeholder
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 16),
                  SizedBox(height: Spacing.sm),
                  ShimmerBox(width: 80, height: 12),
                ],
              ),
            ),
            if (showTrailing) ...[
              SizedBox(width: Spacing.lg),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShimmerBox(width: 60, height: 16),
                  SizedBox(height: Spacing.sm),
                  ShimmerBox(width: 20, height: 12),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for summary cards
class ShimmerSummaryCard extends StatelessWidget {
  final double height;

  const ShimmerSummaryCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        height: height,
        padding: Spacing.cardPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 100, height: 14),
            SizedBox(height: Spacing.md),
            ShimmerBox(width: 150, height: 32),
            const Spacer(),
            ShimmerBox(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for grid items (categories, etc.)
class ShimmerGridItem extends StatelessWidget {
  final double size;

  const ShimmerGridItem({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerBox(
              width: 50,
              height: 50,
              borderRadius: BorderRadius.circular(25),
            ),
            SizedBox(height: Spacing.sm),
            ShimmerBox(width: 60, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for settings rows
class ShimmerSettingsRow extends StatelessWidget {
  const ShimmerSettingsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        padding: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.cardRadius,
        ),
        child: Row(
          children: [
            ShimmerBox(
              width: ComponentSizes.iconBoxMedium,
              height: ComponentSizes.iconBoxMedium,
              borderRadius: Radii.iconBoxRadius,
            ),
            SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 16),
                  SizedBox(height: Spacing.xs),
                  ShimmerBox(width: 200, height: 12),
                ],
              ),
            ),
            ShimmerBox(
              width: 50,
              height: 30,
              borderRadius: BorderRadius.circular(15),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer for search bar
class ShimmerSearchBar extends StatelessWidget {
  const ShimmerSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        height: 44,
        margin: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.buttonRadius,
        ),
      ),
    );
  }
}

/// Shimmer for option cards (selection screens)
class ShimmerOptionCard extends StatelessWidget {
  final double height;

  const ShimmerOptionCard({super.key, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.cardRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerBox(
              width: 64,
              height: 64,
              borderRadius: BorderRadius.circular(32),
            ),
            SizedBox(height: Spacing.lg),
            ShimmerBox(width: 80, height: 16),
          ],
        ),
      ),
    );
  }
}

/// Shimmer for wizard step indicator
class ShimmerStepIndicator extends StatelessWidget {
  final int steps;

  const ShimmerStepIndicator({super.key, this.steps = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          steps,
          (index) => Container(
            margin: EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: ShimmerBox(
              width: index == 0 ? 24 : 8,
              height: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer for text lines (paragraphs)
class ShimmerTextLines extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;

  const ShimmerTextLines({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          lines,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index < lines - 1 ? spacing : 0),
            child: ShimmerBox(
              width: index == lines - 1 ? 150 : double.infinity,
              height: lineHeight,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer for avatar with name
class ShimmerAvatarWithName extends StatelessWidget {
  final double avatarSize;

  const ShimmerAvatarWithName({super.key, this.avatarSize = 44});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Row(
        children: [
          ShimmerBox(
            width: avatarSize,
            height: avatarSize,
            borderRadius: BorderRadius.circular(avatarSize / 2),
          ),
          SizedBox(width: Spacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 100, height: 16),
              SizedBox(height: Spacing.xs),
              ShimmerBox(width: 140, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full screen shimmer for list screens
class ShimmerListScreen extends StatelessWidget {
  final bool showSummaryCard;
  final bool showSearchBar;
  final int itemCount;

  const ShimmerListScreen({
    super.key,
    this.showSummaryCard = false,
    this.showSearchBar = false,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          if (showSearchBar) const ShimmerSearchBar(),
          if (showSummaryCard)
            Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: const ShimmerSummaryCard(),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
              itemCount: itemCount,
              itemBuilder: (context, index) => const ShimmerListCard(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full screen shimmer for grid screens
class ShimmerGridScreen extends StatelessWidget {
  final bool showSearchBar;
  final int itemCount;
  final int crossAxisCount;

  const ShimmerGridScreen({
    super.key,
    this.showSearchBar = true,
    this.itemCount = 9,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          if (showSearchBar) const ShimmerSearchBar(),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(Spacing.lg),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: Spacing.md,
                mainAxisSpacing: Spacing.md,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) => const ShimmerGridItem(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading indicator for buttons
class ShimmerButton extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerButton({
    super.key,
    this.width = double.infinity,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: ShimmerBox(
        width: width,
        height: height,
        borderRadius: Radii.buttonRadius,
      ),
    );
  }
}

/// Shimmer for investment card with progress
class ShimmerInvestmentCard extends StatelessWidget {
  const ShimmerInvestmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        margin: EdgeInsets.only(bottom: Spacing.lg),
        padding: Spacing.cardPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(
                  width: ComponentSizes.iconBoxMedium,
                  height: ComponentSizes.iconBoxMedium,
                  borderRadius: Radii.iconBoxRadius,
                ),
                SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 120, height: 16),
                      SizedBox(height: Spacing.sm),
                      ShimmerBox(width: 80, height: 12),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShimmerBox(width: 70, height: 16),
                    SizedBox(height: Spacing.sm),
                    ShimmerBox(width: 40, height: 12),
                  ],
                ),
              ],
            ),
            SizedBox(height: Spacing.lg),
            ShimmerBox(
              width: double.infinity,
              height: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}
