import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:vittara_fin_os/ui/fintech_loader.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
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
import 'package:vittara_fin_os/ui/manage/savings/savings_planners_screen.dart';
import 'package:vittara_fin_os/ui/manage/ai_planner/ai_monthly_planner_screen.dart';
import 'package:vittara_fin_os/ui/app_menu/app_menu_screen.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

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
      // DARK THEME (AMOLED)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5BB6FF),
          secondary: AppStyles.accentOrange,
          tertiary: AppStyles.accentGreen,
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
          primaryColor: const Color(0xFF5BB6FF),
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
        return ToastOverlay(
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
  @override
  void initState() {
    super.initState();
    // Automatically trigger biometric authentication when lock screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsController>(context, listen: false)
          .authenticateAndUnlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeInAnimation(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated lock icon with glow
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
              SizedBox(height: Spacing.xxxl),
              Text(
                'VittaraFinOS Locked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: TypeScale.title2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: Spacing.sm),
              Text(
                'Authenticating...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: TypeScale.body,
                ),
              ),
              SizedBox(height: Spacing.huge),
              const SizedBox(
                width: 40,
                height: 40,
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 15,
                ),
              ),
            ],
          ),
        ),
      ),
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

    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        logger.info("Navigating from SplashScreen to Dashboard",
            context: 'SplashScreen');
        Provider.of<SettingsController>(context, listen: false)
            .setAppLoaded(); // Enable lock screen
        Navigator.of(context).pushReplacement(FadeScalePageRoute(
          page: const DashboardScreen(),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FintechLoader(size: 200),
            const SizedBox(height: Spacing.xl),
            const Text(
              'VittaraFinOS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Track Wealth, Master Life',
              style: TextStyle(fontSize: TypeScale.headline),
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
                    SizedBox(height: Spacing.md),
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

        final visibleWidgets = dashboardController.config.getVisibleWidgets();

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
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                size: IconSizes.navIcon,
                color: AppStyles.getTextColor(context),
              ),
            ),
            middle: const Text('VittaraFinOS'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dashboard Settings
                BouncyButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      FadeScalePageRoute(page: const DashboardSettingsModal()),
                    );
                  },
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: IconSizes.navIcon,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                SizedBox(width: Spacing.xl),
                // Manage button
                BouncyButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(FadeScalePageRoute(page: const ManageScreen()));
                  },
                  child: Icon(
                    CupertinoIcons.square_grid_2x2,
                    size: IconSizes.navIcon,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                SizedBox(width: Spacing.xl),
                // Settings button
                BouncyButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(FadeScalePageRoute(page: const SettingsScreen()));
                  },
                  child: Icon(
                    CupertinoIcons.settings,
                    size: IconSizes.navIcon,
                    color: AppStyles.getTextColor(context),
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
                                SizedBox(height: Spacing.lg),
                                Text(
                                  'No widgets enabled',
                                  style: AppStyles.titleStyle(context).copyWith(
                                    fontSize: TypeScale.title2,
                                  ),
                                ),
                                SizedBox(height: Spacing.sm),
                                Text(
                                  'All dashboard widgets are hidden',
                                  style: TextStyle(
                                    fontSize: TypeScale.body,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                                SizedBox(height: Spacing.xl),
                                CupertinoButton.filled(
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
                      child: BouncyButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            FadeScalePageRoute(page: const TransactionWizard()),
                          );
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppStyles.accentBlue,
                                AppStyles.accentTeal,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: AppStyles.elevatedShadows(
                              context,
                              tint: AppStyles.accentBlue,
                              strength: 0.85,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.add,
                            color: Colors.white,
                          ),
                        ),
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
            padding: EdgeInsets.all(Spacing.lg),
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
                margin: EdgeInsets.only(bottom: Spacing.md),
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

    // Check if widget has content
    final hasContent = _widgetHasContent(context, widgetConfig);

    return BouncyButton(
      onPressed: () => _handleWidgetTap(context, widgetConfig),
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: MotionCurves.standard,
        decoration: AppStyles.cardDecoration(context).copyWith(
          border: Border.all(
            color: accent.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.50 : 0.25,
            ),
          ),
          boxShadow: AppStyles.elevatedShadows(
            context,
            tint: accent,
            strength: 0.72,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with drag handle
            Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Drag handle icon
                        Icon(
                          CupertinoIcons.line_horizontal_3,
                          size: 18,
                          color: accent.withValues(alpha: 0.50),
                        ),
                        SizedBox(width: Spacing.md),
                        // Title
                        Expanded(
                          child: Text(
                            widgetConfig.title,
                            style: AppStyles.titleStyle(context).copyWith(
                              fontSize: TypeScale.title3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand arrow
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 20,
                    color: accent,
                  ),
                ],
              ),
            ),

            // Content - minimal padding, shrink to fit
            if (hasContent)
              Padding(
                padding: EdgeInsets.only(
                  left: Spacing.md,
                  right: Spacing.md,
                  bottom: Spacing.sm,
                ),
                child: _buildWidgetPreview(context, widgetConfig),
              )
            else
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 32,
                        color: SemanticColors.success.withValues(alpha: 0.8),
                      ),
                      SizedBox(height: Spacing.md),
                      Text(
                        'All caught up!',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
        return SemanticColors.warning;
      case DashboardWidgetType.monthlySummary:
        return AppStyles.accentGreen;
    }
  }

  bool _widgetHasContent(
    BuildContext context,
    DashboardWidgetConfig widgetConfig,
  ) {
    switch (widgetConfig.type) {
      case DashboardWidgetType.netWorth:
      case DashboardWidgetType.goalsOverview:
      case DashboardWidgetType.budgetsOverview:
      case DashboardWidgetType.savingsPlanners:
      case DashboardWidgetType.aiPlanner:
        return true;
      case DashboardWidgetType.transactionHistory:
        // Always render preview; it listens to live transaction updates and
        // handles its own empty state.
        return true;
      case DashboardWidgetType.notificationsAndActions:
        // Always render preview; it listens to live investment updates and
        // handles its own empty state.
        return true;
      default:
        return true;
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

    return Padding(
      padding:
          EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
      child: Container(
        decoration: AppStyles.sectionDecoration(
          context,
          tint: AppStyles.accentBlue,
          radius: 26,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned(
                top: -26,
                right: -12,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyles.accentTeal.withValues(alpha: 0.14),
                  ),
                ),
              ),
              Positioned(
                bottom: -42,
                left: -18,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyles.accentBlue.withValues(alpha: 0.12),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: AppStyles.titleStyle(context).copyWith(
                          fontSize: TypeScale.largeTitle,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: Spacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dateFormatter,
                              style: TextStyle(
                                fontSize: TypeScale.callout,
                                color: AppStyles.getSecondaryTextColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.xs,
                            ),
                            decoration: AppStyles.tabDecoration(
                              context,
                              selected: true,
                              color: SemanticColors.success,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  size: 12,
                                  color: SemanticColors.success,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'All Systems Go',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: SemanticColors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Spacing.lg),
                      Wrap(
                        spacing: Spacing.md,
                        runSpacing: Spacing.md,
                        children: [
                          _buildQuickActionPill(
                            context,
                            'Goals',
                            CupertinoIcons.checkmark_circle,
                            AppStyles.accentBlue,
                          ),
                          _buildQuickActionPill(
                            context,
                            'Budgets',
                            CupertinoIcons.chart_pie,
                            AppStyles.accentCoral,
                          ),
                          _buildQuickActionPill(
                            context,
                            'Savings',
                            CupertinoIcons.heart,
                            AppStyles.accentGreen,
                          ),
                          _buildQuickActionPill(
                            context,
                            'AI Plan',
                            CupertinoIcons.lightbulb,
                            AppStyles.accentOrange,
                          ),
                        ],
                      ),
                    ],
                  ),
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
        constraints: const BoxConstraints(minWidth: 116),
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: AppStyles.elevatedShadows(
            context,
            tint: color,
            strength: 0.52,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: Spacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w700,
                color: color,
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
            final displayColor =
                isPositive ? AppStyles.getPrimaryColor(context) : CupertinoColors.systemRed;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main Net Worth Card
                Container(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                      SizedBox(height: Spacing.xxs),
                      Text(
                        '₹${totalNetWorth.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: TypeScale.largeTitle,
                          fontWeight: FontWeight.w800,
                          color: displayColor,
                        ),
                      ),
                      SizedBox(height: 6),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.systemGreen,
                                  ),
                                ),
                              ],
                            ),
                            if (totalInvestments > 0) ...[
                              SizedBox(height: 3),
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
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.activeBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (totalCreditUsed > 0) ...[
                              SizedBox(height: 3),
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
                                    style: TextStyle(
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
                SizedBox(height: Spacing.md),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      AppStyles.getBackground(context).withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(CupertinoColors.activeBlue),
                ),
                SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved ₹${totalSaved.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: TypeScale.footnote, color: CupertinoColors.systemGreen),
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
                      _buildBadge(
                          context, 'Over', exceeded.length, CupertinoColors.systemRed),
                    if (warning.isNotEmpty) ...[
                      SizedBox(width: Spacing.xs),
                      _buildBadge(context, 'Near', warning.length,
                          CupertinoColors.systemOrange),
                    ],
                  ],
                ),
                if (alertBudgets.isNotEmpty) ...[
                  SizedBox(height: Spacing.md),
                  ...alertBudgets.map((b) {
                    final isExceeded = b.status.name == 'exceeded';
                    final color =
                        isExceeded ? CupertinoColors.systemRed : CupertinoColors.systemOrange;
                    final pct = b.usagePercentage.toStringAsFixed(0);
                    return Container(
                      margin: EdgeInsets.only(bottom: Spacing.xs),
                      padding: EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: color.withValues(alpha: 0.2)),
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
                          SizedBox(width: Spacing.xs),
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
                  SizedBox(height: Spacing.md),
                  Row(
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
                SizedBox(height: Spacing.md),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor:
                      AppStyles.getBackground(context).withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(CupertinoColors.systemGreen),
                ),
                SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved ₹${totalSaved.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: TypeScale.footnote, color: CupertinoColors.systemGreen),
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
                SizedBox(height: Spacing.md),
                Row(
                  children: [
                    Icon(CupertinoIcons.lightbulb,
                        size: 16, color: Colors.purple),
                    SizedBox(width: Spacing.sm),
                    Text(
                      '${progress.toStringAsFixed(0)}% Financial Health',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Spacing.sm),
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
                    color: budgetWarnings > 0 ? CupertinoColors.systemOrange : CupertinoColors.systemGreen,
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
                    SizedBox(height: Spacing.sm),
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
                            color: (isDebit ? CupertinoColors.systemRed : CupertinoColors.systemGreen)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isDebit
                                ? CupertinoIcons.arrow_up
                                : CupertinoIcons.arrow_down,
                            size: 18,
                            color: isDebit ? CupertinoColors.systemRed : CupertinoColors.systemGreen,
                          ),
                        ),
                        SizedBox(width: Spacing.md),
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
                            color: isDebit ? CupertinoColors.systemRed : CupertinoColors.systemGreen,
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Padding(
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
            const monthNames = [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
            ];
            final monthLabel = '${monthNames[now.month - 1]} ${now.year}';

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
            final incomeRatio = total > 0 ? (income / total).clamp(0.0, 1.0) : 0.5;

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
                SizedBox(height: Spacing.md),
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
                    SizedBox(width: Spacing.md),
                    Expanded(
                      child: _buildMonthlyStat(
                        context,
                        label: 'Expenses',
                        amount: expenses,
                        color: CupertinoColors.systemRed,
                        icon: CupertinoIcons.arrow_up_circle_fill,
                      ),
                    ),
                    SizedBox(width: Spacing.md),
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
                SizedBox(height: Spacing.md),
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
                    SizedBox(height: Spacing.sm),
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
                    padding: EdgeInsets.only(
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
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.subhead,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: color,
          ),
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
          EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
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
          SizedBox(width: Spacing.xs),
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

  Widget _buildNetWorthBreakdownItem(
    BuildContext context,
    String label,
    double amount,
    int count,
    IconData icon,
    Color color,
    double total,
  ) {
    final percentage = total > 0 ? (amount / total * 100) : 0.0;

    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
              SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$count item${count != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: AppStyles.getBackground(context),
              valueColor: AlwaysStoppedAnimation<Color>(color),
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
      margin: EdgeInsets.only(bottom: Spacing.sm),
      padding: EdgeInsets.all(Spacing.sm),
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
          SizedBox(width: Spacing.sm),
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
                SizedBox(height: Spacing.xxs),
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
