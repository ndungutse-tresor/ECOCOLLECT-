/// The signed-in member's account details (owned by the server).
class UserProfile {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String district;
  final DateTime memberSince;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    required this.district,
    required this.memberSince,
  });

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'district': district,
        'memberSince': memberSince.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        district: json['district'] as String? ?? 'Nyarugenge',
        memberSince: DateTime.tryParse(json['memberSince'] as String? ?? '') ??
            DateTime.now(),
      );
}
