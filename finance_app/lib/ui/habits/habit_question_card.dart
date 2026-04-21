import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/logic/ai/habit_constructor.dart';
import 'package:vittara_fin_os/logic/ai/habit_observation_engine.dart';
import 'package:vittara_fin_os/logic/ai/habit_question_generator.dart';
import 'package:vittara_fin_os/logic/ai/device_intelligence_tier.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Shows the one-question-at-a-time habit building conversation as a
/// full-screen modal. Call [HabitQuestionCard.show] to launch.
///
/// Returns the constructed [HabitContract] when the user completes the
/// session, or null if they skip.
class HabitQuestionCard extends StatefulWidget {
  final HabitOpportunity opportunity;
  final IntelligenceTier tier;

  const HabitQuestionCard({
    required this.opportunity,
    required this.tier,
    super.key,
  });

  static Future<HabitContract?> show(
    BuildContext context, {
    required HabitOpportunity opportunity,
    required IntelligenceTier tier,
  }) {
    return showCupertinoModalPopup<HabitContract?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HabitQuestionCard(opportunity: opportunity, tier: tier),
    );
  }

  @override
  State<HabitQuestionCard> createState() => _HabitQuestionCardState();
}

class _HabitQuestionCardState extends State<HabitQuestionCard>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _answers = [];
  HabitQuestion? _current;
  bool _transitioning = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _loadNext();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _loadNext() {
    final next = HabitQuestionGenerator.next(
      opportunity: widget.opportunity,
      priorAnswers: _answers,
      tier: widget.tier,
    );
    setState(() => _current = next);
    if (next != null) {
      _animCtrl.forward(from: 0);
    }
  }

  Future<void> _selectAnswer(HabitAnswer answer) async {
    if (_transitioning) return;
    _transitioning = true;
    HapticFeedback.selectionClick();

    _answers.add(answer.payload);

    // Animate out
    await _animCtrl.reverse();
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 60));

    _transitioning = false;
    _loadNext();

    // If no more questions, build and return the contract
    if (_current == null) {
      final contract = HabitConstructor.build(
        opportunity: widget.opportunity,
        answers: _answers,
      );
      await HabitConstructor.save(contract);
      if (mounted) Navigator.of(context).pop(contract);
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _categoryColor(widget.opportunity.category, context);

    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () {}, // Prevent dismiss on tap-outside (barrierDismissible=false)
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _buildContent(accentColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color accentColor) {
    final q = _current;
    if (q == null) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.xxl),
        child: CupertinoActivityIndicator(),
      );
    }

    final totalSteps = 4; // max questions
    final stepLabel = 'Step ${q.stepIndex + 1} of $totalSteps';

    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    'Building your habit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    stepLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xl),

              // Question text
              Text(
                q.questionText,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Answer buttons
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: q.answers.map((a) => _answerChip(a, accentColor)).toList(),
              ),
              const SizedBox(height: Spacing.lg),

              // Skip
              if (q.isSkippable)
                Center(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _skip,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerChip(HabitAnswer answer, Color accentColor) {
    return GestureDetector(
      onTap: () => _selectAnswer(answer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          answer.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppStyles.getTextColor(context),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String category, BuildContext context) {
    final lower = category.toLowerCase();
    if (lower.contains('food') || lower.contains('dining') ||
        lower.contains('restaurant')) {
      return const Color(0xFFFF6B35);
    }
    if (lower.contains('transport') || lower.contains('travel')) {
      return const Color(0xFF4A90D9);
    }
    if (lower.contains('invest')) return const Color(0xFF6C63FF);
    if (lower.contains('shop')) return const Color(0xFFE91E63);
    if (lower.contains('entertain')) return const Color(0xFF00BCD4);
    if (lower.contains('health')) return const Color(0xFF4CAF50);
    return AppStyles.getPrimaryColor(context);
  }
}
