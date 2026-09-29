import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';
import '../../widgets/app_logo.dart';

/// Green header with the logo, and a white card for the form.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration:
                    const BoxDecoration(gradient: AppColors.heroGradient),
                padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 56),
                child: Stack(
                  children: [
                    if (showBack)
                      Positioned(
                        left: -12,
                        top: -4,
                        child: IconButton(
                          tooltip: 'Back',
                          color: Colors.white,
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            const AppLogo(size: 72),
                            const SizedBox(height: 18),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.4,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
