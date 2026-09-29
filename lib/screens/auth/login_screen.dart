import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../services/ewaste_service.dart';
import '../../utils/constants.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/server_settings.dart';
import 'auth_layout.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<EwasteService>().login(_phone.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final expired = context.watch<EwasteService>().sessionExpired;

    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Log in to track your reports, points and cash rewards.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expired)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Your session ended. Please log in again.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const FieldLabel('Phone number'),
              PhoneField(controller: _phone),
              const FieldLabel('Password'),
              PasswordField(
                controller: _password,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              FormError(_error),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _login,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Log in'),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'New to EcoCollect?',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    ),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
              const Divider(height: 28),
              const ServerLine(),
            ],
          ),
        ),
      ),
    );
  }
}
