import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/ai/ai_intelligence_controller.dart';
import 'package:vittara_fin_os/logic/ai/anomaly_detector.dart';
import 'package:vittara_fin_os/logic/ai/behavioral_nudge.dart';
import 'package:vittara_fin_os/logic/ai/financial_health_score.dart';
import 'package:vittara_fin_os/logic/ai/habit_observation_engine.dart';
import 'package:vittara_fin_os/logic/ai/monthly_narrative.dart';
import 'package:vittara_fin_os/ui/habits/habit_question_card.dart';
import 'package:vittara_fin_os/ui/scorecard/financial_health_card.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

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
        healthScore: ai.healthScore,
        topOpportunity: ai.topHabitOpportunity,
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
      cards.add(_AnomalyCard(anomaly: anomaly));
    }

    // 2. Habit nudge
    for (final nudge in data.nudges.take(1)) {
      cards.add(_NudgeCard(nudge: nudge));
    }

    // 3. Monthly narrative
    if (data.narrative != null) {
      cards.add(_NarrativeCard(narrative: data.narrative!));
    }

    // 4. Habit opportunity
    if (data.topOpportunity != null) {
      cards.add(_OpportunityCard(
        opportunity: data.topOpportunity!,
        onTap: () => _showHabitQuestion(context, data.topOpportunity!),
      ));
    }

    // 5. Health score summary
    if (data.healthScore != null) {
      cards.add(_HealthScoreCard(score: data.healthScore!));
    }

    return cards;
  }

  void _showHabitQuestion(BuildContext context, HabitOpportunity opp) {
    final ai = context.read<AIIntelligenceController>();
    HabitQuestionCard.show(context,
            opportunity: opp, tier: ai.tier)
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
  final FinancialHealthScore? healthScore;
  final HabitOpportunity? topOpportunity;

  const _StripData({
    required this.anomalies,
    required this.nudges,
    required this.narrative,
    required this.healthScore,
    required this.topOpportunity,
  });

  @override
  bool operator ==(Object other) =>
      other is _StripData &&
      anomalies.length == other.anomalies.length &&
      nudges.length == other.nudges.length &&
      narrative?.headline == other.narrative?.headline &&
      healthScore?.overallScore == other.healthScore?.overallScore &&
      topOpportunity?.id == other.topOpportunity?.id;

  @override
  int get hashCode => Object.hash(anomalies.length, nudges.length,
      narrative?.headline, healthScore?.overallScore, topOpportunity?.id);
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
  const _AnomalyCard({required this.anomaly});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      accent: const Color(0xFFFF6B6B),
      label: 'ANOMALY',
      body: anomaly.explanation,
    );
  }
}

class _NudgeCard extends StatelessWidget {
  final HabitNudge nudge;
  const _NudgeCard({required this.nudge});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: CupertinoIcons.flame_fill,
      accent: const Color(0xFFFF9500),
      label: 'HABIT CHECK',
      body: nudge.message,
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final MonthlyNarrative narrative;
  const _NarrativeCard({required this.narrative});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: CupertinoIcons.chart_bar_fill,
      accent: AppStyles.aetherTeal,
      label: narrative.headline.toUpperCase(),
      body: narrative.highlight ?? narrative.paragraph,
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

class _HealthScoreCard extends StatelessWidget {
  final FinancialHealthScore score;
  const _HealthScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score.overallScore >= 70
        ? const Color(0xFF4CAF50)
        : score.overallScore >= 40
            ? const Color(0xFFFF9500)
            : const Color(0xFFFF6B6B);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => FinancialHealthCard(score: score),
        ),
      ),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  score.overallScore.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'HEALTH SCORE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    score.overallLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Tap to see breakdown →',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
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
