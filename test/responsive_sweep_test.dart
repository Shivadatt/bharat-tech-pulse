import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:india_tech_web/app/app.dart';
import 'package:india_tech_web/app/bindings/initial_binding.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout sweep: boots the real app across the mandated responsive viewport
/// matrix and walks every public route, failing on anything the framework
/// reports while laying out or painting (RenderFlex overflow, unbounded-width
/// assertions, bad constraints).
///
/// This is the headless half of responsive verification: a browser is not
/// required, and the errors it catches are the ones a `flutter build web`
/// release bundle no longer prints.
///
/// Coverage beyond the original 4-width / portrait-only pass:
///   * portrait: 16 mandated viewport widths x the public route list;
///   * landscape: 5 short-viewport sizes (height < width) that also introduce
///     widths (640/740/844/932) absent from the portrait set;
///   * text scale: the accessibility zoom pass (1.25x and 2.0x) at the widths
///     where a scale is likeliest to break a fixed row (1024, 768, 390, 320).
///
/// Caveat the reader must carry: flutter_test's default font uses square
/// advance widths, so a real Inter string is measurably narrower than what the
/// sweep lays out. The pass therefore catches GROSS and UNBOUNDED layout
/// violations (a Row with no Flexible, an unbounded-width container, a fixed
/// SizedBox wider than the slot), not pixel-tight text overflow. A handful of
/// narrow-width cases that only trip because the test font is artificially
/// wide are expected noise, not production bugs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mandated viewport matrix, portrait (height > width). devicePixelRatio is
  // forced to 1.0 so physicalSize is the logical size the app lays out against.
  const portrait = <String, Size>{
    '1920': Size(1920, 1080),
    '1600': Size(1600, 900),
    '1440': Size(1440, 900),
    '1366': Size(1366, 768),
    '1280': Size(1280, 800),
    '1024': Size(1024, 768),
    '900': Size(900, 1200),
    '800': Size(800, 1280),
    '768': Size(768, 1024),
    '650': Size(650, 1024),
    '430': Size(430, 932),
    '425': Size(425, 760),
    '390': Size(390, 844),
    '375': Size(375, 812),
    '360': Size(360, 800),
    '320': Size(320, 568),
  };

  // Landscape: height < width. Rotating a phone/tablet is not just a mirror —
  // it collapses the vertical budget while landing in a different width bucket,
  // and 640/740/844/932 are widths the portrait set never visits.
  const landscape = <String, Size>{
    '640x360': Size(640, 360),
    '740x360': Size(740, 360),
    '844x390': Size(844, 390),
    '932x430': Size(932, 430),
    '1180x820': Size(1180, 820),
  };

  // Accessibility-zoom pass: only at the widths where a scaled fixed row is
  // likeliest to break. Media queries and the app's own breakpoints are width
  // driven, so the width buckets that matter (1024 desktop boundary, 768 tablet,
  // 390/320 small phone) are covered here.
  const textScaleWidths = <String, Size>{
    '1024': Size(1024, 768),
    '768': Size(768, 1024),
    '390': Size(390, 844),
    '320': Size(320, 568),
  };
  const textScales = <double>[1.25, 2.0];

  // Public routes only — `/admin/login` and every other admin path are out of
  // the QA sweep's scope. Article/author slugs and the author handle are real
  // values taken from `MockDataSource` so the views resolve real content (and
  // the longest article title exercises the breadcrumb / H1 wrapping path).
  const routes = <String>[
    '/',
    '/ai/',
    '/apps/',
    '/smartphones/',
    '/how-to/',
    '/tech-news/',
    '/comparisons/',
    '/cyber-safety/',
    '/buying-guides/',
    '/article/digital-arrest-scam-how-to-protect-yourself-and-report-1930',
    '/author/priya-nambiar',
    '/search',
    '/about',
    '/contact',
    '/editorial-policy',
    '/privacy-policy',
    '/terms',
    '/disclaimer',
    '/404',
    // Not a registered GetPage: exercises the GetMaterialApp.unknownRoute
    // redirect into the NotFoundView shell.
    '/this-route-does-not-exist',
  ];

  /// Boots the app at [size] (optionally with an accessibility [textScale]),
  /// navigates to [route], advances the fake clock past the mock repositories'
  /// delayed futures, and fails on any layout/paint exception the framework
  /// reports. Reused verbatim by all three passes so behaviour stays identical
  /// to the original 80-case sweep.
  Future<void> sweep(
    WidgetTester tester,
    Size size,
    String route, {
    double? textScale,
    required String label,
  }) async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    InitialBinding().dependencies();

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    if (textScale != null) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      // Only the zoom factor may be cleared: `clearAllTestValues` also replays
      // `didChangeLocales`, which asserts inside GetX's root controller during
      // teardown and failed every scaled case.
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    await tester.pumpWidget(const BharatTechApp());
    await tester.pump(const Duration(milliseconds: 400));

    Get.toNamed(route);
    // Fixed pumps advance the fake clock, so the repositories' delayed mock
    // futures resolve, without pumpAndSettle blocking on a route that keeps an
    // animation alive (the home hero and skeleton shimmers repeat forever).
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    final reported = <String>[];
    while (true) {
      final problem = tester.takeException();
      if (problem == null) break;
      reported.add(problem.toString());
    }
    if (reported.isNotEmpty) {
      fail('$label $route @ ${size.width.toInt()}x${size.height.toInt()} '
          'reported:\n  ${reported.join('\n  ')}\n'
          'overlapping flexes:\n${_overflowingFlexes(tester)}');
    }

    // The shell must actually have painted content, not a blank frame.
    expect(find.byType(Scaffold), findsWidgets);
  }

  group('portrait', () {
    for (final width in portrait.entries) {
      for (final route in routes) {
        testWidgets('layout $route at ${width.key}px', (tester) async {
          await sweep(tester, width.value, route, label: 'portrait');
        });
      }
    }
  });

  group('landscape', () {
    for (final size in landscape.entries) {
      for (final route in routes) {
        testWidgets('landscape $route at ${size.key}', (tester) async {
          await sweep(tester, size.value, route, label: 'landscape');
        });
      }
    }
  });

  group('text scale', () {
    for (final scale in textScales) {
      for (final width in textScaleWidths.entries) {
        for (final route in routes) {
          testWidgets('scale ${scale}x $route at ${width.key}px', (tester) async {
            await sweep(tester, width.value, route, textScale: scale, label: 'scale');
          });
        }
      }
    }
  });
}

