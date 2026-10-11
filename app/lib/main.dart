import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final state = AppState(ApiClient());
  runApp(ChangeNotifierProvider.value(value: state, child: const FamilyFundsApp()));
  state.bootstrap();
}

class FamilyFundsApp extends StatelessWidget {
  const FamilyFundsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Funds',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) return const SplashScreen();
    return state.loggedIn ? const HomeShell() : const LoginScreen();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: FFColors.brandGradient),
        child: Center(child: FFLogo(size: 72, light: true)),
      ),
    );
  }
}

class FFLogo extends StatelessWidget {
  const FFLogo({super.key, this.size = 48, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : FFColors.navy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: light ? null : FFColors.brandGradient,
            color: light ? Colors.white.withValues(alpha: 0.2) : null,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(Icons.family_restroom, color: Colors.white, size: size * 0.6),
        ),
        SizedBox(height: size * 0.2),
        Text('Family Funds', style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
