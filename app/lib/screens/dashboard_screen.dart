import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'members_screen.dart';

const healthLevels = {
  'excelente': 'Excelente',
  'boa': 'Boa',
  'atencao': 'Atenção',
  'critica': 'Crítica',
  'sem_dados': 'Sem dados',
};

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Olá, ${state.me?.name.split(' ').first ?? ''}'),
            if (state.me?.familyName != null)
              Text(state.me!.familyName!, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Família',
            icon: const Icon(Icons.family_restroom),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembersScreen())),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (await confirm(context, 'Deseja sair da sua conta?')) state.logout();
            },
          ),
        ],
      ),
      body: AsyncView<Map<String, dynamic>>(
        load: (s) async => await s.api.get('/reports/dashboard', {'month': s.month}) as Map<String, dynamic>,
        builder: (context, data, _) => _DashboardBody(data: data),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>;
    final health = data['health'] as Map<String, dynamic>;
    final byCategory = (summary['expense_by_category'] as List);
    final byMember = (summary['by_member'] as List);
    final budgets = (summary['budgets'] as List);
    final byAccountType = (summary['expense_by_account_type'] as List);
    final figures = health['figures'] as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        const Center(child: MonthSelector()),
        _BalanceCard(summary: summary, netWorth: toDouble(figures['net_worth'])),
        const SizedBox(height: 16),
        _HealthTile(health: health),
        const SizedBox(height: 16),
        SectionCard(title: 'Ganhos x gastos', child: CashflowChart(data: data['cashflow'] as List)),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Gastos por pessoa',
          child: byMember.isEmpty
              ? const Text('Nenhum membro')
              : Column(children: [for (final m in byMember) _MemberRow(member: m, total: toDouble(summary['expense']))]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Gastos por categoria',
          child: byCategory.isEmpty
              ? const EmptyState(icon: Icons.pie_chart_outline, message: 'Nenhuma despesa neste mês')
              : DonutChart(
                  slices: [
                    for (var i = 0; i < byCategory.length; i++)
                      DonutSlice(
                        byCategory[i]['name'],
                        toDouble(byCategory[i]['total']),
                        hexColor(byCategory[i]['color'], FFColors.chart[i % FFColors.chart.length]),
                      ),
                  ],
                  center: Text(moneyCompact(toDouble(summary['expense'])), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
        ),
        if (byAccountType.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(title: 'Como a família pagou', child: _PaymentSplit(items: byAccountType)),
        ],
        if (budgets.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Orçamentos do mês',
            child: Column(children: [for (final b in budgets) _BudgetRow(budget: b)]),
          ),
        ],
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.netWorth});

  final Map<String, dynamic> summary;
  final double netWorth;

  @override
  Widget build(BuildContext context) {
    final income = toDouble(summary['income']);
    final expense = toDouble(summary['expense']);
    final balance = toDouble(summary['balance']);
    final prevExpense = toDouble(summary['previous']['expense']);
    final expenseDelta = prevExpense > 0 ? (expense - prevExpense) / prevExpense : null;
    const white70 = TextStyle(color: Colors.white70, fontSize: 13);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: FFColors.brandGradient, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sobrou no mês', style: white70),
          const SizedBox(height: 4),
          Text(money(balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          Text('Taxa de poupança: ${percent(toDouble(summary['savings_rate']))}', style: white70),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Figure(icon: Icons.arrow_downward, label: 'Ganhos', value: income)),
              Expanded(child: _Figure(icon: Icons.arrow_upward, label: 'Gastos', value: expense)),
            ],
          ),
          const Divider(color: Colors.white24, height: 28),
          Row(
            children: [
              const Icon(Icons.account_balance, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text('Patrimônio: ${money(netWorth)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (expenseDelta != null)
                Text(
                  '${expenseDelta > 0 ? '▲' : '▼'} ${percent(expenseDelta.abs())} gastos',
                  style: white70,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              FittedBox(child: Text(money(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({required this.health});

  final Map<String, dynamic> health;

  @override
  Widget build(BuildContext context) {
    final score = health['score'] as int?;
    final recs = health['recommendations'] as List;
    return SectionCard(
      child: Row(
        children: [
          ScoreGauge(score: score, size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saúde financeira: ${healthLevels[health['level']] ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ScoreGauge.colorFor(score))),
                const SizedBox(height: 4),
                if (recs.isNotEmpty) Text(recs.first['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                if (recs.isNotEmpty)
                  Text(recs.first['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.total});

  final Map<String, dynamic> member;
  final double total;

  @override
  Widget build(BuildContext context) {
    final expense = toDouble(member['expense']);
    final income = toDouble(member['income']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MemberAvatar(name: member['name'], color: member['color']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(money(expense), style: const TextStyle(fontWeight: FontWeight.w700, color: FFColors.expense)),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressBar(value: total > 0 ? expense / total : 0, color: hexColor(member['color'])),
                const SizedBox(height: 4),
                Text(
                  'Ganhou ${money(income)} · ${percent(toDouble(member['expense_share']))} dos gastos',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSplit extends StatelessWidget {
  const _PaymentSplit({required this.items});

  final List items;

  static const labels = {
    'checking': 'Conta corrente (débito/PIX)',
    'credit_card': 'Cartão de crédito',
    'savings': 'Poupança',
    'cash': 'Dinheiro',
    'investment': 'Investimentos',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(i['account_type'] == 'credit_card' ? Icons.credit_card : Icons.account_balance, size: 18, color: i['account_type'] == 'credit_card' ? FFColors.blue : FFColors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(labels[i['account_type']] ?? i['account_type'])),
                    Text(money(toDouble(i['expense'])), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressBar(value: toDouble(i['share']), color: i['account_type'] == 'credit_card' ? FFColors.blue : FFColors.green),
              ],
            ),
          ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final Map<String, dynamic> budget;

  @override
  Widget build(BuildContext context) {
    final usage = toDouble(budget['usage']);
    final remaining = toDouble(budget['remaining']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(budget['icon']), size: 18, color: hexColor(budget['color'])),
              const SizedBox(width: 8),
              Expanded(child: Text(budget['category_name'])),
              Text('${money(toDouble(budget['spent']))} / ${money(toDouble(budget['budget']))}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ProgressBar(value: usage),
          const SizedBox(height: 2),
          Text(
            remaining >= 0 ? 'Restam ${money(remaining)}' : 'Estourou em ${money(-remaining)}',
            style: TextStyle(fontSize: 12, color: remaining >= 0 ? Theme.of(context).hintColor : FFColors.danger),
          ),
        ],
      ),
    );
  }
}
