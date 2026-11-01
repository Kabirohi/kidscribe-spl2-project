// SRS US_24 - the teacher exports a student's progress report.
// Covers T_57 and T_58.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/services/progress_service.dart';
import 'package:kidscribe/services/report_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'helpers.dart';

/// A stand-in for the phone's "documents" folder, so the report can be
/// written to a real folder on this computer during the test.
class _FakePaths extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePaths(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

void main() {
  late Directory tempDir;
  late ReportService reports;
  late ProgressService progress;

  setUp(() async {
    await useEmptyStorage();
    tempDir = await Directory.systemTemp.createTemp('kidscribe_report');
    PathProviderPlatform.instance = _FakePaths(tempDir.path);
    reports = ReportService();
    progress = ProgressService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('T_57 a report file with the progress details is created', () async {
    await progress.saveStars('s1_line', 3);
    await progress.saveGuided('A', 3);
    await progress.saveFree('A', 90);
    await progress.saveWordDone('CAT');

    final (path, content) =
        await reports.exportReport(displayName: 'Sara', scope: guestScope);

    // the file really exists on disk
    expect(File(path).existsSync(), isTrue);
    expect(await File(path).readAsString(), content);

    // and it holds the progress details
    expect(content, contains('Sara'));
    expect(content, contains('Stage 1 - Strokes'));
    expect(content, contains('Stage 2 - Letters'));
    expect(content, contains('Stage 3 - Words'));
    expect(content, contains('Finished letters: A'));
    expect(content, contains('CAT'));
  });

  test('T_58 a student with no activity gets a "no activity yet" report',
      () async {
    final (path, content) =
        await reports.exportReport(displayName: 'Rafi', scope: guestScope);

    expect(File(path).existsSync(), isTrue);
    expect(content, contains('No activity yet.'));
    expect(content, contains('Rafi'));
  });

  test('the file name is safe even when the name has spaces', () async {
    final (path, _) = await reports.exportReport(
        displayName: 'Abu Sayed', scope: guestScope);
    expect(path, contains('Abu_Sayed'));
    expect(path, endsWith('.txt'));
  });

  test('letters that were started but not finished are listed as weak',
      () async {
    await progress.saveGuided('B', 1);
    await progress.saveFree('B', 40);

    final text =
        await reports.buildReport(displayName: 'Sara', scope: guestScope);

    expect(text, contains('Needs practice'));
    expect(text, contains('B (free-hand 40%)'));
  });
}
