import 'package:flutter/material.dart';

class DropoffPoint {
  final String id;
  final String name;
  final String
      type; // 'school', 'church', 'petrol_station', 'sector_office', 'market'
  final String address;
  final double latitude;
  final double longitude;
  final List<int> openDays; // DateTime.monday .. DateTime.sunday
  final int opensAtMinute; // minutes after midnight
  final int closesAtMinute;
  final bool isActive;
  final String district;

  const DropoffPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.openDays,
    required this.opensAtMinute,
    required this.closesAtMinute,
    this.isActive = true,
    required this.district,
  });

  static const weekdays = [1, 2, 3, 4, 5];
  static const everyDay = [1, 2, 3, 4, 5, 6, 7];

  IconData get typeIcon {
    switch (type) {
      case 'school':
        return Icons.school_rounded;
      case 'church':
        return Icons.church_rounded;
      case 'petrol_station':
        return Icons.local_gas_station_rounded;
      case 'sector_office':
        return Icons.account_balance_rounded;
      case 'market':
        return Icons.storefront_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'school':
        return const Color(0xFF2563EB);
      case 'church':
        return const Color(0xFF7C3AED);
      case 'petrol_station':
        return const Color(0xFFEA580C);
      case 'sector_office':
        return const Color(0xFF0D7C5F);
      case 'market':
        return const Color(0xFFDB2777);
      default:
        return const Color(0xFF475569);
    }
  }

  String get typeLabel {
    switch (type) {
      case 'school':
        return 'School';
      case 'church':
        return 'Church';
      case 'petrol_station':
        return 'Petrol Station';
      case 'sector_office':
        return 'Sector Office';
      case 'market':
        return 'Market';
      default:
        return 'Collection Point';
    }
  }

  String get daysLabel {
    if (openDays.length == 7) return 'Daily';
    if (_sameDays(openDays, weekdays)) return 'Mon–Fri';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return openDays.map((d) => names[d - 1]).join(', ');
  }

  String get hoursLabel => '${_clock(opensAtMinute)}–${_clock(closesAtMinute)}';

  String get operatingHours => '$daysLabel · $hoursLabel';

  bool isOpenAt(DateTime time) {
    if (!isActive || !openDays.contains(time.weekday)) return false;
    final minute = time.hour * 60 + time.minute;
    return minute >= opensAtMinute && minute < closesAtMinute;
  }

  bool get isOpenNow => isOpenAt(DateTime.now());

  /// Short human-readable status such as "Open · closes 17:00".
  String get openStatusLabel {
    final now = DateTime.now();
    if (isOpenAt(now)) return 'Open · closes ${_clock(closesAtMinute)}';
    final minute = now.hour * 60 + now.minute;
    if (openDays.contains(now.weekday) && minute < opensAtMinute) {
      return 'Closed · opens ${_clock(opensAtMinute)}';
    }
    for (var i = 1; i <= 7; i++) {
      final day = now.add(Duration(days: i));
      if (openDays.contains(day.weekday)) {
        final when = i == 1 ? 'tomorrow' : _dayName(day.weekday);
        return 'Closed · opens $when ${_clock(opensAtMinute)}';
      }
    }
    return 'Closed';
  }

  static String _clock(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _dayName(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  static bool _sameDays(List<int> a, List<int> b) =>
      a.length == b.length && a.every(b.contains);

  // Sample drop-off points in Kigali for the MVP demo (approximate locations).
  static const List<DropoffPoint> samplePoints = [
    DropoffPoint(
      id: 'dp1',
      name: 'UR-CST Nyarugenge Campus',
      type: 'school',
      address: 'KN 67 St, Nyarugenge',
      latitude: -1.9590,
      longitude: 30.0637,
      openDays: weekdays,
      opensAtMinute: 8 * 60,
      closesAtMinute: 17 * 60,
      district: 'Nyarugenge',
    ),
    DropoffPoint(
      id: 'dp2',
      name: 'Kimisagara Sector Office',
      type: 'sector_office',
      address: 'KN 3 Rd, Kimisagara',
      latitude: -1.9529,
      longitude: 30.0462,
      openDays: weekdays,
      opensAtMinute: 7 * 60 + 30,
      closesAtMinute: 17 * 60,
      district: 'Nyarugenge',
    ),
    DropoffPoint(
      id: 'dp3',
      name: 'Sainte Famille Church',
      type: 'church',
      address: 'KN 2 Ave, Nyarugenge',
      latitude: -1.9446,
      longitude: 30.0617,
      openDays: everyDay,
      opensAtMinute: 8 * 60,
      closesAtMinute: 18 * 60,
      district: 'Nyarugenge',
    ),
    DropoffPoint(
      id: 'dp4',
      name: 'SP Petrol - Kicukiro',
      type: 'petrol_station',
      address: 'KK 15 Rd, Kicukiro',
      latitude: -1.9716,
      longitude: 30.1028,
      openDays: everyDay,
      opensAtMinute: 6 * 60,
      closesAtMinute: 22 * 60,
      district: 'Kicukiro',
    ),
    DropoffPoint(
      id: 'dp5',
      name: 'Kigali Heights Market',
      type: 'market',
      address: 'KG 7 Ave, Gasabo',
      latitude: -1.9535,
      longitude: 30.0928,
      openDays: everyDay,
      opensAtMinute: 7 * 60,
      closesAtMinute: 20 * 60,
      district: 'Gasabo',
    ),
    DropoffPoint(
      id: 'dp6',
      name: 'Lycée de Kigali',
      type: 'school',
      address: 'KN 1 Rd, Nyarugenge',
      latitude: -1.9492,
      longitude: 30.0688,
      openDays: weekdays,
      opensAtMinute: 7 * 60,
      closesAtMinute: 17 * 60,
      district: 'Nyarugenge',
    ),
    DropoffPoint(
      id: 'dp7',
      name: 'Remera Sector Office',
      type: 'sector_office',
      address: 'KG 11 Ave, Gasabo',
      latitude: -1.9577,
      longitude: 30.1134,
      openDays: weekdays,
      opensAtMinute: 7 * 60 + 30,
      closesAtMinute: 17 * 60,
      district: 'Gasabo',
    ),
    DropoffPoint(
      id: 'dp8',
      name: 'Rubilizi Petrol Station',
      type: 'petrol_station',
      address: 'KK 31 Rd, Kicukiro',
      latitude: -1.9857,
      longitude: 30.1440,
      openDays: everyDay,
      opensAtMinute: 6 * 60,
      closesAtMinute: 21 * 60,
      district: 'Kicukiro',
    ),
  ];
}
