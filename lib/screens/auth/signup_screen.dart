import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../services/ewaste_service.dart';
import '../../utils/constants.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/server_settings.dart';
import 'auth_layout.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _district = AppConstants.districts.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await context.read<EwasteService>().register(
            name: _name.text.trim(),
            phone: _phone.text,
            email: _email.text.trim(),
            district: _district,
            password: _password.text,
          );
      navigator.popUntil((route) => route.isFirst);
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Join EcoCollect and start earning EcoPoints and cash.',
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Full name'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'e.g. Aline Uwase',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: validateName,
              ),
              const FieldLabel('Phone number'),
              PhoneField(controller: _phone),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'You log in with this number. Collectors use it for pickups and cash rewards are sent to it.',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              const FieldLabel('Email (optional)'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: validateOptionalEmail,
              ),
              const FieldLabel('Your district'),
              DistrictPicker(
                value: _district,
                onChanged: (d) => setState(() => _district = d),
              ),
              const FieldLabel('Password'),
              PasswordField(
                controller: _password,
                hint: 'At least 6 characters',
                isNew: true,
                validator: validateNewPassword,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _confirm,
                hint: 'Repeat password',
                isNew: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
                validator: (v) =>
                    v != _password.text ? 'Passwords do not match' : null,
              ),
              FormError(_error),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Log in'),
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
