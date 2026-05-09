import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/ai/ai_intelligence_controller.dart';
import 'package:vittara_fin_os/logic/ai/anomaly_detector.dart';
import 'package:vittara_fin_os/logic/ai/behavioral_nudge.dart';
import 'package:vittara_fin_os/logic/ai/habit_observation_engine.dart';
import 'package:vittara_fin_os/logic/ai/habit_weekly_checker.dart';
import 'package:vittara_fin_os/logic/ai/monthly_narrative.dart';
import 'package:vittara_fin_os/ui/habits/habit_question_card.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/habit_detail_sheet.dart';

/// Horizontally scrollable row of proactive AI insight cards.
/// Appears on the dashboard only when the AI system has something to say.
/// Gated: hidden entirely if no cards are available.
class AIInsightsStrip extends StatelessWidget {
  const AIInsightsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AIIntelligenceController, _StripData>(
      selector: (_, ai) => _StripData(
        anomalies: ai.recentAnomalies,
        nudges: ai.habitNudges,
        narrative: ai.currentMonthNarrative,
        topOpportunity: ai.topHabitOpportunity,
        topHabitProgress: ai.topHabitProgress,
      ),
      builder: (context, data, _) {
        final cards = _buildCards(context, data);
        if (cards.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
            itemBuilder: (_, i) => cards[i],
          ),
        );
      },
    );
  }

  List<Widget> _buildCards(BuildContext context, _StripData data) {
    final cards = <Widget>[];

    // 1. Anomaly alert (highest priority)
    for (final anomaly in data.anomalies.take(2)) {
      cards.add(_AnomalyCard(
        anomaly: anomaly,
        onTap: () => _showInsightDetails(
          context,
          title: anomaly.title,
          label: 'SPENDING ALERT',
          body: anomaly.explanation,
          accent: const Color(0xFFFF6B6B),
          actionLabel: 'Dismiss alert',
          onAction: () {
            context.read<AIIntelligenceController>().dismissAnomaly(anomaly.id);
          },
        ),
      ));
    }

    // 2. Habit nudge
    for (final nudge in data.nudges.take(1)) {
      cards.add(_NudgeCard(
        nudge: nudge,
        onTap: () => _showInsightDetails(
          context,
          title: nudge.isBreached ? 'Habit limit crossed' : 'Habit check',
          label: 'HABIT CHECK',
          body:
              '${nudge.message}\n\nCurrent: ₹${nudge.currentSpend.toStringAsFixed(0)} of ₹${nudge.targetSpend.toStringAsFixed(0)}',
          accent: const Color(0xFFFF9500),
        ),
      ));
    }

    // 3. Monthly narrative
    if (data.narrative != null) {
      cards.add(_NarrativeCard(
        narrative: data.narrative!,
        onTap: () => _showInsightDetails(
          context,
          title: data.narrative!.headline,
          label: 'SPENDING PATTERN',
          body: data.narrative!.paragraph,
          accent: AppStyles.aetherTeal,
        ),
      ));
    }

    // 4. Habit opportunity
    if (data.topOpportunity != null) {
      cards.add(_OpportunityCard(
        opportunity: data.topOpportunity!,
        onTap: () => _showHabitQuestion(context, data.topOpportunity!),
      ));
    }

    // 5. Habit check-in (T-105) — only appears after first habit is confirmed
    if (data.topHabitProgress != null) {
      cards.add(_HabitCheckInCard(
        progress: data.topHabitProgress!,
        onTap: () => HabitDetailSheet.show(context, data.topHabitProgress!),
      ));
    }

    return cards;
  }

  void _showInsightDetails(
    BuildContext context, {
    required String title,
    required String label,
    required String body,
    required Color accent,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Radii.xxl),
            topRight: Radius.circular(Radii.xxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.lg,
              Spacing.xl,
              Spacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppStyles.getDividerColor(context),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: accent,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: TypeScale.title3,
                    fontWeight: FontWeight.w800,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: TypeScale.callout,
                    height: 1.35,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: Spacing.lg),
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    borderRadius: BorderRadius.circular(Radii.lg),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onAction();
                    },
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHabitQuestion(BuildContext context, HabitOpportunity opp) {
    final ai = context.read<AIIntelligenceController>();
    HabitQuestionCard.show(context, opportunity: opp, tier: ai.tier)
        .then((contract) {
      if (contract != null) {
        ai.addHabit(contract);
      }
    });
  }
}

