import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final banks = state.accounts.where((a) => !a.isCard).toList();
    final cards = state.accounts.where((a) => a.isCard).toList();
    final totalBanks = banks.fold<double>(0, (s, a) => s + a.balance);
    final totalCardDebt = cards.fold<double>(0, (s, a) => s + (a.balance < 0 ? -a.balance : 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas e cartões'),
        actions: [IconButton(tooltip: 'Nova conta', icon: const Icon(Icons.add_card), onPressed: () => showAccountForm(context))],
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshReference,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Row(
              children: [
                Expanded(child: _TotalTile(label: 'Em conta', value: totalBanks, color: FFColors.green, icon: Icons.account_balance)),
                const SizedBox(width: 12),
                Expanded(child: _TotalTile(label: 'Faturas em aberto', value: totalCardDebt, color: FFColors.blue, icon: Icons.credit_card)),
              ],
            ),
            const SizedBox(height: 20),
            _Header('Contas correntes e poupança'),
            if (banks.isEmpty)
              _AddTile(label: 'Adicionar conta corrente', onTap: () => showAccountForm(context, type: AccountType.checking))
            else
              Card(child: Column(children: [for (final a in banks) _BankTile(account: a)])),
            const SizedBox(height: 20),
            _Header('Cartões de crédito'),
            if (cards.isEmpty)
              _AddTile(label: 'Adicionar cartão de crédito', onTap: () => showAccountForm(context, type: AccountType.creditCard))
            else
              for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: _CardTile(card: c)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
          FittedBox(child: Text(money(value), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.add_circle_outline, color: FFColors.green), title: Text(label), onTap: onTap));
}

class _BankTile extends StatelessWidget {
  const _BankTile({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final owner = context.read<AppState>().memberById(account.ownerId);
    return ListTile(
      onTap: () => showAccountForm(context, account: account),
      leading: CircleAvatar(
        backgroundColor: hexColor(account.color).withValues(alpha: 0.15),
        child: Icon(account.type == AccountType.savings ? Icons.savings_outlined : Icons.account_balance, color: hexColor(account.color)),
      ),
      title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([account.type.label, account.institution, owner?.name ?? 'Conjunta'].whereType<String>().join(' · ')),
      trailing: Text(
        money(account.balance),
        style: TextStyle(fontWeight: FontWeight.w700, color: account.balance < 0 ? FFColors.danger : FFColors.green),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});
  final Account card;

  @override
  Widget build(BuildContext context) {
    final owner = context.read<AppState>().memberById(card.ownerId);
    final base = hexColor(card.color, FFColors.blue);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showAccountForm(context, account: card),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [base, Color.lerp(base, FFColors.navy, 0.45)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(card.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                Text(owner?.name ?? 'Conjunto', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Fatura atual', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(money(card.currentBill ?? (card.balance < 0 ? -card.balance : 0)),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            if (card.closingDay != null)
              Text('Fecha dia ${card.closingDay} · vence dia ${card.dueDay ?? '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (card.creditLimit != null) ...[
              const SizedBox(height: 12),
              ProgressBar(value: card.utilization ?? 0, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                'Usado ${money(card.usedLimit ?? 0)} de ${money(card.creditLimit!)} · disponível ${money(card.availableLimit ?? 0)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showAccountForm(BuildContext context, {Account? account, AccountType? type}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AccountForm(account: account, initialType: type),
  );
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({this.account, this.initialType});
  final Account? account;
  final AccountType? initialType;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _form = GlobalKey<FormState>();
  late final AppState state = context.read<AppState>();
  late final Account? a = widget.account;
  late AccountType _type = a?.type ?? widget.initialType ?? AccountType.checking;
  late final _name = TextEditingController(text: a?.name);
  late final _institution = TextEditingController(text: a?.institution);
  final _initial = TextEditingController();
  late final _limit = TextEditingController(text: a?.creditLimit?.toStringAsFixed(2).replaceAll('.', ','));
  late final _closing = TextEditingController(text: a?.closingDay?.toString());
  late final _due = TextEditingController(text: a?.dueDay?.toString());
  late int? _ownerId = a?.ownerId;
  late Color _color = hexColor(a?.color, FFColors.green);
  bool _saving = false;

  int? _day(String t) => int.tryParse(t.trim());

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'type': _type.api,
      'institution': _institution.text.trim().isEmpty ? null : _institution.text.trim(),
      'owner_id': _ownerId,
      'color': colorHex(_color),
      if (a == null && _initial.text.isNotEmpty) 'initial_balance': parseMoney(_initial.text) ?? 0,
      if (_type == AccountType.creditCard) ...{
        'credit_limit': parseMoney(_limit.text),
        'closing_day': _day(_closing.text),
        'due_day': _day(_due.text),
      },
    };
    try {
      if (a == null) {
        await state.api.post('/accounts', body);
      } else {
        await state.api.patch('/accounts/${a!.id}', body);
      }
      await state.dataChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Excluir "${a!.name}" e todos os seus lançamentos?')) return;
    try {
      await state.api.delete('/accounts/${a!.id}');
      await state.dataChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String? _dayValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final d = _day(v);
    return (d == null || d < 1 || d > 31) ? 'Dia de 1 a 31' : null;
  }

  @override
  Widget build(BuildContext context) {
    final isCard = _type == AccountType.creditCard;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(a == null ? 'Nova conta' : 'Editar conta',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (a != null) IconButton(tooltip: 'Excluir', onPressed: _delete, icon: const Icon(Icons.delete_outline, color: FFColors.danger)),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [for (final t in AccountType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                onChanged: a == null ? (v) => setState(() => _type = v!) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: 'Nome', hintText: isCard ? 'Ex.: Nubank da Ana' : 'Ex.: Conta conjunta'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _institution, decoration: const InputDecoration(labelText: 'Banco / instituição')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _ownerId,
                decoration: const InputDecoration(labelText: 'Titular'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Conjunta (família)')),
                  for (final m in state.members) DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (v) => setState(() => _ownerId = v),
              ),
              if (a == null && !isCard) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _initial,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Saldo atual', prefixText: 'R\$ '),
                ),
              ],
              if (isCard) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _limit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Limite', prefixText: 'R\$ '),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(controller: _closing, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dia do fechamento'), validator: _dayValidator),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(controller: _due, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dia do vencimento'), validator: _dayValidator),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  for (final c in FFColors.chart.take(8))
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: c,
                        child: _color.toARGB32() == c.toARGB32() ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Salvar')),
            ],
          ),
        ),
      ),
    );
  }
}
