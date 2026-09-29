import 'package:ecocollect_rwanda/main.dart';
import 'package:ecocollect_rwanda/models/cash_reward.dart';
import 'package:ecocollect_rwanda/models/dropoff_point.dart';
import 'package:ecocollect_rwanda/models/ewaste_item.dart';
import 'package:ecocollect_rwanda/models/reward.dart';
import 'package:ecocollect_rwanda/models/user_profile.dart';
import 'package:ecocollect_rwanda/services/ewaste_service.dart';
import 'package:ecocollect_rwanda/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

EwasteItem _newItem({String id = 'test1', double kg = 0.6, int qty = 3}) =>
    EwasteItem(
      id: id,
      categoryId: 'phones',
      quantity: qty,
      estimatedWeightKg: kg,
      disposalMethod: DisposalMethod.dropoff,
      dropoffPointId: 'dp1',
      createdAt: DateTime.now(),
    );

/// What the server returns after the admin sets [status] on [items].
Map<String, dynamic> _serverState(
  List<EwasteItem> items, {
  ItemStatus status = ItemStatus.collected,
  List<Map<String, dynamic>> claims = const [],
}) =>
    {
      'reports': [
        for (final item in items)
          {
            ...item.toJson(),
            'status': status.name,
            'collectedAt': DateTime.now().toIso8601String(),
          }..remove('synced'),
      ],
      'redemptions': const [],
      'cashClaims': claims,
    };

Future<EwasteService> _service() async {
  final service = EwasteService(serverUrl: '');
  await service.ready;
  return service;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('EwasteService', () {
    test('a new member starts with an empty history', () async {
      final service = await _service();
      expect(service.items, isEmpty);
      expect(service.ecoPoints, 0);
      expect(service.syncEnabled, isFalse);
    });

    test('points are credited only after EcoCollect verifies', () async {
      final service = await _service();
      await service.addItem(_newItem());
      // 0.6 kg * 10 + 3 items * 5
      expect(service.pendingPoints, 21);

      await service.confirmHandOver('test1');
      final item = service.getItemById('test1')!;
      expect(item.awaitingVerification, isTrue);
      expect(service.ecoPoints, 0);

      service.applyServerState(_serverState([item.copyWith(synced: true)]));
      expect(service.getItemById('test1')!.status, ItemStatus.collected);
      expect(service.ecoPoints, 21);
      expect(service.pendingPoints, 0);
    });

    test('rejected reports earn nothing', () async {
      final service = await _service();
      final item = await service.addItem(_newItem());
      service.applyServerState(
        _serverState([item], status: ItemStatus.rejected),
      );
      expect(service.getItemById('test1')!.isRejected, isTrue);
      expect(service.ecoPoints, 0);
      expect(service.pendingPoints, 0);
    });

    test('unsent local changes survive a server refresh', () async {
      final service = await _service();
      final item = await service.addItem(_newItem());
      service.applyServerState(
        _serverState([item], status: ItemStatus.pending),
      );
      await service.confirmHandOver('test1');
      service.applyServerState(
        _serverState([item], status: ItemStatus.pending),
      );
      expect(service.getItemById('test1')!.userConfirmedAt, isNotNull);
    });

    test('cancelling removes the report and queues the deletion', () async {
      final service = await _service();
      await service.addItem(_newItem());
      await service.cancelItem('test1');
      expect(service.items, isEmpty);
      expect(service.unsyncedCount, 1);
    });

    test('redeeming deducts points and refuses when balance is too low',
        () async {
      final service = await _service();
      final coffee = Reward.byId('coffee')!;
      final item = await service.addItem(_newItem(kg: 10, qty: 2));
      expect(await service.redeem(coffee), isNull);

      service.applyServerState(_serverState([item]));
      expect(service.ecoPoints, 110);
      final redemption = await service.redeem(coffee);
      expect(
          redemption!.code, matches(RegExp(r'^ECO-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
      expect(service.ecoPoints, 10);
    });

    test('cash rewards unlock by verified weight', () async {
      final service = await _service();
      final ten = CashMilestone.byId('kg10')!;
      final item = await service.addItem(_newItem(kg: 12, qty: 1));
      expect(service.canClaimCash(ten), isFalse);

      service.applyServerState(_serverState([item]));
      expect(service.claimableMilestones, [ten]);
      expect(service.nextCashMilestone!.id, 'kg25');

      final claim = await service.claimCash(
        ten,
        momoNumber: '0788123456',
        provider: 'MTN MoMo',
      );
      expect(claim!.amountRwf, 1000);
      expect(service.canClaimCash(ten), isFalse);

      // The admin pays it.
      service.applyServerState(_serverState([
        item
      ], claims: [
        {...claim.toJson(), 'status': 'paid', 'reference': 'TX1'},
      ]));
      expect(service.cashPaidRwf, 1000);
      expect(service.latestClaimFor(ten)!.reference, 'TX1');
    });

    test('persists data between app launches', () async {
      final first = await _service();
      await first.completeOnboarding(UserProfile(
        id: 'u1',
        name: 'Aline',
        phone: '',
        district: 'Gasabo',
        memberSince: DateTime.now(),
      ));
      await first.addItem(_newItem(id: 'persisted'));

      final second = await _service();
      expect(second.getItemById('persisted'), isNotNull);
      expect(second.profile!.id, 'u1');
    });
  });

  group('helpers', () {
    test('formats weights and money', () {
      expect(formatKg(0.45), '0.45 kg');
      expect(formatKg(3), '3 kg');
      expect(formatKg(11.7), '11.7 kg');
      expect(formatKg(1500), '1.5 t');
      expect(formatRwf(15000), 'RWF 15,000');
    });

    test('validates Rwandan phone numbers', () {
      expect(isValidRwandaPhone('0788123456'), isTrue);
      expect(isValidRwandaPhone('+250 788 123 456'), isTrue);
      expect(isValidRwandaPhone('12345'), isFalse);
    });

    test('computes opening hours', () {
      const point = DropoffPoint(
        id: 'x',
        name: 'Test',
        type: 'school',
        address: '',
        latitude: 0,
        longitude: 0,
        openDays: DropoffPoint.weekdays,
        opensAtMinute: 8 * 60,
        closesAtMinute: 17 * 60,
        district: 'Gasabo',
      );
      // 2026-09-28 is a Monday.
      expect(point.isOpenAt(DateTime(2026, 9, 28, 9)), isTrue);
      expect(point.isOpenAt(DateTime(2026, 9, 28, 18)), isFalse);
      expect(point.isOpenAt(DateTime(2026, 9, 27, 9)), isFalse);
      expect(point.operatingHours, 'Mon–Fri · 08:00–17:00');
    });
  });

  testWidgets('first launch walks through onboarding into the app',
      (tester) async {
    await tester
        .pumpWidget(EcoCollectApp(service: EwasteService(serverUrl: '')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Report your e-waste'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Welcome! Let’s set you up'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Aline Uwase');
    await tester.ensureVisible(find.text('Start recycling'));
    await tester.pump();
    await tester.tap(find.text('Start recycling'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Aline'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('0 kg'), findsNWidgets(2));
  });
}