// ── Data container for Selector ──────────────────────────────────────────────

class _StripData {
  final List<AnomalyAlert> anomalies;
  final List<HabitNudge> nudges;
  final MonthlyNarrative? narrative;
  final HabitOpportunity? topOpportunity;
  final HabitWeeklyProgress? topHabitProgress;

  const _StripData({
    required this.anomalies,
    required this.nudges,
    required this.narrative,
    required this.topOpportunity,
    this.topHabitProgress,
  });

  @override
  bool operator ==(Object other) =>
      other is _StripData &&
      anomalies.length == other.anomalies.length &&
      nudges.length == other.nudges.length &&
      narrative?.headline == other.narrative?.headline &&
      topOpportunity?.id == other.topOpportunity?.id &&
      topHabitProgress?.habit.id == other.topHabitProgress?.habit.id;

  @override
  int get hashCode => Object.hash(anomalies.length, nudges.length,
      narrative?.headline, topOpportunity?.id, topHabitProgress?.habit.id);
}

// ── Individual card widgets ───────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String body;
  final VoidCallback? onTap;

  const _InsightCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.body,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: accent, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppStyles.getTextColor(context),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  final AnomalyAlert anomaly;
  final VoidCallback onTap;
  const _AnomalyCard({required this.anomaly, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      accent: const Color(0xFFFF6B6B),
      label: 'ANOMALY',
      body: anomaly.explanation,
      onTap: onTap,
    );
  }
}

class _NudgeCard extends StatelessWidget {
  final HabitNudge nudge;
  final VoidCallback onTap;
  const _NudgeCard({required this.nudge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: CupertinoIcons.flame_fill,
      accent: const Color(0xFFFF9500),
      label: 'HABIT CHECK',
      body: nudge.message,
      onTap: onTap,
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final MonthlyNarrative narrative;
  final VoidCallback onTap;
  const _NarrativeCard({required this.narrative, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: CupertinoIcons.chart_bar_fill,
      accent: AppStyles.aetherTeal,
      label: narrative.headline.toUpperCase(),
      body: narrative.highlight ?? narrative.paragraph,
      onTap: onTap,
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final HabitOpportunity opportunity;
  final VoidCallback onTap;
  const _OpportunityCard({required this.opportunity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: CupertinoIcons.star_fill,
      accent: const Color(0xFF6C63FF),
      label: 'OPPORTUNITY',
      body: opportunity.observation,
      onTap: onTap,
    );
  }
}

// ── T-105: Habit check-in card ────────────────────────────────────────────────

class _HabitCheckInCard extends StatelessWidget {
  final HabitWeeklyProgress progress;
  final VoidCallback onTap;

  const _HabitCheckInCard({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ratio = progress.weeklyTarget > 0
        ? progress.actualCount / progress.weeklyTarget
        : 0.0;
    final color = ratio >= 1.0
        ? AppStyles.accentGreen
        : ratio >= 0.5
            ? AppStyles.accentAmber
            : AppStyles.accentCoral;

    return _InsightCard(
      icon: CupertinoIcons.flame_fill,
      accent: color,
      label: progress.habit.category,
      body: '${progress.actualCount}/${progress.weeklyTarget} days'
          ' · ₹${_fmtCompact(progress.actualSpend)}',
      onTap: onTap,
    );
  }

  String _fmtCompact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toInt().toString();
  }
}
