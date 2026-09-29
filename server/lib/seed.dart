import 'auth.dart';
import 'store.dart';

/// Password for the sample members, for demos.
const samplePassword = 'demo1234';

/// Sample members and reports so a fresh server has a populated dashboard.
void seedSampleData(Store store, {Auth? auth}) {
  final passwordHash = (auth ?? Auth()).hashPassword(samplePassword);
  final now = DateTime.now();
  String ago(int days, [int hours = 0]) =>
      now.subtract(Duration(days: days, hours: hours)).toIso8601String();
  String ahead(int days) =>
      DateTime(now.year, now.month, now.day + days).toIso8601String();

  final users = [
    ('seed-jean', 'Jean Bosco Habimana', '0788000101', 'Gasabo', 60),
    ('seed-claudine', 'Claudine Mukamana', '0788000102', 'Kicukiro', 45),
    ('seed-eric', 'Eric Nshimiyimana', '0788000103', 'Nyarugenge', 30),
    ('seed-diane', 'Diane Uwimana', '0788000104', 'Gasabo', 12),
  ];
  for (final (id, name, phone, district, days) in users) {
    store.users[id] = {
      'id': id,
      'name': name,
      'phone': phone,
      'district': district,
      'email': '',
      'passwordHash': passwordHash,
      'memberSince': ago(days),
      'updatedAt': ago(0),
    };
  }

  var n = 0;
  void report(
    String userId,
    String category,
    int quantity,
    double weight, {
    required String status,
    required int daysAgo,
    String? pointId,
    Map<String, dynamic>? pickup,
    bool userConfirmed = false,
    String? description,
  }) {
    final id = 'seed-report-${++n}';
    final created = ago(daysAgo, 3);
    store.reports[id] = {
      'id': id,
      'userId': userId,
      'categoryId': category,
      'quantity': quantity,
      'estimatedWeightKg': weight,
      'condition': 'dead',
      'description': description,
      'disposalMethod': pickup == null ? 'dropoff' : 'pickup',
      'dropoffPointId': pointId,
      'pickup': pickup,
      'createdAt': created,
      'status': status,
      'userConfirmedAt': userConfirmed ? ago(daysAgo, 1) : null,
      'collectedAt': status == 'collected' || status == 'recycled'
          ? ago(daysAgo > 1 ? daysAgo - 1 : 0)
          : null,
      'recycledAt':
          status == 'recycled' ? ago(daysAgo > 3 ? daysAgo - 3 : 0) : null,
      'ecoPoints': (weight * 10).round() + quantity * 5,
      'updatedAt': ago(0),
    };
  }

  Map<String, dynamic> pickup(
          String address, String phone, int inDays, int slot) =>
      {
        'address': address,
        'phone': phone,
        'date': ahead(inDays),
        'timeSlot': [
          'Morning · 08:00–12:00',
          'Afternoon · 12:00–17:00',
          'Evening · 17:00–19:00',
        ][slot],
      };

  report('seed-jean', 'screens', 2, 16,
      status: 'recycled', daysAgo: 40, pointId: 'dp5');
  report('seed-jean', 'phones', 4, 0.8,
      status: 'collected', daysAgo: 6, pointId: 'dp7');
  report('seed-jean', 'batteries', 10, 1.5,
      status: 'pending', daysAgo: 1, pointId: 'dp7', userConfirmed: true);
  report('seed-claudine', 'computers', 4, 12,
      status: 'recycled', daysAgo: 30, pointId: 'dp4');
  report('seed-claudine', 'appliances', 2, 4,
      status: 'pending',
      daysAgo: 0,
      pickup: pickup('KK 20 Ave, Gikondo, Kicukiro', '0788000102', 1, 0),
      description: 'Old kettle and an iron');
  report('seed-eric', 'chargers', 12, 1.2,
      status: 'recycled', daysAgo: 25, pointId: 'dp3');
  report('seed-eric', 'audio', 3, 0.9,
      status: 'collected', daysAgo: 3, pointId: 'dp1');
  report('seed-eric', 'other', 1, 1.5,
      status: 'pending',
      daysAgo: 0,
      pickup: pickup('KN 59 St, Nyamirambo, Nyarugenge', '0788000103', 2, 1),
      description: 'Broken printer');
  report('seed-diane', 'phones', 2, 0.4,
      status: 'rejected', daysAgo: 8, pointId: 'dp5');
  report('seed-diane', 'screens', 1, 8,
      status: 'pending', daysAgo: 0, pointId: 'dp5');

  store.cashClaims['seed-claim-1'] = {
    'id': 'seed-claim-1',
    'userId': 'seed-claudine',
    'milestoneId': 'kg10',
    'amountRwf': 1000,
    'momoNumber': '0788000102',
    'provider': 'MTN MoMo',
    'status': 'paid',
    'reference': 'MP260915.1432.A12345',
    'requestedAt': ago(20),
    'updatedAt': ago(19),
  };
  store.cashClaims['seed-claim-2'] = {
    'id': 'seed-claim-2',
    'userId': 'seed-jean',
    'milestoneId': 'kg10',
    'amountRwf': 1000,
    'momoNumber': '0788000101',
    'provider': 'Airtel Money',
    'status': 'requested',
    'requestedAt': ago(0, 6),
    'updatedAt': ago(0, 6),
  };
}
