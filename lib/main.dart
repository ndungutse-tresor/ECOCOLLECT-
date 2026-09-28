import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ewaste_service.dart';
import 'services/location_service.dart';
import 'services/shell_controller.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EcoCollectApp());
}

class EcoCollectApp extends StatelessWidget {
  /// Optional pre-built service, used by tests.
  final EwasteService? service;

  const EcoCollectApp({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => service ?? EwasteService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => ShellController()),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
