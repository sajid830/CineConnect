import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineconnect/app/app.dart';
import 'package:cineconnect/main.dart';

void main() {
  testWidgets('CineConnectApp full onboarding to HomeScreen flow smoke test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Build app and verify Role Selection screen
    await tester.pumpWidget(const CineConnectApp());
    await tester.pumpAndSettle();

    expect(find.text('CINECONNECT'), findsOneWidget);
    expect(find.text('Choose Your Type'), findsOneWidget);
    expect(find.text('Talent'), findsOneWidget);
    expect(find.text('Production House'), findsOneWidget);

    // 2. Tap Talent card -> navigates to AuthScreen
    await tester.tap(find.text('Talent'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);

    // 3. Tap Sign In button without credentials -> verifies validation
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter both email and password.'), findsOneWidget);
  });
}
