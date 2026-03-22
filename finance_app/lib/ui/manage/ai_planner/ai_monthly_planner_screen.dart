import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/ai_planner_context.dart';
import 'package:vittara_fin_os/logic/ai_planner_engine.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class AIMonthlyPlannerScreen extends StatefulWidget {
  const AIMonthlyPlannerScreen({super.key});

  @override
  State<AIMonthlyPlannerScreen> createState() =>
      _AIMonthlyPlannerScreenState();
}

class _AIMonthlyPlannerScreenState extends State<AIMonthlyPlannerScreen> {
  AIPlannerContext? _context;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final ctx = await AIPlannerContext.load();
    if (mounted) {
      setState(() {
        _context = ctx;
        _loading = false;
      });
    }
  }

  Future<void> _openContextSheet({bool editing = false}) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _ContextWizardSheet(
        existing: editing ? _context : null,
        onSaved: (newCtx) async {
          await newCtx.save();
          if (mounted) {
            setState(() => _context = newCtx);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: const Text('AI Financial Planner'),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: _context != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openContextSheet(editing: true),
                child: const Text(
                  'Edit',
                  style: TextStyle(color: AppStyles.aetherTeal),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _context == null
                ? _buildNoContextView()
                : _buildAnalysisView(),
      ),
    );
  }

  Widget _buildNoContextView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppStyles.accentOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                size: 36,
                color: AppStyles.accentOrange,
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Text(
              'Set Your Financial Focus',
              style: TextStyle(
                fontSize: TypeScale.title1,
                fontWeight: FontWeight.w800,
                color: AppStyles.getTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Tell me what you\'re working toward and I\'ll build a personalized plan from your actual data.',
              style: TextStyle(
                fontSize: TypeScale.body,
                color: AppStyles.getSecondaryTextColor(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(Radii.lg),
                onPressed: _openContextSheet,
                child: const Text(
                  'Set My Focus',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisView() {
    return Consumer5<TransactionsController, AccountsController,
        InvestmentsController, BudgetsController, GoalsController>(
      builder: (context, txCtrl, accCtrl, invCtrl, budCtrl, goalCtrl, _) {
        final analysis = AIPlannerEngine.analyze(
          context: _context!,
          transactions: txCtrl.transactions,
          accounts: accCtrl.accounts,
          investments: invCtrl.investments,
          budgets: budCtrl.activeBudgets,
          goals: goalCtrl.activeGoals,
        );

        return ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            _buildContextHeader(analysis),
            const SizedBox(height: Spacing.lg),
            _buildSummaryCard(analysis),
            const SizedBox(height: Spacing.lg),
            _buildMetricsRow(analysis),
            const SizedBox(height: Spacing.lg),
            _buildGapIndicator(analysis),
            if (_context!.targetAmount != null &&
                _context!.targetAmount! > 0) ...[
              const SizedBox(height: Spacing.lg),
              _buildProgressBar(analysis),
            ],
            const SizedBox(height: Spacing.lg),
            _buildRecommendations(analysis),
            const SizedBox(height: Spacing.xl),
            _buildUpdateButton(),
            const SizedBox(height: Spacing.lg),
          ],
        );
      },
    );
  }

  Widget _buildContextHeader(PlannerAnalysis analysis) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppStyles.accentOrange.withValues(alpha: 0.15),
            AppStyles.accentOrange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
            color: AppStyles.accentOrange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.sparkles,
                  size: 18, color: AppStyles.accentOrange),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  analysis.context.focusLabel,
                  style: TextStyle(
                    fontSize: TypeScale.title2,
                    fontWeight: FontWeight.w800,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              _buildChip(
                  analysis.context.timelineLabel,
                  CupertinoIcons.time,
                  AppStyles.accentOrange),
              if (analysis.context.targetAmount != null &&
                  analysis.context.targetAmount! > 0) ...[
                const SizedBox(width: Spacing.sm),
                _buildChip(
                    '₹${_compact(analysis.context.targetAmount!)} target',
                    CupertinoIcons.flag_fill,
                    AppStyles.accentBlue),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: TypeScale.caption,
                color: color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(PlannerAnalysis analysis) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Text(
        analysis.summary,
        style: TextStyle(
          fontSize: TypeScale.callout,
          fontWeight: FontWeight.w500,
          color: AppStyles.getTextColor(context),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildMetricsRow(PlannerAnalysis analysis) {
    return Row(
      children: [
        Expanded(
            child: _buildMetricCard(
                'Monthly Income',
                '₹${_compact(analysis.monthlyIncome)}',
                CupertinoColors.systemGreen)),
        const SizedBox(width: Spacing.sm),
        Expanded(
            child: _buildMetricCard(
                'Monthly Savings',
                '₹${_compact(analysis.monthlySavings)}',
                AppStyles.accentBlue)),
        const SizedBox(width: Spacing.sm),
        Expanded(
            child: _buildMetricCard(
                'Savings Rate',
                '${(analysis.savingsRate * 100).toStringAsFixed(0)}%',
                analysis.savingsRate >= 0.20
                    ? AppStyles.accentGreen
                    : CupertinoColors.systemOrange)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: TypeScale.subhead,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: TypeScale.caption,
                color: AppStyles.getSecondaryTextColor(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGapIndicator(PlannerAnalysis analysis) {
    final onTrack = analysis.isOnTrack;
    final color = onTrack ? AppStyles.accentGreen : CupertinoColors.systemOrange;
    final label = onTrack
        ? 'On Track \u2713'
        : '₹${analysis.savingsGap.abs().toStringAsFixed(0)}/month more needed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            onTrack ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.exclamationmark_circle_fill,
            size: 18,
            color: color,
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.callout,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(PlannerAnalysis analysis) {
    final target = analysis.context.targetAmount!;
    // Estimate current progress based on relevant saved amount
    final relevant = analysis.monthlySavings * analysis.context.timelineMonths;
    final progress = target > 0
        ? (relevant / target).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress toward ₹${_compact(target)}',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w700,
                color: AppStyles.accentTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor:
                AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppStyles.aetherTeal),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(PlannerAnalysis analysis) {
    if (analysis.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommendations',
          style: TextStyle(
            fontSize: TypeScale.title2,
            fontWeight: FontWeight.w700,
            color: AppStyles.getTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.md),
        ...analysis.recommendations.map(_buildRecCard),
      ],
    );
  }

  Widget _buildRecCard(PlannerRecommendation rec) {
    final Color color;
    final IconData icon;
    switch (rec.type) {
      case PlannerRecommendationType.positive:
        color = AppStyles.accentGreen;
        icon = CupertinoIcons.checkmark_seal_fill;
        break;
      case PlannerRecommendationType.warning:
        color = CupertinoColors.systemOrange;
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      case PlannerRecommendationType.action:
        color = AppStyles.accentBlue;
        icon = CupertinoIcons.bolt_fill;
        break;
      case PlannerRecommendationType.info:
        color = AppStyles.aetherTeal;
        icon = CupertinoIcons.info_circle_fill;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  rec.title,
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              rec.detail,
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.lg),
        onPressed: () => _openContextSheet(editing: true),
        child: Text(
          'Update Focus',
          style: TextStyle(
            color: AppStyles.getTextColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Context Wizard Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ContextWizardSheet extends StatefulWidget {
  final AIPlannerContext? existing;
  final void Function(AIPlannerContext) onSaved;

  const _ContextWizardSheet({
    required this.existing,
    required this.onSaved,
  });

  @override
  State<_ContextWizardSheet> createState() => _ContextWizardSheetState();
}

class _ContextWizardSheetState extends State<_ContextWizardSheet> {
  int _step = 0;
  PlanningFocus _focus = PlanningFocus.emergencyFund;
  PlanningTimeline _timeline = PlanningTimeline.oneYear;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _customFocusCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _focus = e.focus;
      _timeline = e.timeline;
      if (e.targetAmount != null && e.targetAmount! > 0) {
        _amountCtrl.text = e.targetAmount!.toStringAsFixed(0);
      }
      if (e.customFocusText != null) _customFocusCtrl.text = e.customFocusText!;
      if (e.notes != null) _notesCtrl.text = e.notes!;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _customFocusCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final ctx = AIPlannerContext(
      focus: _focus,
      timeline: _timeline,
      targetAmount: amount,
      customFocusText: _focus == PlanningFocus.custom
          ? _customFocusCtrl.text.trim()
          : null,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    widget.onSaved(ctx);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppStyles.sheetMaxHeight(context),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              child: Row(
                children: [
                  Text(
                    _stepTitle(),
                    style: TextStyle(
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.w800,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_step + 1}/4',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: _buildStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onPressed: () {
                        if (_step < 3) {
                          setState(() => _step++);
                        } else {
                          _save();
                        }
                      },
                      child: Text(
                        _step < 3 ? 'Next' : 'Save Plan',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: Spacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: () => setState(() => _step--),
                        child: Text(
                          'Back',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                      ),
                    ),
                  ],
                  if (_step == 2 || _step == 3) ...[
                    const SizedBox(height: Spacing.xs),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: () => setState(() => _step++),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote),
                        ),
                      ),
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

  String _stepTitle() {
    switch (_step) {
      case 0:
        return 'What are you working toward?';
      case 1:
        return 'What\'s your timeline?';
      case 2:
        return 'What\'s your target? (optional)';
      case 3:
        return 'Any context? (optional)';
      default:
        return '';
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildFocusSelector();
      case 1:
        return _buildTimelinePicker();
      case 2:
        return _buildAmountInput();
      case 3:
        return _buildNotesInput();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFocusSelector() {
    final options = [
      (PlanningFocus.emergencyFund, CupertinoIcons.shield_fill, 'Emergency Fund'),
      (PlanningFocus.homeDownPayment, CupertinoIcons.house_fill, 'Home Down Payment'),
      (PlanningFocus.debtPayoff, CupertinoIcons.creditcard_fill, 'Debt Payoff'),
      (PlanningFocus.retirement, CupertinoIcons.person_fill, 'Retirement'),
      (PlanningFocus.education, CupertinoIcons.book_fill, 'Education'),
      (PlanningFocus.wedding, CupertinoIcons.heart_fill, 'Wedding'),
      (PlanningFocus.travel, CupertinoIcons.airplane, 'Travel'),
      (PlanningFocus.investment, CupertinoIcons.chart_bar_alt_fill, 'Investments'),
      (PlanningFocus.custom, CupertinoIcons.pencil, 'Custom'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.md),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: Spacing.sm,
          mainAxisSpacing: Spacing.sm,
          childAspectRatio: 1.1,
          children: options.map((opt) {
            final (focus, icon, label) = opt;
            final selected = _focus == focus;
            return GestureDetector(
              onTap: () => setState(() => _focus = focus),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected
                      ? AppStyles.accentOrange.withValues(alpha: 0.15)
                      : AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: selected
                        ? AppStyles.accentOrange
                        : AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.15),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: selected
                          ? AppStyles.accentOrange
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? AppStyles.accentOrange
                            : AppStyles.getTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_focus == PlanningFocus.custom) ...[
          const SizedBox(height: Spacing.lg),
          Text(
            'Describe your goal',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _customFocusCtrl,
            placeholder: 'e.g. Buy a car in 2 years',
            style: TextStyle(color: AppStyles.getTextColor(context)),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            padding: const EdgeInsets.all(Spacing.md),
          ),
        ],
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  Widget _buildTimelinePicker() {
    final options = [
      (PlanningTimeline.threeMonths, '3 months'),
      (PlanningTimeline.sixMonths, '6 months'),
      (PlanningTimeline.oneYear, '1 year'),
      (PlanningTimeline.threeYears, '3 years'),
      (PlanningTimeline.fiveYears, '5 years'),
      (PlanningTimeline.tenYears, '10 years'),
    ];

    return Column(
      children: [
        const SizedBox(height: Spacing.lg),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: options.map((opt) {
            final (timeline, label) = opt;
            final selected = _timeline == timeline;
            return GestureDetector(
              onTap: () => setState(() => _timeline = timeline),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.md),
                decoration: BoxDecoration(
                  color: selected
                      ? AppStyles.accentBlue.withValues(alpha: 0.15)
                      : AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.xl),
                  border: Border.all(
                    color: selected
                        ? AppStyles.accentBlue
                        : AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.2),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppStyles.accentBlue
                        : AppStyles.getTextColor(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.lg),
        Text(
          'e.g. 500000 for ₹5 lakh',
          style: TextStyle(
            fontSize: TypeScale.footnote,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _amountCtrl,
          placeholder: 'Target amount in ₹',
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.all(Spacing.lg),
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.lg),
        Text(
          'e.g. "I\'m saving for a ₹20L down payment on a flat in Bangalore"',
          style: TextStyle(
            fontSize: TypeScale.footnote,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _notesCtrl,
          placeholder: 'Any context to keep in mind...',
          maxLines: 4,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.all(Spacing.lg),
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }
}
