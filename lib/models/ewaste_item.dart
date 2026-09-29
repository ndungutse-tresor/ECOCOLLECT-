import 'package:flutter/material.dart';

class EwasteCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final String tip;
  final double avgWeightKg;

  const EwasteCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.tip,
    required this.avgWeightKg,
  });

  static const List<EwasteCategory> categories = [
    EwasteCategory(
      id: 'phones',
      name: 'Phones & Tablets',
      icon: Icons.smartphone_rounded,
      color: Color(0xFF2563EB),
      description: 'Mobile phones, smartphones, tablets',
      tip:
          'Back up your data, remove SIM and memory cards, then factory-reset the device.',
      avgWeightKg: 0.2,
    ),
    EwasteCategory(
      id: 'computers',
      name: 'Laptops & Computers',
      icon: Icons.laptop_chromebook_rounded,
      color: Color(0xFF4F46E5),
      description: 'Laptops, desktops, monitors',
      tip:
          'Sign out of your accounts and wipe the hard drive before handing it over.',
      avgWeightKg: 3.0,
    ),
    EwasteCategory(
      id: 'chargers',
      name: 'Chargers & Cables',
      icon: Icons.cable_rounded,
      color: Color(0xFFD97706),
      description: 'Phone chargers, USB cables, power adapters',
      tip:
          'Bundle cables together with a rubber band so they are easy to sort.',
      avgWeightKg: 0.1,
    ),
    EwasteCategory(
      id: 'batteries',
      name: 'Batteries',
      icon: Icons.battery_charging_full_rounded,
      color: Color(0xFFDC2626),
      description: 'Phone batteries, laptop batteries, AA/AAA',
      tip:
          'Tape the terminals and keep swollen batteries away from heat and water.',
      avgWeightKg: 0.15,
    ),
    EwasteCategory(
      id: 'audio',
      name: 'Audio & Accessories',
      icon: Icons.headphones_rounded,
      color: Color(0xFFDB2777),
      description: 'Headphones, earphones, speakers, Bluetooth devices',
      tip: 'Unpair Bluetooth devices from your phone before recycling them.',
      avgWeightKg: 0.3,
    ),
    EwasteCategory(
      id: 'appliances',
      name: 'Home Appliances',
      icon: Icons.blender_rounded,
      color: Color(0xFF0D9488),
      description: 'Kettles, irons, fans, small electronics',
      tip:
          'Empty and dry kettles and irons. Water inside can damage other items.',
      avgWeightKg: 2.0,
    ),
    EwasteCategory(
      id: 'screens',
      name: 'TVs & Screens',
      icon: Icons.tv_rounded,
      color: Color(0xFF7C3AED),
      description: 'Televisions, monitors, display screens',
      tip:
          'Carry screens upright and wrap cracked glass in cloth or cardboard.',
      avgWeightKg: 8.0,
    ),
    EwasteCategory(
      id: 'other',
      name: 'Other Electronics',
      icon: Icons.memory_rounded,
      color: Color(0xFF475569),
      description: 'Printers, routers, any electronic device',
      tip: 'Remove ink cartridges and batteries. They are recycled separately.',
      avgWeightKg: 1.5,
    ),
  ];

  static EwasteCategory byId(String id) => categories.firstWhere(
        (c) => c.id == id,
        orElse: () => categories.last,
      );
}

enum ItemStatus { pending, collected, recycled, rejected }

extension ItemStatusX on ItemStatus {
  String get label {
    switch (this) {
      case ItemStatus.pending:
        return 'Pending';
      case ItemStatus.collected:
        return 'Collected';
      case ItemStatus.recycled:
        return 'Recycled';
      case ItemStatus.rejected:
        return 'Rejected';
    }
  }
}

enum DisposalMethod { dropoff, pickup }

enum ItemCondition { working, damaged, dead }

extension ItemConditionX on ItemCondition {
  String get label {
    switch (this) {
      case ItemCondition.working:
        return 'Still works';
      case ItemCondition.damaged:
        return 'Damaged';
      case ItemCondition.dead:
        return 'Not working';
    }
  }
}

class PickupDetails {
  final String address;
  final String phone;
  final DateTime date;
  final String timeSlot;

  const PickupDetails({
    required this.address,
    required this.phone,
    required this.date,
    required this.timeSlot,
  });

  static const timeSlots = [
    'Morning · 08:00–12:00',
    'Afternoon · 12:00–17:00',
    'Evening · 17:00–19:00',
  ];

  Map<String, dynamic> toJson() => {
        'address': address,
        'phone': phone,
        'date': date.toIso8601String(),
        'timeSlot': timeSlot,
      };

  factory PickupDetails.fromJson(Map<String, dynamic> json) => PickupDetails(
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        timeSlot: json['timeSlot'] as String? ?? timeSlots.first,
      );
}

