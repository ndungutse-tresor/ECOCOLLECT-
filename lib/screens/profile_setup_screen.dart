import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/app_logo.dart';
import 'main_shell.dart';

/// Creates the profile during onboarding, or edits it when [existing] is set.
class ProfileSetupScreen extends StatefulWidget {
  final UserProfile? existing;

  const ProfileSetupScreen({super.key, this.existing});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late String _district;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.existing?.phone ?? '');
    _district = widget.existing?.district ?? AppConstants.districts.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final service = context.read<EwasteService>();
    final navigator = Navigator.of(context);

    if (_editing) {
      await service.updateProfile(
        widget.existing!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          district: _district,
        ),
      );
      navigator.pop();
      return;
    }

    await service.completeOnboarding(
      UserProfile(
        id: UserProfile.newId(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        district: _district,
        memberSince: DateTime.now(),
      ),
    );
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_editing ? 'Edit profile' : ''),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              if (!_editing) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppLogo(size: 64),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome! Let’s set you up',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We use this to greet you, suggest nearby drop-off points and arrange pickups.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
              ],
              const _FieldLabel('Your name'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. Aline Uwase',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Phone number (for pickups)'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: const InputDecoration(
                  hintText: '07X XXX XXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return isValidRwandaPhone(v)
                      ? null
                      : 'Enter a valid Rwandan mobile number';
                },
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Your district'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.districts.map((d) {
                  final selected = d == _district;
                  return ChoiceChip(
                    label: Text(d),
                    selected: selected,
                    showCheckmark: false,
                    avatar: selected
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.primary)
                        : null,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    onSelected: (_) => setState(() => _district = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),
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
                    : Text(_editing ? 'Save changes' : 'Start recycling'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}
