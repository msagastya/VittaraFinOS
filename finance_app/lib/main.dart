import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vittara_fin_os/ui/fintech_loader.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
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

    runApp(const MyApp());
  }, (error, stackTrace) {
    logger.error('Uncaught Exception', 
      context: 'ZonedGuarded', 
      error: error, 
      stackTrace: stackTrace);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    logger.info('Building MyApp root', context: 'MyApp');
    return MaterialApp(
      title: 'VittaraFinOS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: GoogleFonts.poppins().fontFamily,
        inputDecorationTheme: InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        cupertinoOverrideTheme: const CupertinoThemeData(
          primaryColor: Color(0xFF007AFF), // iOS Blue
        ),
      ),
      home: const SplashScreen(),
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
        // Use standard Navigator, but route to the iOS screen
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    logger.info("Building SplashScreen UI", context: 'SplashScreen');
    
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
    logger.info('Building DashboardScreen UI', context: 'Dashboard');
    // iOS-style Page Scaffold
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'VittaraFinOS',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.slider_horizontal_3, size: 24),
              onPressed: () {
                logger.info('Manage button pressed', context: 'Dashboard');
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (context) => const ManageScreen()),
                );
              },
            ),
            const SizedBox(width: 12), // Space between buttons
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.settings, size: 24),
              onPressed: () {
                logger.info('Settings button pressed', context: 'Dashboard');
              },
            ),
          ],
        ),
        backgroundColor: CupertinoColors.systemGroupedBackground,
        border: const Border(bottom: BorderSide(color: Color(0x4D000000), width: 0.0)),
      ),
      child: SafeArea(
        child: Container(
          color: CupertinoColors.systemGroupedBackground,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.chart_pie_fill,
                        size: 64,
                        color: CupertinoColors.systemGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Financial Overview',
                        style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                          fontSize: 20,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your wealth operating system is ready.',
                        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          color: CupertinoColors.secondaryLabel,
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
