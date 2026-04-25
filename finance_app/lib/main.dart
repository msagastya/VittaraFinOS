import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
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
import 'package:vittara_fin_os/logic/ai_planner_context.dart';
import 'package:vittara_fin_os/logic/backup_restore_service.dart';
import 'package:vittara_fin_os/logic/ai/device_intelligence_tier.dart';
import 'package:vittara_fin_os/logic/ai/merchant_normalizer.dart';
import 'package:vittara_fin_os/logic/ai/ai_intelligence_controller.dart';
import 'package:vittara_fin_os/logic/ai/voice_controller.dart';
import 'package:vittara_fin_os/logic/loan_controller.dart';
import 'package:vittara_fin_os/logic/insurance_controller.dart';
import 'package:vittara_fin_os/ui/fintech_loader.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/spending_insights_screen.dart';
import 'package:vittara_fin_os/ui/financial_calendar_screen.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/loan_model.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/services/usage_tracker_service.dart';
import 'package:vittara_fin_os/services/usage_timing_service.dart';
import 'package:vittara_fin_os/ui/onboarding/onboarding_activation_screen.dart';
import 'package:vittara_fin_os/services/tooltip_service.dart';
import 'package:vittara_fin_os/ui/widgets/coach_mark.dart';
import 'package:vittara_fin_os/ui/styles/app_springs.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/ui/dashboard/dashboard_action_sheet.dart';
import 'package:vittara_fin_os/ui/dashboard/ai_tray_sheet.dart';
import 'package:vittara_fin_os/ui/notifications_page.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/dashboard/dashboard_settings_modal.dart';
import 'package:vittara_fin_os/ui/net_worth_page.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/card_deck_view.dart';
import 'package:vittara_fin_os/ui/widgets/floating_particle_background.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/services/database_service.dart';
import 'package:vittara_fin_os/services/security/device_security_service.dart';
import 'package:vittara_fin_os/services/mf_database_service.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/ui/manage/goals/goals_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/onboarding_screen.dart';
import 'package:vittara_fin_os/ui/manage/savings/savings_planners_screen.dart';
import 'package:vittara_fin_os/ui/manage/ai_planner/ai_monthly_planner_screen.dart';
import 'package:vittara_fin_os/ui/manage/reports_analysis_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/app_menu/app_menu_screen.dart';
import 'package:vittara_fin_os/ui/sms/sms_review_screen.dart';
import 'package:vittara_fin_os/services/sms_auto_scan_service.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/pin_recovery_screen.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/budget_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/cash_flow_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/insights_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/net_worth_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/transaction_history_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/engagement_strip_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/ai_insights_strip.dart';
import 'package:vittara_fin_os/logic/engagement_service.dart';
import 'package:vittara_fin_os/ui/engagement/achievements_screen.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/health_score_widget.dart';
import 'package:vittara_fin_os/ui/widgets/global_search_overlay.dart';
import 'package:vittara_fin_os/ui/widgets/command_bar.dart';
import 'package:vittara_fin_os/ui/whats_new_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart' as sp;

final AppLogger logger = AppLogger();

/// Fires once after a transaction is successfully saved from the quick-entry
/// sheet. The dashboard FAB listens to this and plays its checkmark morph.
final dashboardSavedSignal = ValueNotifier<int>(0);

/// Hard-stop scroll physics applied to every scrollable in the app.
/// ClampingScrollPhysics prevents lists from drifting past top/bottom
/// boundaries and getting stuck — consistent Android scroll behaviour.
class _AppScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Device security checks + screenshot protection — before any UI renders.
    unawaited(DeviceSecurityService.instance.check());
    unawaited(DeviceSecurityService.instance.enableScreenshotProtection());

    // Open encrypted SQLite DB and run one-time SharedPreferences migration
    // BEFORE any controller initializes so load() calls find data in SQLite.
    try {
      await DatabaseService.instance.open();
      await DatabaseService.instance.seedFromExternalFileIfPresent();
      await DatabaseService.instance.migrateFromSharedPrefsIfNeeded();
    } catch (e) {
      logger.error('DatabaseService init failed', error: e);
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      logger.error('Flutter Framework Error',
          context: 'Main', error: details.exception, stackTrace: details.stack);
    };

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            try { return SettingsController()..loadSettings(); }
            catch (e) { logger.error('SettingsController init failed', error: e); return SettingsController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return AccountsController()..loadAccounts(); }
            catch (e) { logger.error('AccountsController init failed', error: e); return AccountsController(); }
          }),
          ChangeNotifierProvider(create: (_) => BanksController()),
          ChangeNotifierProvider(create: (_) => BrokersController()),
          ChangeNotifierProvider(create: (_) {
            try { return PaymentAppsController()..loadApps(); }
            catch (e) { logger.error('PaymentAppsController init failed', error: e); return PaymentAppsController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return InvestmentsController()..loadInvestments(); }
            catch (e) { logger.error('InvestmentsController init failed', error: e); return InvestmentsController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return InvestmentTypePreferencesController()..loadPreferences(); }
            catch (e) { logger.error('InvestmentTypePreferencesController init failed', error: e); return InvestmentTypePreferencesController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return CategoriesController()..loadCategories(); }
            catch (e) { logger.error('CategoriesController init failed', error: e); return CategoriesController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return LendingBorrowingController()..loadRecords(); }
            catch (e) { logger.error('LendingBorrowingController init failed', error: e); return LendingBorrowingController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return ContactsController()..loadContacts(); }
            catch (e) { logger.error('ContactsController init failed', error: e); return ContactsController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return TagsController()..loadTags(); }
            catch (e) { logger.error('TagsController init failed', error: e); return TagsController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return TransactionsController()..loadTransactions(); }
            catch (e) { logger.error('TransactionsController init failed', error: e); return TransactionsController(); }
          }),
          ChangeNotifierProvider(create: (_) => TransactionsArchiveController()),
          ChangeNotifierProvider(create: (_) {
            try { return DashboardController()..initialize(); }
            catch (e) { logger.error('DashboardController init failed', error: e); return DashboardController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return GoalsController()..initialize(); }
            catch (e) { logger.error('GoalsController init failed', error: e); return GoalsController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return BudgetsController()..initialize(); }
            catch (e) { logger.error('BudgetsController init failed', error: e); return BudgetsController(); }
          }),
          ChangeNotifierProvider(create: (_) => RecurringTemplatesController()),
          ChangeNotifierProvider(create: (_) => FinancialPlansController()),
          ChangeNotifierProvider(create: (_) {
            try { return LoanController()..load(); }
            catch (e) { logger.error('LoanController init failed', error: e); return LoanController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return InsuranceController()..load(); }
            catch (e) { logger.error('InsuranceController init failed', error: e); return InsuranceController(); }
          }),
          ChangeNotifierProvider(create: (_) {
            try { return EngagementService()..initialize(); }
            catch (e) { logger.error('EngagementService init failed', error: e); return EngagementService(); }
          }),
          ChangeNotifierProvider(create: (ctx) {
            try {
              final ctrl = AIIntelligenceController();
              // Wire live data providers after the Provider tree is ready.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  final accounts = Provider.of<AccountsController>(ctx, listen: false);
                  final budgetsCtrl = Provider.of<BudgetsController>(ctx, listen: false);
                  final goalsCtrl = Provider.of<GoalsController>(ctx, listen: false);
                  ctrl.wireProviders(AIDataProviders(
                    accountCount: () => accounts.accounts.length,
                    accountBalances: () => {
                      for (final a in accounts.accounts) a.id: a.balance,
                    },
                    budgets: () => budgetsCtrl.budgets.map((b) => b.toMap()).toList(),
                    goals: () => goalsCtrl.activeGoals,
                  ));
                } catch (e) {
                  logger.error('AIDataProviders wiring failed', error: e);
                }
              });
              ctrl.init(); // fire-and-forget, non-blocking
              return ctrl;
            } catch (e) {
              logger.error('AIIntelligenceController init failed', error: e);
              return AIIntelligenceController();
            }
          }),
          ChangeNotifierProvider(create: (_) => VoiceController()),
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
  // Tracks whether a _LockDialog is already on the navigator stack.
  // Prevents duplicate dialogs when the biometric prompt causes a resume event
  // while the lock screen is already handling authentication.
  bool _lockDialogActive = false;

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
      // Re-show lock screen if lock is active — but only if one isn't already shown.
      if (settings.lockOnMinimize && settings.isLocked && settings.appLoaded &&
          !kIsWeb && !_lockDialogActive) {
        _showLockDialog();
      }
    }
  }

  void _showLockDialog() {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    _lockDialogActive = true;
    nav.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const _LockDialog(),
      ),
    ).then((_) => _lockDialogActive = false);
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
                  child: ScrollConfiguration(
                    behavior: _AppScrollBehavior(),
                    child: child!,
                  ),
                ),
                // Lock screen is shown via _LockDialog (dialog route) on resume.
                // Kept as fallback Positioned.fill only during initial cold start.
                if (settings.isLocked && settings.appLoaded && !kIsWeb)
                  Positioned.fill(
                    child: GestureDetector(
                      // Absorb horizontal swipes to prevent iOS edge-swipe bypass.
                      onHorizontalDragUpdate: (_) {},
                      child: const LockScreen(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      navigatorObservers: [_UsageRouteObserver()],
      home: const SplashScreen(),
    );
  }
}

