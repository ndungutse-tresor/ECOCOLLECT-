import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0D7C5F);
  static const primaryDark = Color(0xFF064E3B);
  static const primaryLight = Color(0xFF2AB573);
  static const primarySoft = Color(0xFFE3F3EC);
  static const accent = Color(0xFFF5A623);
  static const accentDark = Color(0xFFA86400);
  static const accentLight = Color(0xFFFFC857);
  static const accentSoft = Color(0xFFFFF3DC);
  static const sky = Color(0xFF0284C7);
  static const skySoft = Color(0xFFE0F2FE);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF1EAFE);
  static const background = Color(0xFFF3F6F4);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF7F9F8);
  static const border = Color(0xFFE2E8E5);
  static const textPrimary = Color(0xFF10201A);
  static const textSecondary = Color(0xFF5F6F68);
  static const textMuted = Color(0xFF8F9E98);
  static const success = Color(0xFF12A150);
  static const successSoft = Color(0xFFE2F6EA);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFEF3E2);
  static const error = Color(0xFFDC3545);
  static const errorSoft = Color(0xFFFDECEE);
  static const cardShadow = Color(0x0F0B3D2C);

  // Rwanda flag colours, used as a small accent stripe.
  static const flagBlue = Color(0xFF00A1DE);
  static const flagYellow = Color(0xFFFAD201);
  static const flagGreen = Color(0xFF20603D);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
    stops: [0, 0.55, 1],
  );
}

class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x120B3D2C), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const soft = [
    BoxShadow(color: Color(0x0D0B3D2C), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x240B3D2C), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

class AppStrings {
  static const appName = 'EcoCollect Rwanda';
  static const tagline = 'Turn e-waste into impact';
  static const splashSubtitle = 'Making e-waste recycling as easy as a tap';
}

class AppConstants {
  static const districts = ['Nyarugenge', 'Kicukiro', 'Gasabo'];

  /// Approximate kg of CO₂ avoided per kg of e-waste recycled.
  static const co2PerKg = 3.0;

  /// Personal CO₂ goal shown on the impact ring.
  static const personalCo2Goal = 50.0;

  /// Collected items move to "recycled" after this long.
  static const recycleProcessingTime = Duration(days: 2);

  static const kigaliCenterLat = -1.9536;
  static const kigaliCenterLng = 30.0806;

  static const tips = [
    'Back up and factory-reset phones and laptops before recycling them to protect your personal data.',
    'Tape over the terminals of loose batteries. It prevents short circuits and fires in collection bins.',
    'Old phones contain gold, silver and copper that can be recovered and reused instead of mined.',
    'Never burn cables to recover copper. The smoke releases toxic fumes that harm your lungs.',
    'Broken screens and swollen batteries are still recyclable. Keep them dry and bring them in as they are.',
    'Rwanda generates over 16,000 tonnes of e-waste per year. Every kilogram you recycle matters!',
    'Chargers you no longer use are e-waste too. Collect them in one bag and drop them off together.',
  ];
}
