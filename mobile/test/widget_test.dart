import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
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

    // 3. Tap Sign In button -> navigates to HomeScreen for Talent
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    // Verify HomeScreen contents for Talent
    expect(find.text('Welcome back, Actor!'), findsOneWidget);
    expect(find.text('Upload Reel'), findsOneWidget);
    expect(find.text('Find Auditions'), findsOneWidget);
    expect(find.text('Recent Applications'), findsOneWidget);

    // Verify BottomNavigationBar items
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Tap on Search tab
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Search Module (AI/ML)'), findsOneWidget);
  });
}
