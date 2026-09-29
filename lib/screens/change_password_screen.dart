import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../widgets/form_fields.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context
          .read<EwasteService>()
          .changePassword(_current.text, _next.text);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password changed. Other devices were signed out.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Change password'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              const FieldLabel('Current password'),
              PasswordField(
                controller: _current,
                hint: 'Current password',
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
              const FieldLabel('New password'),
              PasswordField(
                controller: _next,
                hint: 'At least 6 characters',
                isNew: true,
                validator: validateNewPassword,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _confirm,
                hint: 'Repeat new password',
                isNew: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                validator: (v) =>
                    v != _next.text ? 'Passwords do not match' : null,
              ),
              FormError(_error),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Change password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
