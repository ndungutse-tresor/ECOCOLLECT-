import 'dart:convert';
import 'dart:io';

import 'seed.dart';

typedef Doc = Map<String, dynamic>;

/// Tiny JSON-file database: collections of documents keyed by id.
class Store {
  Store._(this._file, this._data);

  static const collections = [
    'users',
    'sessions',
    'reports',
    'redemptions',
    'cashClaims',
  ];

  final File? _file;
  final Map<String, Map<String, Doc>> _data;
  Future<void> _writing = Future.value();

  /// Opens (or creates) the database at [path]. New databases get sample data
  /// when [seed] is true so the admin dashboard has something to show.
  static Future<Store> open(String path, {bool seed = true}) async {
    final file = File(path);
    if (await file.exists()) {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return Store._(file, _parse(raw));
    }
    await file.parent.create(recursive: true);
    final store = Store._(file, _empty());
    if (seed) seedSampleData(store);
    await store.save();
    return store;
  }

  /// In-memory store for tests.
  factory Store.memory({bool seed = false}) {
    final store = Store._(null, _empty());
    if (seed) seedSampleData(store);
    return store;
  }

  static Map<String, Map<String, Doc>> _empty() =>
      {for (final c in collections) c: <String, Doc>{}};

  static Map<String, Map<String, Doc>> _parse(Map<String, dynamic> raw) {
    final data = _empty();
    for (final c in collections) {
      final docs = raw[c] as Map<String, dynamic>? ?? {};
      docs.forEach((id, doc) => data[c]![id] = Map<String, dynamic>.from(doc));
    }
    return data;
  }

  Map<String, Doc> get users => _data['users']!;
  Map<String, Doc> get sessions => _data['sessions']!;
  Map<String, Doc> get reports => _data['reports']!;
  Map<String, Doc> get redemptions => _data['redemptions']!;
  Map<String, Doc> get cashClaims => _data['cashClaims']!;

  /// Writes are queued so concurrent requests never interleave on disk.
  Future<void> save() {
    final file = _file;
    if (file == null) return Future.value();
    _writing = _writing.then((_) async {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(_data), flush: true);
      try {
        await tmp.rename(file.path);
      } on FileSystemException {
        await file.delete();
        await tmp.rename(file.path);
      }
    });
    return _writing;
  }
}