/// Tracks every named route push/replace in [UsageTrackerService].
class _UsageRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      UsageTrackerService.instance.record(name);
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final name = newRoute?.settings.name;
    if (name != null && name.isNotEmpty) {
      UsageTrackerService.instance.record(name);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
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
            Text(
              'VittaraFinOS Locked',
              style: TextStyle(
                color: Colors.white,
                fontSize: RT.title2(context),
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
            const SizedBox(height: Spacing.xxxl),
            if (settings.isPinEnabled)
              CupertinoButton(
                onPressed: settings.showPinEntryFallback,
                child: Text(
                  'Use PIN instead',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: TypeScale.body,
                  ),
                ),
              )
            else
              CupertinoButton(
                onPressed: settings.authenticateAndUnlock,
                child: Text(
                  'Try again',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: TypeScale.body,
                  ),
                ),
              ),
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
        Text(
          'Enter PIN',
          style: TextStyle(
            color: Colors.white,
            fontSize: RT.title2(context),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: RT.title1(context),
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

    _waitForReadyThenNavigate();
  }

  Future<void> _waitForReadyThenNavigate() async {
    // Wait for minimum splash duration AND DashboardController to be ready.
    // Cap the wait at 5s to avoid hanging indefinitely on slow devices.
    final dashCtrl = Provider.of<DashboardController>(context, listen: false);
    const minWait = Duration(milliseconds: 1200);
    const maxWait = Duration(seconds: 5);

    await Future.any([
      Future.wait([
        Future.delayed(minWait),
        Future.doWhile(() async {
          if (dashCtrl.isInitialized) return false;
          await Future.delayed(const Duration(milliseconds: 100));
          return true;
        }),
      ]),
      Future.delayed(maxWait),
    ]);

    if (!mounted) return;
    logger.info("Navigating from SplashScreen", context: 'SplashScreen');
    Provider.of<SettingsController>(context, listen: false).setAppLoaded();
    // Track session for feature-discovery tooltips
    await TooltipService.instance.incrementSession();

      final v1Done = await hasCompletedOnboarding();
      final v2Done = await hasCompletedActivation();
      if (!mounted) return;

      void _goToDashboard() {
        Navigator.of(context).pushReplacement(
            FadeScalePageRoute(page: const DashboardScreen()));
        _triggerSmsStartupScan();
        _checkAndShowWhatsNew();
        _showDeviceSecurityWarningIfNeeded();
        _checkOptimiseDashboardPrompt();
        BackupRestoreService.runAutoBackupIfNeeded();
        DeviceIntelligenceTier.detect();
        MerchantNormalizer.init();
        UsageTimingService.instance.recordAppOpen(); // T-145/T-146
      }

      if (v1Done || v2Done) {
        // Existing user (v1) or activation-complete user (v2) → dashboard
        _goToDashboard();
      } else {
        // New user → show activation wizard
        Navigator.of(context).pushReplacement(
          FadeScalePageRoute(
            page: OnboardingActivationScreen(
              onComplete: _goToDashboard,
            ),
          ),
        );
      }
  }

  /// T-138: Show a one-time warning if the device is rooted or an emulator.
  /// Stores `security_warning_shown` in SharedPreferences so it is shown
  /// only once, not on every launch.
  void _showDeviceSecurityWarningIfNeeded() {
    final warning = DeviceSecurityService.instance.warningMessage;
    if (warning == null) return;
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      final prefs = await sp.SharedPreferences.getInstance();
      if (prefs.getBool('security_warning_shown') == true) return;
      await prefs.setBool('security_warning_shown', true);
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Security Warning'),
          content: Text(warning),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('I Understand'),
              onPressed: () => Navigator.of(_, rootNavigator: true).pop(),
            ),
          ],
        ),
      );
    });
  }

  /// T-140: After 14 days of usage, offer one-time "Optimise my dashboard" prompt.
  void _checkOptimiseDashboardPrompt() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final should = await UsageTrackerService.instance.shouldShowOptimisePrompt();
      if (!should || !mounted) return;
      await UsageTrackerService.instance.markOptimisePromptShown();
      if (!mounted) return;
      final dashCtrl = context.read<DashboardController>();
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Optimise your dashboard?'),
          content: const Text(
              'Based on how you use the app, we can reorder your dashboard widgets to show the most-used cards first.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Not now'),
              onPressed: () => Navigator.pop(_, false),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Optimise'),
              onPressed: () => Navigator.pop(_, true),
            ),
          ],
        ),
      );
      if (ok == true) {
        final tapCounts =
            await UsageTrackerService.instance.widgetTapCounts();
        await dashCtrl.reorderByUsage(tapCounts);
      }
    });
  }

  /// AU20-02 — Show "What's New" once on first launch after an app update.
  void _checkAndShowWhatsNew() {
    const currentVersion = WhatsNewSheet.currentVersion;
    Future.microtask(() async {
      final prefs = await sp.SharedPreferences.getInstance();
      final lastSeen = prefs.getString('lastSeenVersion') ?? '';
      if (lastSeen != currentVersion) {
        await prefs.setString('lastSeenVersion', currentVersion);
        if (!mounted) return;
        // Small delay so the dashboard finishes its entrance animation first
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => const WhatsNewSheet(),
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
                fontSize: RT.largeTitle(context),
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

// ---------------------------------------------------------------------------
// _EngagementChecker — zero-size widget that triggers achievements & digest
// ---------------------------------------------------------------------------

class _EngagementChecker extends StatefulWidget {
  const _EngagementChecker();

  @override
  State<_EngagementChecker> createState() => _EngagementCheckerState();
}

class _EngagementCheckerState extends State<_EngagementChecker> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_checked || !mounted) return;
    _checked = true;

    final eng = Provider.of<EngagementService>(context, listen: false);
    if (!eng.initialized) return;

    final txCtrl = Provider.of<TransactionsController>(context, listen: false);
    final accCtrl = Provider.of<AccountsController>(context, listen: false);
    final budgetCtrl = Provider.of<BudgetsController>(context, listen: false);
    final goalCtrl = Provider.of<GoalsController>(context, listen: false);
    final invCtrl = Provider.of<InvestmentsController>(context, listen: false);

    // Evaluate streaks
    await eng.evaluateBudgetStreak(budgetCtrl.budgets);
    await eng.evaluateSavingsStreak(txCtrl.transactions);

    // Check achievements
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    double income = 0, expenses = 0;
    for (final tx in txCtrl.transactions) {
      if (tx.dateTime.isBefore(monthStart)) continue;
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback) {
        income += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expenses += tx.amount;
      }
    }

    final hs = computeHealthScore(
      transactions: txCtrl.transactions,
      budgets: budgetCtrl.budgets,
      investments: invCtrl.investments,
      accounts: accCtrl.accounts,
    );

    await eng.checkAchievements(
      transactions: txCtrl.transactions,
      accounts: accCtrl.accounts,
      budgets: budgetCtrl.budgets,
      goals: goalCtrl.activeGoals,
      investments: invCtrl.investments,
      healthScore: hs.total,
    );

    if (!mounted) return;

    // Show pending achievement overlays (one at a time)
    final pending = eng.consumePendingAchievements();
    for (final id in pending) {
      if (!mounted) break;
      await AchievementUnlockOverlay.show(context, id);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;

    // Show monthly digest on first 5 days of month
    if (eng.shouldShowDigest) {
      await eng.markDigestShown();
      if (mounted) {
        _showMonthlyDigest(context, eng, txCtrl, budgetCtrl, goalCtrl);
      }
    }
  }

  void _showMonthlyDigest(
    BuildContext context,
    EngagementService eng,
    TransactionsController txCtrl,
    BudgetsController budgetCtrl,
    GoalsController goalCtrl,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _MonthlyDigestSheet(
        eng: eng,
        txCtrl: txCtrl,
        budgetCtrl: budgetCtrl,
        goalCtrl: goalCtrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Monthly Digest Sheet
// ---------------------------------------------------------------------------

class _MonthlyDigestSheet extends StatelessWidget {
  final EngagementService eng;
  final TransactionsController txCtrl;
  final BudgetsController budgetCtrl;
  final GoalsController goalCtrl;

  const _MonthlyDigestSheet({
    required this.eng,
    required this.txCtrl,
    required this.budgetCtrl,
    required this.goalCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0);
    final monthName = _monthName(prevMonth.month);

    // Compute prev month stats
    double income = 0, expenses = 0;
    int txCount = 0;
    String? topCategory;
    double topCatAmount = 0;
    final catMap = <String, double>{};

    for (final tx in txCtrl.transactions) {
      if (tx.dateTime.isBefore(prevMonth) || tx.dateTime.isAfter(prevMonthEnd)) {
        continue;
      }
      txCount++;
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback) {
        income += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expenses += tx.amount;
        final cat = tx.metadata?['categoryName'] as String? ?? 'General';
        catMap[cat] = (catMap[cat] ?? 0) + tx.amount;
      }
    }

    if (catMap.isNotEmpty) {
      final topEntry = catMap.entries.reduce(
          (a, b) => a.value > b.value ? a : b);
      topCategory = topEntry.key;
      topCatAmount = topEntry.value;
    }

    final savingsRate = income > 0
        ? ((income - expenses) / income * 100).clamp(0.0, 100.0)
        : 0.0;

    final completedGoals =
        goalCtrl.activeGoals.where((g) => g.isCompleted).length;
    final budgetStreak = eng.budgetStreakCount;
    final savingsStreak = eng.savingsStreakCount;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Radii.xxl),
          topRight: Radius.circular(Radii.xxl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: Spacing.md),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      const Icon(CupertinoIcons.sparkles,
                          color: AppStyles.solarGold, size: 18),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        '$monthName — Your Month in Review',
                        style: TextStyle(
                          fontSize: TypeScale.headline,
                          fontWeight: FontWeight.w800,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Stats grid
                  Row(
                    children: [
                      _statTile(context, 'Savings Rate',
                          '${savingsRate.toStringAsFixed(1)}%',
                          savingsRate >= 20
                              ? AppStyles.accentGreen
                              : savingsRate >= 10
                                  ? AppStyles.solarGold
                                  : AppStyles.plasmaRed),
                      const SizedBox(width: Spacing.md),
                      _statTile(context, 'Transactions', '$txCount',
                          AppStyles.accentBlue),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  if (topCategory != null)
                    _infoRow(
                      context,
                      CupertinoIcons.chart_pie_fill,
                      AppStyles.accentOrange,
                      'Top spend',
                      '$topCategory — ₹${topCatAmount.toStringAsFixed(0)}',
                    ),
                  if (budgetStreak > 0)
                    _infoRow(
                      context,
                      CupertinoIcons.flame_fill,
                      AppStyles.accentTeal,
                      'Budget streak',
                      '$budgetStreak week${budgetStreak > 1 ? 's' : ''} under budget',
                    ),
                  if (savingsStreak > 0)
                    _infoRow(
                      context,
                      CupertinoIcons.arrow_up_circle_fill,
                      AppStyles.accentGreen,
                      'Savings streak',
                      '$savingsStreak week${savingsStreak > 1 ? 's' : ''} above 10%',
                    ),
                  if (completedGoals > 0)
                    _infoRow(
                      context,
                      CupertinoIcons.flag_fill,
                      SemanticColors.success,
                      'Goals completed',
                      '$completedGoals goal${completedGoals > 1 ? 's' : ''} reached',
                    ),

                  const SizedBox(height: Spacing.xl),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Start Fresh This Month',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context))),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: TypeScale.title2,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, Color color,
      String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Spacing.sm),
          Text('$label: ',
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context))),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

// ---------------------------------------------------------------------------
// Dashboard Screen
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenOuterState();
}

class _DashboardScreenOuterState extends State<DashboardScreen> {
  // GlobalKeys for coach mark targeting
  final GlobalKey _searchIconKey = GlobalKey();
  final GlobalKey _calendarIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleCoachMarks());
  }

  Future<void> _scheduleCoachMarks() async {
    final session = await TooltipService.instance.sessionCount();
    if (!mounted) return;
    // Session 2: search coach mark
    if (session == 2 && await TooltipService.instance.shouldShow(1)) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await CoachMark.show(
        context: context,
        targetKey: _searchIconKey,
        title: 'Search with natural language',
        body: "Try 'food last week', 'coffee this month', or 'show savings'. Works in English and Hinglish.",
      );
      await TooltipService.instance.markShown(1);
    }
    // Session 3: voice mic coach mark
    if (session == 3 && await TooltipService.instance.shouldShow(2)) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await CoachMark.show(
        context: context,
        targetKey: _searchIconKey, // fallback — ideally mic key
        title: 'Add transactions by voice',
        body: "Tap the + button and hold the mic. Say '500 on Swiggy' or '₹1200 salary credited'. Hindi and Hinglish work too.",
      );
      await TooltipService.instance.markShown(2);
    }
    // Session 4: calendar coach mark
    if (session == 4 && await TooltipService.instance.shouldShow(3)) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await CoachMark.show(
        context: context,
        targetKey: _calendarIconKey,
        title: 'Your financial calendar',
        body: 'This shows when your FDs mature, SIPs are due, and bills are coming — all in one timeline.',
      );
      await TooltipService.instance.markShown(3);
    }
    // Session 5: voice navigation banner
    if (session == 5 && await TooltipService.instance.shouldShow(4)) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await CoachMark.show(
        context: context,
        targetKey: _searchIconKey, // fallback key
        title: 'Navigate by voice',
        body: "Say 'goals dikhao', 'show my budget', or 'open investments' to jump anywhere in the app.",
      );
      await TooltipService.instance.markShown(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DashboardScreenContent(
      searchIconKey: _searchIconKey,
      calendarIconKey: _calendarIconKey,
    );
  }
}

