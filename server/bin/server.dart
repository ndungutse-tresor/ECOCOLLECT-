import 'dart:io';

import 'package:ecocollect_server/api.dart';
import 'package:ecocollect_server/store.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;

/// Run from the `server` folder: `dart run bin/server.dart`
///
/// Environment variables:
///   PORT       HTTP port (default 8787)
///   ADMIN_PIN  PIN for the admin dashboard (default admin123)
///   DATA_DIR   where db.json and photos are stored (default ./data)
Future<void> main() async {
  final env = Platform.environment;
  final port = int.tryParse(env['PORT'] ?? '') ?? 8787;
  final adminPin = env['ADMIN_PIN'] ?? 'admin123';
  final serverDir = Directory.current.path;
  final dataDir = env['DATA_DIR'] ?? p.join(serverDir, 'data');
  final projectDir = p.dirname(serverDir);

  final store = await Store.open(p.join(dataDir, 'db.json'));
  final handler = buildHandler(
    store,
    adminKey: adminPin,
    photosDir: p.join(dataDir, 'photos'),
    adminWebDir: p.join(projectDir, 'build', 'admin'),
    appWebDir: p.join(projectDir, 'build', 'web'),
  );

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  final lanIps = <String>[];
  for (final nic
      in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    lanIps.addAll(
        nic.addresses.where((a) => !a.isLoopback).map((a) => a.address));
  }

  stdout
    ..writeln('EcoCollect server running on port ${server.port}')
    ..writeln('  API:    http://localhost:${server.port}/api/health')
    ..writeln(
        '  Admin:  http://localhost:${server.port}/admin/  (PIN: $adminPin)')
    ..writeln('  Data:   ${p.join(dataDir, 'db.json')}');
  for (final ip in lanIps) {
    stdout.writeln('  On your network: http://$ip:${server.port}');
  }
  if (adminPin == 'admin123') {
    stdout.writeln('  Set ADMIN_PIN to change the default admin PIN.');
  }
}
