import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/app/navigation/campus_destination.dart';
import 'package:campusfix/main.dart';

void main() {
  testWidgets('Desktop navigation opens all pending module previews', (
    tester,
  ) async {
    await _mountPrototype(tester, const Size(1440, 900));

    expect(find.text('CampusFix'), findsOneWidget);
    expect(find.byTooltip('Abrir menú'), findsNothing);

    for (final destination in CampusDestination.values.skip(1)) {
      await tester.tap(find.byKey(ValueKey('nav-${destination.name}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('preview-${destination.name}')),
        findsOneWidget,
      );
      expect(find.text('Funcionalidad pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byKey(const ValueKey('nav-overview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
  });

  testWidgets('Portrait tablet uses its drawer and closes it on selection', (
    tester,
  ) async {
    await _mountPrototype(tester, const Size(768, 1024));

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('preview-profile')), findsOneWidget);
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isFalse);

    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Builds the visual prototype without initializing or contacting Firebase.
Future<void> _mountPrototype(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}