class _DashboardScreenContent extends StatelessWidget {
  final GlobalKey searchIconKey;
  final GlobalKey calendarIconKey;
  const _DashboardScreenContent({
    required this.searchIconKey,
    required this.calendarIconKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<DashboardController>(
      builder: (context, dashboardController, child) {
        // Pre-compute hasDue here to avoid nested Consumer2 in nav bar trailing.
        // A nested Consumer inside CupertinoNavigationBar.trailing can disrupt
        // Cupertino's hero animation, causing trailing widgets to disappear on
        // back navigation. Pulling the watch calls to this level keeps the nav
        // bar widget tree structurally stable.
        final hasDue = _hasEventDueWithin7Days(
          context.watch<InvestmentsController>().investments,
          context.watch<LoanController>().loans,
        );

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
          // Hide nav bar in landscape — replaced by compact inline bar in body
          navigationBar: AppStyles.isLandscape(context)
              ? null
              : CupertinoNavigationBar(
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
                      Semantics(
                        label: 'Command bar',
                        child: BouncyButton(
                          onPressed: () => CommandBar.show(context),
                          child: Icon(
                            CupertinoIcons.square_grid_2x2,
                            size: IconSizes.navIcon,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.xl),
                      Semantics(
                        label: 'Search',
                        child: BouncyButton(
                          key: searchIconKey,
                          onPressed: () => showGlobalSearch(context),
                          child: Icon(
                            CupertinoIcons.search,
                            size: IconSizes.navIcon,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.xl),
                      Semantics(
                        label: 'Dashboard layout',
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
                      Semantics(
                        label: 'Financial calendar',
                        child: BouncyButton(
                          key: calendarIconKey,
                          onPressed: () => Navigator.of(context).push(
                              FadeScalePageRoute(
                                  page: const FinancialCalendarScreen())),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: IconSizes.navIcon,
                                color: AppStyles.getTextColor(context),
                              ),
                              if (hasDue)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppStyles.plasmaRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
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
                                    fontSize: RT.title2(context),
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
                          // Notification count badge
                          Consumer<InvestmentsController>(
                            builder: (_, invCtrl, __) {
                              final all = invCtrl.investments;
                              final fdsMatured = all.where((inv) {
                                final md = inv.metadata;
                                if (md == null || !md.containsKey('maturityDate')) return false;
                                final days = DateTime.parse(md['maturityDate'] as String)
                                    .difference(DateTime.now()).inDays;
                                return days < 0;
                              }).length;
                              final fdsNear = all.where((inv) {
                                final md = inv.metadata;
                                if (md == null || !md.containsKey('maturityDate')) return false;
                                final days = DateTime.parse(md['maturityDate'] as String)
                                    .difference(DateTime.now()).inDays;
                                return days >= 0 && days <= 10;
                              }).length;
                              final sipCount = collectSipNotifications(all).length;
                              final bondCount = collectBondPayoutNotifications(all).length;
                              final count = fdsMatured + fdsNear + sipCount + bondCount;
                              if (count == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: Spacing.sm),
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                      FadeScalePageRoute(page: const NotificationsPage())),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemRed,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: CupertinoColors.systemRed.withValues(alpha: 0.40),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        count > 99 ? '99+' : '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // AI Tray button — above SMS when on, in SMS slot when off
                          Consumer<SettingsController>(
                            builder: (_, settings, __) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const AITrayButton(),
                                  if (settings.isSmsEnabled)
                                    Column(
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
                                    ),
                                ],
                              );
                            },
                          ),
                          // Main + FAB (spring morph to checkmark on save)
                          _buildMorphFAB(context),
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
    // Build card list for the deck — each widget config becomes a swipeable card
    final cards = visibleWidgets
        .map((w) => _buildDashboardWidgetCard(context, w))
        .toList();

    final isLandscape = AppStyles.isLandscape(context);

    // ── LANDSCAPE: proper two-panel layout ──────────────────────────────────
    if (isLandscape) {
      return Row(
        children: [
          // LEFT SIDEBAR ── navigation, greeting, balance, quick actions
          _buildLandscapeSidebar(context),

          // Thin divider
          Container(
            width: 0.5,
            color: AppStyles.getDividerColor(context),
          ),

          // RIGHT PANEL ── the card deck fills the rest
          Expanded(
            child: Column(
              children: [
                const EngagementStripWidget(),
                const SizedBox(height: Spacing.sm),
                const AIInsightsStrip(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: Spacing.xs, bottom: Spacing.sm),
                    child: Selector<AccountsController, bool>(
                      selector: (_, ctrl) => ctrl.accounts.isEmpty,
                      builder: (_, hasNoAccounts, __) => hasNoAccounts
                          ? const _SetupCard()
                          : CardDeckView(
                              cards: cards,
                              onCardChanged: (_) {},
                            ),
                    ),
                  ),
                ),
                const _EngagementChecker(),
              ],
            ),
          ),
        ],
      );
    }

    // ── PORTRAIT: original layout ────────────────────────────────────────────
    return Column(
      children: [
        // PROFESSIONAL HEADER — capped so CardDeck always gets enough space
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.of(context).size.height * 0.22).clamp(100.0, 160.0),
          ),
          child: _buildHeaderSection(context),
        ),

        // ENGAGEMENT: compact strip
        const EngagementStripWidget(),

        // AI INSIGHTS: proactive cards (hidden when no content)
        const SizedBox(height: Spacing.sm),
        const AIInsightsStrip(),

        // CARD DECK — swipe left/right
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.sm),
            child: Selector<AccountsController, bool>(
              selector: (_, ctrl) => ctrl.accounts.isEmpty,
              builder: (_, hasNoAccounts, __) => hasNoAccounts
                  ? const _SetupCard()
                  : CardDeckView(cards: cards, onCardChanged: (_) {}),
            ),
          ),
        ),

        // Engagement checker
        const _EngagementChecker(),
      ],
    );
  }

