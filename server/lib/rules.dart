import 'store.dart';

/// Cash rewards paid to Mobile Money when a member's handed-over weight
/// reaches each milestone. Keep in sync with the app's `CashMilestone.all`.
const cashMilestones = <String, ({double kg, int amountRwf})>{
  'kg10': (kg: 10.0, amountRwf: 1000),
  'kg25': (kg: 25.0, amountRwf: 3000),
  'kg50': (kg: 50.0, amountRwf: 7000),
  'kg100': (kg: 100.0, amountRwf: 15000),
};

const reportStatuses = ['pending', 'collected', 'recycled', 'rejected'];
const claimStatuses = ['requested', 'approved', 'paid', 'rejected'];

bool isCredited(Doc report) =>
    report['status'] == 'collected' || report['status'] == 'recycled';

/// Kilograms a member has handed over (verified reports only).
double creditedKg(Store store, String userId) => store.reports.values
    .where((r) => r['userId'] == userId && isCredited(r))
    .fold(0.0, (sum, r) => sum + (r['estimatedWeightKg'] as num).toDouble());
