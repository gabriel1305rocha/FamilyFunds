import 'package:family_funds/screens/login_screen.dart';
import 'package:family_funds/services/api.dart';
import 'package:family_funds/state/app_state.dart';
import 'package:family_funds/theme.dart';
import 'package:family_funds/utils/format.dart';
import 'package:family_funds/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

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

  test('normalizeApiUrl completa o endereço digitado', () {
    expect(normalizeApiUrl('192.168.0.10:3000'), 'http://192.168.0.10:3000/api');
    expect(normalizeApiUrl('https://financas.casa.com/'), 'https://financas.casa.com/api');
    expect(normalizeApiUrl(' http://10.0.0.5:3000/api '), 'http://10.0.0.5:3000/api');
  });

  testWidgets('tela de login alterna para cadastro e mostra o servidor', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(ApiClient(baseUrl: 'http://192.168.0.10:3000/api')),
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const LoginScreen()),
      ),
    );
    expect(find.text('Servidor: http://192.168.0.10:3000/api'), findsOneWidget);
    expect(find.text('Family Funds'), findsOneWidget);
    expect(find.text('Nome da família'), findsNothing);
    await tester.tap(find.text('Criar uma conta para a família'));
    await tester.pump();
    expect(find.text('Nome da família'), findsOneWidget);
  });
}
