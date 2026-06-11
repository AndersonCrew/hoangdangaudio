import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hoang_dang_audio/main.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hoang_dang_audio_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('hoang_dang_audio_calendar');
  });

  setUp(() async {
    await Hive.box<dynamic>('hoang_dang_audio_calendar').clear();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('shows app title', (tester) async {
    await tester.pumpWidget(const HoangDangAudioApp());

    expect(find.text('Hoàng Đăng Audio'), findsOneWidget);
  });

  testWidgets('updates today from no story to ready with episode', (
    tester,
  ) async {
    final today = DateTime.now();

    await tester.pumpWidget(const HoangDangAudioApp());
    await tester.tap(find.text('${today.day}'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đã có truyện').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '12');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Tập 12'), findsOneWidget);
  });
}
