import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../widgets/form_fields.dart';

/// Updates the signed-in member's account details on the server.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late String _district;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = context.read<EwasteService>().profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
    _email = TextEditingController(text: profile?.email ?? '');
    _district = profile?.district ?? AppConstants.districts.first;
    if (!AppConstants.districts.contains(_district)) {
      _district = AppConstants.districts.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
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
      await context.read<EwasteService>().updateAccount(
            name: _name.text.trim(),
            phone: _phone.text,
            email: _email.text.trim(),
            district: _district,
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
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
        title: const Text('Edit profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              const FieldLabel('Full name'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: validateName,
              ),
              const FieldLabel('Phone number'),
              PhoneField(controller: _phone),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'If you change it, use the new number to log in next time.',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              const FieldLabel('Email (optional)'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: validateOptionalEmail,
              ),
              const FieldLabel('District'),
              DistrictPicker(
                value: _district,
                onChanged: (d) => setState(() => _district = d),
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
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
