import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/logic/brokers_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/dashboard_controller.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'package:vittara_fin_os/logic/investment_type_preferences_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_feed_builder.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/transactions_archive_controller.dart';
import 'package:vittara_fin_os/logic/recurring_templates_controller.dart';
import 'package:vittara_fin_os/logic/loan_controller.dart';
import 'package:vittara_fin_os/logic/insurance_controller.dart';
import 'package:vittara_fin_os/ui/fintech_loader.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/ui/dashboard/dashboard_action_sheet.dart';
import 'package:vittara_fin_os/ui/notifications_page.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/dashboard/dashboard_settings_modal.dart';
import 'package:vittara_fin_os/ui/net_worth_page.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/floating_particle_background.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/services/mf_database_service.dart';
import 'package:vittara_fin_os/ui/manage/goals/goals_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/onboarding_screen.dart';
import 'package:vittara_fin_os/ui/manage/savings/savings_planners_screen.dart';
import 'package:vittara_fin_os/ui/manage/ai_planner/ai_monthly_planner_screen.dart';
import 'package:vittara_fin_os/ui/app_menu/app_menu_screen.dart';
import 'package:vittara_fin_os/ui/sms/sms_review_screen.dart';
import 'package:vittara_fin_os/services/sms_auto_scan_service.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/pin_recovery_screen.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/health_score_widget.dart';

