import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Abre o formulário de lançamento (novo ou edição) como bottom sheet.
Future<void> showTransactionForm(BuildContext context, {Txn? txn}) {
  final state = context.read<AppState>();
  if (state.accounts.isEmpty) {
    showError(context, 'Cadastre uma conta antes de fazer lançamentos (aba Contas).');
    return Future.value();
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TransactionForm(txn: txn),
  );
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key, this.txn});

  final Txn? txn;

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _form = GlobalKey<FormState>();
  late final AppState state = context.read<AppState>();
  late String _type = widget.txn?.type ?? 'expense';
  late final _amount = TextEditingController(text: widget.txn == null ? '' : widget.txn!.amount.toStringAsFixed(2).replaceAll('.', ','));
  late final _description = TextEditingController(text: widget.txn?.description ?? '');
  late DateTime _date = widget.txn == null ? DateTime.now() : DateTime.parse(widget.txn!.date);
  late int? _accountId = widget.txn?.accountId ?? state.accounts.first.id;
  int? _transferAccountId;
  late int? _categoryId = widget.txn?.categoryId;
  late int? _memberId = widget.txn?.memberId ?? state.me?.id;
  int _installments = 1;
  bool _saving = false;

  bool get _editing => widget.txn != null;

  List<Category> get _categories => state.categories.where((c) => c.kind == _type).toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'type': _type,
      'amount': parseMoney(_amount.text),
      'description': _description.text.trim(),
      'date': isoDate(_date),
      'account_id': _accountId,
      'member_id': _memberId,
      'category_id': _type == 'transfer' ? null : _categoryId,
      if (_type == 'transfer') 'transfer_account_id': _transferAccountId,
      if (!_editing && _type == 'expense' && _installments > 1) 'installments': _installments,
    };
    try {
      if (_editing) {
        await state.api.patch('/transactions/${widget.txn!.id}', body);
      } else {
        await state.api.post('/transactions', body);
      }
      await state.dataChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccount = state.accountById(_accountId);
    final color = switch (_type) { 'income' => FFColors.income, 'expense' => FFColors.expense, _ => FFColors.teal };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_editing ? 'Editar lançamento' : 'Novo lançamento', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Gasto'), icon: Icon(Icons.arrow_upward)),
                  ButtonSegment(value: 'income', label: Text('Ganho'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: 'transfer', label: Text('Transferir'), icon: Icon(Icons.swap_horiz)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: !_editing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
                decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                validator: (v) => (parseMoney(v ?? '') ?? 0) <= 0 ? 'Informe um valor maior que zero' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Descrição', prefixIcon: Icon(Icons.notes)),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _type == 'transfer' ? 'Da conta' : 'Conta / cartão',
                  prefixIcon: Icon(selectedAccount?.isCard == true ? Icons.credit_card : Icons.account_balance),
                ),
                items: [for (final a in state.accounts) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${a.type.label}'))],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              if (_type == 'transfer') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _transferAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Para a conta (ex.: pagar fatura)', prefixIcon: Icon(Icons.call_made)),
                  items: [
                    for (final a in state.accounts.where((a) => a.id != _accountId))
                      DropdownMenuItem(value: a.id, child: Text('${a.name} · ${a.type.label}')),
                  ],
                  validator: (v) => v == null ? 'Escolha a conta de destino' : null,
                  onChanged: (v) => setState(() => _transferAccountId = v),
                ),
              ] else ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('cat-$_type'),
                  initialValue: _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.label_outline)),
                  items: [
                    for (final c in _categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [Icon(categoryIcon(c.icon), size: 18, color: hexColor(c.color)), const SizedBox(width: 8), Text(c.name)]),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _memberId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Quem', prefixIcon: Icon(Icons.person_outline)),
                items: [
                  for (final m in state.members) DropdownMenuItem(value: m.id, child: Text(m.name)),
                  const DropdownMenuItem(value: null, child: Text('Família (conjunto)')),
                ],
                onChanged: (v) => setState(() => _memberId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.event),
                      label: Text(shortDate(isoDate(_date))),
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ),
                  if (!_editing && _type == 'expense') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _installments,
                        decoration: const InputDecoration(labelText: 'Parcelas'),
                        items: [for (var i = 1; i <= 24; i++) DropdownMenuItem(value: i, child: Text(i == 1 ? 'À vista' : '${i}x'))],
                        onChanged: (v) => setState(() => _installments = v ?? 1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: color),
                child: _saving ? const CircularProgressIndicator(strokeWidth: 2) : Text(_editing ? 'Salvar alterações' : 'Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
