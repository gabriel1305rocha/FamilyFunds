import 'package:flutter/material.dart';

import 'accounts_screen.dart';
import 'dashboard_screen.dart';
import 'health_screen.dart';
import 'investments_screen.dart';
import 'transaction_form.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    TransactionsScreen(),
    AccountsScreen(),
    HealthScreen(),
    InvestmentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: _index <= 2
          ? FloatingActionButton.extended(
              onPressed: () => showTransactionForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Lançamento'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Lançamentos'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Contas'),
          NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: 'Saúde'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Investir'),
        ],
      ),
    );
  }
}
