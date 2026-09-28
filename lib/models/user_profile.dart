class UserProfile {
  final String name;
  final String phone;
  final String district;
  final DateTime memberSince;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.district,
    required this.memberSince,
  });

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserProfile copyWith({String? name, String? phone, String? district}) =>
      UserProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        district: district ?? this.district,
        memberSince: memberSince,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'district': district,
        'memberSince': memberSince.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        district: json['district'] as String? ?? 'Nyarugenge',
        memberSince: DateTime.tryParse(json['memberSince'] as String? ?? '') ??
            DateTime.now(),
      );
}
