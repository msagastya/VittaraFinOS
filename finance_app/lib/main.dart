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
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/ui/fintech_loader.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/notifications_page.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/dashboard/dashboard_settings_modal.dart';
import 'package:vittara_fin_os/ui/net_worth_page.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/services/mf_database_service.dart';
import 'package:vittara_fin_os/ui/manage/goals/goals_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/manage/savings/savings_planners_screen.dart';
import 'package:vittara_fin_os/ui/manage/ai_planner/ai_monthly_planner_screen.dart';

final AppLogger logger = AppLogger();

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.error('Flutter Framework Error', 
        context: 'Main', 
        error: details.exception, 
        stackTrace: details.stack);
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
            create: (_) => PaymentAppsController(),
          ),
          ChangeNotifierProvider(
            create: (_) => InvestmentsController()..loadInvestments(),
          ),
          ChangeNotifierProvider(
            create: (_) => InvestmentTypePreferencesController()..loadPreferences(),
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
      context: 'ZonedGuarded', 
      error: error, 
      stackTrace: stackTrace);
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
    final textTheme = GoogleFonts.interTextTheme();

    return MaterialApp(
      title: 'VittaraFinOS',
      themeMode: settings.themeMode,
      // LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        fontFamily: GoogleFonts.inter().fontFamily,
        textTheme: textTheme,
        cupertinoOverrideTheme: CupertinoThemeData(
          primaryColor: const Color(0xFF007AFF),
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, color: const Color(0xFF1C1C1E)),
            navTitleTextStyle: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily, 
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
      // DARK THEME (AMOLED)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // AMOLED BLACK
        primarySwatch: Colors.blue,
        fontFamily: GoogleFonts.inter().fontFamily,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cupertinoOverrideTheme: CupertinoThemeData(
          primaryColor: const Color(0xFF0A84FF), // iOS Dark Mode Blue
          scaffoldBackgroundColor: const Color(0xFF000000),
          barBackgroundColor: const Color(0xFF1C1C1E),
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, color: Colors.white),
            navTitleTextStyle: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily, 
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: Colors.white,
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
                  fontFamily: GoogleFonts.inter().fontFamily,
                  decoration: TextDecoration.none,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E),
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
      Provider.of<SettingsController>(context, listen: false).authenticateAndUnlock();
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
  _SplashScreenState createState() => _SplashScreenState();
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
        logger.info("Navigating from SplashScreen to Dashboard", context: 'SplashScreen');
        Provider.of<SettingsController>(context, listen: false).setAppLoaded(); // Enable lock screen
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
            const SizedBox(height: 20),
            const Text(
              'VittaraFinOS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Track Wealth, Master Life',
              style: TextStyle(fontSize: 16),
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
            body: const Center(child: CupertinoActivityIndicator()),
          );
        }

        final visibleWidgets = dashboardController.config.getVisibleWidgets();

        // Debug: Print visible widgets count
        if (kDebugMode) {
          print('Dashboard: ${visibleWidgets.length} visible widgets out of ${dashboardController.config.widgets.length} total');
          for (var w in dashboardController.config.widgets) {
            print('  - ${w.id}: visible=${w.isVisible}');
          }
        }

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('VittaraFinOS'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dashboard Settings
                BouncyButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const DashboardSettingsModal(),
                      ),
                    );
                  },
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: IconSizes.navIcon,
                    color: isDark ? Colors.white : CupertinoColors.black,
                  ),
                ),
                SizedBox(width: Spacing.xl),
                // Manage button
                BouncyButton(
                  onPressed: () {
                    Navigator.of(context).push(FadeScalePageRoute(page: const ManageScreen()));
                  },
                  child: Icon(
                    CupertinoIcons.square_grid_2x2,
                    size: IconSizes.navIcon,
                    color: isDark ? Colors.white : CupertinoColors.black,
                  ),
                ),
                SizedBox(width: Spacing.xl),
                // Settings button
                BouncyButton(
                  onPressed: () {
                    Navigator.of(context).push(FadeScalePageRoute(page: const SettingsScreen()));
                  },
                  child: Icon(
                    CupertinoIcons.settings,
                    size: IconSizes.navIcon,
                    color: isDark ? Colors.white : CupertinoColors.black,
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemGroupedBackground,
            border: null,
          ),
          child: SafeArea(
            child: Container(
              color: isDark ? Colors.black : CupertinoColors.systemGroupedBackground,
              child: visibleWidgets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.square_grid_2x2,
                            size: 80,
                            color: isDark
                                ? CupertinoColors.systemGrey
                                : CupertinoColors.systemGrey,
                          ),
                          SizedBox(height: Spacing.lg),
                          Text(
                            'No widgets enabled',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : CupertinoColors.label,
                            ),
                          ),
                          SizedBox(height: Spacing.sm),
                          Text(
                            'All dashboard widgets are hidden',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          SizedBox(height: Spacing.xl),
                          CupertinoButton.filled(
                            onPressed: () async {
                              if (kDebugMode) print('Resetting dashboard to default');
                              await dashboardController.resetToDefault();
                              if (context.mounted) {
                                toast.showSuccess('Dashboard reset to default');
                              }
                            },
                            child: const Text('Reset to Default'),
                          ),
                        ],
                      ),
                    )
                  : _buildDashboardGrid(context, dashboardController, visibleWidgets),
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
            children: visibleWidgets
                .asMap()
                .entries
                .map((entry) {
              final widget = entry.value;
              return Container(
                key: Key(widget.id),
                margin: EdgeInsets.only(bottom: Spacing.md),
                child: _buildDashboardWidgetCard(context, widget),
              );
            })
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardWidgetCard(
    BuildContext context,
    DashboardWidgetConfig widgetConfig,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if widget has content
    final hasContent = _widgetHasContent(context, widgetConfig);

    return GestureDetector(
      onTap: () {
        _handleWidgetTap(context, widgetConfig);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                          color: AppStyles.getPrimaryColor(context)
                              .withOpacity(0.4),
                        ),
                        SizedBox(width: Spacing.md),
                        // Title
                        Expanded(
                          child: Text(
                            widgetConfig.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.getTextColor(context),
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
                    color: AppStyles.getPrimaryColor(context),
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
                        color: Colors.green.withOpacity(0.7),
                      ),
                      SizedBox(height: Spacing.md),
                      Text(
                        'All caught up!',
                        style: TextStyle(
                          fontSize: 13,
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
        final transactionsController =
            Provider.of<TransactionsController>(context, listen: false);
        return transactionsController.transactions.isNotEmpty;
      case DashboardWidgetType.notificationsAndActions:
        final investmentsController =
            Provider.of<InvestmentsController>(context, listen: false);
        final fdsNearMaturity = investmentsController.investments.where((inv) {
          if (inv.type.name != 'fixedDeposit') return false;
          final metadata = inv.metadata;
          if (metadata == null || !metadata.containsKey('maturityDate'))
            return false;
          final maturityDate = DateTime.parse(metadata['maturityDate'] as String);
          final daysUntil = maturityDate.difference(DateTime.now()).inDays;
          return daysUntil <= 10 && daysUntil >= 0;
        }).toList();

        final fdsMatured = investmentsController.investments.where((inv) {
          if (inv.type.name != 'fixedDeposit') return false;
          final metadata = inv.metadata;
          if (metadata == null || !metadata.containsKey('maturityDate'))
            return false;
          final maturityDate = DateTime.parse(metadata['maturityDate'] as String);
          final daysUntil = maturityDate.difference(DateTime.now()).inDays;
          return daysUntil < 0;
        }).toList();

        return fdsNearMaturity.isNotEmpty || fdsMatured.isNotEmpty;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SemanticColors.primary.withOpacity(0.1),
            SemanticColors.primary.withOpacity(0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              SizedBox(height: Spacing.sm),

              // Date & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormatter,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppStyles.getSecondaryTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 12,
                          color: Colors.green,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'All Systems Go',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Quick Action Pills
              SizedBox(height: Spacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickActionPill(context, 'Goals', CupertinoIcons.checkmark_circle, Colors.blue),
                    SizedBox(width: Spacing.md),
                    _buildQuickActionPill(context, 'Budgets', CupertinoIcons.chart_pie, Colors.purple),
                    SizedBox(width: Spacing.md),
                    _buildQuickActionPill(context, 'Savings', CupertinoIcons.heart, Colors.green),
                    SizedBox(width: Spacing.md),
                    _buildQuickActionPill(context, 'AI Plan', CupertinoIcons.lightbulb, Colors.orange),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        _handleQuickActionTap(context, label);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: Spacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
          CupertinoPageRoute(
            builder: (context) => const GoalsScreen(),
          ),
        );
        break;
      case 'Budgets':
        // Navigate to Budgets screen
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const BudgetsScreen(),
          ),
        );
        break;
      case 'Savings':
        // Navigate to Savings screen
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const SavingsPlannersScreen(),
          ),
        );
        break;
      case 'AI Plan':
        // Navigate to AI Monthly Planner screen
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const AIMonthlyPlannerScreen(),
          ),
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
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }


  Widget _buildWidgetPreview(BuildContext context, DashboardWidgetConfig widgetConfig) {
    switch (widgetConfig.type) {
      case DashboardWidgetType.netWorth:
        return Consumer2<AccountsController, InvestmentsController>(
          builder: (context, accountsController, investmentsController, child) {
            // Calculate Savings (non-credit accounts)
            double totalSavings = 0;
            for (var account in accountsController.accounts) {
              if (account.type != AccountType.credit && account.type != AccountType.payLater) {
                totalSavings += account.balance;
              }
            }

            // Calculate Investments
            double totalInvestments = 0;
            for (var investment in investmentsController.investments) {
              totalInvestments += investment.amount;
            }

            // Calculate Credit (limit and used)
            double totalCreditLimit = 0;
            double totalCreditUsed = 0;
            for (var account in accountsController.accounts) {
              if (account.type == AccountType.credit || account.type == AccountType.payLater) {
                totalCreditLimit += (account.creditLimit ?? 0.0);
                final used = (account.creditLimit ?? 0.0) - account.balance;
                totalCreditUsed += used;
              }
            }

            // Net Worth = Savings + Investments - Credit Used
            final totalNetWorth = totalSavings + totalInvestments - totalCreditUsed;

            // Determine color based on positive/negative
            final isPositive = totalNetWorth >= 0;
            final displayColor = isPositive ? AppStyles.getPrimaryColor(context) : Colors.red;

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
                        displayColor.withOpacity(0.15),
                        displayColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: displayColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Net Worth',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '₹${totalNetWorth.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: displayColor,
                        ),
                      ),
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: displayColor.withOpacity(0.08),
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
                                    fontSize: 11,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                ),
                                Text(
                                  '₹${totalSavings.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            if (totalInvestments > 0) ...[
                              SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Investments',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.getSecondaryTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    '₹${totalInvestments.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (totalCreditUsed > 0) ...[
                              SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Credit Used',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.getSecondaryTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    '₹${totalCreditUsed.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% Complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Spacing.md),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppStyles.getBackground(context).withOpacity(0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved ₹${totalSaved.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                    Text(
                      'Goal ₹${totalTarget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
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
            final warningCount = budgetsController.getBudgetsInWarning().length;
            final exceededCount = budgetsController.getBudgetsExceedingLimit().length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activeCount Active Budget${activeCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                SizedBox(height: Spacing.md),
                Row(
                children: [
                    _buildBadge(context, 'Warning', warningCount, Colors.orange),
                    SizedBox(width: Spacing.sm),
                    _buildBadge(context, 'Exceeded', exceededCount, Colors.red),
                  ],
                ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                SizedBox(height: Spacing.md),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: AppStyles.getBackground(context).withOpacity(0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved ₹${totalSaved.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                    Text(
                      'Target ₹${totalTarget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
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
            final recommendedSavings = goalsController.totalRecommendedMonthlySavings;
            final budgetWarnings = budgetsController.getBudgetsInWarning().length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Planner Score',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                SizedBox(height: Spacing.md),
                Row(
                  children: [
                    Icon(CupertinoIcons.lightbulb, size: 16, color: Colors.purple),
                    SizedBox(width: Spacing.sm),
                    Text(
                      '${progress.toStringAsFixed(0)}% Financial Health',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Recommended monthly savings: ₹${recommendedSavings.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                Text(
                  budgetWarnings > 0
                      ? '$budgetWarnings budgets need attention'
                      : 'Budget health looks stable',
                  style: TextStyle(
                    fontSize: 11,
                    color: budgetWarnings > 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            );
          },
        );
      case DashboardWidgetType.transactionHistory:
        return Consumer<TransactionsController>(
          builder: (context, transactionController, child) {
            final transactions = transactionController.transactions.take(3).toList();

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
                        fontSize: 13,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: transactions
                  .asMap()
                  .entries
                  .map((entry) {
                    final isLast = entry.key == transactions.length - 1;
                    final tx = entry.value;
                    final amount = tx.amount ?? 0;
                    final isExpense = amount < 0;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isExpense ? Colors.red : Colors.green)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isExpense
                                    ? CupertinoIcons.arrow_up
                                    : CupertinoIcons.arrow_down,
                                size: 18,
                                color: isExpense ? Colors.red : Colors.green,
                              ),
                            ),
                            SizedBox(width: Spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tx.description ?? 'Transaction',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Just now',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppStyles.getSecondaryTextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isExpense ? '-' : '+'}₹${amount.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isExpense ? Colors.red : Colors.green,
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
                  })
                  .toList(),
            );
          },
        );
      case DashboardWidgetType.notificationsAndActions:
        return Consumer<InvestmentsController>(
          builder: (context, investmentsController, child) {
            final fdsNearMaturity = investmentsController.investments.where((inv) {
              if (inv.type.name != 'fixedDeposit') return false;
              final metadata = inv.metadata;
              if (metadata == null || !metadata.containsKey('maturityDate')) return false;
              final maturityDate = DateTime.parse(metadata['maturityDate'] as String);
              final daysUntil = maturityDate.difference(DateTime.now()).inDays;
              return daysUntil <= 10 && daysUntil >= 0;
            }).toList();

            final fdsMatured = investmentsController.investments.where((inv) {
              if (inv.type.name != 'fixedDeposit') return false;
              final metadata = inv.metadata;
              if (metadata == null || !metadata.containsKey('maturityDate')) return false;
              final maturityDate = DateTime.parse(metadata['maturityDate'] as String);
              final daysUntil = maturityDate.difference(DateTime.now()).inDays;
              return daysUntil < 0;
            }).toList();

            final totalNotifications = fdsNearMaturity.length + fdsMatured.length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fdsMatured.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle_fill,
                          size: 20,
                          color: Colors.red,
                        ),
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${fdsMatured.length} FD${fdsMatured.length > 1 ? 's' : ''} Matured',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                'Action required',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (fdsMatured.isNotEmpty && fdsNearMaturity.isNotEmpty)
                  SizedBox(height: Spacing.md),
                if (fdsNearMaturity.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.bell_fill,
                          size: 20,
                          color: Colors.orange,
                        ),
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${fdsNearMaturity.length} FD${fdsNearMaturity.length > 1 ? 's' : ''} Maturing Soon',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                'Within 10 days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.withOpacity(0.7),
                                ),
                              ),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
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
      padding: EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
              fontSize: 11,
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
          color: color.withOpacity(0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
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
                        fontSize: 12,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$count item${count != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.getSecondaryTextColor(context).withOpacity(0.7),
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
                      fontSize: 13,
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

  void _handleWidgetTap(BuildContext context, DashboardWidgetConfig widgetConfig) {
    switch (widgetConfig.type) {
      case DashboardWidgetType.transactionHistory:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const TransactionHistoryScreen()),
        );
        break;
      case DashboardWidgetType.netWorth:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const NetWorthPage()),
        );
        break;
      case DashboardWidgetType.goalsOverview:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const GoalsScreen()),
        );
        break;
      case DashboardWidgetType.budgetsOverview:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const BudgetsScreen()),
        );
        break;
      case DashboardWidgetType.savingsPlanners:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const SavingsPlannersScreen()),
        );
        break;
      case DashboardWidgetType.aiPlanner:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const AIMonthlyPlannerScreen()),
        );
        break;
      case DashboardWidgetType.notificationsAndActions:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const NotificationsPage()),
        );
        break;
      default:
        break;
    }
  }

}

extension on List<DashboardWidgetConfig> {
  DashboardWidgetConfig? firstWhereOrNull(bool Function(DashboardWidgetConfig) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
