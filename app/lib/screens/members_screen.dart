import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Gestão dos membros da família (ex.: você e sua esposa).
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isOwner = state.me?.isOwner ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(state.me?.familyName ?? 'Família')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showMemberForm(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Adicionar membro'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            'Cada membro pode ter seus próprios cartões e contas. Os gastos de cada um aparecem separados no painel.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final m in state.members)
                  ListTile(
                    leading: MemberAvatar(name: m.name, color: m.color, radius: 20),
                    title: Text(m.name + (m.id == state.me?.id ? ' (você)' : ''), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([m.isOwner ? 'Responsável' : 'Membro', m.hasLogin ? m.email : 'Sem acesso ao app'].whereType<String>().join(' · ')),
                    trailing: (isOwner || m.id == state.me?.id) ? const Icon(Icons.edit_outlined) : null,
                    onTap: (isOwner || m.id == state.me?.id) ? () => _showMemberForm(context, member: m) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showMemberForm(BuildContext context, {Member? member}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _MemberForm(member: member),
  );
}

class _MemberForm extends StatefulWidget {
  const _MemberForm({this.member});
  final Member? member;

  @override
  State<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<_MemberForm> {
  final _form = GlobalKey<FormState>();
  late final AppState state = context.read<AppState>();
  late final _name = TextEditingController(text: widget.member?.name);
  late final _email = TextEditingController(text: widget.member?.email);
  final _password = TextEditingController();
  late Color _color = hexColor(widget.member?.color, FFColors.blue);
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'color': colorHex(_color),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_password.text.isNotEmpty) 'password': _password.text,
    };
    try {
      if (widget.member == null) {
        await state.api.post('/members', body);
      } else {
        await state.api.patch('/members/${widget.member!.id}', body);
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
    if (!await confirm(context, 'Remover ${widget.member!.name} da família? Os lançamentos ficarão como "Família".')) return;
    try {
      await state.api.delete('/members/${widget.member!.id}');
      await state.dataChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.member != null;
    final canDelete = editing && (state.me?.isOwner ?? false) && widget.member!.id != state.me?.id;
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
                    child: Text(editing ? 'Editar membro' : 'Novo membro',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (canDelete) IconButton(tooltip: 'Remover', onPressed: _delete, icon: const Icon(Icons.delete_outline, color: FFColors.danger)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              Text('Opcional: dê acesso ao app com e-mail e senha.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: editing ? 'Nova senha' : 'Senha'),
                validator: (v) => (v ?? '').isNotEmpty && v!.length < 8 ? 'Mínimo de 8 caracteres' : null,
              ),
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
