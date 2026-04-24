import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/settings/csv_import_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';

const String _kActivationDoneKey = 'onboarding_v2_complete';

/// Returns true if the new activation onboarding has been completed.
Future<bool> hasCompletedActivation() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kActivationDoneKey) == true;
}

/// Marks the activation onboarding as complete.
Future<void> markActivationComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kActivationDoneKey, true);
}

// ─────────────────────────────────────────────────────────────────────────────

class OnboardingActivationScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingActivationScreen({super.key, required this.onComplete});

  @override
  State<OnboardingActivationScreen> createState() =>
      _OnboardingActivationScreenState();
}

class _OnboardingActivationScreenState
    extends State<OnboardingActivationScreen> with SingleTickerProviderStateMixin {
  int _step = 0; // 0-3 = steps, 4 = completion
  bool _showConfetti = false;

  static const _totalSteps = 4;

  void _advance() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _showCompletion();
    }
  }

  void _skip() => _advance();

  Future<void> _showCompletion() async {
    setState(() {
      _step = _totalSteps;
      _showConfetti = true;
    });
    await markActivationComplete();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      child: SafeArea(
        child: Column(
          children: [
            // Progress bar (hidden on completion)
            if (_step < _totalSteps) ...[
              const SizedBox(height: Spacing.lg),
              _ProgressBar(step: _step, total: _totalSteps),
              const SizedBox(height: Spacing.xl),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _buildStep(context, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, bool isDark) {
    switch (_step) {
      case 0:
        return _Step1Account(key: const ValueKey(0), onComplete: _advance);
      case 1:
        return _Step2Import(
            key: const ValueKey(1), onComplete: _advance, onSkip: _skip);
      case 2:
        return _Step3Goal(
            key: const ValueKey(2), onComplete: _advance, onSkip: _skip);
      case 3:
        return _Step4AI(
            key: const ValueKey(3), onComplete: _advance, onSkip: _skip);
      default:
        return _CompletionView(
          key: const ValueKey('complete'),
          showConfetti: _showConfetti,
          onDone: widget.onComplete,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      child: Row(
        children: List.generate(total, (i) {
          final done = i < step;
          final active = i == step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: done || active
                    ? AppStyles.aetherTeal
                    : AppStyles.aetherTeal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Your first account
// ─────────────────────────────────────────────────────────────────────────────

class _Step1Account extends StatefulWidget {
  final VoidCallback onComplete;
  const _Step1Account({super.key, required this.onComplete});

  @override
  State<_Step1Account> createState() => _Step1AccountState();
}

class _Step1AccountState extends State<_Step1Account> {
  bool _saved = false;
  double _savedBalance = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepLabel(index: 1),
          const SizedBox(height: Spacing.sm),
          Text(
            'Link your first account',
            style: TextStyle(
              fontSize: TypeScale.largeTitle,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Add a savings, credit, or cash account so VittaraFinOS can track your money.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          if (_saved) ...[
            _SuccessCard(
              icon: CupertinoIcons.checkmark_circle_fill,
              color: AppStyles.bioGreen,
              title: '₹${_fmt(_savedBalance)} tracked',
              subtitle: 'Your first account is set.',
            ),
            const SizedBox(height: Spacing.xl),
            _PrimaryButton(
              label: 'Continue',
              onPressed: widget.onComplete,
            ),
          ] else ...[
            BouncyButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<dynamic>(
                  CupertinoPageRoute(
                      builder: (_) => const AccountWizard(isInvestment: false)),
                );
                if (result != null) {
                  final acCtrl = context.read<AccountsController>();
                  await acCtrl.addAccount(result);
                  setState(() {
                    _saved = true;
                    _savedBalance = result.balance as double? ?? 0;
                  });
                  HapticFeedback.mediumImpact();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.xl),
                decoration: BoxDecoration(
                  color: AppStyles.aetherTeal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppStyles.aetherTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppStyles.aetherTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(CupertinoIcons.creditcard_fill,
                          size: 22, color: AppStyles.aetherTeal),
                    ),
                    const SizedBox(width: Spacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add an Account',
                            style: TextStyle(
                              fontSize: TypeScale.subhead,
                              fontWeight: FontWeight.w700,
                              color: AppStyles.getTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Savings, credit card, cash, wallet',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 16,
                        color:
                            AppStyles.aetherTeal.withValues(alpha: 0.6)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Import transactions
// ─────────────────────────────────────────────────────────────────────────────

class _Step2Import extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  const _Step2Import(
      {super.key, required this.onComplete, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepLabel(index: 2),
          const SizedBox(height: Spacing.sm),
          Text(
            'Import your transactions',
            style: TextStyle(
              fontSize: TypeScale.largeTitle,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Bring in past transactions so your analysis starts immediately.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          _ImportCard(
            icon: CupertinoIcons.doc_text_fill,
            color: AppStyles.accentBlue,
            title: 'CSV Import',
            subtitle: 'Upload a statement from your bank app',
            onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const CsvImportScreen())),
          ),
          const SizedBox(height: Spacing.md),
          _ImportCard(
            icon: CupertinoIcons.pencil_circle_fill,
            color: AppStyles.novaPurple,
            title: 'Add manually',
            subtitle: 'Enter one or more transactions by hand',
            onTap: onComplete,
          ),
          const SizedBox(height: Spacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onSkip,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ImportCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      )),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Set one goal
// ─────────────────────────────────────────────────────────────────────────────

class _Step3Goal extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  const _Step3Goal(
      {super.key, required this.onComplete, required this.onSkip});

  @override
  State<_Step3Goal> createState() => _Step3GoalState();
}

class _Step3GoalState extends State<_Step3Goal> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _saved = false;

  static const _suggestions = [
    'Emergency Fund',
    'Europe Trip',
    'New Phone',
    'Home Down Payment',
    'New Car',
    'Education Fund',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (name.isEmpty || amount <= 0) return;
    final now = DateTime.now();
    final goal = Goal(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      type: GoalType.custom,
      targetAmount: amount,
      currentAmount: 0,
      targetDate: now.add(const Duration(days: 365)),
      createdDate: now,
      color: CupertinoColors.activeBlue,
    );
    await context.read<GoalsController>().addGoal(goal);
    setState(() => _saved = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 1200));
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepLabel(index: 3),
          const SizedBox(height: Spacing.sm),
          Text(
            'Set one goal',
            style: TextStyle(
              fontSize: TypeScale.largeTitle,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'What are you saving for? We\'ll track your progress automatically.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Suggestion chips
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: _suggestions.map((s) => GestureDetector(
              onTap: () => setState(() => _nameCtrl.text = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.xs),
                decoration: BoxDecoration(
                  color: _nameCtrl.text == s
                      ? AppStyles.novaPurple.withValues(alpha: 0.15)
                      : AppStyles.novaPurple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(Radii.full),
                  border: Border.all(
                    color: AppStyles.novaPurple.withValues(
                        alpha: _nameCtrl.text == s ? 0.5 : 0.18),
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    color: _nameCtrl.text == s
                        ? AppStyles.novaPurple
                        : AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: Spacing.xl),
          _OnboardingField(
            controller: _nameCtrl,
            placeholder: 'Goal name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          _OnboardingField(
            controller: _amountCtrl,
            placeholder: 'Target amount (₹)',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
          ),
          const SizedBox(height: Spacing.xl),
          if (_saved) ...[
            _SuccessCard(
              icon: CupertinoIcons.flag_fill,
              color: AppStyles.novaPurple,
              title: 'Goal set!',
              subtitle: 'We\'ll remind you when you\'re close.',
            ),
          ] else ...[
            _PrimaryButton(
              label: 'Set Goal',
              onPressed: _nameCtrl.text.isNotEmpty && _amountCtrl.text.isNotEmpty
                  ? _save
                  : null,
            ),
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: widget.onSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4: Enable AI insights
// ─────────────────────────────────────────────────────────────────────────────

class _Step4AI extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  const _Step4AI({super.key, required this.onComplete, required this.onSkip});

  @override
  State<_Step4AI> createState() => _Step4AIState();
}

class _Step4AIState extends State<_Step4AI> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepLabel(index: 4),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enable AI insights',
            style: TextStyle(
              fontSize: TypeScale.largeTitle,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'VittaraFinOS learns your patterns and surfaces money opportunities — all on-device, never uploaded.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: AppStyles.aetherTeal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppStyles.aetherTeal.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                _AIBullet(
                  icon: CupertinoIcons.chart_pie_fill,
                  color: AppStyles.aetherTeal,
                  text: 'Detects unusual spending spikes and opportunities to save',
                ),
                const SizedBox(height: Spacing.md),
                _AIBullet(
                  icon: CupertinoIcons.lock_fill,
                  color: AppStyles.aetherTeal,
                  text: 'Everything runs on-device — your data never leaves your phone',
                ),
                const SizedBox(height: Spacing.md),
                _AIBullet(
                  icon: CupertinoIcons.lightbulb_fill,
                  color: AppStyles.aetherTeal,
                  text: 'Improves after 7 days of transactions',
                ),
                const SizedBox(height: Spacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enable AI Insights',
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    CupertinoSwitch(
                      value: _enabled,
                      activeTrackColor: AppStyles.aetherTeal,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          _PrimaryButton(
            label: _enabled ? 'Enable & Continue' : 'Continue',
            onPressed: () async {
              if (_enabled) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('ai_insights_enabled', true);
              }
              widget.onComplete();
            },
          ),
          const SizedBox(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: widget.onSkip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AIBullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AIBullet(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion view
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionView extends StatefulWidget {
  final bool showConfetti;
  final VoidCallback onDone;
  const _CompletionView(
      {super.key, required this.showConfetti, required this.onDone});

  @override
  State<_CompletionView> createState() => _CompletionViewState();
}

class _CompletionViewState extends State<_CompletionView>
    with TickerProviderStateMixin {
  final List<_ConfettiParticle> _particles = [];
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.showConfetti) {
      _generateParticles();
      _ctrl.forward();
    }
  }

  void _generateParticles() {
    final rng = Random();
    for (int i = 0; i < 32; i++) {
      _particles.add(_ConfettiParticle(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.6,
        color: [
          AppStyles.aetherTeal,
          AppStyles.novaPurple,
          AppStyles.solarGold,
          AppStyles.bioGreen,
          AppStyles.plasmaRed,
        ][rng.nextInt(5)],
        size: 6 + rng.nextDouble() * 8,
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetti particles
        if (widget.showConfetti)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Stack(
              children: _particles.map((p) {
                final progress = ((_ctrl.value - p.delay) / (1 - p.delay))
                    .clamp(0.0, 1.0);
                if (progress == 0) return const SizedBox.shrink();
                return Positioned(
                  left: MediaQuery.of(context).size.width * p.x,
                  top: MediaQuery.of(context).size.height *
                      (0.05 + progress * 0.6),
                  child: Opacity(
                    opacity: 1 - progress * 0.8,
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: BoxDecoration(
                        color: p.color,
                        borderRadius: BorderRadius.circular(p.size / 4),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        // Content
        Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppStyles.aetherTeal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.checkmark_circle_fill,
                      size: 44, color: AppStyles.aetherTeal),
                ),
                const SizedBox(height: Spacing.xl),
                Text(
                  'Your Financial OS\nis ready.',
                  style: TextStyle(
                    fontSize: TypeScale.largeTitle,
                    fontWeight: FontWeight.w800,
                    color: AppStyles.getTextColor(context),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'Insights, tracking, and smart suggestions — all set up and ready to go.',
                  style: TextStyle(
                    fontSize: TypeScale.body,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.xxl),
                _PrimaryButton(
                  label: "Let's go →",
                  onPressed: widget.onDone,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double delay;
  final Color color;
  final double size;
  const _ConfettiParticle(
      {required this.x,
      required this.delay,
      required this.color,
      required this.size});
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final int index;
  const _StepLabel({required this.index});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Step $index of 4',
      style: TextStyle(
        fontSize: TypeScale.caption,
        fontWeight: FontWeight.w700,
        color: AppStyles.aetherTeal,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _SuccessCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onPressed ?? () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: onPressed != null
              ? AppStyles.aetherTeal
              : AppStyles.aetherTeal.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: TypeScale.body,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _OnboardingField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _OnboardingField({
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      onChanged: onChanged,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppStyles.darkL2 : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppStyles.getDividerColor(context),
        ),
      ),
      style: TextStyle(
        fontSize: TypeScale.body,
        color: AppStyles.getTextColor(context),
      ),
      placeholderStyle: TextStyle(
        fontSize: TypeScale.body,
        color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.6),
      ),
    );
  }
}