class EwasteItem {
  final String id;
  final String categoryId;
  final int quantity;
  final double estimatedWeightKg;
  final ItemCondition condition;
  final String? photoPath;
  final String? description;
  final DisposalMethod disposalMethod;
  final String? dropoffPointId;
  final PickupDetails? pickup;
  final DateTime createdAt;
  final ItemStatus status;

  /// When the member said they handed the item over (awaiting verification).
  final DateTime? userConfirmedAt;
  final DateTime? collectedAt;
  final DateTime? recycledAt;

  /// Server path of the uploaded photo, e.g. /photos/abc.jpg.
  final String? photoUrl;

  /// Message from the EcoCollect team, e.g. why a report was rejected.
  final String? adminNote;

  /// Whether the latest local changes have reached the server.
  final bool synced;

  /// Points this report is worth. They are credited once it is verified.
  final int ecoPoints;

  EwasteItem({
    required this.id,
    required this.categoryId,
    required this.quantity,
    required this.estimatedWeightKg,
    this.condition = ItemCondition.dead,
    this.photoPath,
    this.description,
    required this.disposalMethod,
    this.dropoffPointId,
    this.pickup,
    required this.createdAt,
    this.status = ItemStatus.pending,
    this.userConfirmedAt,
    this.collectedAt,
    this.recycledAt,
    this.photoUrl,
    this.adminNote,
    this.synced = false,
    int? ecoPoints,
  }) : ecoPoints = ecoPoints ?? pointsFor(estimatedWeightKg, quantity);

  /// 10 points per kg plus 5 points per item.
  static int pointsFor(double weightKg, int quantity) =>
      (weightKg * 10).round() + quantity * 5;

  EwasteCategory get category => EwasteCategory.byId(categoryId);
  String get categoryName => category.name;
  bool get isPending => status == ItemStatus.pending;
  bool get isRejected => status == ItemStatus.rejected;
  bool get isCredited =>
      status == ItemStatus.collected || status == ItemStatus.recycled;
  bool get awaitingVerification => isPending && userConfirmedAt != null;

  EwasteItem copyWith({
    ItemStatus? status,
    DateTime? userConfirmedAt,
    DateTime? collectedAt,
    DateTime? recycledAt,
    String? photoPath,
    String? photoUrl,
    bool? synced,
  }) {
    return EwasteItem(
      id: id,
      categoryId: categoryId,
      quantity: quantity,
      estimatedWeightKg: estimatedWeightKg,
      condition: condition,
      photoPath: photoPath ?? this.photoPath,
      description: description,
      disposalMethod: disposalMethod,
      dropoffPointId: dropoffPointId,
      pickup: pickup,
      createdAt: createdAt,
      status: status ?? this.status,
      userConfirmedAt: userConfirmedAt ?? this.userConfirmedAt,
      collectedAt: collectedAt ?? this.collectedAt,
      recycledAt: recycledAt ?? this.recycledAt,
      photoUrl: photoUrl ?? this.photoUrl,
      adminNote: adminNote,
      synced: synced ?? this.synced,
      ecoPoints: ecoPoints,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'quantity': quantity,
        'estimatedWeightKg': estimatedWeightKg,
        'condition': condition.name,
        'photoPath': photoPath,
        'description': description,
        'disposalMethod': disposalMethod.name,
        'dropoffPointId': dropoffPointId,
        'pickup': pickup?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'userConfirmedAt': userConfirmedAt?.toIso8601String(),
        'collectedAt': collectedAt?.toIso8601String(),
        'recycledAt': recycledAt?.toIso8601String(),
        'photoUrl': photoUrl,
        'adminNote': adminNote,
        'synced': synced,
        'ecoPoints': ecoPoints,
      };

  factory EwasteItem.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);

    return EwasteItem(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      quantity: json['quantity'] as int,
      estimatedWeightKg: (json['estimatedWeightKg'] as num).toDouble(),
      condition: ItemCondition.values.asNameMap()[json['condition']] ??
          ItemCondition.dead,
      photoPath: json['photoPath'] as String?,
      description: json['description'] as String?,
      disposalMethod:
          DisposalMethod.values.asNameMap()[json['disposalMethod']] ??
              DisposalMethod.dropoff,
      dropoffPointId: json['dropoffPointId'] as String?,
      pickup: json['pickup'] == null
          ? null
          : PickupDetails.fromJson(json['pickup'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status:
          ItemStatus.values.asNameMap()[json['status']] ?? ItemStatus.pending,
      userConfirmedAt: date('userConfirmedAt'),
      collectedAt: date('collectedAt'),
      recycledAt: date('recycledAt'),
      photoUrl: json['photoUrl'] as String?,
      adminNote: json['adminNote'] as String?,
      synced: json['synced'] as bool? ?? false,
      ecoPoints: (json['ecoPoints'] as num?)?.toInt(),
    );
  }
}
