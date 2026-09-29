import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ewaste_service.dart';
import '../services/shell_controller.dart';
import 'auth/login_screen.dart';
import 'main_shell.dart';

/// Shows the app when signed in and the login screen otherwise.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool? _wasLoggedIn;

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<EwasteService, bool>((s) => s.isLoggedIn);

    if (_wasLoggedIn == true && !loggedIn) {
      // Signed out (or the session expired): close any screens left on top.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ShellController>().goTo(ShellController.home);
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _wasLoggedIn = loggedIn;

    return loggedIn ? const MainShell() : const LoginScreen();
  }
}
