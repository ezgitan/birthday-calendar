import 'dart:convert';

const specialDayTypes = [
  'Doğum Günü',
  'Sevgililer Günü',
  'Evlilik Yıldönümü',
  'Tanışma Yıldönümü',
  'Diğer',
];

const categories = ['Aile', 'Arkadaşlar', 'Sevgili', 'İş arkadaşları', 'Diğer'];

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class Birthday {
  final String id, name, category;
  final int month, day;
  final int? year;
  final List<int> reminders;
  final int? dailyDays;
  final List<int> customReminderDays, customDailyRanges;
  final String? photo, contactName;
  final String phone;
  final String type;
  final String customType;
  bool get isBirthday => type == 'Doğum Günü';
  String get title => isBirthday
      ? '$name Doğum Günü'
      : '$name ile ${type == 'Diğer' ? customType : type}';
  final bool usesContactName;
  const Birthday({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    this.year,
    this.category = 'Arkadaşlar',
    this.dailyDays,
    this.customReminderDays = const [],
    this.customDailyRanges = const [],
    this.reminders = const [7, 1],
    this.photo,
    this.contactName,
    this.phone = '',
    this.type = 'Doğum Günü',
    this.customType = '',
    this.usesContactName = false,
  });

  DateTime inYear(int year) =>
      DateTime(year, month, day.clamp(1, DateTime(year, month + 1, 0).day));
  DateTime next(DateTime now) {
    final date = inYear(now.year);
    return date.isBefore(dateOnly(now)) ? inYear(now.year + 1) : date;
  }

  int remaining(DateTime now) {
    final target = next(now);
    return DateTime.utc(
      target.year,
      target.month,
      target.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'customType': customType,
    'month': month,
    'day': day,
    'year': year,
    'category': category,
    'dailyDays': dailyDays,
    'customReminderDays': customReminderDays,
    'customDailyRanges': customDailyRanges,
    'reminders': reminders,
    'photo': photo,
    'phone': phone,
    'contactName': contactName,
    'usesContactName': usesContactName,
  };
  factory Birthday.fromJson(Map<String, dynamic> j) => Birthday(
    id: j['id'],
    name: j['name'],
    type: j['type'] ?? 'Doğum Günü',
    customType: j['customType'] ?? '',
    month: j['month'],
    day: j['day'],
    year: j['year'],
    category: j['category'],
    dailyDays: j['dailyDays'] as int?,
    customDailyRanges: List<int>.from(j['customDailyRanges'] ?? const []),
    customReminderDays: List<int>.from(j['customReminderDays'] ?? const []),
    reminders: List<int>.from(j['reminders']),
    photo: j['photo'],
    phone: j['phone'] ?? '',
    contactName: j['contactName'],
    usesContactName: j['usesContactName'] ?? false,
  );
  static String encode(List<Birthday> list) =>
      jsonEncode(list.map((b) => b.toJson()).toList());
  static List<Birthday> decode(String value) =>
      (jsonDecode(value) as List).map((j) => Birthday.fromJson(j)).toList();
}

class ReminderEvent {
  final Birthday birthday;
  final DateTime date;
  final int daysBefore;
  const ReminderEvent(this.birthday, this.date, this.daysBefore);
}

List<ReminderEvent> upcomingEvents(List<Birthday> people, DateTime now) {
  final events = <ReminderEvent>[];
  for (final person in people) {
    for (var year = now.year; year <= now.year + 5; year++) {
      final birthday = person.inYear(year);
      for (final offset in {
        0,
        ...person.reminders,
        for (var d = 1; d <= (person.dailyDays ?? 0); d++) d,
      }) {
        final day = DateTime(
          birthday.year,
          birthday.month,
          birthday.day - offset,
        );
        final date = DateTime(
          day.year,
          day.month,
          day.day,
          offset == 0 ? 0 : 9,
        );
        if (date.isAfter(now)) events.add(ReminderEvent(person, date, offset));
      }
    }
  }
  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}

// National numbers entered without a country code use the app's Turkish default.
String internationalPhone(String input) {
  var number = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (number.startsWith('00')) number = '+${number.substring(2)}';
  if (RegExp(r'^0[1-9][0-9]{9}$').hasMatch(number)) {
    number = '+90${number.substring(1)}';
  }
  if (RegExp(r'^[1-9][0-9]{9}$').hasMatch(number)) number = '+90$number';
  if (RegExp(r'^90[1-9][0-9]{9}$').hasMatch(number)) number = '+$number';
  return RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(number) ? number : '';
}
