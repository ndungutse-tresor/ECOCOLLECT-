import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dropoff_point.dart';
import '../models/ewaste_item.dart';
import '../models/reward.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

class MonthlyTotal {
  final DateTime month;
  final double weightKg;

  const MonthlyTotal(this.month, this.weightKg);
}

/// Holds the user's reports, points, rewards and profile, and persists them
/// to local storage.
class EwasteService extends ChangeNotifier {
  static const _itemsKey = 'ecocollect.items';
  static const _redemptionsKey = 'ecocollect.redemptions';
  static const _profileKey = 'ecocollect.profile';
  static const _onboardedKey = 'ecocollect.onboarded';

  EwasteService({this.seedDemoData = true}) {
    ready = _load();
  }

  /// Whether a fresh install starts with sample history for demos.
  final bool seedDemoData;

  /// Completes once saved data has been loaded.
  late final Future<void> ready;

  SharedPreferences? _prefs;
  List<EwasteItem> _items = [];
  List<Redemption> _redemptions = [];
  UserProfile? _profile;
  bool _onboarded = false;
  bool _loaded = false;
  final _random = Random();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      final itemsJson = prefs.getString(_itemsKey);
      _items = itemsJson == null
          ? (seedDemoData ? _demoItems() : [])
          : (jsonDecode(itemsJson) as List)
              .map((e) => EwasteItem.fromJson(e as Map<String, dynamic>))
              .toList();

      final redemptionsJson = prefs.getString(_redemptionsKey);
      if (redemptionsJson != null) {
        _redemptions = (jsonDecode(redemptionsJson) as List)
            .map((e) => Redemption.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final profileJson = prefs.getString(_profileKey);
      if (profileJson != null) {
        _profile = UserProfile.fromJson(
          jsonDecode(profileJson) as Map<String, dynamic>,
        );
      }
      _onboarded = prefs.getBool(_onboardedKey) ?? false;
    } catch (e) {
      debugPrint('EcoCollect: could not load saved data: $e');
      if (_items.isEmpty && seedDemoData) _items = _demoItems();
    }

    if (_advanceStatuses()) await _save();
    _sortItems();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        _itemsKey,
        jsonEncode(_items.map((i) => i.toJson()).toList()),
      );
      await prefs.setString(
        _redemptionsKey,
        jsonEncode(_redemptions.map((r) => r.toJson()).toList()),
      );
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

  /// Collected items are processed by the recycler after a short delay.
  bool _advanceStatuses() {
    var changed = false;
    final now = DateTime.now();
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final collectedAt = item.collectedAt;
      if (item.status == ItemStatus.collected &&
          collectedAt != null &&
          now.difference(collectedAt) >= AppConstants.recycleProcessingTime) {
        _items[i] = item.copyWith(
          status: ItemStatus.recycled,
          recycledAt: collectedAt.add(AppConstants.recycleProcessingTime),
        );
        changed = true;
      }
    }
    return changed;
  }

  List<EwasteItem> _demoItems() {
    final now = DateTime.now();
    DateTime ago(int days, [int hours = 0]) =>
        now.subtract(Duration(days: days, hours: hours));

    return [
      EwasteItem(
        id: 'demo1',
        categoryId: 'phones',
        quantity: 2,
        estimatedWeightKg: 0.4,
        condition: ItemCondition.damaged,
        description: 'Two old Nokia phones',
        disposalMethod: DisposalMethod.dropoff,
        dropoffPointId: 'dp1',
        createdAt: ago(40),
        status: ItemStatus.recycled,
        collectedAt: ago(38),
        recycledAt: ago(36),
      ),
      EwasteItem(
        id: 'demo2',
        categoryId: 'chargers',
        quantity: 5,
        estimatedWeightKg: 0.5,
        disposalMethod: DisposalMethod.dropoff,
        dropoffPointId: 'dp3',
        createdAt: ago(21),
        status: ItemStatus.recycled,
        collectedAt: ago(20),
        recycledAt: ago(18),
      ),
      EwasteItem(
        id: 'demo3',
        categoryId: 'computers',
        quantity: 1,
        estimatedWeightKg: 3.0,
        condition: ItemCondition.damaged,
        description: 'Laptop with a broken hinge',
        disposalMethod: DisposalMethod.pickup,
        pickup: PickupDetails(
          address: 'KN 14 Ave, Kiyovu, Nyarugenge',
          phone: '',
          date: ago(2),
          timeSlot: PickupDetails.timeSlots.first,
        ),
        createdAt: ago(4),
        status: ItemStatus.collected,
        collectedAt: ago(1),
      ),
      EwasteItem(
        id: 'demo4',
        categoryId: 'batteries',
        quantity: 8,
        estimatedWeightKg: 1.2,
        disposalMethod: DisposalMethod.dropoff,
        dropoffPointId: 'dp4',
        createdAt: ago(0, 5),
      ),
    ];
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

  /// Weight actually handed over (collected or recycled).
  double get totalWeightKg =>
      _credited.fold(0.0, (sum, i) => sum + i.estimatedWeightKg);

  int get totalItemsCollected =>
      _credited.fold(0, (sum, i) => sum + i.quantity);

  double get co2Prevented => totalWeightKg * AppConstants.co2PerKg;

  /// All points ever credited. Drives the user's level.
  int get earnedPoints => _credited.fold(0, (sum, i) => sum + i.ecoPoints);

  /// Points waiting for pending reports to be handed over.
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

  /// Handed-over weight per category, largest first.
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

  /// Handed-over weight for each of the last [months] calendar months.
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

  /// Community impact (simulated baseline for the MVP plus this user's share).
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

  // ---------------------------------------------------------------------------
  // Actions

  Future<EwasteItem> addItem(EwasteItem item) async {
    _items.insert(0, item);
    _sortItems();
    notifyListeners();
    await _save();
    return item;
  }

  /// Marks a pending report as handed over and returns the points credited.
  Future<int> confirmHandOver(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1 || !_items[index].isPending) return 0;
    final item = _items[index];
    _items[index] = item.copyWith(
      status: ItemStatus.collected,
      collectedAt: DateTime.now(),
    );
    notifyListeners();
    await _save();
    return item.ecoPoints;
  }

  Future<void> cancelItem(String id) async {
    _items.removeWhere((i) => i.id == id && i.isPending);
    notifyListeners();
    await _save();
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
    notifyListeners();
    await _save();
    return redemption;
  }

  String _voucherCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String block() =>
        List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    return 'ECO-${block()}-${block()}';
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    _profile = profile;
    _onboarded = true;
    notifyListeners();
    await _save();
  }

  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _save();
  }

  /// Clears everything and restores the demo history.
  Future<void> resetAll() async {
    await _prefs?.clear();
    _items = seedDemoData ? _demoItems() : [];
    _redemptions = [];
    _profile = null;
    _onboarded = false;
    notifyListeners();
  }
}
