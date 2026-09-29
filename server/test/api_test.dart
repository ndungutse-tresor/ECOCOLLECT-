import 'dart:convert';
import 'dart:io';

import 'package:ecocollect_server/api.dart';
import 'package:ecocollect_server/store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Store store;
  late Handler handler;

  Future<(int, dynamic)> call(
    String method,
    String path, {
    Object? body,
    bool admin = false,
  }) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {if (admin) 'x-admin-key': 'pin'},
    ));
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  Map<String, dynamic> report(String id, double kg) => {
        'userId': 'u1',
        'categoryId': 'screens',
        'quantity': 1,
        'estimatedWeightKg': kg,
        'disposalMethod': 'dropoff',
        'dropoffPointId': 'dp1',
        'createdAt': DateTime.now().toIso8601String(),
        'ecoPoints': 85,
      };

  setUp(() async {
    store = Store.memory();
    final photos = await Directory.systemTemp.createTemp('eco_photos');
    handler = buildHandler(store, adminKey: 'pin', photosDir: photos.path);
    await call('PUT', '/api/users/u1',
        body: {'name': 'Aline', 'district': 'Gasabo'});
  });

  test('member reports start pending and cannot set their own status',
      () async {
    final (status, body) = await call('PUT', '/api/reports/r1',
        body: {...report('r1', 8), 'status': 'recycled'});
    expect(status, 200);
    expect(body['status'], 'pending');
  });

  test('admin endpoints require the PIN', () async {
    final (status, _) = await call('GET', '/api/admin/snapshot');
    expect(status, 401);
    final (ok, body) = await call('GET', '/api/admin/snapshot', admin: true);
    expect(ok, 200);
    expect(body['users'], hasLength(1));
  });

  test('admin verification unlocks a cash claim', () async {
    await call('PUT', '/api/reports/r1', body: report('r1', 12));
    final claim = {
      'userId': 'u1',
      'milestoneId': 'kg10',
      'momoNumber': '0788123456',
      'provider': 'MTN MoMo',
    };

    final (early, _) = await call('PUT', '/api/cash-claims/c1', body: claim);
    expect(early, 409);

    await call('PATCH', '/api/admin/reports/r1',
        body: {'status': 'collected'}, admin: true);
    final (ok, created) = await call('PUT', '/api/cash-claims/c1', body: claim);
    expect(ok, 200);
    expect(created['amountRwf'], 1000);

    final (dup, _) = await call('PUT', '/api/cash-claims/c2', body: claim);
    expect(dup, 409);

    await call('PATCH', '/api/admin/cash-claims/c1',
        body: {'status': 'paid', 'reference': 'TX1'}, admin: true);
    final (_, state) = await call('GET', '/api/users/u1/state');
    expect(state['cashClaims'].single['status'], 'paid');
    expect(state['reports'].single['collectedAt'], isNotNull);
  });

  test('only pending reports can be cancelled', () async {
    await call('PUT', '/api/reports/r1', body: report('r1', 1));
    await call('PATCH', '/api/admin/reports/r1',
        body: {'status': 'collected'}, admin: true);
    final (status, _) = await call('DELETE', '/api/reports/r1?userId=u1');
    expect(status, 409);
  });
}
