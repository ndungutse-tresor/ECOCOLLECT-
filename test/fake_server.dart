import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory stand-in for the EcoCollect server's member API.
class FakeServer {
  final users = <String, Map<String, dynamic>>{}; // by phone
  final _passwords = <String, String>{};
  final reports = <String, Map<String, dynamic>>{};
  String? _token;
  String? _phone;
  int _sessions = 0;

  /// Makes every authenticated call fail with 401.
  bool expireSessions = false;

  late final http.Client client = MockClient(_handle);

  Map<String, dynamic>? get currentUser =>
      _phone == null ? null : users[_phone];

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<http.Response> _handle(http.Request request) async {
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final authed = !expireSessions &&
        _token != null &&
        request.headers['Authorization'] == 'Bearer $_token';

    http.Response session(String phone) {
      _token = 'token-${++_sessions}';
      _phone = phone;
      return _json({'token': _token, 'user': users[phone]});
    }

    final route = '${request.method} ${request.url.path}';
    switch (route) {
      case 'POST /api/auth/register':
        final phone = body['phone'] as String;
        if (users.containsKey(phone)) {
          return _json(
              {'error': 'An account with this phone number already exists'},
              409);
        }
        users[phone] = {
          'id': 'u_${users.length + 1}',
          'name': body['name'],
          'phone': phone,
          'email': body['email'] ?? '',
          'district': body['district'],
          'memberSince': DateTime(2026, 9, 1).toIso8601String(),
        };
        _passwords[phone] = body['password'] as String;
        return session(phone);
      case 'POST /api/auth/login':
        final phone = body['phone'] as String;
        if (_passwords[phone] != body['password']) {
          return _json({'error': 'Wrong phone number or password'}, 401);
        }
        return session(phone);
      case 'POST /api/auth/logout':
        _token = null;
        return _json({'ok': true});
    }

    if (!authed) return _json({'error': 'Please log in'}, 401);

    switch (route) {
      case 'PUT /api/me':
        currentUser!.addAll({
          'name': body['name'],
          'district': body['district'],
          'email': body['email'],
        });
        return _json(currentUser!);
      case 'PUT /api/me/password':
        if (_passwords[_phone] != body['currentPassword']) {
          return _json({'error': 'Your current password is not correct'}, 403);
        }
        _passwords[_phone!] = body['newPassword'] as String;
        return _json({'ok': true});
      case 'GET /api/me/state':
        return _json({
          'user': currentUser,
          'reports': reports.values.toList(),
          'redemptions': const [],
          'cashClaims': const [],
        });
    }
    if (route.startsWith('PUT /api/reports/')) {
      final report = {...body, 'status': 'pending'}..remove('synced');
      reports[body['id'] as String] = report;
      return _json(report);
    }
    return _json({'ok': true});
  }
}
