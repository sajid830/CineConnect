import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/shared/widgets/status_pill.dart';

void main() {
  testWidgets('EmptyState shows message and runs its action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyState(
          message: 'Nothing here',
          actionLabel: 'Create',
          onAction: () => tapped = true,
        ),
      ),
    ));
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Create'));
    expect(tapped, isTrue);
  });

  testWidgets('StatusPill shows its label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatusPill(label: 'Open', color: Color(0xFFD4AF37)),
      ),
    ));
    expect(find.text('Open'), findsOneWidget);
  });

  test('formatDate gives day, short month, year', () {
    expect(formatDate(DateTime(2027, 1, 15)), '15 Jan 2027');
  });
}
