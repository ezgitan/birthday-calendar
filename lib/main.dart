import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'birthday.dart';
import 'reminders.dart';
import 'opening.dart';

const ink = Color(0xFF353448);
const purple = Color(0xFF8472BA);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BirthdayApp());
}

class BirthdayApp extends StatelessWidget {
  const BirthdayApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'İyi ki • Özel gün takvimi',
    debugShowCheckedModeBanner: false,
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF8F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        surface: const Color(0xFFFAF8F5),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final reminders = Reminders();
  final openingDone = Completer<void>();
  List<Birthday> people = [];
  SharedPreferences? prefs;
  int page = 0;
  bool enabled = false, loaded = false, busy = false;
  String query = '';
  bool addExpanded = false;
  int birthdayPage = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month),
      selected = dateOnly(DateTime.now());
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && loaded && !busy) sync();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  bool recordsLoaded = false;
  String? lastWidgetError;
  static const iosWidget = MethodChannel('iyiki/widgetSnapshot');

  Future<void> load() async {
    try {
      prefs = await SharedPreferences.getInstance();
      people = Birthday.decode(prefs!.getString('birthdays') ?? '[]');
      recordsLoaded = true;
      enabled = prefs!.getBool('notifications') ?? false;
      if (!mounted) return;
      final ask =
          reminders.supported &&
          !prefs!.containsKey('firstNotificationPrompt') &&
          !prefs!.containsKey('notifications');
      setState(() {
        loaded = true;
        busy = ask;
      });
      if (ask) {
        await syncWidgets();
        await openingDone.future;
        if (!mounted) return;
        try {
          await prefs!.setBool('firstNotificationPrompt', true);
          final granted = await reminders.request(requestExactTime: false);
          await prefs!.setBool('notifications', granted);
          if (mounted) setState(() => enabled = granted);
        } catch (_) {
          message('Bildirimleri Ayarlar’dan açabilirsin.');
        } finally {
          if (mounted) {
            setState(() => busy = false);
            await sync();
          }
        }
      } else {
        await sync();
      }
    } catch (_) {
      if (mounted) setState(() => loaded = true);
      message('Kayıtlar yüklenemedi. Uygulamayı yeniden açmayı deneyin.');
    }
  }

  Future<void> syncWidgets() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // Never replace a good snapshot with an empty list after a failed load.
          if (!recordsLoaded) return;
          await iosWidget.invokeMethod<void>(
            'publish',
            jsonEncode([
              for (final person in people)
                {
                  'name': person.title,
                  'phone': person.phone,
                  'month': person.month,
                  'day': person.day,
                },
            ]),
          );
          lastWidgetError = null;
          return;
        }
        await HomeWidget.saveWidgetData<String>(
          'birthdays',
          jsonEncode(
            people
                .map(
                  (p) => {...p.toJson(), 'name': p.title, 'personName': p.name},
                )
                .toList(),
          ),
        );
        if (defaultTargetPlatform == TargetPlatform.android) {
          await HomeWidget.updateWidget(
            androidName: 'SquareBirthdayWidgetProvider',
          );
        }
        await HomeWidget.updateWidget(
          androidName: 'BirthdayWidgetProvider',
          iOSName: 'BirthdayWidget',
        );
      } on PlatformException catch (error) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          if (lastWidgetError != error.code) {
            lastWidgetError = error.code;
            message(
              error.code == 'groupUnavailable'
                  ? 'iOS widget ortak alanına erişilemiyor. App Group imzasını kontrol et.'
                  : 'iOS widget verisi kaydedilemedi veya doğrulanamadı.',
            );
          }
        } else {
          message('Ana ekran kartı güncellenemedi.');
        }
      } catch (_) {
        message('Ana ekran kartı güncellenemedi.');
      }
    }
  }

  Future<void> sync() async {
    await syncWidgets();
    try {
      await reminders.sync(people, enabled);
    } catch (_) {
      reminders.status =
          'Bildirimler planlanamadı. İzinleri kontrol edip tekrar deneyin.';
    }
    if (mounted) setState(() {});
  }

  Future<void> save(List<Birthday> updated) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!await prefs!.setString('birthdays', Birthday.encode(updated))) {
        throw Exception('save');
      }
      setState(() => people = updated);
      await sync();
    } catch (_) {
      message('Kaydedilemedi. Lütfen yeniden deneyin.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Birthday? person]) async {
    final result = await showModalBottomSheet<Birthday>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFAF8F5),
      builder: (_) => PersonEditor(
        person: person,
        initialDate: page == 1 ? selected : null,
      ),
    );
    if (result != null) {
      await save([...people.where((p) => p.id != result.id), result]);
    }
  }

  Future<void> remove(Birthday p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${p.title} silinsin mi?'),
        content: const Text('Bu kişiye ait hatırlatmalar da kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (yes == true) await save(people.where((b) => b.id != p.id).toList());
  }

  List<Birthday> get sorted => [...people]
    ..sort((a, b) => a.next(DateTime.now()).compareTo(b.next(DateTime.now())));
  Widget panel(Widget child, {Color color = Colors.white}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(26),
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) => LaunchSurface(
    child: OpeningAnimation(
      ready: loaded,
      onComplete: () {
        unawaited(LaunchSurface.signal('homeVisible'));
        if (!openingDone.isCompleted) openingDone.complete();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: !loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                      children: [
                        Row(
                          children: [
                            Semantics(
                              label: 'İyi ki',
                              image: true,
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        logoPart(36, 36, 120, Offset.zero),
                                        Transform.scale(
                                          scale: 0.86,
                                          child: logoPart(
                                            36,
                                            36,
                                            120,
                                            const Offset(-42, -26.25),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'iyi ki',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontFamily: 'Chewy',
                                          color: Colors.black,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (page == 1)
                              TextButton(
                                onPressed: () => setState(() {
                                  selected = dateOnly(DateTime.now());
                                  month = DateTime(
                                    selected.year,
                                    selected.month,
                                  );
                                }),
                                child: const Text('Bugüne dön'),
                              )
                            else
                              Text(
                                DateFormat(
                                  'd MMMM',
                                  'tr',
                                ).format(DateTime.now()),
                                style: const TextStyle(color: Colors.black54),
                              ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        ...switch (page) {
                          0 => home(),
                          1 => calendar(),
                          _ => settings(),
                        },
                      ],
                    ),
            ),
          ),
        ),
        floatingActionButton: loaded && page != 2
            ? TapRegion(
                onTapOutside: (_) {
                  if (addExpanded) setState(() => addExpanded = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: addExpanded ? 142 : 56,
                  height: 56,
                  child: FloatingActionButton(
                    tooltip: 'Tarih ekle',
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    onPressed: busy
                        ? null
                        : () {
                            if (!addExpanded) {
                              setState(() => addExpanded = true);
                              return;
                            }
                            setState(() => addExpanded = false);
                            edit();
                          },
                    child: ClipRect(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add),
                          if (addExpanded)
                            const Flexible(
                              child: Text(
                                ' Tarih ekle',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (i) => setState(() => page = i),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFEAE3F5),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Takvim',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    ),
  );
  static const birthdayHeading = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.bold,
  );
  int nextIndex = 0;
  double swipeDistance = 0;
  List<Widget> home() {
    final list =
        people
            .where(
              (p) =>
                  p.month == DateTime.now().month &&
                  p.title.toLowerCase().contains(query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    final pages = (list.length / 3).ceil().clamp(1, 1000000);
    final currentPage = birthdayPage.clamp(0, pages - 1);
    final now = DateTime.now();
    final ordered = sorted;
    final sameDay = ordered
        .takeWhile((p) => p.next(now) == ordered.first.next(now))
        .toList();
    final index = nextIndex % (sameDay.isEmpty ? 1 : sameDay.length);
    final next = sameDay.isEmpty ? null : sameDay[index];
    void advance(int step) =>
        setState(() => nextIndex = (index + step) % sameDay.length);

    return [
      GestureDetector(
        onHorizontalDragStart: sameDay.length < 2
            ? null
            : (_) => swipeDistance = 0,
        onHorizontalDragUpdate: sameDay.length < 2
            ? null
            : (d) => swipeDistance += d.primaryDelta ?? 0,
        onHorizontalDragEnd: sameDay.length < 2
            ? null
            : (d) {
                final speed = d.primaryVelocity ?? 0;
                if (swipeDistance.abs() >= 32 || speed.abs() >= 180) {
                  advance(
                    (swipeDistance.abs() >= 32 ? swipeDistance : speed) < 0
                        ? 1
                        : -1,
                  );
                }
              },
        child: panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SIRADAKİ GÜZEL GÜN',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: purple,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                next == null ? 'İlk özel gününü ekle' : next.title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                next == null
                    ? 'Hatırlamaya değer insanlar burada buluşsun.'
                    : DateFormat(
                        'd MMMM',
                        'tr',
                      ).format(next.next(DateTime.now())),
              ),
              const SizedBox(height: 20),
              Text(
                next == null
                    ? 'Bir tarih ekle, her yıl hatırlayalım.'
                    : next.remaining(DateTime.now()) == 0
                    ? 'Bugün kutlama zamanı! 🎉'
                    : '${next.remaining(DateTime.now())} gün kaldı',
                style: TextStyle(
                  fontSize: next?.remaining(DateTime.now()) == 0 ? 20 : 22,
                  fontWeight: FontWeight.w700,
                  color: purple,
                ),
              ),
              if (next != null) contactActions(next),
              if (sameDay.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Önceki etkinlik',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => advance(-1),
                    ),
                    Text('${index + 1} / ${sameDay.length}'),
                    IconButton(
                      tooltip: 'Sonraki etkinlik',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => advance(1),
                    ),
                  ],
                ),
            ],
          ),
          color: const Color(0xFFEFE8F8),
        ),
      ),
      const SizedBox(height: 30),
      Row(
        children: [
          const Expanded(
            child: Text('Bu ayki özel günler', style: birthdayHeading),
          ),
          const SizedBox(width: 12),
          if (list.isNotEmpty) Text('${list.length} kişi'),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        onChanged: (v) => setState(() {
          query = v;
          birthdayPage = 0;
        }),
        decoration: const InputDecoration(
          hintText: 'Sevdiklerin arasında ara',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 12),
      if (list.isEmpty) panel(const Text('Bu ay için özel gün bulunamadı.')),
      ...list.skip(currentPage * 3).take(3).map(personTile),
      if (pages > 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Önceki kişiler',
              onPressed: currentPage > 0
                  ? () => setState(() => birthdayPage = currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${currentPage + 1} / $pages'),
            IconButton(
              tooltip: 'Sonraki kişiler',
              onPressed: currentPage + 1 < pages
                  ? () => setState(() => birthdayPage = currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
    ];
  }

  Widget logoPart(double width, double height, double size, Offset offset) =>
      ClipRect(
        child: SizedBox(
          width: width,
          height: height,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: size,
            maxHeight: size,
            child: Transform.translate(
              offset: offset,
              child: Image.asset('assets/logo.jpg', width: size, height: size),
            ),
          ),
        ),
      );

  Widget contactActions(Birthday p) {
    if (p.phone.isEmpty) {
      return TextButton.icon(
        onPressed: () => edit(p),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Numara ekle'),
      );
    }
    Future<void> open(bool chat) async {
      final uri = chat
          ? Uri.https('wa.me', '/${p.phone.substring(1)}')
          : Uri(scheme: 'tel', path: p.phone);
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        /* Show the same recovery hint for unavailable handlers. */
      }
      message(
        chat ? 'WhatsApp sohbeti açılamadı.' : 'Telefon uygulaması açılamadı.',
      );
    }

    return Wrap(
      children: [
        TextButton.icon(
          onPressed: () => open(false),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Ara'),
        ),
        TextButton.icon(
          onPressed: () => open(true),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('WhatsApp'),
        ),
      ],
    );
  }

  Widget personTile(Birthday p) {
    final days = p.remaining(DateTime.now());
    final date = p.next(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onTap: busy ? null : () => edit(p),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFBE8DC),
                foregroundColor: ink,
                backgroundImage: p.photo == null
                    ? null
                    : MemoryImage(base64Decode(p.photo!)),
                child: p.photo == null
                    ? Text(p.name.characters.first.toUpperCase())
                    : null,
              ),
              title: Text(
                p.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${DateFormat('d MMMM', 'tr').format(date)}${p.year == null || !p.isBirthday ? '' : ' • ${date.year - p.year!} yaş'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    days == 0 ? 'Bugün 🎉' : '$days gün',
                    style: const TextStyle(
                      color: purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') {
                        remove(p);
                      } else {
                        edit(p);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: contactActions(p),
            ),
          ],
        ),
      ),
    );
  }

  final firstBirthdayCard = GlobalKey();
  void selectDay(DateTime day) {
    setState(() => selected = day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = firstBirthdayCard.currentContext;
      if (card != null) {
        Scrollable.ensureVisible(
          card,
          duration: const Duration(milliseconds: 220),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  Future<void> pickMonth() async {
    var year = month.year;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: const Text('Ay ve yıl seç'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: year,
                    isExpanded: true,
                    items: [
                      for (
                        var y = (year < 1900 ? year : 1900);
                        y <= (year > 2200 ? year : 2200);
                        y++
                      )
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (y) => refresh(() => year = y!),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      for (var m = 1; m <= 12; m++)
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(ctx, DateTime(year, m)),
                          child: Text(
                            DateFormat('MMMM', 'tr').format(DateTime(year, m)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      changeMonth((picked.year - month.year) * 12 + picked.month - month.month);
    }
  }

  void changeMonth(int step) {
    final target = DateTime(month.year, month.month + step);
    final dates =
        people
            .where((p) => p.month == target.month)
            .map((p) => p.inYear(target.year))
            .toList()
          ..sort();
    setState(() {
      month = target;
      selected = dates.firstOrNull ?? target;
    });
  }

  List<Widget> calendar() {
    final offset = DateTime(month.year, month.month).weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final matches = sorted
        .where((b) => b.inYear(selected.year) == selected)
        .toList();
    return [
      panel(
        Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Önceki ay',
                  onPressed: () => changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: pickMonth,
                    child: Text(
                      DateFormat('MMMM yyyy', 'tr').format(month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sonraki ay',
                  onPressed: () => changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
                  .map(
                    (s) => Expanded(
                      child: Center(
                        child: Text(
                          s,
                          style: const TextStyle(color: Colors.black45),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 46,
              ),
              itemCount: ((offset + count) / 7).ceil() * 7,
              itemBuilder: (_, i) {
                final day = i - offset + 1;
                if (day < 1 || day > count) return const SizedBox();
                final date = DateTime(month.year, month.month, day);
                final marked = people.any((b) => b.inYear(month.year) == date);
                final active = date == selected;
                return Semantics(
                  label:
                      '$day ${DateFormat('MMMM', 'tr').format(month)}${marked ? ', özel gün var' : ''}',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => selectDay(date),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: active
                            ? purple
                            : date == dateOnly(DateTime.now())
                            ? const Color(0xFFEFE8F8)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              color: active ? Colors.white : ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: marked
                                  ? (active ? Colors.white : purple)
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        matches.isEmpty
            ? 'Özel günler'
            : 'Özel günler - ${matches.length} kişi',
        style: birthdayHeading,
      ),
      const SizedBox(height: 8),
      if (matches.isEmpty)
        panel(const Text('Bu gün için kayıtlı özel gün yok. 🌿')),
      if (matches.isNotEmpty)
        KeyedSubtree(key: firstBirthdayCard, child: personTile(matches.first)),
      ...matches.skip(1).map(personTile),
    ];
  }

  List<Widget> settings() => [
    Text('Ayarlar', style: Theme.of(context).textTheme.headlineLarge),
    const SizedBox(height: 20),
    panel(
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Özel gün bildirimleri'),
        subtitle: const Text('Önceden 09.00’da, özel gününde 00.00’da'),
        value: enabled,
        onChanged: busy
            ? null
            : (v) async {
                setState(() => busy = true);
                try {
                  final allowed = !v || await reminders.request();
                  if (allowed) {
                    await prefs!.setBool('notifications', v);
                    setState(() => enabled = v);
                    await sync();
                  } else {
                    message(
                      kIsWeb
                          ? 'Bildirimler için mobil uygulamayı kullan.'
                          : 'Bildirim izni verilmedi. Telefon ayarlarından açabilirsin.',
                    );
                  }
                } catch (_) {
                  message('Bildirim izni alınamadı. Tekrar deneyin.');
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
      ),
    ),
    const SizedBox(height: 16),
    panel(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Widget nasıl eklenir?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Android: Ana ekrana basılı tut → Widget’lar → İyi ki. Kart, sıradaki özel günü gösterir. iOS: Ana ekranı düzenle → Widget ekle → İyi ki.',
          ),
        ],
      ),
    ),
    const SizedBox(height: 28),
    const Center(
      child: Text(
        'İyi ki · 1.9.7',
        style: TextStyle(fontSize: 11, color: Colors.black38),
      ),
    ),
  ];
}

class PersonEditor extends StatefulWidget {
  final Birthday? person;
  final DateTime? initialDate;
  const PersonEditor({super.key, this.person, this.initialDate});
  @override
  State<PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends State<PersonEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, year;
  String dayType = specialDayTypes.first;
  final customType = TextEditingController();
  final custom = TextEditingController();
  final phone = TextEditingController();
  String? contactName;
  late int day, month;
  late String category;
  String? photo;
  late Set<int> offsets;
  bool dailyEnabled = false;
  static const presets = [1, 3, 7, 14, 30];
  final customDays = <int>{};
  int dailyRange = 7;
  static const dailyPresets = [3, 7, 14];
  final customRanges = <int>{};
  bool? editingDaily;
  String? customError;
  bool visibleDay(int n) => !dailyEnabled || n > dailyRange;

  String get reminderSummary {
    final early = offsets.where(visibleDay).toList()
      ..sort((a, b) => b.compareTo(a));
    final parts = <String>[
      if (early.isNotEmpty) "${early.join(', ')} gün önce",
      if (dailyEnabled) 'son $dailyRange gün boyunca her sabah',
    ];
    if (parts.isEmpty) {
      return "Bildirimler açıksa özel gününde saat 00.00'da bildirim göndereceğiz.";
    }
    final when = parts.join(' ve ');
    return "${when[0].toUpperCase()}${when.substring(1)} 09.00'da hatırlatacağız. Özel gününde ise 00.00'da bildirim göndereceğiz.";
  }

  void setDayEditor(bool? group) {
    setState(() {
      editingDaily = group;
      customError = null;
      custom.clear();
    });
  }

  void addCustomDay(bool daily) {
    final n = int.tryParse(custom.text.trim());
    if (n == null || n < 1 || n > 365) {
      setState(() => customError = '1–365 arasında bir sayı yaz.');
      return;
    }
    setState(() {
      if (daily) {
        if (!dailyPresets.contains(n)) customRanges.add(n);
        dailyRange = n;
      } else {
        if (!presets.contains(n)) customDays.add(n);
        offsets.add(n);
      }
    });
    setDayEditor(null);
    if (!daily && !visibleDay(n)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu gün günlük hatırlatma aralığında. Seçimin saklandı.',
          ),
        ),
      );
    }
  }

  Widget dayOptions(bool daily) {
    final added = daily ? customRanges : customDays;
    final values = [
      ...(daily ? dailyPresets : presets),
      ...(added.toList()..sort()),
    ];
    return Column(
      key: ValueKey(daily ? 'daily-options' : 'single-options'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final n in values.where((n) => daily || visibleDay(n)))
              InputChip(
                label: Text('$n gün'),
                selected: daily ? dailyRange == n : offsets.contains(n),
                onSelected: (on) => setState(() {
                  if (daily) {
                    dailyRange = n;
                  } else if (on) {
                    offsets.add(n);
                  } else {
                    offsets.remove(n);
                  }
                }),
                onDeleted: !added.contains(n)
                    ? null
                    : () => setState(() {
                        added.remove(n);
                        if (!daily) {
                          offsets.remove(n);
                        } else if (dailyRange == n) {
                          dailyRange = 7;
                        }
                      }),
                deleteButtonTooltipMessage: '$n günü kaldır',
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Diğer'),
              onPressed: () =>
                  setDayEditor(editingDaily == daily ? null : daily),
            ),
          ],
        ),
        if (editingDaily == daily)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextField(
              key: ValueKey('input-$daily'),
              controller: custom,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => addCustomDay(daily),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Örn. 45 gün önce',
                errorText: customError,
                suffixIcon: IconButton(
                  tooltip: 'Gün sayısını onayla',
                  icon: const Icon(Icons.check),
                  onPressed: () => addCustomDay(daily),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    dayType = p?.type ?? specialDayTypes.first;
    customType.text = p?.customType ?? '';
    name = TextEditingController(
      text: p?.usesContactName == true ? '' : p?.name,
    );
    contactName = p?.contactName;
    phone.text = p?.phone ?? '';
    year = TextEditingController(text: p?.year?.toString());
    final initialDate = widget.initialDate ?? DateTime.now();
    day = p?.day ?? initialDate.day;
    month = p?.month ?? initialDate.month;
    category = p?.category ?? 'Arkadaşlar';
    photo = p?.photo;
    dailyEnabled = p?.dailyDays != null;
    dailyRange = p?.dailyDays ?? 7;
    customRanges.addAll(
      {
        ...?p?.customDailyRanges,
        dailyRange,
      }.where((n) => !dailyPresets.contains(n)),
    );
    customDays.addAll(
      {
        ...?p?.customReminderDays,
        ...?p?.reminders,
      }.where((n) => !presets.contains(n)),
    );
    offsets = {...?p?.reminders};
    if (p == null) offsets = {1, 7};
  }

  @override
  void dispose() {
    phone.dispose();
    name.dispose();
    year.dispose();
    customType.dispose();

    custom.dispose();
    super.dispose();
  }

  Future<void> pickContact() async {
    try {
      final contact = await FlutterNativeContactPicker().selectPhoneNumber();
      if (!mounted || contact == null) return;
      setState(() {
        contactName = contact.fullName?.trim();
        phone.text =
            contact.selectedPhoneNumber ??
            contact.phoneNumbers?.firstOrNull ??
            '';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rehber açılamadı. Adı ve numarayı elle girebilirsin.',
            ),
          ),
        );
      }
    }
  }

  Future<void> pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => photo = base64Encode(bytes));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf seçilemedi. Lütfen tekrar dene.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      20,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.person == null ? 'Tarih ekle' : 'Özel günü düzenle',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFEAE3F5),
                  backgroundImage: photo == null
                      ? null
                      : MemoryImage(base64Decode(photo!)),
                  child: photo == null
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                TextButton(
                  onPressed: pickPhoto,
                  child: const Text('Fotoğraf ekle'),
                ),
                if (photo != null)
                  IconButton(
                    tooltip: 'Fotoğrafı kaldır',
                    onPressed: () => setState(() => photo = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!kIsWeb &&
                [
                  TargetPlatform.android,
                  TargetPlatform.iOS,
                ].contains(defaultTargetPlatform))
              OutlinedButton.icon(
                onPressed: pickContact,
                icon: const Icon(Icons.contacts_outlined),
                label: Text(
                  contactName == null
                      ? 'Rehberden kişi seç'
                      : 'Kişiyi değiştir',
                ),
              ),
            if (contactName?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Rehberdeki ad: $contactName'),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: contactName?.isNotEmpty == true
                    ? 'Görünen ad (isteğe bağlı)'
                    : 'Adı',
                hintText: contactName,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty && (contactName ?? '').isEmpty
                  ? 'Rehberden bir kişi seç veya adını yaz.'
                  : null,
            ),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon (isteğe bağlı)',
                helperText: 'Türkiye dışındaki numaraları ülke koduyla yaz.',
              ),
              validator: (v) =>
                  (v ?? '').trim().isNotEmpty && internationalPhone(v!).isEmpty
                  ? 'Geçerli bir telefon numarası yaz.'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: day,
                    key: ValueKey('day-$month-$day'),
                    decoration: const InputDecoration(labelText: 'Gün'),
                    items: List.generate(
                      DateTime(2000, month + 1, 0).day,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => day = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'Ay'),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(
                          DateFormat(
                            'MMMM',
                            'tr',
                          ).format(DateTime(2000, i + 1)),
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() {
                      month = v!;
                      day = day.clamp(1, DateTime(2000, month + 1, 0).day);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: dayType,
              decoration: const InputDecoration(labelText: 'Özel gün tipi'),
              items: specialDayTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (t) => setState(() => dayType = t!),
            ),
            if (dayType == 'Diğer') const SizedBox(height: 16),
            if (dayType == 'Diğer')
              TextFormField(
                controller: customType,
                decoration: const InputDecoration(labelText: 'Özel günün adı'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Özel günün adını yaz.' : null,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: dayType == 'Doğum Günü'
                    ? 'Doğum yılı (isteğe bağlı)'
                    : 'Yıl (isteğe bağlı)',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final y = int.tryParse(v);
                if (y == null || y < 1900 || y > DateTime.now().year) {
                  return 'Geçerli bir yıl yaz.';
                }
                final date = DateTime(y, month, day);
                if (date.month != month || date.day != day) {
                  return 'Bu yılda seçilen gün yok.';
                }
                return date.isAfter(DateTime.now())
                    ? 'Tarih gelecekte olamaz.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            Text(
              dailyEnabled
                  ? 'Daha erken hatırlatmalar'
                  : 'Özel günden kaç gün önce hatırlatalım?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Text('Bir veya birden fazla gün seçebilirsin.'),
            dayOptions(false),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Son günlerde her gün hatırlat'),
              subtitle: const Text(
                'Özel gün yaklaşırken her sabah hatırlatalım.',
              ),
              value: dailyEnabled,
              onChanged: (v) {
                setDayEditor(null);
                setState(() => dailyEnabled = v);
              },
            ),
            if (dailyEnabled) ...[
              const Text('Kaç gün önceden başlayalım?'),
              dayOptions(true),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFE8F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(reminderSummary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                ),
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      Birthday(
                        id:
                            widget.person?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        name: name.text.trim().isEmpty
                            ? contactName!
                            : name.text.trim(),
                        contactName: contactName,
                        usesContactName: name.text.trim().isEmpty,
                        phone: internationalPhone(phone.text),
                        day: day,
                        month: month,
                        year: int.tryParse(year.text),
                        type: dayType,
                        customType: dayType == 'Diğer'
                            ? customType.text.trim()
                            : '',
                        category: category,
                        dailyDays: dailyEnabled ? dailyRange : null,
                        customDailyRanges: customRanges.toList()..sort(),
                        customReminderDays: customDays.toList()..sort(),
                        reminders: offsets.toList()..sort(),
                        photo: photo,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
