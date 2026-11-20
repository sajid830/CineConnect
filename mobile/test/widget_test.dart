import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineconnect/app/app.dart';

void main() {
  testWidgets('CineConnect Talent Portal smoke test', (WidgetTester tester) async {
    // Set a realistic mobile screen size for testing
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build CineConnect Talent Portal and trigger a frame
    await tester.pumpWidget(const CineConnectApp());
    await tester.pumpAndSettle();

    // Verify CineConnect title is present
    expect(find.text('CineConnect'), findsWidgets);

    // Verify TALENT badge is present
    expect(find.text('TALENT'), findsOneWidget);

    // Story status is shown on the Home page
    expect(find.text('Your Story'), findsOneWidget);

    // Preview sub-bar is removed
    expect(find.text('PREVIEW'), findsNothing);
    expect(find.text('Switch to Production'), findsNothing);
    expect(find.text('✕ Exit'), findsNothing);

    // Verify Top-Right Header actions: Notifications and Chat
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);

    // Verify Bottom Navigation Bar options: Home, Opportunities, Create, Search, Profile
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Opportunities'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Instagram-style flows open correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CineConnectApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Opportunities'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested for You'), findsOneWidget);
    expect(find.textContaining('Application Status'), findsOneWidget);
    expect(find.text('Your Story'), findsNothing);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('New reel'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('@mayaray_dop'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Settings and privacy'), findsOneWidget);
    expect(find.text('Your activity'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('@mayaray_dop'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
  });
}
