import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineconnect/app/app.dart';

void main() {
  testWidgets('CineConnectApp foundation smoke test', (WidgetTester tester) async {
    // Set a realistic mobile screen size for testing
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(const CineConnectApp());
    await tester.pumpAndSettle();

    // Verify CineConnect title is present.
    expect(find.text('CineConnect'), findsWidgets);

    // Verify Foundation Initialized card is displayed.
    expect(find.text('Foundation Initialized'), findsOneWidget);

    // Verify Core Technology Stack section is rendered.
    expect(find.text('Core Technology Stack'), findsOneWidget);

    // Verify Diagnostics button is present.
    expect(find.text('Test Backend Connectivity'), findsOneWidget);
  });
}
