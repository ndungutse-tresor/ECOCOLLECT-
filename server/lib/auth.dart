import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Password hashing (PBKDF2-HMAC-SHA256) and session tokens.
class Auth {
  Auth({this.iterations = 60000});

  /// Lower in tests to keep them fast.
  final int iterations;
  final _random = Random.secure();

  String _randomHex(int bytes) => List.generate(
        bytes,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  /// Returns `pbkdf2$<iterations>$<salt>$<hash>`.
  String hashPassword(String password) {
    final salt = _randomHex(16);
    final hash = _pbkdf2(password, salt, iterations);
    return 'pbkdf2\$$iterations\$$salt\$$hash';
  }

  bool verifyPassword(String password, String? stored) {
    if (stored == null) return false;
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null) return false;
    return _constantTimeEquals(_pbkdf2(password, parts[2], rounds), parts[3]);
  }

  /// A new random session token (returned to the client once).
  String newToken() => _randomHex(32);

  /// Sessions are stored by token hash so a leaked database can't be replayed.
  static String tokenKey(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  static String _pbkdf2(String password, String saltHex, int rounds) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final salt = utf8.encode(saltHex);
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(block);
    for (var i = 1; i < rounds; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Normalises Rwandan mobile numbers to 07XXXXXXXX. Returns null if invalid.
String? normalizePhone(String? input) {
  if (input == null) return null;
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('250') && digits.length == 12) {
    digits = '0${digits.substring(3)}';
  } else if (digits.length == 9 && digits.startsWith('7')) {
    digits = '0$digits';
  }
  return RegExp(r'^07\d{8}$').hasMatch(digits) ? digits : null;
}

bool isValidEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
