import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cash_reward.dart';
import '../models/dropoff_point.dart';
import '../models/ewaste_item.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';

class AdminMember {
  final String id;
  final String name;
  final String phone;
  final String district;
  final DateTime? memberSince;

  const AdminMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.district,
    this.memberSince,
  });

  factory AdminMember.fromJson(Map<String, dynamic> json) => AdminMember(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Unknown member',
        phone: json['phone'] as String? ?? '',
        district: json['district'] as String? ?? '',
        memberSince: DateTime.tryParse(json['memberSince'] as String? ?? ''),
      );
}

class AdminReport {
  final EwasteItem item;
  final String userId;

  const AdminReport(this.item, this.userId);

  factory AdminReport.fromJson(Map<String, dynamic> json) =>
      AdminReport(EwasteItem.fromJson(json), json['userId'] as String? ?? '');

  String get handOverLabel {
    if (item.disposalMethod == DisposalMethod.pickup) {
      return 'Home pickup · ${item.pickup?.address ?? ''}';
    }
    return pointName(item.dropoffPointId);
  }

  static String pointName(String? id) {
    for (final point in DropoffPoint.samplePoints) {
      if (point.id == id) return point.name;
    }
    return 'Drop-off point';
  }
}

class AdminClaim {
  final CashClaim claim;
  final String userId;

  const AdminClaim(this.claim, this.userId);

  factory AdminClaim.fromJson(Map<String, dynamic> json) =>
      AdminClaim(CashClaim.fromJson(json), json['userId'] as String? ?? '');
}

class MemberStats {
  int reports = 0;
  double kg = 0;
  int earned = 0;
  int spent = 0;
  int cashPaid = 0;

  int get points => earned - spent;
}

/// Everything the dashboard shows, from one server snapshot.
class AdminSnapshot {
  final Map<String, AdminMember> members;
  final List<AdminReport> reports;
  final List<AdminClaim> claims;
  final Map<String, int> spentByUser;
  final DateTime generatedAt;

  AdminSnapshot({
    required this.members,
    required this.reports,
    required this.claims,
    required this.spentByUser,
    required this.generatedAt,
  });

  factory AdminSnapshot.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> docs(String key) =>
        (json[key] as List? ?? const []).cast<Map<String, dynamic>>();

