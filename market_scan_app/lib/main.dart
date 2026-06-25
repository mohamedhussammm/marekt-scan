import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_provider.dart';
import 'controllers/scanning_controller.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login/login_screen.dart';

import 'screens/pos/pos_scanner_screen.dart';
import 'screens/pos/sale_confirmation_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/alerts/low_stock_alerts_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/transactions/transaction_history_screen.dart';
import 'widgets/main_navigation.dart';
import 'services/api_service.dart';
import 'services/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initServerIp(); // Load saved API URL (or use ngrok default)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SyncEngine.instance..startMonitoring()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ScanningController()),
      ],
      child: const MarketScanApp(),
    ),
  );
}

class MarketScanApp extends StatelessWidget {
  const MarketScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Scan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MainNavigation(),
        '/pos': (_) => const PosScannerScreen(),
        '/sale-confirmation': (_) => const SaleConfirmationScreen(),
        '/inventory': (_) => const InventoryScreen(),
        '/reports': (_) => const ReportsScreen(),
        '/alerts': (_) => const LowStockAlertsScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/transactions-history': (_) => const TransactionHistoryScreen(),
      },
    );
  }
}