  /// Shown when the user has no accounts yet — guides them to set up their first account.
  Widget _buildSetupCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: AppStyles.heroCardDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppStyles.aetherTeal.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppStyles.aetherTeal.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.creditcard_fill,
                  color: AppStyles.aetherTeal,
                  size: 32,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Add Your First Account',
                style: TextStyle(
                  fontSize: TypeScale.title3,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Connect a bank account, credit card, or cash wallet to start tracking your finances.',
                style: TextStyle(
                  fontSize: TypeScale.callout,
                  color: AppStyles.getSecondaryTextColor(context),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xl),
              BouncyButton(
                onPressed: () => Navigator.of(context).push(
                  FadeScalePageRoute(page: const ManageScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xl, vertical: Spacing.md),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppStyles.aetherTeal, AppStyles.novaPurple],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(Radii.full),
                    boxShadow: AppStyles.elevatedShadows(
                      context,
                      tint: AppStyles.aetherTeal,
                      strength: 0.55,
                    ),
                  ),
                  child: const Text(
                    'Set Up Accounts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: TypeScale.callout,
                      letterSpacing: 0.2,
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

  /// FAB with checkmark morph — listens to [dashboardSavedSignal].
  Widget _buildMorphFAB(BuildContext context) {
    return _MorphFAB(
      onPressed: () => showDashboardActionSheet(context),
      onLongPress: () => CommandBar.show(context),
    );
  }

  /// Full left sidebar shown in landscape — replaces the old 40dp nav bar strip.
  Widget _buildLandscapeSidebar(BuildContext context) {
    final textColor = AppStyles.getTextColor(context);
    final secondary = AppStyles.getSecondaryTextColor(context);
    final isDark = AppStyles.isDarkMode(context);
    final now = DateTime.now();
    final h = now.hour;
    final baseGreet = h >= 5 && h < 12
        ? 'Good Morning'
        : h < 17
            ? 'Good Afternoon'
            : h < 21
                ? 'Good Evening'
                : 'Good Night';
    final landscapeName = context.read<SettingsController>().greetingName;
    final greeting = '$baseGreet, $landscapeName';
    final dateStr = _formatHeaderDate(now);

    return SizedBox(
      width: 196,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppStyles.getCardColor(context).withValues(alpha: 0.95)
              : AppStyles.getCardColor(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar: menu + title + search ───────────────────────
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Row(
                  children: [
                    BouncyButton(
                      onPressed: () => Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              const DashboardAppMenuScreen(),
                          transitionDuration: AppDurations.pageTransition,
                          reverseTransitionDuration:
                              AppDurations.pageTransitionReverse,
                          transitionsBuilder: (ctx, anim, _, child) =>
                              SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(-1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                                parent: anim, curve: MotionCurves.standard)),
                            child: child,
                          ),
                        ),
                      ),
                      child: Icon(CupertinoIcons.line_horizontal_3,
                          size: 18, color: textColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vittara',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'SpaceGrotesk',
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    BouncyButton(
                      onPressed: () => showGlobalSearch(context),
                      child: Icon(CupertinoIcons.search, size: 16, color: secondary),
                    ),
                  ],
                ),
              ),
            ),

            Container(height: 0.5, color: AppStyles.getDividerColor(context)),

            // ── Greeting + date ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.md, Spacing.sm, Spacing.md, Spacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // ── Net worth card ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.sm, Spacing.xs, Spacing.sm, Spacing.xs),
              child: BouncyButton(
                onPressed: () => Navigator.of(context)
                    .push(FadeScalePageRoute(page: const NetWorthPage())),
                child: Consumer<AccountsController>(
                  builder: (ctx, acCtrl, _) {
                    final visible =
                        acCtrl.accounts.where((a) => !a.isHidden).toList();
                    final total = visible.fold(0.0, (sum, a) {
                      if (a.type == AccountType.credit ||
                          a.type == AccountType.payLater) {
                        return sum -
                            ((a.creditLimit ?? 0.0) - a.balance)
                                .clamp(0.0, double.infinity);
                      }
                      return sum + a.balance;
                    });
                    return Container(
                      padding: const EdgeInsets.all(Spacing.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppStyles.aetherTeal
                                .withValues(alpha: isDark ? 0.13 : 0.07),
                            AppStyles.novaPurple
                                .withValues(alpha: isDark ? 0.09 : 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                          color: AppStyles.aetherTeal.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.chart_bar_square_fill,
                                  size: 10, color: AppStyles.aetherTeal),
                              const SizedBox(width: 4),
                              Text(
                                'NET WORTH',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.aetherTeal,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              const Spacer(),
                              Icon(CupertinoIcons.chevron_right,
                                  size: 10, color: secondary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AnimatedCounter(
                            value: total,
                            prefix: '₹',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              fontFamily: 'SpaceGrotesk',
                              letterSpacing: -0.6,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            duration: const Duration(milliseconds: 700),
                          ),
                          Text(
                            '${visible.length} account${visible.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 10,
                              color: secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const Spacer(),

            // ── Quick nav row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.sm, 0, Spacing.sm, Spacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sidebarNavBtn(
                    context,
                    CupertinoIcons.list_bullet,
                    'History',
                    () => Navigator.of(context).push(
                        FadeScalePageRoute(
                            page: const TransactionHistoryScreen())),
                  ),
                  _sidebarNavBtn(
                    context,
                    CupertinoIcons.square_grid_2x2,
                    'Manage',
                    () => Navigator.of(context)
                        .push(FadeScalePageRoute(page: const ManageScreen())),
                  ),
                  _sidebarNavBtn(
                    context,
                    CupertinoIcons.chart_pie_fill,
                    'Insights',
                    () => Navigator.of(context).push(FadeScalePageRoute(
                        page: const SpendingInsightsScreen())),
                  ),
                  _sidebarNavBtn(
                    context,
                    CupertinoIcons.slider_horizontal_3,
                    'Layout',
                    () => Navigator.of(context).push(
                        FadeScalePageRoute(
                            page: const DashboardSettingsModal())),
                  ),
                ],
              ),
            ),

            // ── Engagement strip ──────────────────────────────────────
            const EngagementStripWidget(),
          ],
        ),
      ),
    );
  }