    final reports = docs('reports').map(AdminReport.fromJson).toList()
      ..sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));
    final claims = docs('cashClaims').map(AdminClaim.fromJson).toList()
      ..sort((a, b) => b.claim.requestedAt.compareTo(a.claim.requestedAt));
    final spent = <String, int>{};
    for (final r in docs('redemptions')) {
      final user = r['userId'] as String? ?? '';
      spent[user] = (spent[user] ?? 0) + ((r['cost'] as num?)?.toInt() ?? 0);
    }

    return AdminSnapshot(
      members: {
        for (final m in docs('users').map(AdminMember.fromJson)) m.id: m,
      },
      reports: reports,
      claims: claims,
      spentByUser: spent,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  AdminMember? member(String id) => members[id];

  Iterable<AdminReport> get credited => reports.where((r) => r.item.isCredited);

  double get totalKg =>
      credited.fold(0.0, (sum, r) => sum + r.item.estimatedWeightKg);

  double get co2Kg => totalKg * AppConstants.co2PerKg;

  List<AdminReport> withStatus(ItemStatus status) =>
      reports.where((r) => r.item.status == status).toList();

  List<AdminReport> get toVerify {
    final list = withStatus(ItemStatus.pending);
    // Members who say they already handed over come first.
    list.sort((a, b) {
      final aw = a.item.awaitingVerification ? 0 : 1;
      final bw = b.item.awaitingVerification ? 0 : 1;
      if (aw != bw) return aw - bw;
      return a.item.createdAt.compareTo(b.item.createdAt);
    });
    return list;
  }

  int get awaitingVerificationCount =>
      reports.where((r) => r.item.awaitingVerification).length;

  /// Pending home pickups, soonest first.
  List<AdminReport> get pickupsToDo {
    final list = reports
        .where((r) =>
            r.item.isPending &&
            r.item.disposalMethod == DisposalMethod.pickup &&
            r.item.pickup != null)
        .toList();
    int slot(AdminReport r) =>
        PickupDetails.timeSlots.indexOf(r.item.pickup!.timeSlot);
    list.sort((a, b) {
      final byDate = a.item.pickup!.date.compareTo(b.item.pickup!.date);
      return byDate != 0 ? byDate : slot(a) - slot(b);
    });
    return list;
  }

  List<AdminClaim> get claimsToPay =>
      claims.where((c) => c.claim.isOpen).toList();

  int get cashOwedRwf =>
      claimsToPay.fold(0, (sum, c) => sum + c.claim.amountRwf);

  int get cashPaidRwf => claims
      .where((c) => c.claim.status == ClaimStatus.paid)
      .fold(0, (sum, c) => sum + c.claim.amountRwf);

  Map<String, double> get kgByDistrict {
    final totals = {for (final d in AppConstants.districts) d: 0.0};
    for (final r in credited) {
      final district = members[r.userId]?.district ?? '';
      if (district.isEmpty) continue;
      totals[district] = (totals[district] ?? 0) + r.item.estimatedWeightKg;
    }
    return totals;
  }

  List<MapEntry<EwasteCategory, double>> get kgByCategory {
    final totals = <String, double>{};
    for (final r in credited) {
      totals[r.item.categoryId] =
          (totals[r.item.categoryId] ?? 0) + r.item.estimatedWeightKg;
    }
    return totals.entries
        .map((e) => MapEntry(EwasteCategory.byId(e.key), e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  MemberStats statsFor(String userId) {
    final stats = MemberStats()..spent = spentByUser[userId] ?? 0;
    for (final r in reports.where((r) => r.userId == userId)) {
      stats.reports++;
      if (r.item.isCredited) {
        stats.kg += r.item.estimatedWeightKg;
        stats.earned += r.item.ecoPoints;
      }
    }
    for (final c in claims) {
      if (c.userId == userId && c.claim.status == ClaimStatus.paid) {
        stats.cashPaid += c.claim.amountRwf;
      }
    }
    return stats;
  }
}

/// Admin session: signs in with the server PIN and keeps the data fresh.
class AdminService extends ChangeNotifier {
  static const _urlKey = 'admin.serverUrl';
  static const _pinKey = 'admin.pin';

  AdminService({String? defaultUrl})
      : serverUrl = defaultUrl ?? ApiClient.defaultBaseUrl {
    ready = _restore();
  }

  late final Future<void> ready;
  String serverUrl;
  ApiClient? _api;
  AdminSnapshot? snapshot;
  bool restoring = true;
  bool loading = false;
  String? error;
  Timer? _timer;

  bool get signedIn => _api != null && snapshot != null;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serverUrl = prefs.getString(_urlKey) ?? serverUrl;
      final pin = prefs.getString(_pinKey);
      if (pin != null) await signIn(serverUrl, pin);
    } catch (_) {
      // Stay on the sign-in screen.
    }
    restoring = false;
    notifyListeners();
  }

  /// Returns an error message, or null when signed in.
  Future<String?> signIn(String url, String pin) async {
    final api = ApiClient(url, adminKey: pin.trim());
    try {
      snapshot = AdminSnapshot.fromJson(await api.adminSnapshot());
    } on ApiException catch (e) {
      return e.statusCode == 401 ? 'Wrong admin PIN.' : e.message;
    }
    _api = api;
    serverUrl = api.baseUrl;
    error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, serverUrl);
    await prefs.setString(_pinKey, pin.trim());
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refresh(quiet: true),
    );
    notifyListeners();
    return null;
  }

  Future<void> refresh({bool quiet = false}) async {
    final api = _api;
    if (api == null || loading) return;
    loading = !quiet;
    notifyListeners();
    try {
      snapshot = AdminSnapshot.fromJson(await api.adminSnapshot());
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> setReportStatus(
    String id,
    ItemStatus status, {
    String? note,
  }) =>
      _run(() => _api!.adminUpdateReport(id, status: status.name, note: note));

  Future<String?> updateClaim(
    String id,
    ClaimStatus status, {
    String? reference,
    String? note,
  }) =>
      _run(() => _api!.adminUpdateClaim(
            id,
            status: status.name,
            reference: reference,
            note: note,
          ));

  Future<String?> _run(Future<void> Function() action) async {
    if (_api == null) return 'Not signed in';
    try {
      await action();
    } on ApiException catch (e) {
      return e.message;
    }
    await refresh(quiet: true);
    return null;
  }

  String photoUrl(String path) => _api?.resolve(path) ?? path;

  Future<void> signOut() async {
    _timer?.cancel();
    _api = null;
    snapshot = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
