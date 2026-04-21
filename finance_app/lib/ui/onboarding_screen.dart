import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

const String _kOnboardingDoneKey = 'onboarding_complete_v1';

/// Returns true if the user has already seen onboarding.
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDoneKey) ?? false;
}

/// Marks onboarding as complete so it is never shown again.
Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
}

// ──────────────────────────────────────────────────────────────────────────────
// Data
// ──────────────────────────────────────────────────────────────────────────────

class _OnboardingPage {
  final String title;
  final String subtitle;
  final String emoji;
  final Color accent;
  final List<String> bullets;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.accent,
    required this.bullets,
  });
}

// Onboarding uses fixed dark-mode hero backgrounds, so static accent colors are fine
const _pages = [
  _OnboardingPage(
    title: 'Your Financial OS',
    subtitle: 'One app. Every rupee. Total clarity.',
    emoji: '✦',
    accent: AppStyles.aetherTeal,
    bullets: [
      'Track all accounts in one place',
      'Investments, goals, budgets — unified',
      'Private, on-device, no cloud sync',
    ],
  ),
  _OnboardingPage(
    title: 'Track Everything',
    subtitle: 'Accounts, investments, scorecard — live.',
    emoji: '◈',
    accent: AppStyles.novaPurple,
    bullets: [
      'Savings, credit cards, loans',
      'Stocks, MF, FD/RD, crypto & more',
      'Auto-import via SMS scanning',
    ],
  ),
  _OnboardingPage(
    title: 'Smart Insights',
    subtitle: 'Know where every rupee goes.',
    emoji: '⬡',
    accent: AppStyles.solarGold,
    bullets: [
      'Monthly budget alerts at 80 % / 100 %',
      'Category trends & spending patterns',
      'Goals with milestone celebrations',
    ],
  ),
  _OnboardingPage(
    title: 'Ready to Begin',
    subtitle: 'Set up your first account and start today.',
    emoji: '◉',
    accent: AppStyles.bioGreen,
    bullets: [
      'Add an account in under 30 seconds',
      'Import past transactions via SMS',
      'Your data stays on your device',
    ],
  ),
  // Page 5 — interactive demo (rendered separately)
  _OnboardingPage(
    title: 'See it in action',
    subtitle: 'This is what your dashboard will look like once you start tracking.',
    emoji: '⚡',
    accent: AppStyles.solarGold,
    bullets: [],
  ),
];

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  /// Called when the user taps "Get Started" or "Skip".
  /// Receives the onboarding screen's own [BuildContext] so callers can
  /// navigate away safely even after the splash screen is gone.
  final void Function(BuildContext context) onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Per-page animation controllers
  late final List<AnimationController> _pageAnims;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _pageAnims = List.generate(
      _pages.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _fadeAnims = _pageAnims
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _slideAnims = _pageAnims
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    // Play first page immediately
    _pageAnims[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _pageAnims) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToPage(int index) {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _pageAnims[index].reset();
    _pageAnims[index].forward();
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    await markOnboardingComplete();
    if (!mounted) return;
    widget.onComplete(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppStyles.darkBackground : AppStyles.lightBackground;
    final accent = _pages[_currentPage].accent;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Ambient glow orb behind current page
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            top: AppStyles.sheetMaxHeight(context),
            left: MediaQuery.of(context).size.width * 0.1,
            right: MediaQuery.of(context).size.width * 0.1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.12),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              // Skip button top-right
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20, top: 8),
                    child: _currentPage < _pages.length - 1
                        ? CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            onPressed: _finish,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 15,
                              ),
                            ),
                          )
                        : const SizedBox(height: 44),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return FadeTransition(
                      opacity: _fadeAnims[index],
                      child: SlideTransition(
                        position: _slideAnims[index],
                        // Last page = interactive demo
                        child: index == _pages.length - 1
                            ? _DemoOnboardingPage(page: _pages[index], isDark: isDark)
                            : _OnboardingPageView(
                                page: _pages[index],
                                isDark: isDark,
                              ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom controls
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  MediaQuery.of(context).orientation == Orientation.landscape ? 4 : 0,
                ),
                child: Column(
                  children: [
                    // Dot indicators + page counter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(_pages.length, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: active
                                  ? accent
                                  : (isDark
                                      ? Colors.white24
                                      : Colors.black26),
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                        Text(
                          '${_currentPage + 1} / ${_pages.length}',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // CTA button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _currentPage < _pages.length - 1
                          ? _NextButton(
                              key: const ValueKey('next'),
                              accent: accent,
                              onTap: () => _goToPage(_currentPage + 1),
                              label: 'Next',
                            )
                          : _NextButton(
                              key: const ValueKey('start'),
                              accent: accent,
                              onTap: _finish,
                              label: 'Get Started',
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Back button (not on first page)
                    if (_currentPage > 0)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        onPressed: () => _goToPage(_currentPage - 1),
                        child: Text(
                          'Back',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: 15,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 36),

                    const SafeArea(top: false, child: SizedBox(height: 8)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Single page content
// ──────────────────────────────────────────────────────────────────────────────

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  final bool isDark;

  const _OnboardingPageView({required this.page, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return isLandscape
        ? _buildLandscape(context)
        : _buildPortrait(context);
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _buildIcon(double size, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: page.accent.withValues(alpha: 0.1),
        border: Border.all(
          color: page.accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: page.accent.withValues(alpha: 0.25),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          page.emoji,
          style: TextStyle(color: page.accent, fontSize: fontSize, height: 1),
        ),
      ),
    );
  }

  Widget _buildBullets(BuildContext context, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: page.bullets
          .map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: page.accent,
                      boxShadow: [
                        BoxShadow(
                          color: page.accent.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Portrait: centered column ───────────────────────────────────────────────

  Widget _buildPortrait(BuildContext context) {
    final textColor = isDark ? AppStyles.darkText : AppStyles.lightText;
    final secondaryColor = AppStyles.getSecondaryTextColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(120, 52),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: RT.title1(context),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryColor,
              fontSize: TypeScale.callout,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          _buildBullets(context, textColor),
        ],
      ),
    );
  }

  // ── Landscape: icon left, text+bullets right, scrollable ───────────────────

  Widget _buildLandscape(BuildContext context) {
    final textColor = isDark ? AppStyles.darkText : AppStyles.lightText;
    final secondaryColor = AppStyles.getSecondaryTextColor(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIcon(88, 38),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  page.subtitle,
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: TypeScale.callout,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _buildBullets(context, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Next / Get Started button
// ──────────────────────────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  final String label;

  const _NextButton({
    super.key,
    required this.accent,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          gradient: LinearGradient(
            colors: [
              accent,
              accent.withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: TypeScale.callout,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Demo onboarding page (last page — interactive preview)
// ──────────────────────────────────────────────────────────────────────────────

class _DemoOnboardingPage extends StatelessWidget {
  final _OnboardingPage page;
  final bool isDark;

  const _DemoOnboardingPage({required this.page, required this.isDark});

  void _haptic() => HapticFeedback.lightImpact();

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppStyles.darkText : AppStyles.lightText;
    final secondaryColor = AppStyles.getSecondaryTextColor(context);
    final cardBg = isDark
        ? const Color(0xFF0D0D0D)
        : Colors.white.withValues(alpha: 0.9);
    final cardBorder = isDark
        ? const Color(0xFF1C1C1C)
        : Colors.black.withValues(alpha: 0.08);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Header
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: RT.title1(context),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryColor,
              fontSize: TypeScale.callout,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Mock net-worth card
          GestureDetector(
            onTap: _haptic,
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppStyles.aetherTeal.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scorecard',
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppStyles.bioGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '+2.4%',
                          style: TextStyle(
                            color: AppStyles.bioGreen,
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹12,45,000',
                    style: TextStyle(
                      color: textColor,
                      fontSize: TypeScale.display,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assets ₹18,20,000  ·  Liabilities ₹5,75,000',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: TypeScale.caption,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Mini sparkline (static bars)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [72, 68, 78, 75, 82, 80, 88, 85, 92, 90, 96, 100]
                        .map((h) => Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1.5),
                                height: h * 0.36,
                                decoration: BoxDecoration(
                                  color: AppStyles.aetherTeal
                                      .withValues(alpha: 0.5 + h * 0.004),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Mock transaction rows
          ...[
            (
              icon: Icons.shopping_bag_outlined,
              iconColor: AppStyles.novaPurple,
              title: 'Swiggy Order',
              subtitle: 'Food & Dining · today',
              amount: '-₹349',
              amtColor: const Color(0xFFFF6B6B),
            ),
            (
              icon: Icons.account_balance_outlined,
              iconColor: AppStyles.aetherTeal,
              title: 'Salary Credit',
              subtitle: 'Income · Mar 1',
              amount: '+₹85,000',
              amtColor: AppStyles.bioGreen,
            ),
          ].map(
            (tx) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: _haptic,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: cardBorder),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tx.iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tx.icon, color: tx.iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: TypeScale.body,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tx.subtitle,
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: TypeScale.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        tx.amount,
                        style: TextStyle(
                          color: tx.amtColor,
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Your data. Your insights. Let\'s set it up.',
            style: TextStyle(
              color: page.accent.withValues(alpha: 0.7),
              fontSize: TypeScale.caption,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
