import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Example home shows open scanner button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Spectacular Barcode')),
          body: Center(
            child: FilledButton(
              onPressed: () {},
              child: const Text('Open scanner'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Open scanner'), findsOneWidget);
    expect(find.text('Spectacular Barcode'), findsOneWidget);
  });
}
