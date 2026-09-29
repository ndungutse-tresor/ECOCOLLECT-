import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_theme.dart';
import 'admin_login_screen.dart';
import 'admin_service.dart';
import 'admin_shell.dart';

/// Admin dashboard entry point.
///
///   flutter run -d chrome -t lib/admin/admin_main.dart
///   flutter build web -t lib/admin/admin_main.dart --base-href /admin/ -o build/admin
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminService(),
      child: MaterialApp(
        title: 'EcoCollect Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Consumer<AdminService>(
          builder: (context, service, _) {
            if (service.restoring) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return service.signedIn
                ? const AdminShell()
                : const AdminLoginScreen();
          },
        ),
      ),
    );
  }
}
