// SRS US_28 and US_29 - the premium plan and the advanced report.
// Covers T_65, T_66, T_67, T_68.
//
// NOTE: the payment is a DEMO. No card details are asked for and no
// money moves. These tests check the locking and unlocking only.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/blocs/report/advanced_report_cubit.dart';
import 'package:kidscribe/services/family_service.dart';
import 'package:kidscribe/services/premium_service.dart';
import 'package:kidscribe/services/progress_service.dart';

import 'helpers.dart';

void main() {
  late PremiumService premium;

  setUp(() async {
    await useEmptyStorage();
    premium = PremiumService();
  });

  group('US_28 buying premium', () {
    test('premium starts locked', () async {
      expect(await premium.isPremium(), isFalse);
    });

    test('T_65 a finished payment opens the premium features', () async {
      final result = await premium.buy();

      expect(result.success, isTrue);
      expect(await premium.isPremium(), isTrue);
      expect(await premium.since(), isNotNull);
    });

    test('T_66 a failed payment leaves premium locked and says so', () async {
      final result = await premium.buy(simulateFailure: true);

      expect(result.success, isFalse);
      expect(result.message, contains('did not go through'));
      expect(result.message, contains('Nothing was charged'));
      expect(await premium.isPremium(), isFalse);
    });

    test('the plan can be cancelled again', () async {
      await premium.buy();
      await premium.cancel();
      expect(await premium.isPremium(), isFalse);
    });

    test('the price is clearly marked as a demo', () {
      expect(PremiumService.priceText.toLowerCase(), contains('demo'));
      expect(PremiumService.features, isNotEmpty);
    });
  });

  group('US_29 the advanced report', () {
    AdvancedReportCubit makeCubit() => AdvancedReportCubit(
          progress: ProgressService(),
          premium: premium,
          family: FamilyService(),
        );

    test('T_68 a free parent is blocked and sees the upgrade state',
        () async {
      final cubit = makeCubit();
      await cubit.load();

      expect(cubit.state.isPremium, isFalse);
      expect(cubit.state.letters, isEmpty, reason: 'no detail without premium');
      await cubit.close();
    });

    test('T_67 a premium parent sees the detailed charts', () async {
      await premium.buy();
      final progress = ProgressService();
      await progress.saveGuided('A', 3);
      await progress.saveFree('A', 90);
      await progress.saveGuided('B', 1);
      await progress.saveFree('B', 40); // tried, but still weak

      final cubit = makeCubit();
      await cubit.load();

      expect(cubit.state.isPremium, isTrue);
      expect(cubit.state.letters, isNotEmpty);
      expect(cubit.state.last14Days.length, 14);

      // B was tried but is not finished, so it counts as weak. A is done.
      final weak = cubit.state.weakLetters.map((l) => l.letter);
      expect(weak, contains('B'));
      expect(weak, isNot(contains('A')));
      await cubit.close();
    });
  });
}
