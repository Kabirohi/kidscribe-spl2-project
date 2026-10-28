// SRS US_14, US_25 and US_26 - the five stages in order, the parent
// progress screen, and work that is kept on the device.
// Covers T_35, T_36, T_59, T_60, T_61, T_62.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/blocs/progress/progress_cubit.dart';
import 'package:kidscribe/blocs/stages/stages_cubit.dart';
import 'package:kidscribe/data/trace_templates.dart';
import 'package:kidscribe/models/profile_models.dart';
import 'package:kidscribe/services/family_service.dart';
import 'package:kidscribe/services/progress_service.dart';
import 'package:kidscribe/services/report_service.dart';

import 'helpers.dart';

void main() {
  late ProgressService progress;
  late FamilyService family;

  setUp(() async {
    await useEmptyStorage();
    progress = ProgressService();
    family = FamilyService();
  });

  Future<StagesState> loadStages() async {
    final cubit = StagesCubit(progress: progress, family: family);
    await cubit.load();
    final s = cubit.state;
    await cubit.close();
    return s;
  }

  /// Finishes every Stage 1 stroke.
  Future<void> finishStage1() async {
    for (final item in stage1Items) {
      await progress.saveStars(item.id, 3);
    }
  }

  group('US_14 the five learning stages', () {
    test('a new child starts at Stage 1 and Stage 2 is still shut', () async {
      final s = await loadStages();
      expect(s.currentStage, 1);
      expect(s.stage1Complete, isFalse);
      expect(s.stage2Complete, isFalse);
    });

    test('T_35 finishing Stage 1 opens Stage 2', () async {
      await finishStage1();

      final s = await loadStages();
      expect(s.stage1Complete, isTrue);
      expect(s.currentStage, 2);
    });

    test('T_36 Stage 3 stays shut while Stage 2 is not finished', () async {
      await finishStage1();
      // only one letter out of 26 is done
      await progress.saveGuided('A', 3);
      await progress.saveFree('A', 90);

      final s = await loadStages();
      expect(s.stage2Complete, isFalse);
      expect(s.currentStage, 2, reason: 'the child is still on Stage 2');
      expect(s.stage3Complete, isFalse);
    });

    test('a half finished Stage 1 does not open Stage 2', () async {
      await progress.saveStars(stage1Items.first.id, 3);
      final s = await loadStages();
      expect(s.stage1Complete, isFalse);
      expect(s.currentStage, 1);
    });

    test('the stage screen shows who is learning', () async {
      await family.saveChild(const ChildProfile(id: '1', name: 'Sara', age: 5));
      await family.setActiveChild('1');

      final s = await loadStages();
      expect(s.learnerName, 'Sara');
    });
  });

  group('US_25 the parent progress screen', () {
    Future<ProgressState> loadProgress() async {
      final cubit = ProgressCubit(
          progress: progress, family: family, reports: ReportService());
      await cubit.load();
      final s = cubit.state;
      await cubit.close();
      return s;
    }

    test('T_60 a brand new child shows "no progress yet"', () async {
      final s = await loadProgress();
      expect(s.loading, isFalse);
      expect(s.hasActivity, isFalse);
      expect(s.doneLetters, isEmpty);
    });

    test('T_59 weekly progress and weak areas are shown for an active child',
        () async {
      await progress.saveGuided('A', 3);
      await progress.saveFree('A', 90);   // finished
      await progress.saveGuided('B', 1);
      await progress.saveFree('B', 30);   // started, still weak

      final s = await loadProgress();

      expect(s.hasActivity, isTrue);
      expect(s.doneLetters, contains('A'));
      expect(s.weakLetters, contains('B'));
      expect(s.week.length, 7, reason: 'the chart shows 7 days');
      // today has practice in it
      expect(s.week.last.value, greaterThan(0));
    });
  });

  group('US_26 work is kept on the device', () {
    test('T_61 and T_62 saved work is still there when the app opens again',
        () async {
      await progress.saveStars('s1_line', 2);
      await progress.saveWordDone('CAT');

      // A brand new service object is like opening the app again.
      final afterRestart = ProgressService();

      expect((await afterRestart.loadAll())['s1_line'], 2);
      expect(await afterRestart.loadWords(), contains('CAT'));
    });

    test('only the best result is kept, never a worse one', () async {
      await progress.saveStars('s1_line', 3);
      await progress.saveStars('s1_line', 1); // a worse try later

      expect((await progress.loadAll())['s1_line'], 3);
    });

    test('each child keeps their own progress', () async {
      await family.saveChild(const ChildProfile(id: '1', name: 'Sara', age: 5));
      await family.saveChild(const ChildProfile(id: '2', name: 'Rafi', age: 6));

      await family.setActiveChild('1');
      await progress.saveWordDone('CAT');

      await family.setActiveChild('2');
      expect(await progress.loadWords(), isEmpty,
          reason: "Rafi must not see Sara's words");

      await family.setActiveChild('1');
      expect(await progress.loadWords(), contains('CAT'));
    });
  });
}
