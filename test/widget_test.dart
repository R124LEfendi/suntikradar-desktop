import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic material surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Admin Console')),
      ),
    );

    expect(find.text('Admin Console'), findsOneWidget);
  });
}
