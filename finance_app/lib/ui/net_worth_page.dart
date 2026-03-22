import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/card_deck_view.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Asset Allocation Ring — animated donut showing savings/investments/debt
// ─────────────────────────────────────────────────────────────────────────────

class _AllocationArcPainter extends CustomPainter {
  final double savingsFrac;
  final double investmentsFrac;
  final double debtFrac;
  final double progress; // 0→1 animation progress

  const _AllocationArcPainter({
    required this.savingsFrac,
    required this.investmentsFrac,
    required this.debtFrac,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = size.width * 0.16;
    final radius = (size.width - strokeW) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const gap = 0.04; // radians gap between segments
    const full = math.pi * 2;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    canvas.drawArc(rect, 0, full, false, trackPaint);

    void drawArc(double startFrac, double sweepFrac, Color color) {
      if (sweepFrac <= 0) return;
      final start = full * startFrac - math.pi / 2;
      final sweep = (full * sweepFrac - gap) * progress;
      if (sweep <= 0) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    final total = savingsFrac + investmentsFrac + debtFrac;
    if (total <= 0) return;
    final sFrac = savingsFrac / total;
    final iFrac = investmentsFrac / total;
    final dFrac = debtFrac / total;

    drawArc(0, sFrac, const Color(0xFF34C759));
    drawArc(sFrac, iFrac, const Color(0xFF00D4AA));
    drawArc(sFrac + iFrac, dFrac, const Color(0xFFFF453A));
  }

  @override
  bool shouldRepaint(_AllocationArcPainter old) =>
      old.savingsFrac != savingsFrac ||
      old.investmentsFrac != investmentsFrac ||
      old.debtFrac != debtFrac ||
      old.progress != progress;
}

class _AllocationRing extends StatefulWidget {
  final double savings;
  final double investments;
  final double debt;
  final String centerLabel;

  const _AllocationRing({
    required this.savings,
    required this.investments,
    required this.debt,
    required this.centerLabel,
  });

  @override
  State<_AllocationRing> createState() => _AllocationRingState();
}

class _AllocationRingState extends State<_AllocationRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        size: const Size(72, 72),
        painter: _AllocationArcPainter(
          savingsFrac: widget.savings,
          investmentsFrac: widget.investments,
          debtFrac: widget.debt,
          progress: _anim.value,
        ),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              widget.centerLabel,
              style: const TextStyle(
                fontSize: TypeScale.micro,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated composition bar (savings | investments | debt segments)
// ─────────────────────────────────────────────────────────────────────────────

class _CompositionBar extends StatefulWidget {
  final double savings;
  final double investments;
  final double debt;

  const _CompositionBar({
    required this.savings,
    required this.investments,
    required this.debt,
  });

  @override
  State<_CompositionBar> createState() => _CompositionBarState();
}

class _CompositionBarState extends State<_CompositionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.savings + widget.investments + widget.debt;
    if (total <= 0) return const SizedBox.shrink();
    final sFrac = widget.savings / total;
    final iFrac = widget.investments / total;
    final dFrac = widget.debt / total;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final p = _anim.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Flexible(
                      flex: (sFrac * 1000 * p).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF34C759)),
                    ),
                    if (iFrac > 0)
                      Flexible(
                        flex: (iFrac * 1000 * p).round().clamp(0, 1000),
                        child: Container(color: const Color(0xFF00D4AA)),
                      ),
                    if (dFrac > 0)
                      Flexible(
                        flex: (dFrac * 1000 * p).round().clamp(0, 1000),
                        child: Container(color: const Color(0xFFFF453A)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _LegendDot(color: const Color(0xFF34C759), label: '${(sFrac * 100).toStringAsFixed(0)}% Savings'),
                const SizedBox(width: 12),
                if (iFrac > 0) ...[
                  _LegendDot(color: const Color(0xFF00D4AA), label: '${(iFrac * 100).toStringAsFixed(0)}% Invest'),
                  const SizedBox(width: 12),
                ],
                if (dFrac > 0)
                  _LegendDot(color: const Color(0xFFFF453A), label: '${(dFrac * 100).toStringAsFixed(0)}% Debt'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: TypeScale.micro,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  bool _expandInvestments = false;
  List<_NetWorthSnapshot> _historySnapshots = [];
  bool _snapshotSavedThisSession = false;

  @override
  void initState() {
    super.initState();
    _loadNetWorthHistory();
  }

  Future<void> _loadNetWorthHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('nw_history_'))
        .toList()
      ..sort();
    final snapshots = <_NetWorthSnapshot>[];
    for (final key in keys) {
      final value = prefs.getDouble(key);
      if (value == null) continue;
      // key format: nw_history_YYYY_MM
      final datePart = key.substring('nw_history_'.length);
      final parts = datePart.split('_');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null) {
          snapshots.add(
              _NetWorthSnapshot(date: DateTime(year, month), value: value));
        }
      }
    }
    // Keep last 12 months
    final trimmed = snapshots.length > 12
        ? snapshots.sublist(snapshots.length - 12)
        : snapshots;
    if (mounted) setState(() => _historySnapshots = trimmed);
  }

  void _maybeSaveSnapshot(double netWorth) {
    if (_snapshotSavedThisSession) return;
    _snapshotSavedThisSession = true;
    final now = DateTime.now();
    final key =
        'nw_history_${now.year}_${now.month.toString().padLeft(2, '0')}';
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(key, netWorth);
      _loadNetWorthHistory();
    });
  }

  double _calculateNetWorth(AccountsController ac, InvestmentsController ic) {
    double savings = 0;
    for (final a in ac.accounts) {
      if (a.type != AccountType.credit && a.type != AccountType.payLater) {
        savings += a.balance;
      }
    }
    double investments = 0;
    for (final inv in ic.investments) {
      final metadata = inv.metadata ?? {};
      final cv = (metadata['currentValue'] as num?)?.toDouble();
      investments += cv ?? inv.amount;
    }
    double creditUsed = 0;
    for (final a in ac.accounts) {
      if (a.type == AccountType.credit || a.type == AccountType.payLater) {
        creditUsed += (a.creditLimit ?? 0.0) - a.balance;
      }
    }
    return savings + investments - creditUsed;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = AppStyles.isLandscape(context);

    return CupertinoPageScaffold(
      // Landscape: hide nav bar — replaced by compact inline bar in body
      navigationBar: isLandscape
          ? null
          : const CupertinoNavigationBar(
              middle: Text('Net Worth'),
              previousPageTitle: 'Back',
              border: null,
            ),
      child: SafeArea(
        child: Consumer3<AccountsController, InvestmentsController,
            TransactionsController>(
          builder:
              (context, accountsController, investmentsController, txCtrl, _) {
            // Loading skeleton
            if (!accountsController.isLoaded ||
                !investmentsController.isLoaded) {
              return const SkeletonAnimationProvider(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(Spacing.lg),
                  child: Column(
                    children: [
                      SkeletonSummaryCard(),
                      SizedBox(height: Spacing.xl),
                      SkeletonListView(itemCount: 4),
                    ],
                  ),
                ),
              );
            }

            // Empty state
            if (accountsController.accounts.isEmpty &&
                investmentsController.investments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.chart_pie_fill,
                        size: 72,
                        color: SemanticColors.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: Spacing.xl),
                      Text(
                        'Your Net Worth Awaits',
                        style: TextStyle(
                          fontSize: TypeScale.title1,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        'Add your first account or investment to see your net worth here.',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.xxl),
                      CupertinoButton.filled(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go to Manage'),
                      ),
                    ],
                  ),
                ),
              );
            }

            try {
              final totalNetWorth = _calculateNetWorth(
                  accountsController, investmentsController);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _maybeSaveSnapshot(totalNetWorth);
              });

              // ── Card Deck Layout ────────────────────────────────────────
              return Column(
                children: [
                  // Compact nav bar in landscape
                  if (isLandscape) _buildLandscapeNavBar(context),
                  Expanded(
                    child: CardDeckView(
                      cards: [
                        // Card 1: Vault — headline net worth + momentum banner
                        _buildNwDeckCard(
                          context,
                          label: 'VAULT',
                          icon: CupertinoIcons.lock_shield_fill,
                          accent: AppStyles.teal(context),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTotalNetWorthCard(context,
                                  accountsController, investmentsController),
                              if (_historySnapshots.length >= 2) ...[
                                const SizedBox(height: Spacing.md),
                                _buildMotivationalBanner(
                                    context, totalNetWorth),
                              ],
                            ],
                          ),
                        ),
                        // Card 2: Trajectory — trend + forecast
                        _buildNwDeckCard(
                          context,
                          label: 'TRAJECTORY',
                          icon: CupertinoIcons.chart_bar_alt_fill,
                          accent: AppStyles.violet(context),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_historySnapshots.length >= 2)
                                _buildNetWorthTrendCard(context),
                              const SizedBox(height: Spacing.lg),
                              _buildForecastCard(
                                  context, txCtrl, totalNetWorth),
                            ],
                          ),
                        ),
                        // Card 3: Liquid Assets — bank accounts
                        _buildNwDeckCard(
                          context,
                          label: 'LIQUID ASSETS',
                          icon: CupertinoIcons.building_2_fill,
                          accent: AppStyles.gain(context),
                          child: _buildBankAccountsSection(
                              context, accountsController),
                        ),
                        // Card 4: Portfolio — demat + investments
                        _buildNwDeckCard(
                          context,
                          label: 'PORTFOLIO',
                          icon: CupertinoIcons.chart_pie_fill,
                          accent: AppStyles.gold(context),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDematAccountsSection(
                                  context, accountsController),
                              const SizedBox(height: Spacing.lg),
                              _buildInvestmentsSection(
                                  context, investmentsController),
                            ],
                          ),
                        ),
                        // Card 5: Obligations — credit liabilities
                        _buildNwDeckCard(
                          context,
                          label: 'OBLIGATIONS',
                          icon: CupertinoIcons.creditcard_fill,
                          accent: AppStyles.loss(context),
                          child: _buildCreditLiabilitiesSection(
                              context, accountsController),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } catch (e) {
              if (kDebugMode) {
                print('Error building Net Worth page: $e');
                print(StackTrace.current);
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 50,
                      color: AppStyles.loss(context).withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Text(
                      'Error Loading Net Worth',
                      style: TextStyle(
                        fontSize: TypeScale.headline,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      e.toString(),
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ── Compact landscape nav bar (back button + title) ─────────────────────────
  Widget _buildLandscapeNavBar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
              color: AppStyles.getDividerColor(context), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          BouncyButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.chevron_back,
                    size: 16,
                    color: AppStyles.getPrimaryColor(context)),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppStyles.getPrimaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'NET WORTH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppStyles.getSecondaryTextColor(context),
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          // Spacer to balance back button width
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  // ── Bloomberg-style deck card wrapper ───────────────────────────────────────
  Widget _buildNwDeckCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    final isDark = AppStyles.isDarkMode(context);
    return Container(
      decoration: AppStyles.cardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(Radii.xxl),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bloomberg panel header
          Container(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Radii.xxl),
                topRight: Radius.circular(Radii.xxl),
              ),
              border: Border(
                bottom: BorderSide(
                  color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 13, color: accent),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalBanner(BuildContext context, double currentNetWorth) {
    // Compare current to previous month snapshot
    // Last snapshot is current month (just saved); use the one before it
    final prevSnapshot = _historySnapshots.length >= 2
        ? _historySnapshots[_historySnapshots.length - 2]
        : null;
    if (prevSnapshot == null) return const SizedBox.shrink();

    final delta = currentNetWorth - prevSnapshot.value;
    final absDelta = delta.abs();
    final pct = prevSnapshot.value != 0
        ? (delta / prevSnapshot.value.abs()) * 100
        : 0.0;

    final String message;
    final Color color;
    final IconData icon;

    if (delta > 0) {
      if (pct >= 10) {
        message =
            'Up ${CurrencyFormatter.compact(absDelta)} (+${pct.toStringAsFixed(1)}%) — crushing it!';
      } else if (pct >= 3) {
        message = 'Up ${CurrencyFormatter.compact(absDelta)} this month. Keep going!';
      } else {
        message = 'Up ${CurrencyFormatter.compact(absDelta)} from last month.';
      }
      color = AppStyles.gain(context);
      icon = CupertinoIcons.arrow_up_right_circle_fill;
    } else if (delta < 0) {
      if (pct.abs() >= 10) {
        message =
            'Down ${CurrencyFormatter.compact(absDelta)} (${pct.toStringAsFixed(1)}%) — let\'s recover!';
      } else {
        message =
            'Down ${CurrencyFormatter.compact(absDelta)} from last month — let\'s turn it around.';
      }
      color = AppStyles.loss(context);
      icon = CupertinoIcons.arrow_down_right_circle_fill;
    } else {
      message = 'Net worth unchanged from last month.';
      color = AppStyles.getSecondaryTextColor(context);
      icon = CupertinoIcons.minus_circle_fill;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalNetWorthCard(
    BuildContext context,
    AccountsController accountsController,
    InvestmentsController investmentsController,
  ) {
    // Calculate Savings (all non-credit accounts)
    double totalSavings = 0;
    for (var account in accountsController.accounts) {
      if (account.type != AccountType.credit &&
          account.type != AccountType.payLater) {
        totalSavings += account.balance;
      }
    }

    // Calculate Total Investment
    double totalInvestments = 0;
    for (var investment in investmentsController.investments) {
      final metadata = investment.metadata ?? {};
      final currentValue = (metadata['currentValue'] as num?)?.toDouble();
      totalInvestments += currentValue ?? investment.amount;
    }

    // Calculate Total Credit Limit
    double totalCreditLimit = 0;
    double totalCreditUsed = 0;
    for (var account in accountsController.accounts) {
      if (account.type == AccountType.credit ||
          account.type == AccountType.payLater) {
        totalCreditLimit += (account.creditLimit ?? 0.0);
        final used = (account.creditLimit ?? 0.0) - account.balance;
        totalCreditUsed += used;
      }
    }

    // Net Worth = Savings + Investment - Credit Used
    final totalNetWorth = totalSavings + totalInvestments - totalCreditUsed;

    // Determine color based on positive/negative
    final netWorthColor =
        totalNetWorth >= 0 ? SemanticColors.primary : AppStyles.loss(context);

    final isPositive = totalNetWorth >= 0;
    final heroGradient = isPositive
        ? AppStyles.heroGradient(isDark: AppStyles.isDarkMode(context))
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E0A0A), Color(0xFF2E0E0E), Color(0xFF1A0808)],
          );
    final accentColor =
        isPositive ? AppStyles.accentBlue : const Color(0xFFFF453A);

    return Container(
      decoration: BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.circular(Radii.xxl),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: AppStyles.elevatedShadows(
          context,
          tint: accentColor,
          strength: 1.1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.xxl),
        child: Stack(
          children: [
            // Ambient glow orbs
            Positioned(
              top: -40,
              right: -20,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    accentColor.withValues(alpha: 0.18),
                    accentColor.withValues(alpha: 0.00),
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppStyles.accentTeal.withValues(alpha: 0.12),
                    AppStyles.accentTeal.withValues(alpha: 0.00),
                  ]),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TOTAL NET WORTH',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Spacing.md),

                  // The big number + allocation ring side-by-side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AnimatedCounter(
                          value: totalNetWorth,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.5,
                            height: 1.0,
                          ),
                          prefix: '₹',
                        ),
                      ),
                      _AllocationRing(
                        savings: totalSavings,
                        investments: totalInvestments,
                        debt: totalCreditUsed,
                        centerLabel: totalNetWorth >= 0 ? 'Assets' : 'Deficit',
                      ),
                    ],
                  ),

                  const SizedBox(height: Spacing.md),

                  // Animated composition bar
                  _CompositionBar(
                    savings: totalSavings,
                    investments: totalInvestments,
                    debt: totalCreditUsed,
                  ),

                  const SizedBox(height: Spacing.md),

                  // Breakdown strip
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _heroRow(
                          icon: CupertinoIcons.building_2_fill,
                          label: 'Savings',
                          value: CurrencyFormatter.compact(totalSavings),
                          color: const Color(0xFF34C759),
                        ),
                        if (totalInvestments > 0) ...[
                          const SizedBox(height: 6),
                          _heroRow(
                            icon: CupertinoIcons.graph_square_fill,
                            label: 'Investments',
                            value: CurrencyFormatter.compact(totalInvestments),
                            color: AppStyles.teal(context),
                          ),
                        ],
                        if (totalCreditUsed > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            height: 0.5,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          const SizedBox(height: 6),
                          _heroRow(
                            icon: CupertinoIcons.creditcard_fill,
                            label: 'Credit Used',
                            value:
                                '−${CurrencyFormatter.compact(totalCreditUsed)}',
                            color: const Color(0xFFFF453A),
                          ),
                        ],
                      ],
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

  Widget _heroRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: Colors.white.withValues(alpha: 0.60),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: TypeScale.footnote,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBankAccountsSection(
    BuildContext context,
    AccountsController accountsController,
  ) {
    // Filter for regular bank accounts only (exclude investment, credit, and BNPL accounts)
    final bankAccounts = accountsController.accounts
        .where((a) =>
            a.type != AccountType.investment &&
            a.type != AccountType.credit &&
            a.type != AccountType.payLater)
        .toList();

    if (bankAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            'No bank accounts added',
            style: TextStyle(
              fontSize: TypeScale.subhead,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ),
      );
    }

    double total = 0;
    for (var account in bankAccounts) {
      total += account.balance;
    }

    const sectionColor = Color(0xFF00D4AA);

    return Container(
      decoration: AppStyles.sectionDecoration(
        context,
        tint: sectionColor,
        radius: Radii.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.lg, Spacing.lg, Spacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: AppStyles.iconBoxDecoration(context, sectionColor),
                  child: const Icon(CupertinoIcons.building_2_fill,
                      size: 20, color: sectionColor),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Accounts',
                        style: TextStyle(
                          fontSize: TypeScale.headline,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.getTextColor(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${bankAccounts.length} account${bankAccounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.compact(total),
                  style: AppStyles.amountStyle(context,
                      color: sectionColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: bankAccounts.asMap().entries.map((entry) {
                final isLast = entry.key == bankAccounts.length - 1;
                final account = entry.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                account.bankName,
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedCounter(
                          value: account.balance,
                          prefix: '₹',
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: Spacing.md),
                        child: Divider(height: 1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDematAccountsSection(
    BuildContext context,
    AccountsController accountsController,
  ) {
    // Filter for investment/demat accounts only
    final dematAccounts = accountsController.accounts
        .where((a) => a.type == AccountType.investment)
        .toList();

    if (dematAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    double total = 0;
    for (var account in dematAccounts) {
      total += account.balance;
    }

    return Container(
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: AppStyles.iconBoxDecoration(context, CupertinoColors.systemOrange),
                  child: const Icon(CupertinoIcons.graph_square_fill,
                      size: 20, color: CupertinoColors.systemOrange),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demat / Investments',
                        style: TextStyle(
                          fontSize: TypeScale.headline,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.getTextColor(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${dematAccounts.length} account${dematAccounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.compact(total),
                  style: AppStyles.amountStyle(context, color: CupertinoColors.systemOrange),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: dematAccounts.asMap().entries.map((entry) {
                final isLast = entry.key == dematAccounts.length - 1;
                final account = entry.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                account.bankName,
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedCounter(
                          value: account.balance,
                          prefix: '₹',
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: Spacing.md),
                        child: Divider(height: 1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditLiabilitiesSection(
    BuildContext context,
    AccountsController accountsController,
  ) {
    // Filter for credit cards and BNPL accounts
    final creditAccounts = accountsController.accounts
        .where((a) =>
            a.type == AccountType.credit || a.type == AccountType.payLater)
        .toList();

    if (creditAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    double totalCreditLimit = 0;
    double totalUsed = 0;
    for (var account in creditAccounts) {
      totalCreditLimit += (account.creditLimit ?? 0.0);
      totalUsed += ((account.creditLimit ?? 0.0) - account.balance);
    }
    final totalAvailable = totalCreditLimit - totalUsed;

    return Container(
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppStyles.loss(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.creditcard_fill,
                      size: 20, color: AppStyles.loss(context)),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit & BNPL Liabilities',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${creditAccounts.length} account${creditAccounts.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${totalUsed.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: TypeScale.callout,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.loss(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: creditAccounts.asMap().entries.map((entry) {
                final isLast = entry.key == creditAccounts.length - 1;
                final account = entry.value;
                final used = (account.creditLimit ?? 0.0) - account.balance;
                final available = account.balance;
                final utilization = (account.creditLimit ?? 0.0) > 0
                    ? (used / (account.creditLimit ?? 1.0) * 100)
                    : 0.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                account.bankName,
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    // Credit details row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Limit',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                '₹${(account.creditLimit ?? 0.0).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Used',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: AppStyles.loss(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                '₹${used.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.loss(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: AppStyles.gain(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                '₹${available.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.gain(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    // Utilization progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: utilization / 100,
                        minHeight: 6,
                        backgroundColor:
                            CupertinoColors.systemGrey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          utilization > 80
                              ? AppStyles.loss(context)
                              : CupertinoColors.systemOrange,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Utilization',
                          style: TextStyle(
                            fontSize: TypeScale.label,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        Text(
                          '${utilization.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: TypeScale.label,
                            fontWeight: FontWeight.w600,
                            color: utilization > 80
                                ? AppStyles.loss(context)
                                : CupertinoColors.systemOrange,
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: Spacing.md),
                        child: Divider(height: 1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentsSection(
    BuildContext context,
    InvestmentsController investmentsController,
  ) {
    if (investmentsController.investments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            'No investments yet',
            style: TextStyle(
              fontSize: TypeScale.subhead,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ),
      );
    }

    // Group by type
    final investmentsByType = <String, List<Investment>>{};
    double totalInvested = 0;
    double totalCurrent = 0;

    for (var inv in investmentsController.investments) {
      final type = inv.type.toString().split('.').last;
      if (!investmentsByType.containsKey(type)) {
        investmentsByType[type] = [];
      }
      investmentsByType[type]!.add(inv);
      totalInvested += inv.amount;
      totalCurrent += _currentValueForInvestment(inv);
    }

    // Sort by total amount
    final sortedEntries = investmentsByType.entries.toList();
    sortedEntries.sort((a, b) {
      double totalA = 0, totalB = 0;
      for (var inv in a.value) {
        totalA += inv.amount;
      }
      for (var inv in b.value) {
        totalB += inv.amount;
      }
      return totalB.compareTo(totalA);
    });

    final displayEntries =
        _expandInvestments ? sortedEntries : sortedEntries.take(3).toList();
    final hasMore = sortedEntries.length > 3;

    return Container(
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppStyles.gain(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.chart_bar_fill,
                      size: 20, color: AppStyles.gain(context)),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Investments',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${investmentsByType.length} type${investmentsByType.length != 1 ? 's' : ''} • ${investmentsController.investments.length} total',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${totalCurrent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Invested ₹${totalInvested.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...displayEntries.asMap().entries.map((entry) {
                  final isLast = entry.key == displayEntries.length - 1;
                  final type = entry.value.key;
                  final investments = entry.value.value;

                  double typeInvested = 0;
                  double typeCurrent = 0;
                  for (var inv in investments) {
                    typeInvested += inv.amount;
                    typeCurrent += _currentValueForInvestment(inv);
                  }
                  final percentage = totalCurrent > 0
                      ? (typeCurrent / totalCurrent * 100)
                      : 0.0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getInvestmentTypeLabel(type),
                                  style: TextStyle(
                                    fontSize: TypeScale.subhead,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                                Text(
                                  '${investments.length} item${investments.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Current ₹${typeCurrent.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              Text(
                                'Invested ₹${typeInvested.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: AppStyles.gain(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: Spacing.md),
                          child: Divider(height: 1),
                        ),
                    ],
                  );
                }),
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.md),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _expandInvestments = !_expandInvestments;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _expandInvestments ? 'Show Less' : 'Show All',
                            style: TextStyle(
                              fontSize: TypeScale.subhead,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.gain(context),
                            ),
                          ),
                          const SizedBox(width: Spacing.xs),
                          Icon(
                            _expandInvestments
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            size: 14,
                            color: AppStyles.gain(context),
                          ),
                        ],
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

  String _getInvestmentTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'stocks':
        return 'Stocks';
      case 'bonds':
        return 'Bonds';
      case 'fixeddeposit':
        return 'Fixed Deposits';
      case 'recurringdeposit':
        return 'Recurring Deposits';
      case 'mutualfunds':
        return 'Mutual Funds';
      case 'digitaldeposit':
        return 'Digital Gold';
      case 'crypto':
        return 'Cryptocurrency';
      case 'nps':
        return 'NPS';
      case 'pension':
        return 'Pension Plans';
      case 'commodities':
        return 'Commodities';
      case 'forex':
        return 'Forex';
      case 'forwardcontracts':
        return 'Forward Contracts';
      default:
        return type;
    }
  }

  // ── 6-Month Forecast card ─────────────────────────────────────────────────

  /// Returns the monthly average savings (income − expenses) over the last
  /// [lookbackMonths] full calendar months. Months with no transactions are
  /// skipped when computing the average to avoid distortion.
  double _averageMonthlySavings(
    List<Transaction> transactions,
    int lookbackMonths,
  ) {
    final now = DateTime.now();
    final incomeByMonth = <int, double>{};
    final expenseByMonth = <int, double>{};

    for (int i = 1; i <= lookbackMonths; i++) {
      // month key = year*100 + month
      final target = DateTime(now.year, now.month - i);
      final key = target.year * 100 + target.month;
      incomeByMonth[key] = 0;
      expenseByMonth[key] = 0;
    }

    for (final tx in transactions) {
      final key = tx.dateTime.year * 100 + tx.dateTime.month;
      if (!incomeByMonth.containsKey(key)) continue;
      if (tx.type == TransactionType.income) {
        incomeByMonth[key] = (incomeByMonth[key] ?? 0) + tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expenseByMonth[key] = (expenseByMonth[key] ?? 0) + tx.amount;
      }
    }

    final savings = <double>[];
    for (final key in incomeByMonth.keys) {
      final income = incomeByMonth[key] ?? 0;
      final expense = expenseByMonth[key] ?? 0;
      // Only count months that have at least one transaction
      if (income > 0 || expense > 0) {
        savings.add(income - expense);
      }
    }

    if (savings.isEmpty) return 0;
    return savings.reduce((a, b) => a + b) / savings.length;
  }

  Widget _buildForecastCard(
    BuildContext context,
    TransactionsController txCtrl,
    double currentNetWorth,
  ) {
    const lookback = 3;
    const forecastMonths = 6;
    final monthlyAvg = _averageMonthlySavings(txCtrl.transactions, lookback);

    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Build projected balance list (month 0 = current, 1..6 = future)
    final projectedValues = List.generate(
      forecastMonths + 1,
      (i) => currentNetWorth + monthlyAvg * i,
    );

    final endValue = projectedValues.last;
    final delta = endValue - currentNetWorth;
    final isPositiveDelta = delta >= 0;
    final deltaColor =
        isPositiveDelta ? AppStyles.gain(context) : AppStyles.loss(context);

    // Build month labels for x-axis (current month + next 6)
    final xLabels = List.generate(forecastMonths + 1, (i) {
      final d = DateTime(now.year, now.month + i);
      return months[d.month - 1];
    });

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppStyles.violet(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CupertinoIcons.chart_bar_alt_fill,
                      size: 16,
                      color: AppStyles.violet(context),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    '6-Month Outlook',
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositiveDelta
                          ? CupertinoIcons.arrow_up_right
                          : CupertinoIcons.arrow_down_right,
                      size: 11,
                      color: deltaColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      CurrencyFormatter.compact(delta.abs()),
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                        color: deltaColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: Spacing.xs),
          Text(
            monthlyAvg == 0
                ? 'Add income & expense transactions to see projections'
                : 'Based on last $lookback-month avg savings: ${CurrencyFormatter.compact(monthlyAvg)}/mo',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),

          const SizedBox(height: Spacing.lg),

          // Forecast chart
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _ForecastPainter(
                values: projectedValues,
                actualColor: AppStyles.teal(context),
                forecastColor: AppStyles.violet(context),
                gridColor: AppStyles.getSecondaryTextColor(context),
              ),
              size: Size.infinite,
            ),
          ),

          const SizedBox(height: Spacing.sm),

          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: xLabels
                .asMap()
                .entries
                .where((e) =>
                    e.key == 0 ||
                    e.key == forecastMonths ~/ 2 ||
                    e.key == forecastMonths)
                .map(
                  (e) => Text(
                    e.value,
                    style: TextStyle(
                      fontSize: TypeScale.label,
                      color: e.key == 0
                          ? AppStyles.teal(context)
                          : e.key == forecastMonths
                              ? AppStyles.violet(context)
                              : AppStyles.getSecondaryTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: Spacing.lg),

          // Projection table
          _buildProjectionTable(
              context, projectedValues, xLabels, months, now, deltaColor),
        ],
      ),
    );
  }

  Widget _buildProjectionTable(
    BuildContext context,
    List<double> projectedValues,
    List<String> xLabels,
    List<String> months,
    DateTime now,
    Color deltaColor,
  ) {
    // Show only months 1-6 (skip index 0 which is current)
    final rows = <Widget>[];
    for (int i = 1; i <= 6; i++) {
      final targetDate = DateTime(now.year, now.month + i);
      final monthLabel =
          '${months[targetDate.month - 1]} ${targetDate.year}';
      final value = projectedValues[i];
      final isLast = i == 6;

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : Spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              Text(
                CurrencyFormatter.compact(value),
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: i == 6
                      ? deltaColor
                      : AppStyles.getTextColor(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.violet(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: AppStyles.violet(context).withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  Widget _buildNetWorthTrendCard(BuildContext context) {
    final snapshots = _historySnapshots;
    final first = snapshots.first.value;
    final last = snapshots.last.value;
    final change = last - first;
    final changePct = first != 0 ? (change / first.abs()) * 100 : 0.0;
    final isPositive = change >= 0;
    final trendColor =
        isPositive ? AppStyles.gain(context) : AppStyles.loss(context);
    final monthCount = snapshots.length;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Worth Trend',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? CupertinoIcons.arrow_up_right
                          : CupertinoIcons.arrow_down_right,
                      size: 12,
                      color: trendColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${changePct.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Last $monthCount month${monthCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // Sparkline chart
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _NetWorthSparklinePainter(
                snapshots: snapshots,
                lineColor: trendColor,
                gridColor: AppStyles.getSecondaryTextColor(context),
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          // X-axis month labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                months[snapshots.first.date.month - 1],
                style: TextStyle(
                  fontSize: TypeScale.label,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              if (monthCount > 2)
                Text(
                  months[snapshots[monthCount ~/ 2].date.month - 1],
                  style: TextStyle(
                    fontSize: TypeScale.label,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              Text(
                months[snapshots.last.date.month - 1],
                style: TextStyle(
                  fontSize: TypeScale.label,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _currentValueForInvestment(Investment investment) {
    final metadata = investment.metadata ?? {};
    final currentValue = (metadata['currentValue'] as num?)?.toDouble();
    if (currentValue != null && currentValue > 0) return currentValue;
    final units = (metadata['units'] as num?)?.toDouble();
    final currentNav = (metadata['currentNAV'] as num?)?.toDouble();
    if (units != null && currentNav != null) return units * currentNav;
    final pricePerUnit = (metadata['pricePerShare'] as num?)?.toDouble();
    final quantity = (metadata['qty'] as num?)?.toDouble();
    if (pricePerUnit != null && quantity != null) {
      return pricePerUnit * quantity;
    }
    return investment.amount;
  }
}

// ---------------------------------------------------------------------------
// Net Worth History data model
// ---------------------------------------------------------------------------

class _NetWorthSnapshot {
  final DateTime date;
  final double value;
  const _NetWorthSnapshot({required this.date, required this.value});
}

// ---------------------------------------------------------------------------
// Sparkline painter for net worth trend chart
// ---------------------------------------------------------------------------

class _NetWorthSparklinePainter extends CustomPainter {
  final List<_NetWorthSnapshot> snapshots;
  final Color lineColor;
  final Color gridColor;

  const _NetWorthSparklinePainter({
    required this.snapshots,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.length < 2) return;

    const leftPad = 4.0;
    const rightPad = 4.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final values = snapshots.map((s) => s.value).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs();
    final adjustedMin = range == 0 ? minV - 1 : minV;
    final adjustedMax = range == 0 ? maxV + 1 : maxV;
    final adjustedRange = adjustedMax - adjustedMin;

    double xOf(int i) => leftPad + (i / (snapshots.length - 1)) * w;
    double yOf(double v) =>
        topPad + h - ((v - adjustedMin) / adjustedRange * h);

    // Draw horizontal grid lines (3 lines)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 2; i++) {
      final y = topPad + (i / 2) * h;
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + w, y), gridPaint);
    }

    // Build path for line
    final path = Path();
    for (int i = 0; i < snapshots.length; i++) {
      final x = xOf(i);
      final y = yOf(snapshots[i].value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient fill below the line
    final fillPath = Path.from(path);
    fillPath.lineTo(xOf(snapshots.length - 1), topPad + h);
    fillPath.lineTo(leftPad, topPad + h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.20),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw dots at each point
    final dotPaint = Paint()..color = lineColor;
    final dotRadius = snapshots.length <= 6 ? 3.5 : 2.5;
    for (int i = 0; i < snapshots.length; i++) {
      canvas.drawCircle(
          Offset(xOf(i), yOf(snapshots[i].value)), dotRadius, dotPaint);
    }

    // Highlight last point
    final lastX = xOf(snapshots.length - 1);
    final lastY = yOf(snapshots.last.value);
    canvas.drawCircle(
      Offset(lastX, lastY),
      5.0,
      Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(lastX, lastY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _NetWorthSparklinePainter old) =>
      old.snapshots != snapshots || old.lineColor != lineColor;
}

// ---------------------------------------------------------------------------
// Forecast painter — current point in actualColor, dashed projected line
// ---------------------------------------------------------------------------

class _ForecastPainter extends CustomPainter {
  /// index 0 = current net worth; indices 1..N = projected monthly values
  final List<double> values;
  final Color actualColor;
  final Color forecastColor;
  final Color gridColor;

  const _ForecastPainter({
    required this.values,
    required this.actualColor,
    required this.forecastColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    const leftPad = 4.0;
    const rightPad = 4.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs();
    final adjustedMin = range == 0 ? minV - 1 : minV;
    final adjustedMax = range == 0 ? maxV + 1 : maxV;
    final adjustedRange = adjustedMax - adjustedMin;
    final n = values.length;

    double xOf(int i) => leftPad + (i / (n - 1)) * w;
    double yOf(double v) =>
        topPad + h - ((v - adjustedMin) / adjustedRange * h);

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int g = 0; g <= 2; g++) {
      final y = topPad + (g / 2) * h;
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + w, y), gridPaint);
    }

    // Gradient fill below forecast line
    final forecastPath = Path()..moveTo(xOf(0), yOf(values[0]));
    for (int i = 1; i < n; i++) {
      forecastPath.lineTo(xOf(i), yOf(values[i]));
    }
    final fillPath = Path.from(forecastPath)
      ..lineTo(xOf(n - 1), topPad + h)
      ..lineTo(xOf(0), topPad + h)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            forecastColor.withValues(alpha: 0.18),
            forecastColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(leftPad, topPad, w, h)),
    );

    // Dashed forecast line
    final dashPaint = Paint()
      ..color = forecastColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashLen = 6.0;
    const gapLen = 4.0;

    for (int i = 0; i < n - 1; i++) {
      final x1 = xOf(i);
      final y1 = yOf(values[i]);
      final x2 = xOf(i + 1);
      final y2 = yOf(values[i + 1]);
      final dx = x2 - x1;
      final dy = y2 - y1;
      final segLen = math.sqrt(dx * dx + dy * dy);
      if (segLen == 0) continue;
      final ux = dx / segLen;
      final uy = dy / segLen;
      double drawn = 0;
      bool drawing = true;
      while (drawn < segLen) {
        final step = drawing
            ? math.min(dashLen, segLen - drawn)
            : math.min(gapLen, segLen - drawn);
        if (drawing) {
          canvas.drawLine(
            Offset(x1 + ux * drawn, y1 + uy * drawn),
            Offset(x1 + ux * (drawn + step), y1 + uy * (drawn + step)),
            dashPaint,
          );
        }
        drawn += step;
        drawing = !drawing;
      }
    }

    // Small dots on projected points
    final dotPaint = Paint()..color = forecastColor;
    for (int i = 1; i < n; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(values[i])), 2.5, dotPaint);
    }

    // Current point — larger, aetherTeal
    final cx = xOf(0);
    final cy = yOf(values[0]);
    canvas.drawCircle(
      Offset(cx, cy),
      6.0,
      Paint()
        ..color = actualColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(cx, cy), 4.0, Paint()..color = actualColor);

    // End-point glow
    final lx = xOf(n - 1);
    final ly = yOf(values[n - 1]);
    canvas.drawCircle(
      Offset(lx, ly),
      6.0,
      Paint()
        ..color = forecastColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(lx, ly), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter old) =>
      old.values != values ||
      old.actualColor != actualColor ||
      old.forecastColor != forecastColor;
}
