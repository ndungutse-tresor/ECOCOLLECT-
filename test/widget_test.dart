import 'dart:convert';

import 'package:ecocollect_rwanda/main.dart';
import 'package:ecocollect_rwanda/models/dropoff_point.dart';
import 'package:ecocollect_rwanda/models/ewaste_item.dart';
import 'package:ecocollect_rwanda/models/reward.dart';
import 'package:ecocollect_rwanda/services/ewaste_service.dart';
import 'package:ecocollect_rwanda/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

EwasteItem _newItem({String id = 'test1'}) => EwasteItem(
      id: id,
      categoryId: 'phones',
      quantity: 3,
      estimatedWeightKg: 0.6,
      disposalMethod: DisposalMethod.dropoff,
      dropoffPointId: 'dp1',
      createdAt: DateTime.now(),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('EwasteService', () {
    test('seeds demo data and derives totals from handed-over items', () async {
      final service = EwasteService();
      await service.ready;

      expect(service.items, hasLength(4));
      expect(service.pendingItems, hasLength(1));
      expect(service.earnedPoints, 14 + 30 + 35);
      expect(service.pendingPoints, 52);
      expect(service.totalWeightKg, closeTo(3.9, 1e-9));
      expect(service.co2Prevented, closeTo(11.7, 1e-9));
    });

    test('credits points only after hand-over', () async {
      final service = EwasteService(seedDemoData: false);
      await service.ready;

      await service.addItem(_newItem());
      // 0.6 kg * 10 + 3 items * 5
      expect(service.pendingPoints, 21);
      expect(service.ecoPoints, 0);

      final credited = await service.confirmHandOver('test1');
      expect(credited, 21);
      expect(service.ecoPoints, 21);
      expect(service.pendingPoints, 0);
      expect(service.getItemById('test1')!.status, ItemStatus.collected);
    });

    test('cancelling a pending report removes it', () async {
      final service = EwasteService(seedDemoData: false);
      await service.ready;
      await service.addItem(_newItem());
      await service.cancelItem('test1');
      expect(service.items, isEmpty);
    });

    test('redeeming deducts points and refuses when balance is too low',
        () async {
      final service = EwasteService();
      await service.ready;
      final coffee = Reward.byId('coffee')!;

      expect(service.ecoPoints, 79);
      expect(await service.redeem(coffee), isNull);

      await service.confirmHandOver('demo4');
      expect(service.ecoPoints, 131);

      final redemption = await service.redeem(coffee);
      expect(redemption, isNotNull);
      expect(
          redemption!.code, matches(RegExp(r'^ECO-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
      expect(service.ecoPoints, 31);
      expect(service.spentPoints, 100);
    });

    test('persists data between app launches', () async {
      final first = EwasteService(seedDemoData: false);
      await first.ready;
      await first.addItem(_newItem(id: 'persisted'));

      final second = EwasteService(seedDemoData: false);
      await second.ready;
      expect(second.getItemById('persisted'), isNotNull);
    });

    test('collected items become recycled after the processing time', () async {
      final collectedAt = DateTime.now().subtract(const Duration(days: 3));
      final item = EwasteItem(
        id: 'old',
        categoryId: 'batteries',
        quantity: 1,
        estimatedWeightKg: 0.15,
        disposalMethod: DisposalMethod.dropoff,
        dropoffPointId: 'dp2',
        createdAt: collectedAt.subtract(const Duration(days: 1)),
        status: ItemStatus.collected,
        collectedAt: collectedAt,
      );
      SharedPreferences.setMockInitialValues({
        'ecocollect.items': jsonEncode([item.toJson()]),
      });

      final service = EwasteService();
      await service.ready;
      expect(service.getItemById('old')!.status, ItemStatus.recycled);
    });
  });

  group('helpers', () {
    test('formats weights without trailing zeros', () {
      expect(formatKg(0.45), '0.45 kg');
      expect(formatKg(3), '3 kg');
      expect(formatKg(11.7), '11.7 kg');
      expect(formatKg(1500), '1.5 t');
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
    await tester.pumpWidget(const EcoCollectApp());
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
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
