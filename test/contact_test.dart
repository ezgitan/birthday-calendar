import 'package:intl/date_symbol_data_local.dart';
import 'package:birthday_calendar/birthday.dart';
import 'package:birthday_calendar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));
  test('Numbers retain their country code and old records need no phone', () {
    expect(internationalPhone('0532 123 45 67'), '+905321234567');
    expect(internationalPhone('00 44 7700 900123'), '+447700900123');
    expect(internationalPhone('123;45'), '');
    final old = Birthday.decode(
      '[{"id":"1","name":"Ada","day":1,"month":2,"category":"Aile","reminders":[]}]',
    ).single;
    expect(old.name, 'Ada');
    expect(old.phone, '');
  });
  testWidgets(
    'Daily range hides and restores selections without changing the schedule twice',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PersonEditor(
              person: Birthday(
                id: '1',
                name: 'Ada',
                month: 1,
                day: 1,
                reminders: [3, 14, 30, 45],
              ),
            ),
          ),
        ),
      );
      Future<void> tapLabel(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tapLabel('Son günlerde her gün hatırlat');
      expect(find.text('Daha erken hatırlatmalar'), findsOneWidget);
      expect(find.text('3 gün'), findsOneWidget);
      final daily14 = find.descendant(
        of: find.byKey(const ValueKey('daily-options')),
        matching: find.text('14 gün'),
      );
      await tester.ensureVisible(daily14);
      await tester.tap(daily14);
      await tester.pumpAndSettle();
      expect(find.text('14 gün'), findsOneWidget);
      expect(find.textContaining('son 14 gün boyunca'), findsOneWidget);
      await tapLabel('Son günlerde her gün hatırlat');
      for (final n in [3, 14, 30, 45]) {
        final chip = find.widgetWithText(InputChip, '$n gün');
        expect(tester.widget<InputChip>(chip).selected, isTrue);
      }
    },
  );
  for (final alias in ['', 'Annem']) {
    testWidgets('Contact picker saves the correct name and number ($alias)', (
      tester,
    ) async {
      const picker = MethodChannel('flutter_native_contact_picker');
      final bridge = tester.binding.defaultBinaryMessenger;
      bridge.setMockMethodCallHandler(picker, (call) async {
        expect(call.method, 'selectPhoneNumber');
        return {
          'fullName': 'Aylin Kaya',
          'selectedPhoneNumber': '0532 123 45 67',
        };
      });
      addTearDown(() => bridge.setMockMethodCallHandler(picker, null));
      Birthday? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showModalBottomSheet<Birthday>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => const PersonEditor(),
                  );
                },
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rehberden kişi seç'));
      await tester.pumpAndSettle();
      expect(find.text('Rehberdeki ad: Aylin Kaya'), findsOneWidget);
      if (alias.isNotEmpty) {
        await tester.enterText(find.byType(TextFormField).first, alias);
      }
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(saved?.name, alias.isEmpty ? 'Aylin Kaya' : alias);
      expect(saved?.contactName, 'Aylin Kaya');
      expect(saved?.phone, '+905321234567');
    });
  }
}