/// Names every Row/Column whose children no longer fit, quoting the child
/// widgets so the offending line of source is recognizable. Only runs on a
/// failing case: walking the element tree is not cheap.
String _overflowingFlexes(WidgetTester tester) {
  final found = <String>[];
  for (final type in <Type>[Row, Column]) {
    final finder = find.byType(type, skipOffstage: false);
    final widgets = tester.widgetList(finder).toList();
    final renders = tester.renderObjectList<RenderObject>(finder).toList();
    if (widgets.length != renders.length) continue;
    for (var i = 0; i < widgets.length; i++) {
      final ro = renders[i];
      if (ro is! RenderFlex) continue;
      final horizontal = ro.direction == Axis.horizontal;
      var sum = 0.0;
      ro.visitChildren((child) {
        if (child is! RenderBox) return;
        sum += horizontal ? child.size.width : child.size.height;
      });
      final extent = horizontal ? ro.size.width : ro.size.height;
      if (sum <= extent + 0.5) continue;
      final flex = widgets[i] as dynamic;
      final kids = (flex.children as List<Widget>)
          .map((w) => w.toString().split('\n').first)
          .take(6)
          .join(', ');
      found.add('  $type needs ${sum.toStringAsFixed(1)} in ${extent.toStringAsFixed(1)} '
          '(constraints=${ro.constraints}) children: $kids');
    }
  }
  return found.isEmpty ? '  (no oversized flex found after layout)' : found.join('\n');
}
