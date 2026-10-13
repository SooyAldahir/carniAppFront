import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carniapp/main.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla de salud', (tester) async {
    await tester.pumpWidget(const CarniApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
