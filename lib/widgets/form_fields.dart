import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/format.dart';

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 18),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputAction textInputAction;

  const PhoneField({
    super.key,
    required this.controller,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
      decoration: const InputDecoration(
        hintText: '07X XXX XXXX',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
      validator: validatePhone,
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool isNew;

  const PasswordField({
    super.key,
    required this.controller,
    this.hint = 'Password',
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.isNew = false,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: [
        widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
      ],
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class DistrictPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const DistrictPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.districts.map((d) {
        final selected = d == value;
        return ChoiceChip(
          label: Text(d),
          selected: selected,
          showCheckmark: false,
          avatar: selected
              ? const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.primary,
                )
              : null,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          onSelected: (_) => onChanged(d),
        );
      }).toList(),
    );
  }
}

/// Inline error message under a form.
class FormError extends StatelessWidget {
  final String? message;

  const FormError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: Color(0xFF9F1D2A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? validateName(String? value) =>
    (value == null || value.trim().length < 2)
        ? 'Please enter your name'
        : null;

String? validatePhone(String? value) =>
    (value == null || !isValidRwandaPhone(value))
        ? 'Enter a valid Rwandan mobile number'
        : null;

String? validateOptionalEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
      ? null
      : 'Enter a valid email address';
}

String? validateNewPassword(String? value) =>
    (value == null || value.length < 6) ? 'Use at least 6 characters' : null;
