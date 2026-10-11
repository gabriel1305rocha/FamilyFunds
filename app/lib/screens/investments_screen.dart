import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class _InvestData {
  _InvestData(this.summary, this.investments, this.goals, this.health);
  final Map<String, dynamic> summary;
  final List<Investment> investments;
  final List<Goal> goals;
  final Map<String, dynamic> health;
}

class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investimentos e metas'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (v) => v == 'inv' ? _showInvestmentForm(context) : _showGoalForm(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'inv', child: Text('Novo investimento')),
              PopupMenuItem(value: 'goal', child: Text('Nova meta')),
            ],
          ),
        ],
      ),
      body: AsyncView<_InvestData>(
        load: (s) async {
          final r = await Future.wait([s.api.get('/reports/investments'), s.api.get('/investments'), s.api.get('/goals'), s.api.get('/reports/health')]);
          return _InvestData(
            r[0],
            (r[1] as List).map((j) => Investment.fromJson(j)).toList(),
            (r[2] as List).map((j) => Goal.fromJson(j)).toList(),
            r[3],
          );
        },
        builder: (context, d, _) => _Body(data: d),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final _InvestData data;

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final allocation = s['allocation'] as List;
    final profit = toDouble(s['profit']);
    final insights = (data.health['recommendations'] as List)
        .where((r) => const ['Hora de investir', 'Prioridade: liquidez', 'Diversifique a carteira', 'Exposição alta a cripto', 'Monte a reserva de emergência'].contains(r['title']))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: FFColors.brandGradient, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Patrimônio investido', style: TextStyle(color: Colors.white70)),
              Text(money(toDouble(s['current'])), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${profit >= 0 ? '+' : ''}${money(profit)} (${percent(toDouble(s['return_rate']))}) sobre ${money(toDouble(s['invested']))} aplicados',
                style: const TextStyle(color: Colors.white),
              ),
              Text('Com liquidez diária: ${money(toDouble(s['liquid']))}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        if (insights.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Insights',
            child: Column(
              children: [
                for (final r in insights)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insights, color: FFColors.blue),
                    title: Text(r['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(r['message']),
                  ),
              ],
            ),
          ),
        ],
        if (allocation.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Alocação',
            child: DonutChart(
              slices: [
                for (var i = 0; i < allocation.length; i++)
                  DonutSlice(allocation[i]['label'], toDouble(allocation[i]['current']), FFColors.chart[i % FFColors.chart.length]),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'Carteira',
          trailing: TextButton.icon(onPressed: () => _showInvestmentForm(context), icon: const Icon(Icons.add), label: const Text('Adicionar')),
          child: data.investments.isEmpty
              ? const EmptyState(icon: Icons.trending_up, message: 'Cadastre seus investimentos para acompanhar a rentabilidade.')
              : Column(children: [for (final i in data.investments) _InvestmentTile(inv: i)]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Metas da família',
          trailing: TextButton.icon(onPressed: () => _showGoalForm(context), icon: const Icon(Icons.add), label: const Text('Adicionar')),
          child: data.goals.isEmpty
              ? const EmptyState(icon: Icons.flag_outlined, message: 'Crie metas como viagem, carro novo ou reserva de emergência.')
              : Column(children: [for (final g in data.goals) _GoalTile(goal: g)]),
        ),
      ],
    );
  }
}

class _InvestmentTile extends StatelessWidget {
  const _InvestmentTile({required this.inv});
  final Investment inv;

