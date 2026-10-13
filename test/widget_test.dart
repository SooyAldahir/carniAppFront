import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carniapp/main.dart';

void main() {
  testWidgets('La app arranca mostrando el indicador de sesion', (tester) async {
    await tester.pumpWidget(const CarniApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
