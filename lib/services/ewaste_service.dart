import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cash_reward.dart';
import '../models/dropoff_point.dart';
import '../models/ewaste_item.dart';
import '../models/reward.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import 'api_client.dart';

class MonthlyTotal {
  final DateTime month;
  final double weightKg;

  const MonthlyTotal(this.month, this.weightKg);
}

enum SyncStatus { off, idle, syncing, synced, offline }

/// Holds the member's reports, points, rewards and profile. Everything is
/// saved on the device first and synced with the EcoCollect server whenever
/// it is reachable, so the app keeps working offline.
class EwasteService extends ChangeNotifier {
  static const _itemsKey = 'ecocollect.items';
  static const _redemptionsKey = 'ecocollect.redemptions';
  static const _claimsKey = 'ecocollect.cashClaims';
  static const _profileKey = 'ecocollect.profile';
  static const _onboardedKey = 'ecocollect.onboarded';
  static const _serverUrlKey = 'ecocollect.serverUrl';
  static const _pendingDeletesKey = 'ecocollect.pendingDeletes';

  /// [serverUrl] sets the default server (an empty string disables syncing).
  EwasteService({String? serverUrl, http.Client? httpClient})
      : _defaultServerUrl = serverUrl ?? ApiClient.defaultBaseUrl,
        _httpClient = httpClient {
    ready = _load();
  }

  final String _defaultServerUrl;
  final http.Client? _httpClient;

  /// Completes once saved data has been loaded.
  late final Future<void> ready;

  SharedPreferences? _prefs;
  List<EwasteItem> _items = [];
  List<Redemption> _redemptions = [];
  List<CashClaim> _claims = [];
  List<String> _pendingDeletes = [];
  UserProfile? _profile;
  bool _onboarded = false;
  bool _loaded = false;
  final _random = Random();

