import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'rules.dart';
import 'store.dart';

class ApiError implements Exception {
  ApiError(this.status, this.message);

  final int status;
  final String message;
}

/// Builds the HTTP handler: the JSON API, report photos, and (when built)
/// the admin dashboard at /admin/ and the member web app at /.
Handler buildHandler(
  Store store, {
  required String adminKey,
  required String photosDir,
  String? adminWebDir,
  String? appWebDir,
}) {
  final router = Router();
  String now() => DateTime.now().toIso8601String();

  void requireAdmin(Request request) {
    if (request.headers['x-admin-key'] != adminKey) {
      throw ApiError(401, 'Wrong admin PIN');
    }
  }

  List<Doc> byUser(Map<String, Doc> docs, String userId) =>
      docs.values.where((d) => d['userId'] == userId).toList();

  router.get(
      '/api/health', (Request request) => _json({'ok': true, 'time': now()}));

  // Members -------------------------------------------------------------------

  router.put('/api/users/<id>', (Request request, String id) async {
    final body = await _body(request);
    final name = body['name'];
    if (name is! String || name.trim().isEmpty) {
      throw ApiError(400, 'Name is required');
    }
    final user = store.users[id] ?? {'id': id, 'createdAt': now()};
    user
      ..['name'] = name.trim()
      ..['phone'] = body['phone'] ?? ''
      ..['district'] = body['district'] ?? ''
      ..['memberSince'] = body['memberSince'] ?? user['memberSince'] ?? now()
      ..['updatedAt'] = now();
    store.users[id] = user;
    await store.save();
    return _json(user);
  });

  router.get('/api/users/<id>/state', (Request request, String id) {
    return _json({
      'user': store.users[id],
      'reports': byUser(store.reports, id),
      'redemptions': byUser(store.redemptions, id),
      'cashClaims': byUser(store.cashClaims, id),
    });
  });

  router.put('/api/reports/<id>', (Request request, String id) async {
    final body = await _body(request);
    final userId = body['userId'];
    if (userId is! String || !store.users.containsKey(userId)) {
      throw ApiError(400, 'Unknown member');
    }
    var report = store.reports[id];
    if (report == null) {
      _validateReport(body);
      report = {
        'id': id,
        'userId': userId,
        for (final field in _reportFields)
          if (body.containsKey(field)) field: body[field],
        'status': 'pending',
        'userConfirmedAt': body['userConfirmedAt'],
        'updatedAt': now(),
      };
      store.reports[id] = report;
    } else if (report['userId'] != userId) {
      throw ApiError(403, 'This report belongs to another member');
    } else if (report['userConfirmedAt'] == null &&
        body['userConfirmedAt'] != null) {
      report
        ..['userConfirmedAt'] = body['userConfirmedAt']
        ..['updatedAt'] = now();
    }

    final photo = body['photoBase64'];
    if (photo is String && report['photoUrl'] == null) {
      final bytes = base64Decode(photo);
      if (bytes.length > 6 * 1024 * 1024) {
        throw ApiError(413, 'Photo is too large');
      }
      final file = File(p.join(photosDir, '$id.jpg'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      report['photoUrl'] = '/photos/$id.jpg';
    }
    await store.save();
    return _json(report);
  });

  router.delete('/api/reports/<id>', (Request request, String id) async {
    final report = store.reports[id];
    if (report == null) return _json({'deleted': false});
    if (report['userId'] != request.url.queryParameters['userId']) {
      throw ApiError(403, 'This report belongs to another member');
    }
    if (report['status'] != 'pending') {
      throw ApiError(409, 'Only pending reports can be cancelled');
    }
    store.reports.remove(id);
    await store.save();
    return _json({'deleted': true});
  });

  router.put('/api/redemptions/<id>', (Request request, String id) async {
    final existing = store.redemptions[id];
    if (existing != null) return _json(existing);
    final body = await _body(request);
    final redemption = {
      'id': id,
      'userId': body['userId'],
      'rewardId': body['rewardId'],
      'code': body['code'],
      'cost': body['cost'],
      'redeemedAt': body['redeemedAt'] ?? now(),
    };
    store.redemptions[id] = redemption;
    await store.save();
    return _json(redemption);
  });

  router.put('/api/cash-claims/<id>', (Request request, String id) async {
    final existing = store.cashClaims[id];
    if (existing != null) return _json(existing);
    final body = await _body(request);
    final userId = body['userId'];
    if (userId is! String || !store.users.containsKey(userId)) {
      throw ApiError(400, 'Unknown member');
    }
    final milestone = cashMilestones[body['milestoneId']];
    if (milestone == null) throw ApiError(400, 'Unknown cash reward');
    if (creditedKg(store, userId) < milestone.kg) {
      throw ApiError(409, 'Not enough verified recycling for this reward yet');
    }
    final alreadyClaimed = store.cashClaims.values.any((c) =>
        c['userId'] == userId &&
        c['milestoneId'] == body['milestoneId'] &&
        c['status'] != 'rejected');
    if (alreadyClaimed) throw ApiError(409, 'This reward was already claimed');
    final phone = body['momoNumber'];
    if (phone is! String || phone.trim().isEmpty) {
      throw ApiError(400, 'Mobile Money number is required');
    }

    final claim = {
      'id': id,
      'userId': userId,
      'milestoneId': body['milestoneId'],
      'amountRwf': milestone.amountRwf,
      'momoNumber': phone.trim(),
      'provider': body['provider'] ?? 'MTN MoMo',
      'status': 'requested',
      'requestedAt': body['requestedAt'] ?? now(),
      'updatedAt': now(),
    };
    store.cashClaims[id] = claim;
    await store.save();
    return _json(claim);
  });

  // Admin ---------------------------------------------------------------------

  router.get('/api/admin/snapshot', (Request request) {
    requireAdmin(request);
    return _json({
      'users': store.users.values.toList(),
      'reports': store.reports.values.toList(),
      'redemptions': store.redemptions.values.toList(),
      'cashClaims': store.cashClaims.values.toList(),
      'generatedAt': now(),
    });
  });

  router.patch('/api/admin/reports/<id>', (Request request, String id) async {
    requireAdmin(request);
    final report = store.reports[id];
    if (report == null) throw ApiError(404, 'Report not found');
    final body = await _body(request);
    final status = body['status'];
    if (!reportStatuses.contains(status)) throw ApiError(400, 'Invalid status');

    final stamp = now();
    report['status'] = status;
    switch (status) {
      case 'pending':
        report['collectedAt'] = null;
        report['recycledAt'] = null;
      case 'collected':
        report['collectedAt'] ??= stamp;
        report['recycledAt'] = null;
      case 'recycled':
        report['collectedAt'] ??= stamp;
        report['recycledAt'] ??= stamp;
    }
    if (body.containsKey('note')) report['adminNote'] = body['note'];
    report['updatedAt'] = stamp;
    await store.save();
    return _json(report);
  });

  router.patch('/api/admin/cash-claims/<id>',
      (Request request, String id) async {
    requireAdmin(request);
    final claim = store.cashClaims[id];
    if (claim == null) throw ApiError(404, 'Payout not found');
    final body = await _body(request);
    final status = body['status'];
    if (!claimStatuses.contains(status)) throw ApiError(400, 'Invalid status');
    claim['status'] = status;
    if (body.containsKey('reference')) claim['reference'] = body['reference'];
    if (body.containsKey('note')) claim['note'] = body['note'];
    if (status == 'paid') claim['paidAt'] = now();
    claim['updatedAt'] = now();
    await store.save();
    return _json(claim);
  });

  // Static files --------------------------------------------------------------

  Directory(photosDir).createSync(recursive: true);
  router.mount('/photos/', createStaticHandler(photosDir));
  if (adminWebDir != null && Directory(adminWebDir).existsSync()) {
    router.get('/admin', (Request request) => Response.found('/admin/'));
    router.mount(
      '/admin/',
      createStaticHandler(adminWebDir, defaultDocument: 'index.html'),
    );
  }

  var cascade = Cascade().add(router.call);
  if (appWebDir != null && Directory(appWebDir).existsSync()) {
    cascade = cascade.add(
      createStaticHandler(appWebDir, defaultDocument: 'index.html'),
    );
  }

  return const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(_errors())
      .addHandler(cascade.handler);
}

const _reportFields = [
  'categoryId',
  'quantity',
  'estimatedWeightKg',
  'condition',
  'description',
  'disposalMethod',
  'dropoffPointId',
  'pickup',
  'createdAt',
  'ecoPoints',
];

void _validateReport(Doc body) {
  if (body['categoryId'] is! String) {
    throw ApiError(400, 'categoryId is required');
  }
  final quantity = body['quantity'];
  if (quantity is! int || quantity < 1) {
    throw ApiError(400, 'quantity must be at least 1');
  }
  if (body['estimatedWeightKg'] is! num) {
    throw ApiError(400, 'estimatedWeightKg is required');
  }
  if (!const ['dropoff', 'pickup'].contains(body['disposalMethod'])) {
    throw ApiError(400, 'disposalMethod must be dropoff or pickup');
  }
  if (body['createdAt'] is! String) {
    throw ApiError(400, 'createdAt is required');
  }
}

Response _json(Object? body, [int status = 200]) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<Doc> _body(Request request) async {
  final text = await request.readAsString();
  if (text.isEmpty) return {};
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic>) {
    throw ApiError(400, 'Expected a JSON object');
  }
  return decoded;
}

Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Key',
  };
  return (inner) => (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: headers);
        }
        final response = await inner(request);
        return response.change(headers: headers);
      };
}

Middleware _errors() {
  return (inner) => (request) async {
        try {
          return await inner(request);
        } on ApiError catch (e) {
          return _json({'error': e.message}, e.status);
        } on FormatException catch (e) {
          return _json({'error': 'Invalid request: ${e.message}'}, 400);
        }
      };
}
