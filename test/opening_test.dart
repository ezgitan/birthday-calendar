import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birthday_calendar/opening.dart';

void main() {
  testWidgets('Android window stays lilac until entry completes', (
    tester,
  ) async {
    final entered = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LaunchSurface.channel, (
      MethodCall call,
    ) async {
      expect(call.method, 'waitForEntry');
      await entered.future;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(LaunchSurface.channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LaunchSurface(
          child: OpeningAnimation(
            ready: true,
            onComplete: () {},
            child: const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('splash-brand')), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == splashColor),
      findsOneWidget,
    );
    entered.complete();
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('Blowing animation retains its artwork and fixed position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: OpeningAnimation(
          ready: true,
          onComplete: () {},
          child: const Scaffold(),
        ),
      ),
    );
    final brand = find.byKey(const ValueKey('splash-brand'));
    final bounds = tester.getRect(brand);
    await tester.pump(const Duration(milliseconds: 950));
    expect(tester.getRect(brand), bounds);
    await expectLater(
      find.byType(OpeningAnimation),
      matchesGoldenFile('goldens/splash_blow.png'),
    );
    await tester.pump(const Duration(milliseconds: 240));
    expect(tester.getRect(brand), bounds);
    await expectLater(
      find.byType(OpeningAnimation),
      matchesGoldenFile('goldens/splash.png'),
    );
    await tester.pumpAndSettle();
    expect(brand, findsNothing);
  });
  testWidgets('Animation waits for loading and plays only once', (
    tester,
  ) async {
    var ready = false;
    var completed = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return OpeningAnimation(
              ready: ready,
              onComplete: () => completed++,
              child: const Scaffold(body: Text('Home')),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(completed, 0);
    update(() => ready = true);
    await tester.pumpAndSettle();
    expect(completed, 1);
    update(() {});
    await tester.pumpAndSettle();
    expect(completed, 1);
  });
}
