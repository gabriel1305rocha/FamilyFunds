import 'package:family_funds/screens/login_screen.dart';
import 'package:family_funds/theme.dart';
import 'package:family_funds/utils/format.dart';
import 'package:family_funds/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('parseMoney aceita formato brasileiro e com ponto', () {
    expect(parseMoney('1.234,56'), 1234.56);
    expect(parseMoney('R\$ 89,90'), 89.9);
    expect(parseMoney('1500.5'), 1500.5);
    expect(parseMoney('abc'), isNull);
  });

  test('formatação de moeda e meses em pt_BR', () {
    expect(money(1234.5).replaceAll(' ', ' '), 'R\$ 1.234,50');
    expect(monthLabel('2026-03'), 'Março 2026');
    expect(monthShort('2026-10'), 'Out');
  });

  test('conversão de cores hex', () {
    expect(colorHex(hexColor('#00A86B')), '#00A86B');
    expect(hexColor(null), FFColors.green);
  });

  testWidgets('tela de login alterna para cadastro', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const LoginScreen()));
    expect(find.text('Family Funds'), findsOneWidget);
    expect(find.text('Nome da família'), findsNothing);
    await tester.tap(find.text('Criar uma conta para a família'));
    await tester.pump();
    expect(find.text('Nome da família'), findsOneWidget);
  });
}
