import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/fintech_loader.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/notifications_page.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_renewal_modal.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_withdrawal_modal.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/ui/dashboard/notification_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/actions_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/transaction_history_widget.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/net_worth_widget.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';

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

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('VittaraFinOS'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Manage button
                BouncyButton(
                  onPressed: () {
                    Navigator.of(context).push(FadeScalePageRoute(page: const ManageScreen()));
                  },
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
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
                            'Tap Edit to enable widgets',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.lg),
      child: Column(
        children: visibleWidgets
            .map((widget) => Padding(
                  padding: EdgeInsets.only(bottom: Spacing.md),
                  child: _buildExpandableCard(context, widget),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildExpandableCard(BuildContext context, DashboardWidgetConfig widgetConfig) {
    return GestureDetector(
      onTap: () {
        _handleWidgetTap(context, widgetConfig);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widgetConfig.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 20,
                    color: AppStyles.getPrimaryColor(context),
                  ),
                ],
              ),
            ),
            // Preview content (2-3 lines)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 80),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildWidgetPreview(context, widgetConfig),
                ),
              ),
            ),
            SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetPreview(BuildContext context, DashboardWidgetConfig widgetConfig) {
    switch (widgetConfig.type) {
      case DashboardWidgetType.actions:
        return Text(
          'Manage accounts, transactions, and investments',
          style: TextStyle(
            fontSize: 13,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      case DashboardWidgetType.netWorth:
        return Text(
          'View your total net worth across all accounts and investments',
          style: TextStyle(
            fontSize: 13,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      case DashboardWidgetType.transactionHistory:
        return Text(
          'Track all your recent transactions',
          style: TextStyle(
            fontSize: 13,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      case DashboardWidgetType.fdNotifications:
        return Consumer<InvestmentsController>(
          builder: (context, investmentsController, child) {
            final investments = investmentsController.investments;
            final fdsMatured = investments.where((inv) {
              if (inv.type.name != 'fixedDeposit') return false;
              final metadata = inv.metadata;
              if (metadata == null || !metadata.containsKey('maturityDate')) return false;
              final maturityDate = DateTime.parse(metadata['maturityDate'] as String);
              final daysUntil = maturityDate.difference(DateTime.now()).inDays;
              return daysUntil < 0;
            }).toList();

            if (fdsMatured.isEmpty) {
              return Text(
                'No matured FDs. All investments are on track',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            }

            return Text(
              '${fdsMatured.length} matured FD${fdsMatured.length > 1 ? 's' : ''} awaiting action',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleWidgetTap(BuildContext context, DashboardWidgetConfig widgetConfig) {
    switch (widgetConfig.type) {
      case DashboardWidgetType.actions:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const ManageScreen()),
        );
        break;
      case DashboardWidgetType.transactionHistory:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const TransactionHistoryScreen()),
        );
        break;
      case DashboardWidgetType.netWorth:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => const ManageScreen()),
        );
        break;
      case DashboardWidgetType.fdNotifications:
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
