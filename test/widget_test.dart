import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_live/shared/widgets/status_chip.dart';

void main() {
  testWidgets('status chip renders label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(label: 'LIVE STARTED', color: Colors.redAccent),
        ),
      ),
    );

    expect(find.text('LIVE STARTED'), findsOneWidget);
  });
}
