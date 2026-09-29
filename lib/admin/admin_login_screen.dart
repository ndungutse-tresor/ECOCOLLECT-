import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../widgets/app_logo.dart';
import 'admin_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  late final TextEditingController _url;
  final _pin = TextEditingController();
  bool _busy = false;
  bool _hidePin = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: context.read<AdminService>().serverUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_pin.text.trim().isEmpty) {
      setState(() => _error = 'Enter the admin PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error =
        await context.read<AdminService>().signIn(_url.text, _pin.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadows.floating,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 64)),
                  const SizedBox(height: 18),
                  const Text(
                    'EcoCollect Admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Verify hand-overs, schedule pickups and pay cash rewards.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pin,
                    obscureText: _hidePin,
                    autofocus: true,
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Admin PIN',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hidePin ? 'Show PIN' : 'Hide PIN',
                        onPressed: () => setState(() => _hidePin = !_hidePin),
                        icon: Icon(
                          _hidePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
