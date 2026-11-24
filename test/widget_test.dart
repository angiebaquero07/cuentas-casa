import 'package:flutter_test/flutter_test.dart';
import 'package:cuentas_casa/main.dart';

void main() {
  testWidgets('Carga inicial de la app', (WidgetTester tester) async {
    await tester.pumpWidget(const CuentasCasaApp());
    expect(find.text('Mis Cuentas & Deudas'), findsOneWidget);
  });
}
