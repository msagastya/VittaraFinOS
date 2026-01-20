import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/logic/brokers_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/fintech_loader.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
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
        return Stack(
          children: [
            DefaultTextStyle(
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                decoration: TextDecoration.none,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E),
              ),
              child: child!,
            ),
            // LOCK SCREEN OVERLAY
            if (settings.isLocked && settings.appLoaded)
              const Positioned.fill(child: LockScreen()),
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.lock_fill, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'VittaraFinOS Locked',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            CupertinoButton(
              color: CupertinoColors.systemBlue,
              onPressed: () {
                Provider.of<SettingsController>(context, listen: false).authenticateAndUnlock();
              },
              child: const Text('Unlock', style: TextStyle(color: Colors.white)),
            ),
          ],
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
    final settings = Provider.of<SettingsController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('VittaraFinOS'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.slider_horizontal_3, size: 24, color: isDark ? Colors.white : CupertinoColors.black),
              onPressed: () {
                Navigator.of(context).push(FadeScalePageRoute(page: const ManageScreen()));
              },
            ),
            const SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.settings, size: 24, color: isDark ? Colors.white : CupertinoColors.black),
              onPressed: () {
                Navigator.of(context).push(FadeScalePageRoute(page: const SettingsScreen()));
              },
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemGroupedBackground,
        border: null,
      ),
      child: SafeArea(
        child: Container(
          color: isDark ? Colors.black : CupertinoColors.systemGroupedBackground,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.chart_pie_fill,
                        size: 64,
                        color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Financial Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : CupertinoColors.label,
                        ),
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
}