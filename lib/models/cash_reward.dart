/// Mobile Money payout unlocked when a member's verified recycling reaches
/// [kg]. Keep in sync with `cashMilestones` in server/lib/rules.dart.
class CashMilestone {
  final String id;
  final double kg;
  final int amountRwf;

  const CashMilestone(this.id, this.kg, this.amountRwf);

  static const all = [
    CashMilestone('kg10', 10, 1000),
    CashMilestone('kg25', 25, 3000),
    CashMilestone('kg50', 50, 7000),
    CashMilestone('kg100', 100, 15000),
  ];

  static CashMilestone? byId(String id) {
    for (final milestone in all) {
      if (milestone.id == id) return milestone;
    }
    return null;
  }
}

enum ClaimStatus { requested, approved, paid, rejected }

extension ClaimStatusX on ClaimStatus {
  String get label {
    switch (this) {
      case ClaimStatus.requested:
        return 'Requested';
      case ClaimStatus.approved:
        return 'Approved';
      case ClaimStatus.paid:
        return 'Paid';
      case ClaimStatus.rejected:
        return 'Rejected';
    }
  }
}

class CashClaim {
  static const providers = ['MTN MoMo', 'Airtel Money'];

  final String id;
  final String milestoneId;
  final int amountRwf;
  final String momoNumber;
  final String provider;
  final ClaimStatus status;
  final DateTime requestedAt;
  final DateTime? paidAt;
  final String? reference;
  final String? note;
  final bool synced;

  const CashClaim({
    required this.id,
    required this.milestoneId,
    required this.amountRwf,
    required this.momoNumber,
    required this.provider,
    this.status = ClaimStatus.requested,
    required this.requestedAt,
    this.paidAt,
    this.reference,
    this.note,
    this.synced = false,
  });

  CashMilestone? get milestone => CashMilestone.byId(milestoneId);
  bool get isOpen =>
      status == ClaimStatus.requested || status == ClaimStatus.approved;

  CashClaim copyWith({ClaimStatus? status, String? note, bool? synced}) =>
      CashClaim(
        id: id,
        milestoneId: milestoneId,
        amountRwf: amountRwf,
        momoNumber: momoNumber,
        provider: provider,
        status: status ?? this.status,
        requestedAt: requestedAt,
        paidAt: paidAt,
        reference: reference,
        note: note ?? this.note,
        synced: synced ?? this.synced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'milestoneId': milestoneId,
        'amountRwf': amountRwf,
        'momoNumber': momoNumber,
        'provider': provider,
        'status': status.name,
        'requestedAt': requestedAt.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'reference': reference,
        'note': note,
        'synced': synced,
      };

  factory CashClaim.fromJson(Map<String, dynamic> json) => CashClaim(
        id: json['id'] as String,
        milestoneId: json['milestoneId'] as String,
        amountRwf: (json['amountRwf'] as num).toInt(),
        momoNumber: json['momoNumber'] as String? ?? '',
        provider: json['provider'] as String? ?? providers.first,
        status: ClaimStatus.values.asNameMap()[json['status']] ??
            ClaimStatus.requested,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        paidAt: json['paidAt'] == null
            ? null
            : DateTime.parse(json['paidAt'] as String),
        reference: json['reference'] as String?,
        note: json['note'] as String?,
        synced: json['synced'] as bool? ?? false,
      );
}
