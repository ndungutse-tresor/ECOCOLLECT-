import 'package:flutter/material.dart';

class Reward {
  final String id;
  final String title;
  final String description;
  final int cost;
  final IconData icon;
  final Color color;

  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
  });

  static const catalog = [
    Reward(
      id: 'coffee',
      title: 'Free Coffee Voucher',
      description: 'One coffee at a partner café in Kigali',
      cost: 100,
      icon: Icons.local_cafe_rounded,
      color: Color(0xFF92400E),
    ),
    Reward(
      id: 'trees',
      title: 'Donate to Tree Planting',
      description: 'We plant a tree with a local partner on your behalf',
      cost: 150,
      icon: Icons.park_rounded,
      color: Color(0xFF15803D),
    ),
    Reward(
      id: 'data',
      title: '500 MB Mobile Data',
      description: 'Data bundle sent to your registered number',
      cost: 200,
      icon: Icons.signal_cellular_alt_rounded,
      color: Color(0xFF2563EB),
    ),
    Reward(
      id: 'tote',
      title: 'Eco Tote Bag',
      description: 'Reusable bag made from recycled materials',
      cost: 300,
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFDB2777),
    ),
    Reward(
      id: 'tshirt',
      title: 'EcoCollect T-Shirt',
      description: 'Show your support for a cleaner Rwanda',
      cost: 500,
      icon: Icons.checkroom_rounded,
      color: Color(0xFF7C3AED),
    ),
  ];

  static Reward? byId(String id) {
    for (final reward in catalog) {
      if (reward.id == id) return reward;
    }
    return null;
  }
}

class Redemption {
  final String id;
  final String rewardId;
  final String code;
  final int cost;
  final DateTime redeemedAt;
  final bool synced;

  const Redemption({
    required this.id,
    required this.rewardId,
    required this.code,
    required this.cost,
    required this.redeemedAt,
    this.synced = false,
  });

  Redemption markSynced() => Redemption(
        id: id,
        rewardId: rewardId,
        code: code,
        cost: cost,
        redeemedAt: redeemedAt,
        synced: true,
      );

  Reward? get reward => Reward.byId(rewardId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'rewardId': rewardId,
        'code': code,
        'cost': cost,
        'redeemedAt': redeemedAt.toIso8601String(),
        'synced': synced,
      };

  factory Redemption.fromJson(Map<String, dynamic> json) => Redemption(
        id: json['id'] as String,
        rewardId: json['rewardId'] as String,
        code: json['code'] as String,
        cost: (json['cost'] as num).toInt(),
        redeemedAt: DateTime.parse(json['redeemedAt'] as String),
        synced: json['synced'] as bool? ?? false,
      );
}

class EcoLevel {
  final String name;
  final int minPoints;
  final IconData icon;

  const EcoLevel(this.name, this.minPoints, this.icon);

  static const levels = [
    EcoLevel('Seedling', 0, Icons.spa_rounded),
    EcoLevel('Sprout', 100, Icons.grass_rounded),
    EcoLevel('Sapling', 250, Icons.eco_rounded),
    EcoLevel('Tree', 500, Icons.park_rounded),
    EcoLevel('Forest', 1000, Icons.forest_rounded),
  ];

  static EcoLevel forPoints(int points) =>
      levels.lastWhere((l) => points >= l.minPoints);

  static EcoLevel? nextAfter(EcoLevel level) {
    final i = levels.indexOf(level);
    return i < levels.length - 1 ? levels[i + 1] : null;
  }

  /// Progress (0–1) from this level towards the next one.
  static double progress(int points) {
    final current = forPoints(points);
    final next = nextAfter(current);
    if (next == null) return 1;
    return (points - current.minPoints) / (next.minPoints - current.minPoints);
  }
}