  @override
  Widget build(BuildContext context) {
    final owner = context.read<AppState>().memberById(inv.memberId);
    final up = inv.profit >= 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _showInvestmentForm(context, inv: inv),
      leading: CircleAvatar(backgroundColor: FFColors.blue.withValues(alpha: 0.12), child: const Icon(Icons.show_chart, color: FFColors.blue)),
      title: Text(inv.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([Investment.types[inv.type], Investment.liquidities[inv.liquidity], owner?.name].whereType<String>().join(' · ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(inv.current), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${up ? '▲' : '▼'} ${percent(inv.returnRate.abs())}', style: TextStyle(fontSize: 12, color: up ? FFColors.green : FFColors.danger)),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    String? monthly;
    if (goal.deadline != null) {
      final now = DateTime.now();
      final end = DateTime.parse(goal.deadline!);
      final months = (end.year - now.year) * 12 + end.month - now.month;
      final missing = goal.target - goal.current;
      if (missing > 0 && months > 0) monthly = 'Guarde ${money(missing / months)}/mês até ${shortDate(goal.deadline!)}';
    }
    return InkWell(
      onTap: () => _showGoalForm(context, goal: goal),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: hexColor(goal.color), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(percent(goal.progress), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            ProgressBar(value: goal.progress, color: hexColor(goal.color), height: 10),
            const SizedBox(height: 4),
            Text(
              '${money(goal.current)} de ${money(goal.target)}${monthly != null ? ' · $monthly' : ''}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

String _moneyText(double? v) => v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

Future<void> _saveOrDelete(BuildContext context, String path, int? id, Map<String, dynamic>? body) async {
  final state = context.read<AppState>();
  try {
    if (body == null) {
      await state.api.delete('$path/$id');
    } else if (id == null) {
      await state.api.post(path, body);
    } else {
      await state.api.patch('$path/$id', body);
    }
    await state.dataChanged();
    if (context.mounted) Navigator.pop(context);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

void _showInvestmentForm(BuildContext context, {Investment? inv}) {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: inv?.name);
  final institution = TextEditingController(text: inv?.institution);
  final invested = TextEditingController(text: _moneyText(inv?.invested));
  final current = TextEditingController(text: _moneyText(inv?.current));
  var type = inv?.type ?? 'fixed_income';
  var liquidity = inv?.liquidity ?? 'daily';
  int? memberId = inv?.memberId;
  final members = context.read<AppState>().members;
  String? moneyValidator(String? v) => (parseMoney(v ?? '') ?? -1) < 0 ? 'Valor inválido' : null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(inv == null ? 'Novo investimento' : 'Editar investimento', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                    if (inv != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: FFColors.danger),
                        onPressed: () async {
                          if (await confirm(ctx, 'Excluir ${inv.name}?') && ctx.mounted) _saveOrDelete(ctx, '/investments', inv.id, null);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Tesouro Selic 2029'), validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [for (final e in Investment.types.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: liquidity,
                  decoration: const InputDecoration(labelText: 'Liquidez'),
                  items: [for (final e in Investment.liquidities.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => liquidity = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: memberId,
                  decoration: const InputDecoration(labelText: 'Titular'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Família')),
                    for (final m in members) DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (v) => setState(() => memberId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: institution, decoration: const InputDecoration(labelText: 'Instituição / corretora')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: invested, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor aplicado', prefixText: 'R\$ '), validator: moneyValidator)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: current, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor atual', prefixText: 'R\$ '), validator: moneyValidator)),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    _saveOrDelete(ctx, '/investments', inv?.id, {
                      'name': name.text.trim(),
                      'type': type,
                      'liquidity': liquidity,
                      'member_id': memberId,
                      'institution': institution.text.trim().isEmpty ? null : institution.text.trim(),
                      'invested_amount': parseMoney(invested.text),
                      'current_value': parseMoney(current.text),
                    });
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _showGoalForm(BuildContext context, {Goal? goal}) {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: goal?.name);
  final target = TextEditingController(text: _moneyText(goal?.target));
  final current = TextEditingController(text: _moneyText(goal?.current));
  DateTime? deadline = goal?.deadline == null ? null : DateTime.parse(goal!.deadline!);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(goal == null ? 'Nova meta' : 'Editar meta', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                    if (goal != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: FFColors.danger),
                        onPressed: () async {
                          if (await confirm(ctx, 'Excluir a meta ${goal.name}?') && ctx.mounted) _saveOrDelete(ctx, '/goals', goal.id, null);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Meta', hintText: 'Ex.: Viagem de férias'), validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: target,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor da meta', prefixText: 'R\$ '),
                        validator: (v) => (parseMoney(v ?? '') ?? 0) <= 0 ? 'Valor inválido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: current,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Já guardado', prefixText: 'R\$ '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.event),
                  label: Text(deadline == null ? 'Definir prazo (opcional)' : 'Prazo: ${shortDate(isoDate(deadline!))}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: deadline ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => deadline = d);
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    _saveOrDelete(ctx, '/goals', goal?.id, {
                      'name': name.text.trim(),
                      'target_amount': parseMoney(target.text),
                      'current_amount': parseMoney(current.text) ?? 0,
                      'deadline': deadline == null ? null : isoDate(deadline!),
                    });
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
