import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'auth.dart';
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
  Auth? auth,
  String? adminWebDir,
  String? appWebDir,
}) {
  final router = Router();
  final passwords = auth ?? Auth();
  String now() => DateTime.now().toIso8601String();

  void requireAdmin(Request request) {
    if (request.headers['x-admin-key'] != adminKey) {
      throw ApiError(401, 'Wrong admin PIN');
    }
  }

  /// The signed-in member for this request.
  Doc requireMember(Request request) {
    final header = request.headers['authorization'] ?? '';
    if (!header.startsWith('Bearer ')) {
      throw ApiError(401, 'Please log in');
    }
    final session = store.sessions[Auth.tokenKey(header.substring(7).trim())];
    final user = session == null ? null : store.users[session['userId']];
    if (user == null) {
      throw ApiError(401, 'Your session has ended. Please log in again.');
    }
    return user;
  }

  Future<Response> startSession(Doc user) async {
    final token = passwords.newToken();
    store.sessions[Auth.tokenKey(token)] = {
      'userId': user['id'],
      'createdAt': now(),
    };
    user['lastLoginAt'] = now();
    await store.save();
    return _json({'token': token, 'user': publicUser(user)});
  }

  Doc? userByPhone(String phone) {
    for (final user in store.users.values) {
      if (user['phone'] == phone) return user;
    }
    return null;
  }

  List<Doc> byUser(Map<String, Doc> docs, String userId) =>
      docs.values.where((d) => d['userId'] == userId).toList();

  router.get(
    '/api/health',
    (Request request) => _json({'ok': true, 'time': now()}),
  );

  // Accounts ------------------------------------------------------------------

  router.post('/api/auth/register', (Request request) async {
    final body = await _body(request);
    final profile = _validateProfile(body);
    final password = body['password'];
    _validatePassword(password);
    if (userByPhone(profile['phone']!) != null) {
      throw ApiError(409, 'An account with this phone number already exists');
    }
    final id = 'u_${passwords.newToken().substring(0, 20)}';
    final user = <String, dynamic>{
      'id': id,
      ...profile,
      'passwordHash': passwords.hashPassword(password as String),
      'memberSince': now(),
      'createdAt': now(),
      'updatedAt': now(),
    };
    store.users[id] = user;
    return startSession(user);
  });

  router.post('/api/auth/login', (Request request) async {
    final body = await _body(request);
    final phone = normalizePhone(body['phone'] as String?);
    final user = phone == null ? null : userByPhone(phone);
    if (user == null ||
        !passwords.verifyPassword(
            '${body['password']}', user['passwordHash'])) {
      throw ApiError(401, 'Wrong phone number or password');
    }
    return startSession(user);
  });

  router.post('/api/auth/logout', (Request request) async {
    final header = request.headers['authorization'] ?? '';
    if (header.startsWith('Bearer ')) {
      store.sessions.remove(Auth.tokenKey(header.substring(7).trim()));
      await store.save();
    }
    return _json({'ok': true});
  });

  router.get('/api/me', (Request request) {
    return _json(publicUser(requireMember(request)));
  });

  router.put('/api/me', (Request request) async {
    final user = requireMember(request);
    final profile = _validateProfile(await _body(request));
    final owner = userByPhone(profile['phone']!);
    if (owner != null && owner['id'] != user['id']) {
      throw ApiError(409, 'Another account already uses this phone number');
    }
    user
      ..addAll(profile)
      ..['updatedAt'] = now();
    await store.save();
    return _json(publicUser(user));
  });

  router.put('/api/me/password', (Request request) async {
    final user = requireMember(request);
    final body = await _body(request);
    if (!passwords.verifyPassword(
        '${body['currentPassword']}', user['passwordHash'])) {
      throw ApiError(403, 'Your current password is not correct');
    }
    _validatePassword(body['newPassword']);
    user
      ..['passwordHash'] = passwords.hashPassword(body['newPassword'] as String)
      ..['updatedAt'] = now();
    // Sign out every other device.
    store.sessions.removeWhere(
      (key, session) =>
          session['userId'] == user['id'] &&
          key !=
              Auth.tokenKey(
                  request.headers['authorization']!.substring(7).trim()),
    );
    await store.save();
    return _json({'ok': true});
  });

  router.get('/api/me/state', (Request request) {
    final user = requireMember(request);
    final id = user['id'] as String;
    return _json({
      'user': publicUser(user),
      'reports': byUser(store.reports, id),
      'redemptions': byUser(store.redemptions, id),
      'cashClaims': byUser(store.cashClaims, id),
    });
  });

  // Member data ---------------------------------------------------------------

  router.put('/api/reports/<id>', (Request request, String id) async {
    final userId = requireMember(request)['id'];
    final body = await _body(request);
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
    final userId = requireMember(request)['id'];
    final report = store.reports[id];
    if (report == null) return _json({'deleted': false});
    if (report['userId'] != userId) {
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
    final userId = requireMember(request)['id'];
    final existing = store.redemptions[id];
    if (existing != null) return _json(existing);
    final body = await _body(request);
    final redemption = {
      'id': id,
      'userId': userId,
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
    final userId = requireMember(request)['id'] as String;
    final existing = store.cashClaims[id];
    if (existing != null) return _json(existing);
    final body = await _body(request);
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
    final phone = normalizePhone(body['momoNumber'] as String?);
    if (phone == null) throw ApiError(400, 'Enter a valid Mobile Money number');

    final claim = {
      'id': id,
      'userId': userId,
      'milestoneId': body['milestoneId'],
      'amountRwf': milestone.amountRwf,
      'momoNumber': phone,
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
      'users': store.users.values.map(publicUser).toList(),
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
    if (!reportStatuses.contains(status)) {
      throw ApiError(400, 'Invalid status');
    }

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
    if (!claimStatuses.contains(status)) {
      throw ApiError(400, 'Invalid status');
    }
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

/// A member record without secrets.
Doc publicUser(Doc user) => {
      for (final entry in user.entries)
        if (entry.key != 'passwordHash') entry.key: entry.value,
    };

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

Map<String, String> _validateProfile(Doc body) {
  final name = (body['name'] as String? ?? '').trim();
  if (name.length < 2) throw ApiError(400, 'Please enter your name');
  final phone = normalizePhone(body['phone'] as String?);
  if (phone == null) {
    throw ApiError(400, 'Enter a valid Rwandan mobile number');
  }
  final email = (body['email'] as String? ?? '').trim();
  if (email.isNotEmpty && !isValidEmail(email)) {
    throw ApiError(400, 'Enter a valid email address');
  }
  return {
    'name': name,
    'phone': phone,
    'email': email,
    'district': (body['district'] as String? ?? '').trim(),
  };
}

void _validatePassword(Object? password) {
  if (password is! String || password.length < 6) {
    throw ApiError(400, 'Password must be at least 6 characters');
  }
}

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
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Key',
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
