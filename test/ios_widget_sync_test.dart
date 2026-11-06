import 'dart:convert';
import 'package:birthday_calendar/birthday.dart';
import 'package:birthday_calendar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'iOS publishes existing records, edits, additions and deletions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final original = Birthday(
        id: 'one',
        name: 'Test',
        day: now.day,
        month: now.month,
      );
      SharedPreferences.setMockInitialValues({
        'birthdays': Birthday.encode([original]),
        'firstNotificationPrompt': true,
      });
      final writes = <List<dynamic>>[];
      const channel = MethodChannel('iyiki/widgetSnapshot');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // Notification services are independent of widget publication.
      const timezone = MethodChannel('flutter_timezone');
      messenger.setMockMethodCallHandler(
        timezone,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'publish');
        writes.add(jsonDecode(call.arguments as String) as List);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(const BirthdayApp());
      await tester.pumpAndSettle();
      expect(writes.last.single, {
        'name': 'Test Doğum Günü',
        'phone': '',
        'month': now.month,
        'day': now.day,
      });

      Future<void> editName(String name) async {
        await tester.enterText(find.byType(TextFormField).first, name);
        await tester.ensureVisible(find.text('Kaydet'));
        await tester.tap(find.text('Kaydet'));
        await tester.pumpAndSettle();
      }

      final menu = find.byType(PopupMenuButton<String>).first;
      Future<void> choose(String label) async {
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await choose('Düzenle');
      await editName('Updated');
      expect(writes.last.single['name'], 'Updated Doğum Günü');
      await choose('Sil');
      await tester.tap(find.text('Sil').last);
      await tester.pumpAndSettle();
      expect(writes.last, isEmpty);
      await tester.tap(find.byTooltip('Tarih ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tarih ekle'));
      await tester.pumpAndSettle();
      await editName('Added');
      expect(writes.last.single['name'], 'Added Doğum Günü');
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