final AppLogger logger = AppLogger();

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      logger.error('Flutter Framework Error',
          context: 'Main', error: details.exception, stackTrace: details.stack);
    };

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsController()..loadSettings(),
          ),
          ChangeNotifierProvider(
            create: (_) => AccountsController()..loadAccounts(),
          ),
          ChangeNotifierProvider(
            create: (_) => BanksController(),
          ),
          ChangeNotifierProvider(
            create: (_) => BrokersController(),
          ),
          ChangeNotifierProvider(
            create: (_) => PaymentAppsController()..loadApps(),
          ),
          ChangeNotifierProvider(
            create: (_) => InvestmentsController()..loadInvestments(),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                InvestmentTypePreferencesController()..loadPreferences(),
          ),
          ChangeNotifierProvider(
            create: (_) => CategoriesController()..loadCategories(),
          ),
          ChangeNotifierProvider(
            create: (_) => LendingBorrowingController()..loadRecords(),
          ),
          ChangeNotifierProvider(
            create: (_) => ContactsController()..loadContacts(),
          ),
          ChangeNotifierProvider(
            create: (_) => TagsController()..loadTags(),
          ),
          ChangeNotifierProvider(
            create: (_) => TransactionsController()..loadTransactions(),
          ),
          ChangeNotifierProvider(
            create: (_) => TransactionsArchiveController(),
          ),
          ChangeNotifierProvider(
            create: (_) => DashboardController()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => GoalsController()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => BudgetsController()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => RecurringTemplatesController(),
          ),
          ChangeNotifierProvider(
            create: (_) => LoanController()..load(),
          ),
          ChangeNotifierProvider(
            create: (_) => InsuranceController()..load(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stackTrace) {
    logger.error('Uncaught Exception',
        context: 'ZonedGuarded', error: error, stackTrace: stackTrace);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = Provider.of<SettingsController>(context, listen: false);
    if (state == AppLifecycleState.paused) {
      settings.appPaused();
    } else if (state == AppLifecycleState.resumed) {
      settings.appResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsController>(context);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();
    final navTitle = GoogleFonts.spaceGrotesk(
      fontWeight: FontWeight.w700,
      fontSize: 18,
    );

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'VittaraFinOS',
      themeMode: settings.themeMode,
      // LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppStyles.accentBlue,
          secondary: AppStyles.accentOrange,
          tertiary: AppStyles.accentGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppStyles.lightBackground,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        textTheme: textTheme.apply(
          bodyColor: AppStyles.lightText,
          displayColor: AppStyles.lightText,
        ),
        cupertinoOverrideTheme: CupertinoThemeData(
          primaryColor: AppStyles.accentBlue,
          scaffoldBackgroundColor: AppStyles.lightBackground,
          barBackgroundColor: Colors.white.withValues(alpha: 0.95),
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
              color: AppStyles.lightText,
            ),
            navTitleTextStyle: TextStyle(
              fontFamily: navTitle.fontFamily,
              fontWeight: navTitle.fontWeight,
              fontSize: navTitle.fontSize,
              color: AppStyles.lightText,
            ),
          ),
        ),
      ),
      // DARK THEME (AMOLED — Aether system)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppStyles.aetherTeal, // phosphorescent primary
          secondary: AppStyles.novaPurple,
          tertiary: AppStyles.solarGold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppStyles.darkBackground,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: AppStyles.darkText,
          displayColor: AppStyles.darkText,
        ),
        cupertinoOverrideTheme: CupertinoThemeData(
          primaryColor: AppStyles.aetherTeal,
          scaffoldBackgroundColor: AppStyles.darkBackground,
          barBackgroundColor: const Color(0xFF000000),
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
              color: AppStyles.darkText,
            ),
            navTitleTextStyle: TextStyle(
              fontFamily: navTitle.fontFamily,
              fontWeight: navTitle.fontWeight,
              fontSize: navTitle.fontSize,
              color: AppStyles.darkText,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: ToastOverlay(
            child: Stack(
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                    decoration: TextDecoration.none,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppStyles.darkText
                        : AppStyles.lightText,
                  ),
                  child: child!,
                ),
                // LOCK SCREEN OVERLAY (disabled on web)
                if (settings.isLocked && settings.appLoaded && !kIsWeb)
                  const Positioned.fill(child: LockScreen()),
              ],
            ),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final List<String> _enteredDigits = [];
  bool _pinError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsController>(context, listen: false)
          .authenticateAndUnlock();
    });
  }

  void _onDigitTap(String digit, SettingsController settings) {
    if (_enteredDigits.length >= 6) return;
    setState(() {
      _enteredDigits.add(digit);
      _pinError = false;
    });
    if (_enteredDigits.length == 6) {
      _verifyPin(settings);
    }
  }

  void _onBackspace() {
    if (_enteredDigits.isEmpty) return;
    setState(() => _enteredDigits.removeLast());
  }

  Future<void> _verifyPin(SettingsController settings) async {
    final pin = _enteredDigits.join();
    if (settings.verifyPin(pin)) {
      settings.hidePinFallback();
      settings.authenticateAndUnlockWithPin();
    } else {
      setState(() {
        _pinError = true;
        _enteredDigits.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, settings, _) {
        final showPin = settings.showPinFallback;
        return PopScope(
          canPop: false, // Prevent back gesture from bypassing the lock screen
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: showPin
                  ? _buildPinEntry(context, settings)
                  : _buildBiometricWaiting(context, settings),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBiometricWaiting(
      BuildContext context, SettingsController settings) {
    return FadeInAnimation(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    SemanticColors.primary.withValues(alpha: 0.3),
                    SemanticColors.primary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SemanticColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.lock_shield_fill,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: Spacing.xxxl),
            const Text(
              'VittaraFinOS Locked',
              style: TextStyle(
                color: Colors.white,
                fontSize: TypeScale.title2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Authenticating...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: TypeScale.body,
              ),
            ),
            const SizedBox(height: Spacing.huge),
            const SizedBox(
              width: 40,
              height: 40,
              child: CupertinoActivityIndicator(
                color: Colors.white,
                radius: 15,
              ),
            ),
            if (settings.isPinEnabled) ...[
              const SizedBox(height: Spacing.xxxl),
              CupertinoButton(
                onPressed: settings.showPinEntryFallback,
                child: Text(
                  'Use PIN instead',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: TypeScale.body,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPinEntry(BuildContext context, SettingsController settings) {
    final dotColor = _pinError ? Colors.red : Colors.white;
    final btnSize =
        (MediaQuery.of(context).size.width / 5.5).clamp(56.0, 80.0);
    return Column(
      children: [
        const SizedBox(height: Spacing.xxxl),
        const Icon(CupertinoIcons.lock_fill, color: Colors.white, size: 40),
        const SizedBox(height: Spacing.lg),
        const Text(
          'Enter PIN',
          style: TextStyle(
            color: Colors.white,
            fontSize: TypeScale.title2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          _pinError ? 'Incorrect PIN. Try again.' : 'Enter your 6-digit PIN',
          style: TextStyle(
            color: _pinError ? Colors.red : Colors.white.withValues(alpha: 0.6),
            fontSize: TypeScale.body,
          ),
        ),
        const SizedBox(height: Spacing.xxxl),
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < _enteredDigits.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? dotColor : Colors.transparent,
                border: Border.all(
                  color: dotColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            );
          }),
        ),
        const Spacer(),
        // Numpad
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', '⌫'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: row.map((label) {
                      if (label.isEmpty) return SizedBox(width: btnSize, height: btnSize);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (label == '⌫') {
                            _onBackspace();
                          } else {
                            _onDigitTap(label, settings);
                          }
                        },
                        child: Container(
                          width: btnSize,
                          height: btnSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        if (settings.isBiometricEnabled) ...[
          CupertinoButton(
            onPressed: () {
              settings.hidePinFallback();
              settings.authenticateAndUnlock();
            },
            child: Text(
              'Use Biometric',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: TypeScale.body,
              ),
            ),
          ),
        ],
        CupertinoButton(
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const PinRecoveryScreen(),
              ),
            );
          },
          child: Text(
            'Forgot PIN?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: TypeScale.subhead,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    logger.info("Initializing SplashScreen state", context: 'SplashScreen');

    // Initialize MFDatabaseService in background (non-blocking)
    MFDatabaseService().initialize();

    Timer(const Duration(milliseconds: 3500), () async {
      if (!mounted) return;
      logger.info("Navigating from SplashScreen", context: 'SplashScreen');
      Provider.of<SettingsController>(context, listen: false).setAppLoaded();

      final done = await hasCompletedOnboarding();
      if (!mounted) return;

      if (done) {
        Navigator.of(context).pushReplacement(
            FadeScalePageRoute(page: const DashboardScreen()));
        _triggerSmsStartupScan();
      } else {
        Navigator.of(context).pushReplacement(
          FadeScalePageRoute(
            page: OnboardingScreen(
              onComplete: (ctx) {
                Navigator.of(ctx).pushReplacement(
                    FadeScalePageRoute(page: const DashboardScreen()));
                _triggerSmsStartupScan();
              },
            ),
          ),
        );
      }
    });
  }

  void _triggerSmsStartupScan() {
    final smsEnabled = Provider.of<SettingsController>(context, listen: false).isSmsEnabled;
    if (!smsEnabled) return;
    // Run silently — errors are swallowed so they never crash the app.
    Future.microtask(() async {
      try {
        await SmsAutoScanService.instance.runStartupScan(
          banksCtrl: Provider.of<BanksController>(context, listen: false),
          accountsCtrl: Provider.of<AccountsController>(context, listen: false),
          txCtrl: Provider.of<TransactionsController>(context, listen: false),
        );
      } catch (e) {
        logger.error('SMS startup scan failed', error: e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppStyles.darkText : AppStyles.lightText;
    final subColor =
        isDark ? const Color(0xFF6B8AAD) : Colors.black54;

    return Scaffold(
      backgroundColor:
          isDark ? AppStyles.darkBackground : AppStyles.lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FintechLoader(size: 200),
            const SizedBox(height: Spacing.xl),
            Text(
              'VittaraFinOS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Track Wealth, Master Life',
              style: TextStyle(
                fontSize: TypeScale.headline,
                color: subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<DashboardController>(
      builder: (context, dashboardController, child) {
        if (!dashboardController.isInitialized) {
          return Scaffold(
            backgroundColor: AppStyles.getBackground(context),
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 250,
                      child: FintechLoader(size: 220),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'Preparing your financial command center...',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // AU6-02 — Use cached getter instead of recomputing on every build
        final visibleWidgets = dashboardController.visibleWidgets;

        // Debug: Print visible widgets count
        if (kDebugMode) {
          print(
              'Dashboard: ${visibleWidgets.length} visible widgets out of ${dashboardController.config.widgets.length} total');
          for (var w in dashboardController.config.widgets) {
            print('  - ${w.id}: visible=${w.isVisible}');
          }
        }

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: BouncyButton(
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const DashboardAppMenuScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final slideTween = Tween<Offset>(
                        begin: const Offset(-1.0, 0.0),
                        end: Offset.zero,
                      ).chain(
                        CurveTween(curve: MotionCurves.standard),
                      );
                      final fadeTween = Tween<double>(
                        begin: 0.0,
                        end: 1.0,
                      ).chain(
                        CurveTween(curve: MotionCurves.standard),
                      );
                      return SlideTransition(
                        position: animation.drive(slideTween),
                        child: FadeTransition(
                          opacity: animation.drive(fadeTween),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: AppDurations.pageTransition,
                    reverseTransitionDuration:
                        AppDurations.pageTransitionReverse,
                  ),
                );
              },
              child: Semantics(
                label: 'Open app menu',
                child: Icon(
                  CupertinoIcons.line_horizontal_3,
                  size: IconSizes.navIcon,
                  color: AppStyles.getTextColor(context),
                ),
              ),
            ),
            middle: const Text('VittaraFinOS'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dashboard Settings
                Semantics(
                  label: 'Dashboard layout settings',
                  child: BouncyButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        FadeScalePageRoute(
                            page: const DashboardSettingsModal()),
                      );
                    },
                    child: Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: IconSizes.navIcon,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xl),
                // Manage button
                Semantics(
                  label: 'Manage accounts and investments',
                  child: BouncyButton(
                    onPressed: () {
                      Navigator.of(context).push(
                          FadeScalePageRoute(page: const ManageScreen()));
                    },
                    child: Icon(
                      CupertinoIcons.square_grid_2x2,
                      size: IconSizes.navIcon,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xl),
                // Settings button
                Semantics(
                  label: 'Settings',
                  child: BouncyButton(
                    onPressed: () {
                      Navigator.of(context).push(
                          FadeScalePageRoute(page: const SettingsScreen()));
                    },
                    child: Icon(
                      CupertinoIcons.settings,
                      size: IconSizes.navIcon,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor:
                AppStyles.getCardColor(context).withValues(alpha: 0.90),
            border: null,
          ),
          child: SafeArea(
            child: SubtleParticleOverlay(
              particleCount: isDark ? 42 : 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppStyles.backgroundGradient(context),
                ),
                child: Stack(
                  children: [
                    visibleWidgets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: AppStyles.iconBoxDecoration(
                                    context,
                                    AppStyles.accentBlue,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.square_grid_2x2,
                                    size: 42,
                                    color: AppStyles.getPrimaryColor(context),
                                  ),
                                ),
                                const SizedBox(height: Spacing.lg),
                                Text(
                                  'No widgets enabled',
                                  style: AppStyles.titleStyle(context).copyWith(
                                    fontSize: TypeScale.title2,
                                  ),
                                ),
                                const SizedBox(height: Spacing.sm),
                                Text(
                                  'All dashboard widgets are hidden',
                                  style: TextStyle(
                                    fontSize: TypeScale.body,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                                const SizedBox(height: Spacing.xl),
                                CupertinoButton.filled(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      FadeScalePageRoute(
                                          page: const DashboardSettingsModal()),
                                    );
                                  },
                                  child: const Text('Manage Dashboard'),
                                ),
                                const SizedBox(height: Spacing.sm),
                                CupertinoButton(
                                  onPressed: () async {
                                    if (kDebugMode) {
                                      print('Resetting dashboard to default');
                                    }
                                    await dashboardController.resetToDefault();
                                    if (context.mounted) {
                                      toast.showSuccess(
                                          'Dashboard reset to default');
                                    }
                                  },
                                  child: const Text('Reset to Default'),
                                ),
                              ],
                            ),
                          )
                        : _buildDashboardGrid(
                            context, dashboardController, visibleWidgets),
                    Positioned(
                      bottom: Spacing.lg,
                      right: Spacing.lg,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // SMS scan mini button (only if SMS Scanning enabled)
                          Consumer<SettingsController>(
                            builder: (_, settings, __) {
                              if (!settings.isSmsEnabled) return const SizedBox.shrink();
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BouncyButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        FadeScalePageRoute(
                                          page: const SmsReviewScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: AppStyles.isDarkMode(context)
                                            ? const Color(0xFF00D4AA).withValues(alpha: 0.10)
                                            : const Color(0xFFE0FAF5),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppStyles.aetherTeal
                                              .withValues(alpha: 0.40),
                                        ),
                                        boxShadow: AppStyles.elevatedShadows(
                                          context,
                                          tint: AppStyles.aetherTeal,
                                          strength: 0.35,
                                        ),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.chat_bubble_text_fill,
                                        color: AppStyles.aetherTeal,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.sm),
                                ],
                              );
                            },
                          ),
                          // Main + FAB
                          BouncyButton(
                            onPressed: () {
                              showDashboardActionSheet(context);
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppStyles.aetherTeal,
                                    AppStyles.novaPurple,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: AppStyles.elevatedShadows(
                                  context,
                                  tint: AppStyles.aetherTeal,
                                  strength: 0.90,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.add,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardGrid(
    BuildContext context,
    DashboardController controller,
    List<DashboardWidgetConfig> visibleWidgets,
  ) {
    return Column(
      children: [
        // PROFESSIONAL HEADER
        _buildHeaderSection(context),

        // REORDERABLE DASHBOARD WIDGETS
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.all(Spacing.lg),
            onReorder: (oldIndex, newIndex) {
              // Reorder in the visible widgets list
              final newVisibleWidgets = [...visibleWidgets];
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final widget = newVisibleWidgets.removeAt(oldIndex);
              newVisibleWidgets.insert(newIndex, widget);

              // Update controller with new order
              for (int i = 0; i < newVisibleWidgets.length; i++) {
                controller.updateWidget(
                  newVisibleWidgets[i].copyWith(gridRow: i + 1),
                );
              }
              controller.saveConfig();
            },
            children: visibleWidgets.asMap().entries.map((entry) {
              final widget = entry.value;
              return Container(
                key: Key(widget.id),
                margin: const EdgeInsets.only(bottom: Spacing.md),
                child: _buildDashboardWidgetCard(context, widget),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardWidgetCard(
    BuildContext context,
    DashboardWidgetConfig widgetConfig,
  ) {
    final accent = _widgetAccentColor(widgetConfig.type);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BouncyButton(
      onPressed: () => _handleWidgetTap(context, widgetConfig),
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: MotionCurves.standard,
        decoration: AppStyles.accentCardDecoration(context, accent),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent bar ──────────────────────────────────────
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent,
                        accent.withValues(alpha: 0.40),
                      ],
                    ),
                  ),
                ),

                // ── Card body ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Spacing.md, Spacing.md, Spacing.md, Spacing.xs),
                        child: Row(
                          children: [
                            // Icon badge
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                    alpha: isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(Radii.sm),
                                border: Border.all(
                                  color: accent.withValues(
                                      alpha: isDark ? 0.45 : 0.28),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(
                                _widgetIcon(widgetConfig.type),
                                size: 16,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                            // Title
                            Expanded(
                              child: Text(
                                widgetConfig.title,
                                style: TextStyle(
                                  fontSize: TypeScale.headline,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.getTextColor(context),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            // Drag handle + arrow
                            Icon(
                              CupertinoIcons.line_horizontal_3,
                              size: 16,
                              color: accent.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: accent.withValues(alpha: 0.70),
                            ),
                          ],
                        ),
                      ),

                      // Thin divider
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(
                            horizontal: Spacing.md),
                        color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                      ),

                      // Content — wrapped in RepaintBoundary so that when one
                      // widget's data source changes only that widget repaints,
                      // not the entire dashboard list.
                      RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                          child: _buildWidgetPreview(context, widgetConfig),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _widgetIcon(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.netWorth:
        return CupertinoIcons.chart_pie_fill;
      case DashboardWidgetType.goalsOverview:
        return CupertinoIcons.checkmark_seal_fill;
      case DashboardWidgetType.budgetsOverview:
        return CupertinoIcons.chart_bar_fill;
      case DashboardWidgetType.savingsPlanners:
        return CupertinoIcons.heart_fill;
      case DashboardWidgetType.aiPlanner:
        return CupertinoIcons.sparkles;
      case DashboardWidgetType.transactionHistory:
        return CupertinoIcons.arrow_right_arrow_left_circle_fill;
      case DashboardWidgetType.notificationsAndActions:
        return CupertinoIcons.bell_fill;
      case DashboardWidgetType.actions:
        return CupertinoIcons.bolt_fill;
      case DashboardWidgetType.monthlySummary:
        return CupertinoIcons.calendar_circle_fill;
      case DashboardWidgetType.sipTracker:
        return CupertinoIcons.graph_circle_fill;
      case DashboardWidgetType.healthScore:
        return CupertinoIcons.heart_fill;
    }
  }

  Color _widgetAccentColor(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.netWorth:
        return AppStyles.accentBlue;
      case DashboardWidgetType.goalsOverview:
        return AppStyles.accentTeal;
      case DashboardWidgetType.budgetsOverview:
        return AppStyles.accentCoral;
      case DashboardWidgetType.savingsPlanners:
        return AppStyles.accentGreen;
      case DashboardWidgetType.aiPlanner:
        return AppStyles.accentOrange;
      case DashboardWidgetType.transactionHistory:
        return SemanticColors.info;
      case DashboardWidgetType.notificationsAndActions:
        return SemanticColors.warning;
      case DashboardWidgetType.actions:
        return AppStyles.novaPurple;
      case DashboardWidgetType.monthlySummary:
        return AppStyles.accentGreen;
      case DashboardWidgetType.sipTracker:
        return CupertinoColors.activeBlue;
      case DashboardWidgetType.healthScore:
        return AppStyles.accentCoral;
    }
  }

  Widget _buildHeaderSection(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    final dateFormatter = _formatHeaderDate(now);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Container(
        decoration: AppStyles.heroCardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
          child: Stack(
            children: [
              // Ambient orbs for depth
              // Aether teal emission — top-right
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppStyles.aetherTeal.withValues(alpha: 0.22),
                        AppStyles.aetherTeal.withValues(alpha: 0.00),
                      ],
                    ),
                  ),
                ),
              ),
              // Nova violet emission — bottom-left
              Positioned(
                bottom: -50,
                left: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppStyles.novaPurple.withValues(alpha: 0.18),
                        AppStyles.novaPurple.withValues(alpha: 0.00),
                      ],
                    ),
                  ),
                ),
              ),
              // Subtle grid dots overlay
              Positioned.fill(
                child: CustomPaint(painter: _DotGridPainter(isDark: isDark)),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.xl, Spacing.lg, Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting + Status badge row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: const TextStyle(
                                  fontSize: TypeScale.title2,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFormatter,
                                style: TextStyle(
                                  fontSize: TypeScale.footnote,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: SemanticColors.success.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(Radii.full),
                            border: Border.all(
                              color: SemanticColors.success
                                  .withValues(alpha: 0.55),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: SemanticColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: SemanticColors.success,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: Spacing.lg),

                    // Divider line
                    Container(
                      height: 0.6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.00),
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.00),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: Spacing.lg),

                    // Quick action pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildQuickActionPill(
                            context,
                            'Goals',
                            CupertinoIcons.checkmark_seal_fill,
                            AppStyles.aetherTeal,
                          ),
                          const SizedBox(width: Spacing.sm),
                          _buildQuickActionPill(
                            context,
                            'Budgets',
                            CupertinoIcons.chart_pie_fill,
                            AppStyles.accentCoral,
                          ),
                          const SizedBox(width: Spacing.sm),
                          _buildQuickActionPill(
                            context,
                            'Savings',
                            CupertinoIcons.heart_fill,
                            AppStyles.accentGreen,
                          ),
                          const SizedBox(width: Spacing.sm),
                          _buildQuickActionPill(
                            context,
                            'AI Plan',
                            CupertinoIcons.sparkles,
                            AppStyles.accentOrange,
                          ),
                        ],
                      ),
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

  Widget _buildQuickActionPill(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return BouncyButton(
      onPressed: () => _handleQuickActionTap(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
            color: color.withValues(alpha: 0.50),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickActionTap(BuildContext context, String action) {
    switch (action) {
      case 'Goals':
        // Navigate to Goals screen
        Navigator.of(context).push(
          FadeScalePageRoute(page: const GoalsScreen()),
        );
        break;
      case 'Budgets':
        // Navigate to Budgets screen
        Navigator.of(context).push(
          FadeScalePageRoute(page: const BudgetsScreen()),
        );
        break;
      case 'Savings':
        // Navigate to Savings screen
        Navigator.of(context).push(
          FadeScalePageRoute(page: const SavingsPlannersScreen()),
        );
        break;
      case 'AI Plan':
        // Navigate to AI Monthly Planner screen
        Navigator.of(context).push(
          FadeScalePageRoute(page: const AIMonthlyPlannerScreen()),
        );
        break;
      default:
        break;
    }
  }

  String _formatHeaderDate(DateTime date) {
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
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return '${days[date.weekday - 1]}, ${date.day} ${DateFormatter.getMonthName(date.month)} ${date.year}';
  }

  Widget _buildWidgetPreview(
      BuildContext context, DashboardWidgetConfig widgetConfig) {
    switch (widgetConfig.type) {
      case DashboardWidgetType.netWorth:
        return Consumer2<AccountsController, InvestmentsController>(
          builder: (context, accountsController, investmentsController, child) {
            // Calculate Savings (non-credit accounts)
            double totalSavings = 0;
            for (var account in accountsController.accounts) {
              if (account.type != AccountType.credit &&
                  account.type != AccountType.payLater) {
                totalSavings += account.balance;
              }
            }

            // Calculate Investments (use current values)
            double totalInvestments = 0;
            for (var investment in investmentsController.investments) {
              final metadata = investment.metadata ?? {};
              final currentValue =
                  (metadata['currentValue'] as num?)?.toDouble();
              totalInvestments += currentValue ?? investment.amount;
            }

            // Calculate Credit (limit and used)
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

            // Net Worth = Savings + Investments - Credit Used
            final totalNetWorth =
                totalSavings + totalInvestments - totalCreditUsed;

            // Determine color based on positive/negative
            final isPositive = totalNetWorth >= 0;
            final displayColor = isPositive
                ? AppStyles.getPrimaryColor(context)
                : CupertinoColors.systemRed;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main Net Worth Card
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        displayColor.withValues(alpha: 0.15),
                        displayColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: displayColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Net Worth',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        '₹${totalNetWorth.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: TypeScale.largeTitle,
                          fontWeight: FontWeight.w800,
                          color: displayColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: displayColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Savings',
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                                Text(
                                  '₹${totalSavings.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: TypeScale.caption,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.systemGreen,
                                  ),
                                ),
                              ],
                            ),
                            if (totalInvestments > 0) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Investments',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                  Text(
                                    '₹${totalInvestments.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: TypeScale.caption,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.activeBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (totalCreditUsed > 0) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Credit Used',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                  Text(
                                    '₹${totalCreditUsed.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: TypeScale.caption,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.systemRed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      case DashboardWidgetType.goalsOverview:
        return Consumer<GoalsController>(
          builder: (context, goalsController, child) {
            final activeGoals = goalsController.activeGoals.length;
            final totalSaved = goalsController.totalSavedAmount;
            final totalTarget = goalsController.totalTargetAmount;
            final progress = totalTarget > 0
                ? (totalSaved / totalTarget).clamp(0, 1).toDouble()
                : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$activeGoals Active Goal${activeGoals == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% Complete',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      AppStyles.getBackground(context).withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      CupertinoColors.activeBlue),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved ₹${totalSaved.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: TypeScale.footnote,
                          color: CupertinoColors.systemGreen),
                    ),
                    Text(
                      'Goal ₹${totalTarget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      case DashboardWidgetType.budgetsOverview:
        return Consumer<BudgetsController>(
          builder: (context, budgetsController, child) {
            final activeCount = budgetsController.activeBudgets.length;
            final exceeded = budgetsController.getBudgetsExceedingLimit();
            final warning = budgetsController.getBudgetsInWarning();
            final alertBudgets = [...exceeded, ...warning].take(3).toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$activeCount Active Budget${activeCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ),
                    if (exceeded.isNotEmpty)
                      _buildBadge(context, 'Over', exceeded.length,
                          CupertinoColors.systemRed),
                    if (warning.isNotEmpty) ...[
                      const SizedBox(width: Spacing.xs),
                      _buildBadge(context, 'Near', warning.length,
                          CupertinoColors.systemOrange),
                    ],
                  ],
                ),
                if (alertBudgets.isNotEmpty) ...[
                  const SizedBox(height: Spacing.md),
                  ...alertBudgets.map((b) {
                    final isExceeded = b.status.name == 'exceeded';
                    final color = isExceeded
                        ? CupertinoColors.systemRed
                        : CupertinoColors.systemOrange;
                    final pct = b.usagePercentage.toStringAsFixed(0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: Spacing.xs),
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExceeded
                                ? CupertinoIcons.exclamationmark_circle_fill
                                : CupertinoIcons.exclamationmark_triangle_fill,
                            size: 12,
                            color: color,
                          ),
                          const SizedBox(width: Spacing.xs),
                          Expanded(
                            child: Text(
                              b.name,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                fontWeight: FontWeight.w600,
                                color: AppStyles.getTextColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else if (activeCount > 0) ...[
                  const SizedBox(height: Spacing.md),
                  const Row(
                    children: [
                      Icon(CupertinoIcons.checkmark_seal_fill,
                          size: 13, color: AppStyles.accentGreen),
                      SizedBox(width: Spacing.xs),
                      Text(
                        'All budgets on track',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.accentGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      case DashboardWidgetType.savingsPlanners:
        return Consumer<BudgetsController>(
          builder: (context, budgetsController, child) {
            final plannerCount = budgetsController.savingsplanners.length;
            final totalTarget = budgetsController.totalMonthlySavingsTarget;
            final totalSaved = budgetsController.totalMonthlySaved;
            final ratio = totalTarget > 0
                ? (totalSaved / totalTarget).clamp(0, 1).toDouble()
                : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$plannerCount Savings Planner${plannerCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor:
                      AppStyles.getBackground(context).withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      CupertinoColors.systemGreen),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved ₹${totalSaved.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: TypeScale.footnote,
                          color: CupertinoColors.systemGreen),
                    ),
                    Text(
                      'Target ₹${totalTarget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      case DashboardWidgetType.aiPlanner:
        return Consumer2<GoalsController, BudgetsController>(
          builder: (context, goalsController, budgetsController, child) {
            final progress = goalsController.overallProgress;
            final recommendedSavings =
                goalsController.totalRecommendedMonthlySavings;
            final budgetWarnings =
                budgetsController.getBudgetsInWarning().length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Planner Score',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    const Icon(CupertinoIcons.lightbulb,
                        size: 16, color: Colors.purple),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '${progress.toStringAsFixed(0)}% Financial Health',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Recommended monthly savings: ₹${recommendedSavings.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                Text(
                  budgetWarnings > 0
                      ? '$budgetWarnings budgets need attention'
                      : 'Budget health looks stable',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: budgetWarnings > 0
                        ? CupertinoColors.systemOrange
                        : CupertinoColors.systemGreen,
                  ),
                ),
              ],
            );
          },
        );
      case DashboardWidgetType.transactionHistory:
        return Consumer2<TransactionsController, InvestmentsController>(
          builder:
              (context, transactionController, investmentsController, child) {
            final transactions = TransactionFeedBuilder.buildUnifiedFeed(
              transactions: transactionController.transactions,
              investments: investmentsController.investments,
            ).take(3).toList();

            if (transactions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.doc_text,
                      size: 32,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: transactions.asMap().entries.map((entry) {
                final isLast = entry.key == transactions.length - 1;
                final tx = entry.value;
                final amount = tx.amount;
                final isDebit = tx.type == TransactionType.expense ||
                    tx.type == TransactionType.investment ||
                    tx.type == TransactionType.lending;

                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (isDebit
                                    ? CupertinoColors.systemRed
                                    : CupertinoColors.systemGreen)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isDebit
                                ? CupertinoIcons.arrow_up
                                : CupertinoIcons.arrow_down,
                            size: 18,
                            color: isDebit
                                ? CupertinoColors.systemRed
                                : CupertinoColors.systemGreen,
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tx.description,
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Just now',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isDebit ? '-' : '+'}₹${amount.abs().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.bold,
                            color: isDebit
                                ? CupertinoColors.systemRed
                                : CupertinoColors.systemGreen,
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
            );
          },
        );
      case DashboardWidgetType.monthlySummary:
        return Consumer<TransactionsController>(
          builder: (context, txController, child) {
            final now = DateTime.now();
            final monthStart = DateTime(now.year, now.month, 1);
            final monthLabel =
                '${DateFormatter.getMonthName(now.month)} ${now.year}';

            double income = 0;
            double expenses = 0;
            for (final tx in txController.transactions) {
              if (tx.dateTime.isBefore(monthStart)) continue;
              if (tx.type == TransactionType.income ||
                  tx.type == TransactionType.cashback) {
                income += tx.amount;
              } else if (tx.type == TransactionType.expense) {
                expenses += tx.amount;
              }
            }
            final net = income - expenses;
            final total = income + expenses;
            final incomeRatio =
                total > 0 ? (income / total).clamp(0.0, 1.0) : 0.5;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getSecondaryTextColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _buildMonthlyStat(
                        context,
                        label: 'Income',
                        amount: income,
                        color: CupertinoColors.systemGreen,
                        icon: CupertinoIcons.arrow_down_circle_fill,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: _buildMonthlyStat(
                        context,
                        label: 'Expenses',
                        amount: expenses,
                        color: CupertinoColors.systemRed,
                        icon: CupertinoIcons.arrow_up_circle_fill,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: _buildMonthlyStat(
                        context,
                        label: 'Saved',
                        amount: net.abs(),
                        color: net >= 0
                            ? AppStyles.accentTeal
                            : CupertinoColors.systemOrange,
                        icon: net >= 0
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.exclamationmark_circle_fill,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Flexible(
                        flex: (incomeRatio * 100).round(),
                        child: Container(
                          height: 6,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                      Flexible(
                        flex: ((1 - incomeRatio) * 100).round(),
                        child: Container(
                          height: 6,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                ),
                // F30 — Savings rate
                if (income > 0) ...[
                  const SizedBox(height: Spacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        CupertinoIcons.percent,
                        size: 11,
                        color: net >= 0
                            ? AppStyles.accentTeal
                            : CupertinoColors.systemOrange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Savings rate: ${((net / income) * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: net >= 0
                              ? AppStyles.accentTeal
                              : CupertinoColors.systemOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                // AU13-05 — Logging streak counter
                Builder(builder: (context) {
                  final streak = txController.loggingStreakDays;
                  if (streak == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemOrange
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: CupertinoColors.systemOrange
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.flame_fill,
                            size: 13,
                            color: CupertinoColors.systemOrange,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$streak-day logging streak',
                            style: const TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      case DashboardWidgetType.sipTracker:
        return Consumer<InvestmentsController>(
          builder: (context, investmentsController, child) {
            final activeSips = investmentsController.investments
                .where((inv) => inv.metadata?['sipActive'] == true)
                .toList();

            if (activeSips.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.repeat,
                        size: 28,
                        color: AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.4)),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'No active SIPs',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              );
            }

            double totalMonthly = 0;
            for (final inv in activeSips) {
              final meta = inv.metadata ?? {};
              final sipData = meta['sipData'] as Map<String, dynamic>?;
              final freq = (sipData?['frequency'] as String? ??
                      meta['sipFrequency'] as String? ??
                      'monthly')
                  .toLowerCase();
              double amt = (sipData?['sipAmount'] as num?)?.toDouble() ??
                  (meta['sipAmount'] as num?)?.toDouble() ??
                  0.0;
              if (freq == 'weekly') amt *= 4.33;
              if (freq == 'quarterly') amt /= 3;
              if (freq == 'yearly' || freq == 'annual') amt /= 12;
              totalMonthly += amt;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${activeSips.length} active SIP${activeSips.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '~₹${totalMonthly.toStringAsFixed(0)}/mo',
                      style: const TextStyle(
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                ...activeSips.take(4).map((inv) {
                  final meta = inv.metadata ?? {};
                  final sipData = meta['sipData'] as Map<String, dynamic>?;
                  final freq = sipData?['frequency'] as String? ??
                      meta['sipFrequency'] as String? ??
                      'monthly';
                  final amt = (sipData?['sipAmount'] as num?)?.toDouble() ??
                      (meta['sipAmount'] as num?)?.toDouble() ??
                      0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.repeat,
                            size: 12,
                            color: CupertinoColors.activeBlue
                                .withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            inv.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          amt > 0 ? '₹${amt.toStringAsFixed(0)} · $freq' : freq,
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (activeSips.length > 4)
                  Text(
                    '+${activeSips.length - 4} more',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
              ],
            );
          },
        );
      case DashboardWidgetType.notificationsAndActions:
        return Consumer<InvestmentsController>(
          builder: (context, investmentsController, child) {
            final fdsNearMaturity =
                investmentsController.investments.where((inv) {
              if (inv.type.name != 'fixedDeposit') return false;
              final metadata = inv.metadata;
              if (metadata == null || !metadata.containsKey('maturityDate')) {
                return false;
              }
              final maturityDate =
                  DateTime.parse(metadata['maturityDate'] as String);
              final daysUntil = maturityDate.difference(DateTime.now()).inDays;
              return daysUntil <= 10 && daysUntil >= 0;
            }).toList();

            final fdsMatured = investmentsController.investments.where((inv) {
              if (inv.type.name != 'fixedDeposit') return false;
              final metadata = inv.metadata;
              if (metadata == null || !metadata.containsKey('maturityDate')) {
                return false;
              }
              final maturityDate =
                  DateTime.parse(metadata['maturityDate'] as String);
              final daysUntil = maturityDate.difference(DateTime.now()).inDays;
              return daysUntil < 0;
            }).toList();

            final sipNotifications =
                collectSipNotifications(investmentsController.investments);
            final bondNotifications = collectBondPayoutNotifications(
                investmentsController.investments);
            final hasAnyNotification = fdsMatured.isNotEmpty ||
                fdsNearMaturity.isNotEmpty ||
                sipNotifications.isNotEmpty ||
                bondNotifications.isNotEmpty;

            if (!hasAnyNotification) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.bell_slash,
                      size: 30,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'No active notifications',
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            const maxPreviewItems = 3;
            final alerts = <Widget>[
              if (fdsMatured.isNotEmpty)
                _buildCompactDashboardAlert(
                  context,
                  icon: CupertinoIcons.exclamationmark_circle_fill,
                  color: CupertinoColors.systemRed,
                  title:
                      '${fdsMatured.length} FD${fdsMatured.length > 1 ? 's' : ''} matured',
                  subtitle: 'Action required',
                ),
              if (fdsNearMaturity.isNotEmpty)
                _buildCompactDashboardAlert(
                  context,
                  icon: CupertinoIcons.bell_fill,
                  color: CupertinoColors.systemOrange,
                  title:
                      '${fdsNearMaturity.length} FD${fdsNearMaturity.length > 1 ? 's' : ''} maturing soon',
                  subtitle: 'Within 10 days',
                ),
              ...sipNotifications.map(
                  (entry) => _buildDashboardSipNotification(context, entry)),
              ...bondNotifications.map(
                  (entry) => _buildDashboardBondNotification(context, entry)),
            ];
            final previewAlerts = alerts.take(maxPreviewItems).toList();
            final hiddenCount = alerts.length - previewAlerts.length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...previewAlerts,
                if (hiddenCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Spacing.xs,
                      left: Spacing.xs,
                    ),
                    child: Text(
                      '+$hiddenCount more alerts. Tap to view all',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      case DashboardWidgetType.healthScore:
        return HealthScoreWidget(config: widgetConfig);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBadge(
    BuildContext context,
    String label,
    int value,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.circle_fill,
            size: 8,
            color: color,
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            '$label $value',
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  void _handleWidgetTap(
      BuildContext context, DashboardWidgetConfig widgetConfig) {
    switch (widgetConfig.type) {
      case DashboardWidgetType.transactionHistory:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const TransactionHistoryScreen()),
        );
        break;
      case DashboardWidgetType.netWorth:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const NetWorthPage()),
        );
        break;
      case DashboardWidgetType.goalsOverview:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const GoalsScreen()),
        );
        break;
      case DashboardWidgetType.budgetsOverview:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const BudgetsScreen()),
        );
        break;
      case DashboardWidgetType.savingsPlanners:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const SavingsPlannersScreen()),
        );
        break;
      case DashboardWidgetType.aiPlanner:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const AIMonthlyPlannerScreen()),
        );
        break;
      case DashboardWidgetType.notificationsAndActions:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const NotificationsPage()),
        );
        break;
      case DashboardWidgetType.monthlySummary:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const TransactionHistoryScreen()),
        );
        break;
      case DashboardWidgetType.sipTracker:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const NotificationsPage()),
        );
        break;
      case DashboardWidgetType.healthScore:
        // No dedicated detail screen — widget is self-contained
        break;
      default:
        break;
    }
  }

  Widget _buildDashboardSipNotification(
      BuildContext context, SipNotificationInfo entry) {
    final amountText =
        entry.amount > 0 ? '₹${entry.amount.toStringAsFixed(0)}' : '₹—';
    final dueLabel = entry.daysUntil < 0
        ? 'Overdue by ${entry.daysUntil.abs()} day${entry.daysUntil.abs() > 1 ? 's' : ''}'
        : entry.daysUntil == 0
            ? 'Due today'
            : 'In ${entry.daysUntil} day${entry.daysUntil > 1 ? 's' : ''}';
    return _buildCompactDashboardAlert(
      context,
      icon: CupertinoIcons.repeat,
      color: CupertinoColors.activeBlue,
      title: entry.investment.name,
      subtitle: '${entry.frequencyLabel} • $amountText • $dueLabel',
    );
  }

  Widget _buildCompactDashboardAlert(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStat(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: Spacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppStyles.getSecondaryTextColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          '₹${amount >= 1e7 ? '${(amount / 1e7).toStringAsFixed(1)}Cr' : amount >= 1e5 ? '${(amount / 1e5).toStringAsFixed(1)}L' : amount >= 1e3 ? '${(amount / 1e3).toStringAsFixed(1)}K' : amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: TypeScale.body,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardBondNotification(
    BuildContext context,
    BondPayoutNotificationInfo entry,
  ) {
    final dueLabel = entry.daysUntil == 0
        ? 'Due today'
        : 'In ${entry.daysUntil} day${entry.daysUntil > 1 ? 's' : ''}';

    return _buildCompactDashboardAlert(
      context,
      icon: CupertinoIcons.money_dollar,
      color: Colors.teal,
      title: entry.investment.name,
      subtitle: 'Payout #${entry.schedule.payoutNumber} • $dueLabel',
    );
  }
}

extension on List<DashboardWidgetConfig> {
  DashboardWidgetConfig? firstWhereOrNull(
      bool Function(DashboardWidgetConfig) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

/// Subtle dot grid overlay — adds premium texture to hero card backgrounds.
class _DotGridPainter extends CustomPainter {
  final bool isDark;
  const _DotGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.035 : 0.12)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    const radius = 1.2;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
