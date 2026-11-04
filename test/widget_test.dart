import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:birthday_calendar/main.dart';
import 'package:birthday_calendar/birthday.dart';

void main() {
  test(
    'Daily reminders cross New Year and merge overlapping single reminders',
    () {
      const person = Birthday(
        id: 'daily',
        name: 'Ada',
        month: 1,
        day: 3,
        dailyDays: 5,
        reminders: [3, 1],
      );
      final restored = Birthday.decode(Birthday.encode([person])).single;
      final events = upcomingEvents(
        [restored],
        DateTime(2026, 12, 28),
      ).where((e) => e.date.isBefore(DateTime(2027, 1, 4))).toList();
      expect(events.map((e) => e.daysBefore), [5, 4, 3, 2, 1, 0]);
      expect(events.first.date, DateTime(2026, 12, 29, 9));
      expect(events.last.date, DateTime(2027, 1, 3));
    },
  );

  test('Today stays today, past birthdays roll into next year', () {
    const p = Birthday(id: '1', name: 'Ayşe', month: 10, day: 30);
    expect(p.remaining(DateTime(2026, 10, 30, 23, 59)), 0);
    expect(p.next(DateTime(2026, 10, 31)), DateTime(2027, 10, 30));
  });
  test('Leap birthday uses February 28 only in non-leap years', () {
    const p = Birthday(id: '1', name: 'Ayşe', month: 2, day: 29);
    expect(p.inYear(2027), DateTime(2027, 2, 28));
    expect(p.inYear(2028), DateTime(2028, 2, 29));
  });
  test('Reminders cross year boundary and birthdays use midnight', () {
    const p = Birthday(
      id: '1',
      name: 'Ayşe',
      month: 1,
      day: 2,
      reminders: [7, 7],
    );
    final events = upcomingEvents([p], DateTime(2026, 12, 24));
    expect(events.first.date, DateTime(2026, 12, 26, 9));
    expect(events[1].date, DateTime(2027, 1, 2));
    expect(events.where((e) => e.date == events.first.date).length, 1);
  });
  test('Unknown year and photo survive persistence', () {
    const p = Birthday(
      id: '1',
      name: 'İpek',
      month: 3,
      day: 8,
      photo: 'aGVsbG8=',
      reminders: [14, 42],
    );
    final result = Birthday.decode(Birthday.encode([p])).single;
    expect(result.year, isNull);
    expect(result.photo, p.photo);
    expect(result.reminders, [14, 42]);
  });
  testWidgets('Swipe to the next event on the same day', (tester) async {
    final now = DateTime.now();
    final events = [
      for (final name in ['Ada', 'Deniz'])
        Birthday(id: name, name: name, month: now.month, day: now.day),
    ];
    SharedPreferences.setMockInitialValues({
      'birthdays': Birthday.encode(events),
    });
    await tester.pumpWidget(const BirthdayApp());
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.drag(find.text('SIRADAKİ GÜZEL GÜN'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Phone layout can save a person and open the calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'firstNotificationPrompt': true});
    await tester.pumpWidget(const BirthdayApp());
    await tester.pumpAndSettle();
    expect(find.text('Bu ayki özel günler'), findsOneWidget);
    await tester.tap(find.byTooltip('Tarih ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tarih ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Deniz');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Deniz Doğum Günü'), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(Birthday.decode(prefs.getString('birthdays')!).single.name, 'Deniz');
    await tester.tap(find.text('Takvim'));
    await tester.pumpAndSettle();
    expect(find.text('Bugüne dön'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

