// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:gerador_qr/main.dart';

void main() {
  testWidgets('Renderiza o gerador QR e navega para o historico', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Gerador QR'), findsAtLeastNWidgets(1));
    expect(find.text('Codigo de identificacao'), findsOneWidget);
    expect(find.text('ATALHOS RAPIDOS'), findsOneWidget);

    await tester.tap(find.text('Historico'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum codigo salvo ainda'), findsOneWidget);
  });
}
