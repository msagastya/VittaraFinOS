import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show Share;

import 'package:vittara_fin_os/logic/engagement_service.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';

// ---------------------------------------------------------------------------
// Achievement Unlock Overlay — shown full-screen on unlock
// ---------------------------------------------------------------------------

class AchievementUnlockOverlay extends StatefulWidget {
  final String achievementId;
  final VoidCallback onDismiss;

  const AchievementUnlockOverlay({
    super.key,
    required this.achievementId,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, String achievementId) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim, _) => AchievementUnlockOverlay(
        achievementId: achievementId,
        onDismiss: () => Navigator.of(ctx, rootNavigator: true).pop(),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curve, child: child),
        );
      },
    );
  }

  @override
  State<AchievementUnlockOverlay> createState() =>
      _AchievementUnlockOverlayState();
}

class _AchievementUnlockOverlayState extends State<AchievementUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final achievement = kAchievements.firstWhere(
      (a) => a.id == widget.achievementId,
      orElse: () => kAchievements.first,
    );
    final color = _tierColor(achievement.tier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Container(
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.xxl),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xl, vertical: Spacing.md),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(Radii.xxl),
                    topRight: Radius.circular(Radii.xxl),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.sparkles,
                        size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'Achievement Unlocked',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(Spacing.xxl),
                child: Column(
                  children: [
                    // Icon with glow
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                  alpha: 0.15 + _pulseCtrl.value * 0.15),
                              blurRadius: 24 + _pulseCtrl.value * 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _tierIcon(achievement.tier),
                          size: 40,
                          color: color,
                        ),
                      ),
                    ),

                    const SizedBox(height: Spacing.xl),

                    // Tier badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.xxs),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.full),
                        border: Border.all(
                            color: color.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Text(
                        _tierLabel(achievement.tier),
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: Spacing.md),

                    Text(
                      achievement.name,
                      style: TextStyle(
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.w800,
                        color: AppStyles.getTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: Spacing.sm),

                    Text(
                      achievement.label,
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: Spacing.md),

                    Text(
                      achievement.description,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: Spacing.xxl),

                    Row(
                      children: [
                        Expanded(
                          child: BouncyButton(
                            onPressed: () async {
                              await Share.share(
                                'I just unlocked "${achievement.name}" on VittaraFinOS!\n"${achievement.label}"',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: Spacing.md),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(Radii.md),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.share,
                                      size: 15, color: color),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Share',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: TypeScale.footnote,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          flex: 2,
                          child: BouncyButton(
                            onPressed: widget.onDismiss,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: Spacing.md),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.8)],
                                ),
                                borderRadius:
                                    BorderRadius.circular(Radii.md),
                              ),
                              child: const Text(
                                'Awesome!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: TypeScale.callout,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Achievements Shelf Screen
// ---------------------------------------------------------------------------

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Achievements',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<EngagementService>(
        builder: (context, eng, _) {
          final unlocked = eng.unlockedAchievements;
          final unlockedCount = unlocked.length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: _buildProgressHeader(
                      context, unlockedCount, kAchievements.length),
                ),
              ),
              ...AchievementTier.values.map((tier) {
                final tierAch =
                    kAchievements.where((a) => a.tier == tier).toList();
                return _buildTierSection(
                    context, tier, tierAch, unlocked, eng);
              }),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(
      BuildContext context, int unlocked, int total) {
    final frac = total > 0 ? unlocked / total : 0.0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppStyles.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: const Icon(CupertinoIcons.star_fill,
                    color: AppStyles.accentBlue, size: 22),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Achievements',
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    Text(
                      '$unlocked of $total unlocked',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(frac * 100).round()}%',
                style: TextStyle(
                  fontSize: TypeScale.title2,
                  fontWeight: FontWeight.w800,
                  color: AppStyles.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.15),
                ),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppStyles.aetherTeal, AppStyles.accentBlue]),
                      borderRadius: BorderRadius.circular(Radii.full),
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

  Widget _buildTierSection(
    BuildContext context,
    AchievementTier tier,
    List<Achievement> achievements,
    Set<String> unlocked,
    EngagementService eng,
  ) {
    final color = _tierColor(tier);
    final unlockedInTier =
        achievements.where((a) => unlocked.contains(a.id)).length;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, 0, Spacing.lg, Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tier header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Row(
                children: [
                  Icon(_tierIcon(tier), size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    _tierLabel(tier),
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Divider(
                        color: color.withValues(alpha: 0.25), height: 1),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    '$unlockedInTier/${achievements.length}',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Achievement grid (2 per row)
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: Spacing.md,
                mainAxisSpacing: Spacing.md,
                childAspectRatio: 1.4,
              ),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final a = achievements[index];
                final isUnlocked = unlocked.contains(a.id);
                return _AchievementCard(
                  achievement: a,
                  isUnlocked: isUnlocked,
                  date: eng.getAchievementDate(a.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final DateTime? date;

  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(achievement.tier);
    final color = isUnlocked ? tierColor : tierColor;
    final isDark = AppStyles.isDarkMode(context);

    // Locked: still show tier color but muted
    final iconBg = isUnlocked
        ? color.withValues(alpha: 0.15)
        : color.withValues(alpha: isDark ? 0.12 : 0.09);
    final iconColor = isUnlocked
        ? color
        : color.withValues(alpha: 0.45);
    final borderColor = isUnlocked
        ? color.withValues(alpha: 0.35)
        : color.withValues(alpha: isDark ? 0.18 : 0.15);
    final nameColor = isUnlocked
        ? AppStyles.getTextColor(context)
        : AppStyles.getTextColor(context).withValues(alpha: 0.65);
    final subColor = isUnlocked
        ? AppStyles.getSecondaryTextColor(context)
        : AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.65);

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppStyles.getCardColor(context)
            : Color.alphaBlend(
                color.withValues(alpha: isDark ? 0.06 : 0.04),
                AppStyles.getCardColor(context),
              ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(
                    isUnlocked
                        ? _tierIcon(achievement.tier)
                        : CupertinoIcons.lock_fill,
                    size: 17,
                    color: iconColor,
                  ),
                ),
                if (isUnlocked)
                  Icon(CupertinoIcons.checkmark_seal_fill,
                      size: 14, color: color),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w700,
                    color: nameColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (date != null)
                  Text(
                    '${date!.day}/${date!.month}/${date!.year}',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: color.withValues(alpha: 0.6),
                    ),
                  )
                else
                  Text(
                    achievement.label,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: subColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared tier helpers
// ---------------------------------------------------------------------------

Color _tierColor(AchievementTier tier) {
  switch (tier) {
    case AchievementTier.foundation:
      return AppStyles.accentBlue;
    case AchievementTier.discipline:
      return AppStyles.accentTeal;
    case AchievementTier.mastery:
      return AppStyles.accentPurple;
    case AchievementTier.legend:
      return AppStyles.solarGold;
  }
}

IconData _tierIcon(AchievementTier tier) {
  switch (tier) {
    case AchievementTier.foundation:
      return CupertinoIcons.star_circle_fill;
    case AchievementTier.discipline:
      return CupertinoIcons.flame_fill;
    case AchievementTier.mastery:
      return CupertinoIcons.rosette;
    case AchievementTier.legend:
      return CupertinoIcons.star_circle_fill;
  }
}

String _tierLabel(AchievementTier tier) {
  switch (tier) {
    case AchievementTier.foundation:
      return 'FOUNDATION';
    case AchievementTier.discipline:
      return 'DISCIPLINE';
    case AchievementTier.mastery:
      return 'MASTERY';
    case AchievementTier.legend:
      return 'LEGEND';
  }
}
