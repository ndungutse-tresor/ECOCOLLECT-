import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cash_reward.dart';
import '../models/ewaste_item.dart';
import '../models/reward.dart';
import '../models/user_profile.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// The server understood the request but refused it (not a network problem).
  bool get isRejection =>
      statusCode != null && statusCode! >= 400 && statusCode != 401;

  @override
  String toString() => message;
}

/// Talks to the EcoCollect server (see the `server` folder).
class ApiClient {
  ApiClient(
    String baseUrl, {
    this.adminKey,
    this.token,
    http.Client? client,
  })  : baseUrl = normalizeUrl(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  final String? adminKey;

  /// Member session token from [login] or [register].
  String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 12);

  /// Default server address for this platform. Override at build time with
  /// `--dart-define=API_URL=http://192.168.1.10:8787`.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) {
      final base = Uri.base;
      if (base.port == 8787) return base.origin;
      return 'http://${base.host.isEmpty ? 'localhost' : base.host}:8787';
    }
    // The Android emulator reaches the host computer at 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://localhost:8787';
  }

  static String normalizeUrl(String url) {
    var value = url.trim();
    if (value.isEmpty) return value;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  /// Absolute URL for a server path such as a report photo.
  String resolve(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';
    if (adminKey != null) request.headers['X-Admin-Key'] = adminKey!;
    if (token != null) request.headers['Authorization'] = 'Bearer ${token!}';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw ApiException('The server did not respond in time.');
    } catch (e) {
      throw ApiException('Could not reach the server at $baseUrl.');
    }

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] != null
          ? '${decoded['error']}'
          : 'Request failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    }
    return decoded;
  }

  Future<void> health() => _send('GET', '/api/health');

  // Accounts ------------------------------------------------------------------

  /// Creates an account and returns the session token and profile.
  Future<(String, UserProfile)> register({
    required String name,
    required String phone,
    required String district,
    required String password,
    String email = '',
  }) async {
    final body = await _send('POST', '/api/auth/register', body: {
      'name': name,
      'phone': phone,
      'district': district,
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    return _session(body);
  }

  Future<(String, UserProfile)> login(String phone, String password) async {
    final body = await _send(
      'POST',
      '/api/auth/login',
      body: {'phone': phone, 'password': password},
    ) as Map<String, dynamic>;
    return _session(body);
  }

  (String, UserProfile) _session(Map<String, dynamic> body) {
    token = body['token'] as String;
    return (
      token!,
      UserProfile.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout() => _send('POST', '/api/auth/logout');

  Future<UserProfile> updateProfile({
    required String name,
    required String phone,
    required String district,
    String email = '',
  }) async {
    final body = await _send('PUT', '/api/me', body: {
      'name': name,
      'phone': phone,
      'district': district,
      'email': email,
    }) as Map<String, dynamic>;
    return UserProfile.fromJson(body);
  }

  Future<void> changePassword(String current, String next) => _send(
        'PUT',
        '/api/me/password',
        body: {'currentPassword': current, 'newPassword': next},
      );

  // Member data ---------------------------------------------------------------

  Future<Map<String, dynamic>> fetchMyState() async =>
      await _send('GET', '/api/me/state') as Map<String, dynamic>;

  Future<Map<String, dynamic>> upsertReport(
    EwasteItem item, {
    String? photoBase64,
  }) async {
    final body = {
      ...item.toJson(),
      if (photoBase64 != null) 'photoBase64': photoBase64,
    };
    return await _send('PUT', '/api/reports/${item.id}', body: body)
        as Map<String, dynamic>;
  }

  Future<void> deleteReport(String reportId) =>
      _send('DELETE', '/api/reports/$reportId');

  Future<void> createRedemption(Redemption redemption) => _send(
        'PUT',
        '/api/redemptions/${redemption.id}',
        body: redemption.toJson(),
      );

  Future<void> createCashClaim(CashClaim claim) => _send(
        'PUT',
        '/api/cash-claims/${claim.id}',
        body: claim.toJson(),
      );

  // Admin ---------------------------------------------------------------------

  Future<Map<String, dynamic>> adminSnapshot() async =>
      await _send('GET', '/api/admin/snapshot') as Map<String, dynamic>;

  Future<void> adminUpdateReport(String id,
          {required String status, String? note}) =>
      _send(
        'PATCH',
        '/api/admin/reports/$id',
        body: {'status': status, if (note != null) 'note': note},
      );

  Future<void> adminUpdateClaim(
    String id, {
    required String status,
    String? reference,
    String? note,
  }) =>
      _send(
        'PATCH',
        '/api/admin/cash-claims/$id',
        body: {
          'status': status,
          if (reference != null) 'reference': reference,
          if (note != null) 'note': note,
        },
      );

  void close() => _client.close();
}