  /// Small icon+label button for the sidebar's quick-nav row.
  Widget _sidebarNavBtn(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final secondary = AppStyles.getSecondaryTextColor(context);
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppStyles.getDividerColor(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: secondary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: secondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardWidgetCard(
    BuildContext context,
    DashboardWidgetConfig widgetConfig,
  ) {
    final accent = _widgetAccentColor(widgetConfig.type);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showReorderSheet(context);
      },
      child: BouncyButton(
      onPressed: () => _handleWidgetTap(context, widgetConfig),
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: MotionCurves.standard,
        decoration: AppStyles.accentCardDecoration(context, accent),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
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
                              style: AppTypography.headline(
                                color: AppStyles.getTextColor(context),
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ),
                          // Tap indicator
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

                    // Content — fills remaining card height; scrollable on overflow
                    Expanded(
                      child: RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: _buildWidgetPreview(
                                      context, widgetConfig),
                                ),
                              );
                            },
                          ),
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
    ), // BouncyButton
    ); // GestureDetector
  }

  IconData _widgetIcon(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.netWorth:
        return CupertinoIcons.chart_pie_fill;
      case DashboardWidgetType.transactionHistory:
        return CupertinoIcons.arrow_right_arrow_left_circle_fill;
      case DashboardWidgetType.sipTracker:
        return CupertinoIcons.graph_circle_fill;
      case DashboardWidgetType.spendingInsights:
        return CupertinoIcons.lightbulb_fill;
      case DashboardWidgetType.financialCalendar:
        return CupertinoIcons.calendar;
    }
  }

  Color _widgetAccentColor(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.netWorth:
        return AppStyles.accentBlue;
      case DashboardWidgetType.transactionHistory:
        return SemanticColors.info;
      case DashboardWidgetType.sipTracker:
        return CupertinoColors.activeBlue;
      case DashboardWidgetType.spendingInsights:
        return AppStyles.aetherTeal;
      case DashboardWidgetType.financialCalendar:
        return AppStyles.aetherTeal;
    }
  }

  Widget _buildHeaderSection(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final baseGreeting = hour >= 5 && hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : hour < 21
                ? 'Good Evening'
                : 'Good Night';
    // T-148: personalise greeting with display name
    final name =
        context.read<SettingsController>().greetingName;
    final greeting = '$baseGreeting, $name';

    final dateFormatter = _formatHeaderDate(now);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Container(
        decoration: AppStyles.heroCardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
          child: Stack(
            children: [
              // Dark mode only: ambient orbs + dot grid give the emissive feel.
              // Light mode: clean gradient from heroCardDecoration is enough —
              // orbs look washed out on white and the grid disappears entirely.
              if (isDark) ...[
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
              ],
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
                              _FadeSlideIn(
                                delay: Duration.zero,
                                child: Text(
                                  greeting,
                                  style: TextStyle(
                                    fontSize: RT.title2(context),
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppStyles.getTextColor(context),
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _FadeSlideIn(
                                delay: const Duration(milliseconds: 80),
                                child: Text(
                                  dateFormatter,
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : AppStyles.getSecondaryTextColor(context),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Net worth mini-badge — tappable, navigates to net worth page
                        BouncyButton(
                          onPressed: () => Navigator.of(context).push(
                            FadeScalePageRoute(page: const NetWorthPage())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppStyles.aetherTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(Radii.full),
                              border: Border.all(
                                color: AppStyles.aetherTeal.withValues(alpha: 0.40),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.chart_bar_square_fill,
                                  size: 11,
                                  color: AppStyles.aetherTeal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Net Worth',
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.aetherTeal,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: Spacing.xl),

                    // Hero balance — total across all accounts
                    Consumer<AccountsController>(
                      builder: (context, acCtrl, _) {
                        final visibleAccounts = acCtrl.accounts
                            .where((a) => !a.isHidden)
                            .toList();
                        final total = visibleAccounts.fold(0.0, (sum, a) {
                          // Credit/payLater: balance = available limit remaining.
                          // Amount owed = creditLimit - balance. Subtract as liability.
                          if (a.type == AccountType.credit ||
                              a.type == AccountType.payLater) {
                            final owed = (a.creditLimit ?? 0.0) - a.balance;
                            return sum - owed.clamp(0.0, double.infinity);
                          }
                          return sum + a.balance;
                        });
                        final count = visibleAccounts.length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedCounter(
                              value: total,
                              prefix: '₹',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppStyles.getTextColor(context),
                                letterSpacing: -1.0,
                                fontFamily: 'SpaceGrotesk',
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              duration: const Duration(milliseconds: 700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Across $count account${count == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : AppStyles.getSecondaryTextColor(context),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: Spacing.lg),

                    // Divider line
                    Container(
                      height: 0.6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  Colors.white.withValues(alpha: 0.00),
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.00),
                                ]
                              : [
                                  AppStyles.aetherTeal.withValues(alpha: 0.00),
                                  AppStyles.aetherTeal.withValues(alpha: 0.25),
                                  AppStyles.aetherTeal.withValues(alpha: 0.00),
                                ],
                        ),
                      ),
                    ),

                    const SizedBox(height: Spacing.lg),

                    // Quick action pills — frequency descending: History first
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: [
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 200),
                            child: _buildQuickActionPill(
                              context,
                              'History',
                              CupertinoIcons.clock_fill,
                              SemanticColors.info,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 240),
                            child: _buildQuickActionPill(
                              context,
                              'Budgets',
                              CupertinoIcons.chart_pie_fill,
                              AppStyles.accentCoral,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 280),
                            child: _buildQuickActionPill(
                              context,
                              'Goals',
                              CupertinoIcons.checkmark_seal_fill,
                              AppStyles.aetherTeal,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 320),
                            child: _buildQuickActionPill(
                              context,
                              'Savings',
                              CupertinoIcons.heart_fill,
                              AppStyles.accentGreen,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 360),
                            child: _buildQuickActionPill(
                              context,
                              'AI Plan',
                              CupertinoIcons.sparkles,
                              AppStyles.accentOrange,
                            ),
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
      ), // ClipRRect / Container
      ), // Padding
      // T-072: "Edit layout" hint — visible after 3 sessions, hides once user has reordered
      FutureBuilder<bool>(
        future: _shouldShowEditLayoutHint(),
        builder: (_, snap) {
          if (snap.data != true) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4, right: Spacing.lg),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _showReorderSheet(context),
                child: Text(
                  'Edit layout',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppStyles.getSecondaryTextColor(context),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ], // Column children
    ); // Column
  }

  Future<bool> _shouldShowEditLayoutHint() async {
    final prefs = await sp.SharedPreferences.getInstance();
    final sessions = prefs.getInt('app_session_count') ?? 1;
    final hasReordered = prefs.getBool('dashboard_reordered') ?? false;
    return sessions >= 3 && !hasReordered;
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
      case 'History':
        Navigator.of(context).push(
          FadeScalePageRoute(page: const TransactionHistoryScreen()),
        );
        break;
      case 'Goals':
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

  /// Returns true if any FD matures or loan EMI falls within the next 7 days.
  bool _hasEventDueWithin7Days(
      List<Investment> investments, List<Loan> loans) {
    final today = DateTime.now();
    final cutoff = today.add(const Duration(days: 7));

    for (final inv in investments) {
      if (inv.type != InvestmentType.fixedDeposit) continue;
      final meta = inv.metadata;
      if (meta == null) continue;
      try {
        if (meta.containsKey('fdData')) {
          final fd = FixedDeposit.fromMap(
              Map<String, dynamic>.from(meta['fdData'] as Map));
          if (fd.status != FDStatus.prematurelyWithdrawn &&
              !fd.maturityDate.isBefore(today) &&
              fd.maturityDate.isBefore(cutoff)) return true;
        } else if (meta.containsKey('maturityDate')) {
          final d = DateTime.tryParse((meta['maturityDate'] as String?) ?? '');
          if (d != null && !d.isBefore(today) && d.isBefore(cutoff)) return true;
        }
      } catch (_) {}
    }

    for (final loan in loans) {
      if (!loan.isActive) continue;
      var d = DateTime(loan.startDate.year, loan.startDate.month, loan.startDate.day);
      while (d.isBefore(today)) {
        d = DateTime(d.year, d.month + 1, d.day);
      }
      if (d.isBefore(cutoff)) return true;
    }

    return false;
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
        return NetWorthWidget(config: widgetConfig);
      case DashboardWidgetType.transactionHistory:
        return Consumer2<TransactionsController, InvestmentsController>(
          builder: (context, transactionController, investmentsController, child) {
            final allTx = transactionController.transactions;
            final transactions = TransactionFeedBuilder.buildUnifiedFeed(
              transactions: allTx,
              investments: investmentsController.investments,
            ).toList();

            // Month summary
            final now = DateTime.now();
            final monthStart = DateTime(now.year, now.month, 1);
            double monthSpent = 0, monthIncome = 0;
            int txCount = 0;
            for (final tx in allTx) {
              if (tx.dateTime.isBefore(monthStart)) continue;
              txCount++;
              if (tx.type == TransactionType.expense) {
                monthSpent += tx.amount.abs();
              } else if (tx.type == TransactionType.income ||
                  tx.type == TransactionType.cashback) {
                monthIncome += tx.amount.abs();
              }
            }

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

            return FadeInAnimation(
              duration: const Duration(milliseconds: 450),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                      FadeScalePageRoute(page: const TransactionHistoryScreen())),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (monthSpent > 0 || monthIncome > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.calendar,
                                  size: 11,
                                  color: AppStyles.getSecondaryTextColor(context)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'This month: $txCount tx · ${_fmtAmt(monthSpent)} out · ${_fmtAmt(monthIncome)} in',
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Spacing.sm),
                      ],
                      ...transactions.asMap().entries.map((entry) {
                        final isLast = entry.key == transactions.length - 1;
                        final tx = entry.value;
                        final amount = tx.amount;
                        final isDebit = tx.type == TransactionType.expense ||
                            tx.type == TransactionType.investment ||
                            tx.type == TransactionType.lending;
                        final diff = now.difference(tx.dateTime);
                        final timeLabel = diff.inMinutes < 60
                            ? '${diff.inMinutes}m ago'
                            : diff.inHours < 24
                                ? '${diff.inHours}h ago'
                                : diff.inDays == 1
                                    ? 'Yesterday'
                                    : '${diff.inDays}d ago';

                        return StaggeredItem(
                          index: entry.key,
                          baseDelay: const Duration(milliseconds: 80),
                          itemDelay: const Duration(milliseconds: 45),
                          child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
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
                                    size: 16,
                                    color: isDebit
                                        ? CupertinoColors.systemRed
                                        : CupertinoColors.systemGreen,
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tx.description,
                                        style: TextStyle(
                                          fontSize: TypeScale.footnote,
                                          fontWeight: FontWeight.w600,
                                          color: AppStyles.getTextColor(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        timeLabel,
                                        style: TextStyle(
                                          fontSize: TypeScale.caption,
                                          color: AppStyles.getSecondaryTextColor(
                                              context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isDebit ? '-' : '+'}₹${amount.abs().toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
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
                                padding:
                                    EdgeInsets.symmetric(vertical: Spacing.sm),
                                child: Divider(height: 1),
                              ),
                          ],
                        ));
                      }),
                    ],
                  ),
                ),
              ],
            ));
          },
        );
      case DashboardWidgetType.sipTracker:
        return Consumer<InvestmentsController>(
          builder: (context, investmentsController, child) {
            final allInvestments = investmentsController.investments;
            final activeSips = allInvestments
                .where((inv) => inv.metadata?['sipActive'] == true)
                .toList();

            // Alerts computation
            final fdsMatured = allInvestments.where((inv) {
              if (inv.type.name != 'fixedDeposit') return false;
              final md = inv.metadata;
              if (md == null || !md.containsKey('maturityDate')) return false;
              return DateTime.parse(md['maturityDate'] as String)
                  .difference(DateTime.now()).inDays < 0;
            }).toList();
            final fdsNear = allInvestments.where((inv) {
              if (inv.type.name != 'fixedDeposit') return false;
              final md = inv.metadata;
              if (md == null || !md.containsKey('maturityDate')) return false;
              final days = DateTime.parse(md['maturityDate'] as String)
                  .difference(DateTime.now()).inDays;
              return days >= 0 && days <= 10;
            }).toList();
            final sipAlerts = collectSipNotifications(allInvestments);
            final bondAlerts = collectBondPayoutNotifications(allInvestments);
            final hasAlerts = fdsMatured.isNotEmpty || fdsNear.isNotEmpty ||
                sipAlerts.isNotEmpty || bondAlerts.isNotEmpty;
            final alertWidgets = <Widget>[
              if (fdsMatured.isNotEmpty)
                _buildCompactDashboardAlert(context,
                    icon: CupertinoIcons.exclamationmark_circle_fill,
                    color: CupertinoColors.systemRed,
                    title: '${fdsMatured.length} FD${fdsMatured.length > 1 ? 's' : ''} matured',
                    subtitle: 'Action required'),
              if (fdsNear.isNotEmpty)
                _buildCompactDashboardAlert(context,
                    icon: CupertinoIcons.bell_fill,
                    color: CupertinoColors.systemOrange,
                    title: '${fdsNear.length} FD${fdsNear.length > 1 ? 's' : ''} maturing soon',
                    subtitle: 'Within 10 days'),
              ...sipAlerts.take(2).map((e) => _buildDashboardSipNotification(context, e)),
              ...bondAlerts.take(1).map((e) => _buildDashboardBondNotification(context, e)),
            ];

            // No early return — Cash Flow is always shown even with no SIPs/alerts

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

            return FadeInAnimation(
              duration: const Duration(milliseconds: 450),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeSips.isNotEmpty) ...[
                  // ── SIP section ─────────────────────────────────────────
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const InvestmentsScreen())),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                            AnimatedCounter(
                              value: totalMonthly,
                              prefix: '~₹',
                              suffix: '/mo',
                              duration: const Duration(milliseconds: 700),
                              style: const TextStyle(
                                fontSize: TypeScale.footnote,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.activeBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        ...activeSips.asMap().entries.map((entry) {
                          final inv = entry.value;
                          final meta = inv.metadata ?? {};
                          final sipData = meta['sipData'] as Map<String, dynamic>?;
                          final freq = sipData?['frequency'] as String? ??
                              meta['sipFrequency'] as String? ??
                              'monthly';
                          final amt = (sipData?['sipAmount'] as num?)?.toDouble() ??
                              (meta['sipAmount'] as num?)?.toDouble() ??
                              0.0;
                          return StaggeredItem(
                            index: entry.key,
                            baseDelay: const Duration(milliseconds: 100),
                            itemDelay: const Duration(milliseconds: 50),
                            child: Padding(
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
                          ));
                        }),
                        if (totalMonthly > 0) ...[
                          const SizedBox(height: Spacing.sm),
                          const Divider(height: 1),
                          const SizedBox(height: Spacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSipStat(context,
                                    label: 'Per month',
                                    amount: totalMonthly,
                                    color: CupertinoColors.activeBlue),
                              ),
                              Expanded(
                                child: _buildSipStat(context,
                                    label: 'Per year',
                                    amount: totalMonthly * 12,
                                    color: AppStyles.accentTeal),
                              ),
                              Expanded(
                                child: _buildSipStat(context,
                                    label: 'Avg / SIP',
                                    amount: totalMonthly / activeSips.length,
                                    color: AppStyles.accentOrange),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // ── ALERTS section ───────────────────────────────────────
                if (hasAlerts) ...[
                  if (activeSips.isNotEmpty) ...[
                    const SizedBox(height: Spacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: Spacing.sm),
                  ],
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const NotificationsPage())),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTappableSectionHeader(
                          context,
                          'ALERTS',
                          CupertinoColors.systemRed,
                          () => Navigator.of(context).push(
                              FadeScalePageRoute(page: const NotificationsPage())),
                        ),
                        const SizedBox(height: Spacing.xs),
                        ...alertWidgets,
                      ],
                    ),
                  ),
                ],

                // ── CASH FLOW section ────────────────────────────────────
                if (activeSips.isNotEmpty || hasAlerts) ...[
                  const SizedBox(height: Spacing.sm),
                  const Divider(height: 1),
                  const SizedBox(height: Spacing.sm),
                ],
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                      FadeScalePageRoute(page: const ReportsAnalysisScreen())),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTappableSectionHeader(
                        context,
                        'CASH FLOW',
                        AppStyles.accentTeal,
                        () => Navigator.of(context).push(
                            FadeScalePageRoute(page: const ReportsAnalysisScreen())),
                      ),
                      const SizedBox(height: Spacing.sm),
                      const CashFlowDashboardWidget(),
                    ],
                  ),
                ),
              ],
            ));
          },
        );
      case DashboardWidgetType.spendingInsights:
        return FadeInAnimation(
          duration: const Duration(milliseconds: 500),
          child: InsightsWidget(config: widgetConfig),
        );
      case DashboardWidgetType.financialCalendar:
        return FadeInAnimation(
          duration: const Duration(milliseconds: 500),
          child: _UpcomingEventsWidget(config: widgetConfig),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Compact amount formatter shared across dashboard widget previews.
  String _fmtAmt(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 10000000) return '$sign₹${(abs / 10000000).toStringAsFixed(1)}Cr';
    if (abs >= 100000) return '$sign₹${(abs / 100000).toStringAsFixed(1)}L';
    if (abs >= 1000) return '$sign₹${(abs / 1000).toStringAsFixed(1)}K';
    return '$sign₹${abs.toStringAsFixed(0)}';
  }

  /// Mini stat tile used in SIP tracker footer row.
  Widget _buildSipStat(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: AppStyles.getSecondaryTextColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedCounter(
          value: amount,
          prefix: '₹',
          duration: const Duration(milliseconds: 750),
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Tappable section header with label + chevron. Navigates via [onTap].
  Widget _buildTappableSectionHeader(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.micro,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(CupertinoIcons.chevron_right, size: 10, color: color),
        ],
      ),
    );
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

  void _showReorderSheet(BuildContext context) {
    final dashCtrl = context.read<DashboardController>();
    final widgets = [...dashCtrl.visibleWidgets];
    showCupertinoModalPopup(
      context: context,
      builder: (sheetCtx) {
        final items = [...widgets];
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.6,
            decoration: AppStyles.bottomSheetDecoration(ctx),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Text('Reorder Widgets',
                          style: TextStyle(
                              fontSize: TypeScale.headline,
                              fontWeight: FontWeight.w700,
                              color: AppStyles.getTextColor(ctx))),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    itemCount: items.length,
                    onReorder: (oldIdx, newIdx) {
                      setModalState(() {
                        if (newIdx > oldIdx) newIdx--;
                        final moved = items.removeAt(oldIdx);
                        items.insert(newIdx, moved);
                      });
                      final ids = items.map((w) => w.id).toList();
                      dashCtrl.reorderWidgets(ids);
                      sp.SharedPreferences.getInstance().then(
                          (p) => p.setBool('dashboard_reordered', true));
                    },
                    itemBuilder: (_, i) {
                      final w = items[i];
                      return ListTile(
                        key: ValueKey(w.id),
                        leading: Icon(_widgetIcon(w.type),
                            color: _widgetAccentColor(w.type), size: 20),
                        title: Text(w.title,
                            style: TextStyle(
                                fontSize: TypeScale.body,
                                color: AppStyles.getTextColor(ctx))),
                        trailing: const Icon(CupertinoIcons.line_horizontal_3,
                            size: 18, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _handleWidgetTap(
      BuildContext context, DashboardWidgetConfig widgetConfig) {
    // T-140: record widget tap for usage-based reorder
    UsageTrackerService.instance.recordWidgetTap(widgetConfig.id);
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
      case DashboardWidgetType.sipTracker:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const InvestmentsScreen()),
        );
        break;
      case DashboardWidgetType.spendingInsights:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const SpendingInsightsScreen()),
        );
        break;
      case DashboardWidgetType.financialCalendar:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const FinancialCalendarScreen()),
        );
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

/// Full-screen lock dialog shown via Navigator push (covers all overlays).
/// Pops itself when the underlying [SettingsController.isLocked] goes false.
class _LockDialog extends StatelessWidget {
  const _LockDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, settings, _) {
        if (!settings.isLocked) {
          // Dismiss self when unlock succeeds.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
        }
        // Absorb horizontal swipes to prevent iOS edge-swipe bypass.
        return GestureDetector(
          onHorizontalDragUpdate: (_) {},
          child: const LockScreen(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MorphFAB — FAB that springs to a checkmark when dashboardSavedSignal fires
// ─────────────────────────────────────────────────────────────────────────────

class _MorphFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  const _MorphFAB({required this.onPressed, this.onLongPress});

  @override
  State<_MorphFAB> createState() => _MorphFABState();
}

class _MorphFABState extends State<_MorphFAB>
    with SingleTickerProviderStateMixin {
  // 0.0 = plus icon, 1.0 = checkmark icon
  late final AnimationController _ctrl = AnimationController.unbounded(
    vsync: this,
    value: 0.0,
  );

  // Separate controller for the one-shot pulse on first launch
  AnimationController? _pulseCtrl;

  bool _showCheck = false;

  @override
  void initState() {
    super.initState();
    dashboardSavedSignal.addListener(_onSaved);
    _checkFirstLaunchPulse();
  }

  Future<void> _checkFirstLaunchPulse() async {
    final prefs = await sp.SharedPreferences.getInstance();
    if (prefs.getBool('fab_pulse_done') == true) return;
    await prefs.setBool('fab_pulse_done', true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      _pulseCtrl = pulse;
      pulse.animateWith(AppSprings.from(AppSprings.gentle, 0.0, 1.0))
          .then((_) {
        if (mounted) {
          pulse.animateWith(AppSprings.from(AppSprings.gentle, 1.0, 0.0));
        }
      });
    });
  }

  @override
  void dispose() {
    dashboardSavedSignal.removeListener(_onSaved);
    _pulseCtrl?.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onSaved() {
    if (!mounted) return;
    setState(() => _showCheck = true);
    // Spring bounce in
    _ctrl.animateWith(
      SpringSimulation(AppSprings.bouncy, 0.0, 1.0, 0.0),
    );
    // Auto-return after 1.4s
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      _ctrl.animateWith(
        SpringSimulation(AppSprings.crisp, _ctrl.value, 0.0, 0.0),
      );
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _showCheck = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Merge the morph animation with the optional first-launch pulse
    final listenable = _pulseCtrl != null
        ? Listenable.merge([_ctrl, _pulseCtrl!])
        : _ctrl;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: BouncyButton(
      onPressed: widget.onPressed,
      scaleFactor: 0.92,
      child: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final t = _ctrl.value.clamp(0.0, 1.0);
          // Scale pulse: expands slightly past 1.0 during spring overshoot
          final morphScale = 1.0 + (_ctrl.value - t) * 0.3;
          // First-launch pulse: gentle 0→1→0 scale adds up to 6% extra
          final pulseScale = _pulseCtrl != null
              ? 1.0 + _pulseCtrl!.value.abs() * 0.06
              : 1.0;
          final scale = morphScale;
          return Transform.scale(
            scale: (1.0 + scale * 0.04) * pulseScale,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _showCheck
                      ? [
                          Color.lerp(AppStyles.aetherTeal,
                              SemanticColors.success, t)!,
                          Color.lerp(AppStyles.novaPurple,
                              SemanticColors.success, t)!,
                        ]
                      : [AppStyles.aetherTeal, AppStyles.novaPurple],
                ),
                shape: BoxShape.circle,
                boxShadow: AppStyles.elevatedShadows(
                  context,
                  tint: _showCheck
                      ? Color.lerp(AppStyles.aetherTeal,
                          SemanticColors.success, t)!
                      : AppStyles.aetherTeal,
                  strength: 0.90,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  _showCheck
                      ? CupertinoIcons.checkmark_alt
                      : CupertinoIcons.add,
                  key: ValueKey(_showCheck),
                  color: Colors.white,
                  size: _showCheck ? 22 : 24,
                ),
              ),
            ),
          );
        },
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 4A animation helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Fades and slides a child upward into view after an optional [delay].
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Spring-scales a child from [beginScale] → 1.0 with a bouncy spring,
/// fading in simultaneously, after an optional [delay].
class _SpringScaleIn extends StatefulWidget {
  final Widget child;
  final double beginScale;
  final Duration delay;

  const _SpringScaleIn({
    required this.child,
    this.beginScale = 0.5,
    this.delay = Duration.zero,
  });

  @override
  State<_SpringScaleIn> createState() => _SpringScaleInState();
}

class _SpringScaleInState extends State<_SpringScaleIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this, value: 0.0);
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl.view,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    Future.delayed(widget.delay, () {
      if (mounted) {
        _ctrl.animateWith(AppSprings.from(AppSprings.bouncy, 0.0, 1.0));
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value.clamp(0.0, 1.0);
        final scale = widget.beginScale + (1.0 - widget.beginScale) * t;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SetupCard — first-launch setup prompt with stagger entrance animation
// ─────────────────────────────────────────────────────────────────────────────

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: AppStyles.heroCardDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon — spring-scales in first
              _SpringScaleIn(
                beginScale: 0.5,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyles.aetherTeal.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppStyles.aetherTeal.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.creditcard_fill,
                    color: AppStyles.aetherTeal,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              // Title — slides up 120ms after icon
              _FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  'Add Your First Account',
                  style: AppTypography.title3(
                    color: AppStyles.getTextColor(context),
                    fontWeight: AppTypography.bold,
                  ).copyWith(letterSpacing: -0.3),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              // Subtitle — 200ms
              _FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Connect a bank account, credit card, or cash wallet to start tracking your finances.',
                  style: AppTypography.callout(
                    color: AppStyles.getSecondaryTextColor(context),
                  ).copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              // Button — 300ms
              _FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: BouncyButton(
                  onPressed: () => Navigator.of(context).push(
                    FadeScalePageRoute(page: const ManageScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xl, vertical: Spacing.md),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppStyles.aetherTeal, AppStyles.novaPurple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(Radii.full),
                      boxShadow: AppStyles.elevatedShadows(
                        context,
                        tint: AppStyles.aetherTeal,
                        strength: 0.55,
                      ),
                    ),
                    child: Text(
                      'Set Up Accounts',
                      style: AppTypography.button(color: Colors.white)
                          .copyWith(letterSpacing: 0.2),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// _UpcomingEventsWidget — compact dashboard card showing next 3 calendar events
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingEventsWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  const _UpcomingEventsWidget({required this.config});

  @override
  Widget build(BuildContext context) {
    return Consumer4<InvestmentsController, RecurringTemplatesController,
        GoalsController, LoanController>(
      builder: (context, investments, templates, goals, loans, _) {
        final events = _computeUpcoming(
          investments: investments.investments,
          templates: templates.templates,
          goals: goals.goals,
          loans: loans.loans,
        );

        final isDark = AppStyles.isDarkMode(context);
        final teal = AppStyles.aetherTeal;

        return Container(
          decoration: AppStyles.sectionDecoration(context, tint: teal, radius: 20),
          padding: Spacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(CupertinoIcons.calendar, size: 16, color: teal),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'UPCOMING EVENTS',
                      style: TextStyle(
                        fontSize: TypeScale.micro,
                        fontWeight: FontWeight.w700,
                        color: teal,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  BouncyButton(
                    onPressed: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const FinancialCalendarScreen())),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  child: Text(
                    'No upcoming events in the next 30 days',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                )
              else
                ...events.take(3).map((e) => _EventRow(event: e, isDark: isDark)),
            ],
          ),
        );
      },
    );
  }

  List<_UpcomingEvent> _computeUpcoming({
    required List<Investment> investments,
    required List<RecurringTemplate> templates,
    required List<Goal> goals,
    required List<Loan> loans,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.add(const Duration(days: 30));
    final events = <_UpcomingEvent>[];

    // FD maturity from investments
    for (final inv in investments) {
      if (inv.type != InvestmentType.fixedDeposit) continue;
      final meta = inv.metadata;
      if (meta == null) continue;
      DateTime? maturity;
      if (meta.containsKey('fdData')) {
        try {
          final fd = FixedDeposit.fromMap(
              Map<String, dynamic>.from(meta['fdData'] as Map));
          if (fd.status != FDStatus.prematurelyWithdrawn) maturity = fd.maturityDate;
        } catch (_) {}
      } else if (meta.containsKey('maturityDate')) {
        maturity = DateTime.tryParse((meta['maturityDate'] as String?) ?? '');
      }
      if (maturity != null && !maturity.isBefore(today) && maturity.isBefore(cutoff)) {
        events.add(_UpcomingEvent(
          title: inv.name,
          subtitle: 'FD Maturity',
          date: maturity,
          icon: CupertinoIcons.lock_fill,
          color: AppStyles.solarGold,
        ));
      }
    }

    // Recurring templates (SIP / bills)
    for (final t in templates) {
      final next = _nextOccurrence(t.nextDueDate, today, cutoff);
      if (next != null) {
        events.add(_UpcomingEvent(
          title: t.name,
          subtitle: t.categoryName ?? 'Recurring',
          date: next,
          icon: CupertinoIcons.arrow_2_circlepath,
          color: AppStyles.aetherTeal,
        ));
      }
    }

    // Loan EMIs
    for (final loan in loans) {
      if (!loan.isActive) continue;
      final next = _nextEmiDate(loan.startDate, today, cutoff);
      if (next != null) {
        events.add(_UpcomingEvent(
          title: loan.name,
          subtitle: 'Loan EMI',
          date: next,
          icon: CupertinoIcons.creditcard_fill,
          color: const Color(0xFFFF6D00),
        ));
      }
    }

    // Goals with target date
    for (final g in goals) {
      final d = g.targetDate;
      if (!d.isBefore(today) && d.isBefore(cutoff)) {
        events.add(_UpcomingEvent(
          title: g.name,
          subtitle: 'Goal deadline',
          date: d,
          icon: CupertinoIcons.flag_fill,
          color: AppStyles.novaPurple,
        ));
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  DateTime? _nextOccurrence(DateTime? base, DateTime today, DateTime cutoff) {
    if (base == null) return null;
    var d = DateTime(base.year, base.month, base.day);
    if (d.isAfter(cutoff)) return null;
    if (!d.isBefore(today)) return d;
    // Advance by month until within range
    while (d.isBefore(today)) {
      d = DateTime(d.year, d.month + 1, d.day);
    }
    return d.isBefore(cutoff) ? d : null;
  }

  DateTime? _nextEmiDate(DateTime startDate, DateTime today, DateTime cutoff) {
    var d = DateTime(startDate.year, startDate.month, startDate.day);
    while (d.isBefore(today)) {
      d = DateTime(d.year, d.month + 1, d.day);
    }
    return d.isBefore(cutoff) ? d : null;
  }
}

class _UpcomingEvent {
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final Color color;
  const _UpcomingEvent({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.color,
  });
}

class _EventRow extends StatelessWidget {
  final _UpcomingEvent event;
  final bool isDark;
  const _EventRow({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final daysAway = event.date.difference(DateTime.now()).inDays;
    final dayLabel = daysAway == 0
        ? 'Today'
        : daysAway == 1
            ? 'Tomorrow'
            : 'in $daysAway days';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.icon, size: 15, color: event.color),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  event.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: event.color.withValues(alpha: 0.25)),
            ),
            child: Text(
              dayLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: event.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
