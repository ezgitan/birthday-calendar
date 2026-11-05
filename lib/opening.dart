import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'cake_path.dart';
import 'splash_word_path.dart';

const splashColor = Color(0xFFF4EDFA);

/// The first Flutter frame is plain lilac, so Android can use it while
/// expanding the app window without taking a snapshot of the animated cake.
class LaunchSurface extends StatefulWidget {
  const LaunchSurface({super.key, required this.child});
  final Widget child;
  static const channel = MethodChannel('iyiki/launch');
  static bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> signal(String method) async {
    if (!android) return;
    try {
      await channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Widget tests and older embedders do not have this channel.
    } on PlatformException {
      // Platform transitions must never block access to the calendar.
    }
  }

  @override
  State<LaunchSurface> createState() => _LaunchSurfaceState();
}

class _LaunchSurfaceState extends State<LaunchSurface> {
  late bool entered = !LaunchSurface.android;
  @override
  void initState() {
    super.initState();
    if (!entered) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await LaunchSurface.signal('waitForEntry');
        if (mounted) setState(() => entered = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => entered
      ? widget.child
      : const ColoredBox(color: splashColor, child: SizedBox.expand());
}

class OpeningAnimation extends StatefulWidget {
  const OpeningAnimation({
    super.key,
    required this.child,
    required this.ready,
    required this.onComplete,
  });
  final Widget child;
  final bool ready;
  final VoidCallback onComplete;
  @override
  State<OpeningAnimation> createState() => _OpeningAnimationState();
}

class _OpeningAnimationState extends State<OpeningAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool finished = false;
  bool reduced = false;
  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1800),
          )
          ..addListener(() {
            if (!widget.ready && controller.value >= 2 / 3) {
              controller.stop();
              if (controller.value > 2 / 3) controller.value = 2 / 3;
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && !finished) {
              setState(() => finished = true);
              widget.onComplete();
            }
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (!finished && !controller.isAnimating) {
      if (reduced && widget.ready) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.value = 1;
        });
      } else if (!reduced && controller.value == 0) {
        controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(OpeningAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready && !finished) {
      if (reduced) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.value = 1;
        });
      } else if (!controller.isAnimating) {
        controller.forward();
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  double phase(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);
  @override
  Widget build(BuildContext context) {
    if (finished) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(child: IgnorePointer(child: widget.child)),
        AnimatedBuilder(
          animation: controller,
          builder: (_, _) {
            final t = controller.value * 1.8;
            final exit = widget.ready
                ? Curves.easeInOut.transform(phase(t, 1.2, 1.8))
                : 0.0;
            final blow = reduced ? 0.0 : phase(t, .8, 1.2);
            final glow = reduced
                ? 0.0
                : math.sin(phase(t, .3, 1.2) * math.pi) * (1 - blow);
            return Opacity(
              opacity: 1 - exit,
              child: ColoredBox(
                color: splashColor,
                child: Center(
                  child: Semantics(
                    label: 'İyi ki',
                    image: true,
                    child: CustomPaint(
                      key: const ValueKey('splash-brand'),
                      size: const Size(192, 192),
                      painter: SplashBrandPainter(glow, blow),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class SplashBrandPainter extends CustomPainter {
  SplashBrandPainter(this.glow, this.blow);
  final double glow, blow;
  static final Path silhouette = cakePath();
  static final Path word = splashWordPath();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 192, size.height / 192);
    canvas.drawPath(word, Paint()..color = const Color(0xFF8061A8));
    canvas.translate(40, 8);
    canvas.scale(112 / 340);
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 120, 340, 370));
    canvas.drawPath(silhouette, Paint()..color = const Color(0xFF8061A8));
    canvas.restore();
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 340, 120));
    canvas.drawPath(
      silhouette,
      Paint()..color = Color.fromRGBO(128, 97, 168, 1 - .65 * blow),
    );
    canvas.restore();
    const center = Offset(170, 65);
    if (glow > 0) {
      canvas.drawCircle(
        center,
        45,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 220, 162, glow * .65),
              const Color(0x00FFDAA2),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 45)),
      );
    }
    if (blow > 0 && blow < 1) {
      final opacity = math.sin(blow * math.pi);
      final air = Paint()
        ..color = Color.fromRGBO(156, 134, 182, opacity * .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 2; i++) {
        final y = 64.0 + i * 15;
        canvas.drawPath(
          Path()
            ..moveTo(65 + blow * 30, y)
            ..quadraticBezierTo(103 + blow * 30, y - 9, 139 + blow * 18, y - 3),
          air,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(170, 55 - blow * 16)
          ..cubicTo(
            185,
            40 - blow * 25,
            156,
            28 - blow * 25,
            177 + blow * 20,
            9 - blow * 15,
          ),
        air..color = Color.fromRGBO(156, 134, 182, opacity * .65),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashBrandPainter oldDelegate) =>
      glow != oldDelegate.glow || blow != oldDelegate.blow;
}
