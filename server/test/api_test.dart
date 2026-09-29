import 'dart:convert';
import 'dart:io';

import 'package:ecocollect_server/api.dart';
import 'package:ecocollect_server/auth.dart';
import 'package:ecocollect_server/store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Store store;
  late Handler handler;
  late String token;

  Future<(int, dynamic)> call(
    String method,
    String path, {
    Object? body,
    bool admin = false,
    String? auth,
  }) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        if (admin) 'x-admin-key': 'pin',
        if (auth != null) 'authorization': 'Bearer $auth',
      },
    ));
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  Map<String, dynamic> report(double kg) => {
        'categoryId': 'screens',
        'quantity': 1,
        'estimatedWeightKg': kg,
        'disposalMethod': 'dropoff',
        'dropoffPointId': 'dp1',
        'createdAt': DateTime.now().toIso8601String(),
        'ecoPoints': 85,
      };

  const account = {
    'name': 'Aline Uwase',
    'phone': '+250 788 123 456',
    'district': 'Gasabo',
    'password': 'secret123',
  };

  setUp(() async {
    store = Store.memory();
    final photos = await Directory.systemTemp.createTemp('eco_photos');
    handler = buildHandler(
      store,
      adminKey: 'pin',
      photosDir: photos.path,
      auth: Auth(iterations: 1000),
    );
    final (_, body) = await call('POST', '/api/auth/register', body: account);
    token = body['token'] as String;
  });

  group('accounts', () {
    test('register normalises the phone and hides the password', () async {
      final (status, me) = await call('GET', '/api/me', auth: token);
      expect(status, 200);
      expect(me['phone'], '0788123456');
      expect(me.containsKey('passwordHash'), isFalse);
    });

    test('a phone number can only have one account', () async {
      final (status, _) =
          await call('POST', '/api/auth/register', body: account);
      expect(status, 409);
    });

    test('login checks the password', () async {
      final (wrong, _) = await call('POST', '/api/auth/login',
          body: {'phone': '0788123456', 'password': 'nope'});
      expect(wrong, 401);
      final (ok, body) = await call('POST', '/api/auth/login',
          body: {'phone': '0788123456', 'password': 'secret123'});
      expect(ok, 200);
      expect(body['user']['name'], 'Aline Uwase');
    });

    test('logout ends the session', () async {
      await call('POST', '/api/auth/logout', auth: token);
      final (status, _) = await call('GET', '/api/me', auth: token);
      expect(status, 401);
    });

    test('members can update their details and password', () async {
      final (status, me) = await call('PUT', '/api/me', auth: token, body: {
        'name': 'Aline U.',
        'phone': '0788123456',
        'district': 'Kicukiro',
        'email': 'aline@example.com',
      });
      expect(status, 200);
      expect(me['district'], 'Kicukiro');

      final (bad, _) = await call('PUT', '/api/me/password',
          auth: token,
          body: {'currentPassword': 'wrong', 'newPassword': 'newpass1'});
      expect(bad, 403);
      final (ok, _) = await call('PUT', '/api/me/password',
          auth: token,
          body: {'currentPassword': 'secret123', 'newPassword': 'newpass1'});
      expect(ok, 200);
      final (login, _) = await call('POST', '/api/auth/login',
          body: {'phone': '0788123456', 'password': 'newpass1'});
      expect(login, 200);
    });
  });

  test('member endpoints require a session', () async {
    final (status, _) = await call('PUT', '/api/reports/r1', body: report(8));
    expect(status, 401);
  });

  test('member reports start pending and cannot set their own status',
      () async {
    final (status, body) = await call('PUT', '/api/reports/r1',
        auth: token, body: {...report(8), 'status': 'recycled'});
    expect(status, 200);
    expect(body['status'], 'pending');
  });

  test('admin endpoints require the PIN and never expose passwords', () async {
    final (status, _) = await call('GET', '/api/admin/snapshot');
    expect(status, 401);
    final (ok, body) = await call('GET', '/api/admin/snapshot', admin: true);
    expect(ok, 200);
    expect(body['users'], hasLength(1));
    expect(body['users'][0].containsKey('passwordHash'), isFalse);
  });

  test('admin verification unlocks a cash claim', () async {
    await call('PUT', '/api/reports/r1', auth: token, body: report(12));
    final claim = {
      'milestoneId': 'kg10',
      'momoNumber': '0788123456',
      'provider': 'MTN MoMo',
    };

    final (early, _) =
        await call('PUT', '/api/cash-claims/c1', auth: token, body: claim);
    expect(early, 409);

    await call('PATCH', '/api/admin/reports/r1',
        body: {'status': 'collected'}, admin: true);
    final (ok, created) =
        await call('PUT', '/api/cash-claims/c1', auth: token, body: claim);
    expect(ok, 200);
    expect(created['amountRwf'], 1000);

    final (dup, _) =
        await call('PUT', '/api/cash-claims/c2', auth: token, body: claim);
    expect(dup, 409);

    await call('PATCH', '/api/admin/cash-claims/c1',
        body: {'status': 'paid', 'reference': 'TX1'}, admin: true);
    final (_, state) = await call('GET', '/api/me/state', auth: token);
    expect(state['cashClaims'].single['status'], 'paid');
    expect(state['reports'].single['collectedAt'], isNotNull);
  });

  test('only pending reports can be cancelled', () async {
    await call('PUT', '/api/reports/r1', auth: token, body: report(1));
    await call('PATCH', '/api/admin/reports/r1',
        body: {'status': 'collected'}, admin: true);
    final (status, _) = await call('DELETE', '/api/reports/r1', auth: token);
    expect(status, 409);
  });
}
