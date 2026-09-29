import 'dart:math';

class UserProfile {
  /// Member id shared with the server.
  final String id;
  final String name;
  final String phone;
  final String district;
  final DateTime memberSince;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.district,
    required this.memberSince,
  });

  static String newId() {
    final random = Random.secure();
    final hex = List.generate(
      12,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'u_$hex';
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserProfile copyWith({String? name, String? phone, String? district}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        district: district ?? this.district,
        memberSince: memberSince,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'district': district,
        'memberSince': memberSince.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? newId(),
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        district: json['district'] as String? ?? 'Nyarugenge',
        memberSince: DateTime.tryParse(json['memberSince'] as String? ?? '') ??
            DateTime.now(),
      );
}
