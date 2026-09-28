import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ).createShader(bounds),
        child: Icon(
          Icons.recycling_rounded,
          size: size * 0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Thin stripe in the colours of the Rwandan flag.
class FlagStripe extends StatelessWidget {
  final double width;
  final double height;

  const FlagStripe({super.key, this.width = 72, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          children: [
            Expanded(flex: 2, child: Container(color: AppColors.flagBlue)),
            Expanded(child: Container(color: AppColors.flagYellow)),
            Expanded(child: Container(color: AppColors.flagGreen)),
          ],
        ),
      ),
    );
  }
}
