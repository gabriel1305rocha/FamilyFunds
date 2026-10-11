import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart' show healthLevels;

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saúde financeira')),
      body: AsyncView<List<dynamic>>(
        load: (s) => Future.wait([
          s.api.get('/reports/health', {'month': s.month}),
          s.api.get('/reports/summary', {'month': s.month}),
        ]),
        builder: (context, data, _) => _HealthBody(health: data[0], summary: data[1]),
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.health, required this.summary});

  final Map<String, dynamic> health;
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final score = health['score'] as int?;
    final figures = health['figures'] as Map<String, dynamic>;
    final indicators = health['indicators'] as List;
    final recs = health['recommendations'] as List;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const Center(child: MonthSelector()),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: FFColors.brandGradient, borderRadius: BorderRadius.circular(24)),
          child: Row(
            children: [
              ScoreGauge(score: score, size: 110, light: true),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(healthLevels[health['level']] ?? '', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Renda média: ${money(toDouble(figures['avg_income']))}', style: const TextStyle(color: Colors.white)),
                    Text('Gasto médio: ${money(toDouble(figures['avg_expense']))}', style: const TextStyle(color: Colors.white)),
                    Text('Patrimônio: ${money(toDouble(figures['net_worth']))}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Indicadores',
          child: Column(children: [for (final i in indicators) _IndicatorRow(indicator: i)]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Recomendações',
          child: Column(children: [for (final r in recs) _RecommendationTile(rec: r)]),
        ),
        const SizedBox(height: 16),
        _BudgetsCard(summary: summary),
      ],
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({required this.indicator});

  final Map<String, dynamic> indicator;

  String _format(String key, dynamic value) {
    if (value == null) return 'sem orçamento definido';
    final v = toDouble(value);
    return switch (key) {
      'emergency_fund' => '${v.toStringAsFixed(1).replaceAll('.', ',')} meses (meta: 6)',
      'savings_rate' => '${percent(v)} (meta: 20%)',
      'credit_utilization' || 'debt_to_income' => '${percent(v)} (ideal: até 30%)',
      _ => percent(v),
    };
  }

  @override
  Widget build(BuildContext context) {
    final score = indicator['score'] as int?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(indicator['label'], style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(score == null ? '--' : '$score', style: TextStyle(fontWeight: FontWeight.w800, color: ScoreGauge.colorFor(score))),
            ],
          ),
          const SizedBox(height: 6),
          ProgressBar(value: (score ?? 0) / 100, color: ScoreGauge.colorFor(score)),
          const SizedBox(height: 4),
          Text(_format(indicator['key'], indicator['value']), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.rec});

  final Map<String, dynamic> rec;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (rec['priority']) {
      'high' => (FFColors.danger, Icons.error_outline),
      'medium' => (FFColors.warning, Icons.lightbulb_outline),
      _ => (FFColors.green, Icons.tips_and_updates_outlined),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec['title'], style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(rec['message']),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Orçamento por categoria: mostra gasto x limite e permite definir/ajustar.
class _BudgetsCard extends StatelessWidget {
  const _BudgetsCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final budgets = {for (final b in summary['budgets'] as List) b['category_id'] as int: b};
    final spent = {
      for (final c in summary['expense_by_category'] as List)
        if (c['id'] != null) c['id'] as int: toDouble(c['total']),
    };
    final categories = state.categories.where((c) => c.kind == 'expense').toList()
      ..sort((a, b) => (spent[b.id] ?? 0).compareTo(spent[a.id] ?? 0));

    return SectionCard(
      title: 'Orçamento por categoria',
      child: Column(
        children: [
          for (final c in categories)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(categoryIcon(c.icon), color: hexColor(c.color)),
              title: Text(c.name),
              subtitle: budgets[c.id] == null
                  ? Text('Gasto: ${money(spent[c.id] ?? 0)} · sem limite')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        ProgressBar(value: toDouble(budgets[c.id]['usage'])),
                        const SizedBox(height: 2),
                        Text('${money(toDouble(budgets[c.id]['spent']))} de ${money(toDouble(budgets[c.id]['budget']))}'),
                      ],
                    ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () => _editBudget(context, c.id, c.name, budgets[c.id]),
            ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, int categoryId, String name, Map<String, dynamic>? current) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(text: current == null ? '' : toDouble(current['budget']).toStringAsFixed(2).replaceAll('.', ','));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Limite para $name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: 'R\$ ', helperText: monthLabel(state.month)),
        ),
        actions: [
          if (current != null) TextButton(onPressed: () => Navigator.pop(ctx, 'remove'), child: const Text('Remover')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Salvar')),
        ],
      ),
    );
    if (result == null) return;
    try {
      if (result == 'remove') {
        await state.api.delete('/budgets/${current!['id']}');
      } else {
        final amount = parseMoney(ctrl.text);
        if (amount == null || amount < 0) throw 'Valor inválido';
        if (current == null) {
          await state.api.post('/budgets', {'category_id': categoryId, 'month': state.month, 'amount': amount});
        } else {
          await state.api.patch('/budgets/${current['id']}', {'amount': amount});
        }
      }
      await state.dataChanged();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
