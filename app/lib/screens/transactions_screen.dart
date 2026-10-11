import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'transaction_form.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _type;
  int? _memberId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos')),
      body: Column(
        children: [
          const MonthSelector(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (value, label) in [(null, 'Todos'), ('expense', 'Gastos'), ('income', 'Ganhos'), ('transfer', 'Transferências')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(label), selected: _type == value, onSelected: (_) => setState(() => _type = value)),
                  ),
                const SizedBox(width: 8),
                for (final m in state.members)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: MemberAvatar(name: m.name, color: m.color, radius: 10),
                      label: Text(m.name),
                      selected: _memberId == m.id,
                      onSelected: (s) => setState(() => _memberId = s ? m.id : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncView<List<Txn>>(
              key: ValueKey('$_type|$_memberId'),
              load: (s) async {
                final rows = await s.api.get('/transactions', {'month': s.month, 'type': _type, 'member_id': _memberId, 'limit': 500}) as List;
                return rows.map((j) => Txn.fromJson(j)).toList();
              },
              builder: (context, txns, _) => _TxnList(txns: txns),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnList extends StatelessWidget {
  const _TxnList({required this.txns});

  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) {
      return ListView(children: const [EmptyState(icon: Icons.receipt_long_outlined, message: 'Nenhum lançamento neste mês.\nToque em "Lançamento" para adicionar.')]);
    }
    final groups = <String, List<Txn>>{};
    for (final t in txns) {
      groups.putIfAbsent(t.date, () => []).add(t);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(dayLabel(entry.key), style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).hintColor)),
          ),
          Card(child: Column(children: [for (final t in entry.value) TxnTile(txn: t)])),
        ],
      ],
    );
  }
}

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn});

  final Txn txn;

  Future<void> _delete(BuildContext context) async {
    final state = context.read<AppState>();
    var scope = 'one';
    if (txn.installmentTotal != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Compra parcelada'),
          children: [
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'one'), child: const Text('Excluir só esta parcela')),
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'all'), child: const Text('Excluir todas as parcelas')),
          ],
        ),
      );
      if (choice == null) return;
      scope = choice;
    } else if (!await confirm(context, 'Excluir "${txn.description.isEmpty ? 'lançamento' : txn.description}"?')) {
      return;
    }
    try {
      await state.api.delete('/transactions/${txn.id}', {'scope': scope});
      await state.dataChanged();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == 'income';
    final isTransfer = txn.type == 'transfer';
    final color = isTransfer ? FFColors.teal : hexColor(txn.categoryColor, isIncome ? FFColors.income : FFColors.expense);
    final title = txn.description.isNotEmpty ? txn.description : (txn.categoryName ?? (isTransfer ? 'Transferência' : 'Sem descrição'));
    final subtitle = [
      if (isTransfer) '${txn.accountName} → ${txn.transferAccountName}' else txn.accountName,
      if (!isTransfer && txn.categoryName != null) txn.categoryName!,
      txn.memberName ?? 'Família',
    ].join(' · ');

    return ListTile(
      onTap: () => showTransactionForm(context, txn: txn),
      onLongPress: () => _delete(context),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(isTransfer ? Icons.swap_horiz : categoryIcon(txn.categoryIcon), color: color),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isIncome ? '+' : isTransfer ? '' : '-'} ${money(txn.amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: isIncome ? FFColors.income : isTransfer ? FFColors.teal : FFColors.expense),
          ),
          IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(context)),
        ],
      ),
    );
  }
}