  String _serverUrl = '';
  ApiClient? _api;
  SyncStatus _syncStatus = SyncStatus.idle;
  DateTime? _lastSyncedAt;
  String? _syncError;
  bool _syncing = false;
  bool _syncAgain = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
        final raw = prefs.getString(key);
        if (raw == null) return [];
        return (jsonDecode(raw) as List)
            .map((e) => parse(e as Map<String, dynamic>))
            .toList();
      }

      _items = list(_itemsKey, EwasteItem.fromJson);
      _redemptions = list(_redemptionsKey, Redemption.fromJson);
      _claims = list(_claimsKey, CashClaim.fromJson);
      _pendingDeletes = prefs.getStringList(_pendingDeletesKey) ?? [];

      final profileJson = prefs.getString(_profileKey);
      if (profileJson != null) {
        _profile = UserProfile.fromJson(
          jsonDecode(profileJson) as Map<String, dynamic>,
        );
      }
      _onboarded = prefs.getBool(_onboardedKey) ?? false;
      _serverUrl = ApiClient.normalizeUrl(
        prefs.getString(_serverUrlKey) ?? _defaultServerUrl,
      );
    } catch (e) {
      debugPrint('EcoCollect: could not load saved data: $e');
      _serverUrl = ApiClient.normalizeUrl(_defaultServerUrl);
    }

    _syncStatus = _serverUrl.isEmpty ? SyncStatus.off : SyncStatus.idle;
    _sortItems();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      String encode(Iterable<dynamic> list) =>
          jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(_itemsKey, encode(_items));
      await prefs.setString(_redemptionsKey, encode(_redemptions));
      await prefs.setString(_claimsKey, encode(_claims));
      await prefs.setStringList(_pendingDeletesKey, _pendingDeletes);
      await prefs.setString(_serverUrlKey, _serverUrl);
      if (_profile != null) {
        await prefs.setString(_profileKey, jsonEncode(_profile!.toJson()));
      }
      await prefs.setBool(_onboardedKey, _onboarded);
    } catch (e) {
      debugPrint('EcoCollect: could not save data: $e');
    }
  }

  void _sortItems() =>
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _changed() async {
    notifyListeners();
    await _save();
    unawaited(sync());
  }

  // ---------------------------------------------------------------------------
  // Read-only state

  bool get isLoaded => _loaded;
  bool get isOnboarded => _onboarded;
  UserProfile? get profile => _profile;

  List<EwasteItem> get items => List.unmodifiable(_items);

  EwasteItem? getItemById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<EwasteItem> itemsWithStatus(ItemStatus status) =>
      _items.where((i) => i.status == status).toList();

  List<EwasteItem> get pendingItems => itemsWithStatus(ItemStatus.pending);
  List<EwasteItem> get collectedItems => itemsWithStatus(ItemStatus.collected);
  List<EwasteItem> get recycledItems => itemsWithStatus(ItemStatus.recycled);

  Iterable<EwasteItem> get _credited => _items.where((i) => i.isCredited);

  /// Verified weight (collected or recycled).
  double get totalWeightKg =>
      _credited.fold(0.0, (sum, i) => sum + i.estimatedWeightKg);

  int get totalItemsCollected =>
      _credited.fold(0, (sum, i) => sum + i.quantity);

  double get co2Prevented => totalWeightKg * AppConstants.co2PerKg;

  /// All points ever credited. Drives the member's level.
  int get earnedPoints => _credited.fold(0, (sum, i) => sum + i.ecoPoints);

  /// Points waiting for pending reports to be verified.
  int get pendingPoints => pendingItems.fold(0, (sum, i) => sum + i.ecoPoints);

  int get spentPoints => _redemptions.fold(0, (sum, r) => sum + r.cost);

  /// Spendable balance.
  int get ecoPoints => earnedPoints - spentPoints;

  EcoLevel get level => EcoLevel.forPoints(earnedPoints);

  List<Redemption> get redemptions {
    final list = [..._redemptions];
    list.sort((a, b) => b.redeemedAt.compareTo(a.redeemedAt));
    return list;
  }

  List<DropoffPoint> get dropoffPoints => DropoffPoint.samplePoints;

  List<DropoffPoint> getPointsByDistrict(String district) =>
      DropoffPoint.samplePoints.where((p) => p.district == district).toList();

  DropoffPoint? getPointById(String id) {
    for (final point in DropoffPoint.samplePoints) {
      if (point.id == id) return point;
    }
    return null;
  }

  /// Where to load a report photo from: the local file, or the uploaded copy.
  String? photoFor(EwasteItem item) {
    final url = item.photoUrl == null || _serverUrl.isEmpty
        ? null
        : '$_serverUrl${item.photoUrl}';
    // Web blob URLs only live for one session, so prefer the uploaded copy.
    if (kIsWeb) return url ?? item.photoPath;
    return item.photoPath ?? url;
  }

  /// Verified weight per category, largest first.
  List<MapEntry<EwasteCategory, double>> get weightByCategory {
    final totals = <String, double>{};
    for (final item in _credited) {
      totals[item.categoryId] =
          (totals[item.categoryId] ?? 0) + item.estimatedWeightKg;
    }
    final entries = totals.entries
        .map((e) => MapEntry(EwasteCategory.byId(e.key), e.value))
        .toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Verified weight for each of the last [months] calendar months.
  List<MonthlyTotal> monthlyWeights({int months = 6}) {
    final now = DateTime.now();
    return List.generate(months, (i) {
      final month = DateTime(now.year, now.month - (months - 1 - i));
      final weight = _credited.where((item) {
        final date = item.collectedAt ?? item.createdAt;
        return date.year == month.year && date.month == month.month;
      }).fold(0.0, (sum, item) => sum + item.estimatedWeightKg);
      return MonthlyTotal(month, weight);
    });
  }

  /// Community impact (simulated baseline for the MVP plus this member's share).
  Map<String, num> get communityStats {
    final weight = 342.5 + totalWeightKg;
    return {
      'totalUsers': 127,
      'totalWeightKg': weight,
      'totalItems': 1580 + totalItemsCollected,
      'co2Prevented': weight * AppConstants.co2PerKg,
      'activeCollectors': 8,
      'dropoffPoints': DropoffPoint.samplePoints.length,
    };
  }

  // Cash rewards --------------------------------------------------------------

  List<CashClaim> get cashClaims {
    final list = [..._claims];
    list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  CashClaim? latestClaimFor(CashMilestone milestone) {
    for (final claim in cashClaims) {
      if (claim.milestoneId == milestone.id) return claim;
    }
    return null;
  }

  bool canClaimCash(CashMilestone milestone) {
    if (totalWeightKg < milestone.kg) return false;
    final claim = latestClaimFor(milestone);
    return claim == null || claim.status == ClaimStatus.rejected;
  }

  List<CashMilestone> get claimableMilestones =>
      CashMilestone.all.where(canClaimCash).toList();

  /// The next milestone the member has not reached yet.
  CashMilestone? get nextCashMilestone {
    for (final milestone in CashMilestone.all) {
      if (totalWeightKg < milestone.kg) return milestone;
    }
    return null;
  }

  int get cashPaidRwf => _claims
      .where((c) => c.status == ClaimStatus.paid)
      .fold(0, (sum, c) => sum + c.amountRwf);

  // Sync state ----------------------------------------------------------------

  String get serverUrl => _serverUrl;
  bool get syncEnabled => _serverUrl.isNotEmpty;
  SyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get syncError => _syncError;

  int get unsyncedCount =>
      _items.where((i) => !i.synced).length +
      _redemptions.where((r) => !r.synced).length +
      _claims.where((c) => !c.synced).length +
      _pendingDeletes.length;

  // ---------------------------------------------------------------------------
  // Actions

  Future<EwasteItem> addItem(EwasteItem item) async {
    _items.insert(0, item);
    _sortItems();
    await _changed();
    return item;
  }

  /// The member says the item was dropped off or picked up. Points are
  /// credited once the EcoCollect team verifies it.
  Future<void> confirmHandOver(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1 || !_items[index].isPending) return;
    _items[index] = _items[index].copyWith(
      userConfirmedAt: DateTime.now(),
      synced: false,
    );
    await _changed();
  }

  Future<void> cancelItem(String id) async {
    final before = _items.length;
    _items.removeWhere((i) => i.id == id && i.isPending);
    if (_items.length == before) return;
    if (!_pendingDeletes.contains(id)) _pendingDeletes.add(id);
    await _changed();
  }

  /// Spends points on [reward]. Returns null when the balance is too low.
  Future<Redemption?> redeem(Reward reward) async {
    if (ecoPoints < reward.cost) return null;
    final redemption = Redemption(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      rewardId: reward.id,
      code: _voucherCode(),
      cost: reward.cost,
      redeemedAt: DateTime.now(),
    );
    _redemptions.add(redemption);
    await _changed();
    return redemption;
  }

  String _voucherCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String block() =>
        List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    return 'ECO-${block()}-${block()}';
  }

  /// Requests a Mobile Money payout for [milestone].
  Future<CashClaim?> claimCash(
    CashMilestone milestone, {
    required String momoNumber,
    required String provider,
  }) async {
    if (!canClaimCash(milestone)) return null;
    final claim = CashClaim(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      milestoneId: milestone.id,
      amountRwf: milestone.amountRwf,
      momoNumber: momoNumber.trim(),
      provider: provider,
      requestedAt: DateTime.now(),
    );
    _claims.add(claim);
    await _changed();
    return claim;
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    _profile = profile;
    _onboarded = true;
    await _changed();
  }

  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    await _changed();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = ApiClient.normalizeUrl(url);
    _api = null;
    _syncStatus = _serverUrl.isEmpty ? SyncStatus.off : SyncStatus.idle;
    _syncError = null;
    await _changed();
  }

  /// Clears this device's data. Server records are kept.
  Future<void> resetAll() async {
    final serverUrl = _serverUrl;
    await _prefs?.clear();
    _items = [];
    _redemptions = [];
    _claims = [];
    _pendingDeletes = [];
    _profile = null;
    _onboarded = false;
    _serverUrl = serverUrl;
    _lastSyncedAt = null;
    notifyListeners();
    await _save();
  }

  // ---------------------------------------------------------------------------
  // Sync

  /// Pushes local changes, then pulls the latest statuses from the server.
  Future<void> sync() async {
    final profile = _profile;
    if (!_loaded || profile == null || _serverUrl.isEmpty) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    final api = _api ??= ApiClient(_serverUrl, client: _httpClient);
    try {
      await api.upsertUser(profile);
      await _pushDeletes(api, profile.id);
      await _pushItems(api, profile.id);
      await _pushRedemptions(api, profile.id);
      await _pushClaims(api, profile.id);
      applyServerState(await api.fetchUserState(profile.id));
      _syncStatus = SyncStatus.synced;
      _lastSyncedAt = DateTime.now();
      _syncError = null;
    } catch (e) {
      _syncStatus = SyncStatus.offline;
      _syncError = e.toString();
    }

    _syncing = false;
    notifyListeners();
    await _save();
    if (_syncAgain) {
      _syncAgain = false;
      unawaited(sync());
    }
  }

  Future<void> _pushDeletes(ApiClient api, String userId) async {
    for (final id in [..._pendingDeletes]) {
      try {
        await api.deleteReport(userId, id);
      } on ApiException catch (e) {
        if (!e.isRejection) rethrow;
      }
      _pendingDeletes.remove(id);
    }
  }

  Future<void> _pushItems(ApiClient api, String userId) async {
    for (final item in _items.where((i) => !i.synced).toList()) {
      String? photo;
      if (item.photoPath != null && item.photoUrl == null) {
        photo = await _readPhoto(item.photoPath!);
      }
      EwasteItem updated;
      try {
        final saved = await api.upsertReport(userId, item, photoBase64: photo);
        updated = EwasteItem.fromJson(saved)
            .copyWith(photoPath: item.photoPath, synced: true);
      } on ApiException catch (e) {
        if (!e.isRejection) rethrow;
        updated = item.copyWith(synced: true);
      }
      // Keep any change the member made while the request was in flight.
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1 && identical(_items[index], item)) {
        _items[index] = updated;
      }
    }
  }

  Future<void> _pushRedemptions(ApiClient api, String userId) async {
    for (final redemption in _redemptions.where((r) => !r.synced).toList()) {
      try {
        await api.createRedemption(userId, redemption);
      } on ApiException catch (e) {
        if (!e.isRejection) rethrow;
      }
      final index = _redemptions.indexWhere((r) => r.id == redemption.id);
      if (index != -1) _redemptions[index] = redemption.markSynced();
    }
  }

  Future<void> _pushClaims(ApiClient api, String userId) async {
    for (final claim in _claims.where((c) => !c.synced).toList()) {
      CashClaim updated;
      try {
        await api.createCashClaim(userId, claim);
        updated = claim.copyWith(synced: true);
      } on ApiException catch (e) {
        if (!e.isRejection) rethrow;
        updated = claim.copyWith(
          status: ClaimStatus.rejected,
          note: e.message,
          synced: true,
        );
      }
      final index = _claims.indexWhere((c) => c.id == claim.id);
      if (index != -1) _claims[index] = updated;
    }
  }

  Future<String?> _readPhoto(String path) async {
    try {
      return base64Encode(await XFile(path).readAsBytes());
    } catch (e) {
      debugPrint('EcoCollect: could not read photo for upload: $e');
      return null;
    }
  }

  /// Merges the server's copy of this member's data. The server decides
  /// statuses; local changes that have not been pushed yet are kept.
  @visibleForTesting
  void applyServerState(Map<String, dynamic> state) {
    List<Map<String, dynamic>> docs(String key) =>
        (state[key] as List? ?? const []).cast<Map<String, dynamic>>();

    final localItems = {for (final item in _items) item.id: item};
    final items = <EwasteItem>[];
    for (final json in docs('reports')) {
      final server = EwasteItem.fromJson(json);
      if (_pendingDeletes.contains(server.id)) continue;
      final local = localItems.remove(server.id);
      items.add(server.copyWith(
        // The server owns the status; the member owns their hand-over
        // confirmation, which may not have been sent yet.
        userConfirmedAt: server.userConfirmedAt ?? local?.userConfirmedAt,
        photoPath: local?.photoPath,
        synced: local == null || local.synced,
      ));
    }
    items.addAll(localItems.values.where((i) => !i.synced));
    _items = items;
    _sortItems();

    final serverRedemptions =
        docs('redemptions').map((j) => Redemption.fromJson(j).markSynced());
    final redemptionIds = serverRedemptions.map((r) => r.id).toSet();
    _redemptions = [
      ...serverRedemptions,
      ..._redemptions.where((r) => !r.synced && !redemptionIds.contains(r.id)),
    ];

    final serverClaims = docs('cashClaims')
        .map((j) => CashClaim.fromJson(j).copyWith(synced: true));
    final claimIds = serverClaims.map((c) => c.id).toSet();
    _claims = [
      ...serverClaims,
      ..._claims.where((c) => !c.synced && !claimIds.contains(c.id)),
    ];
    notifyListeners();
  }
}
