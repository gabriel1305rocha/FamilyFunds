import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

Color hexColor(String? hex, [Color fallback = FFColors.green]) {
  if (hex == null || hex.length != 7) return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

const _icons = <String, IconData>{
  'work': Icons.work_outline,
  'savings': Icons.savings_outlined,
  'trending_up': Icons.trending_up,
  'home': Icons.home_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
  'directions_car': Icons.directions_car_outlined,
  'favorite': Icons.favorite_border,
  'school': Icons.school_outlined,
  'receipt': Icons.receipt_long_outlined,
  'restaurant': Icons.restaurant_outlined,
  'celebration': Icons.celebration_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'subscriptions': Icons.subscriptions_outlined,
  'pets': Icons.pets_outlined,
  'flight': Icons.flight_outlined,
  'child_care': Icons.child_care_outlined,
};

IconData categoryIcon(String? name) => _icons[name] ?? Icons.category_outlined;

const categoryIconNames = ['category', ..._iconKeys];
const _iconKeys = [
  'work', 'savings', 'trending_up', 'home', 'shopping_cart', 'directions_car', 'favorite', 'school',
  'receipt', 'restaurant', 'celebration', 'shopping_bag', 'subscriptions', 'pets', 'flight', 'child_care',
];

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(16)});

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => state.shiftMonth(-1), tooltip: 'Mês anterior'),
        Text(monthLabel(state.month), style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => state.shiftMonth(1), tooltip: 'Próximo mês'),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: FFColors.green.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 8});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (value > 1 ? FFColors.danger : value > 0.85 ? FFColors.warning : FFColors.green);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: height,
        color: c,
        backgroundColor: c.withValues(alpha: 0.15),
      ),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.name, required this.color, this.radius = 16});

  final String name;
  final String color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: hexColor(color),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.9),
      ),
    );
  }
}

/// Carrega dados assíncronos e recarrega quando o mês ou os dados mudam.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function(AppState state) load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  Future<T>? _future;
  String? _key;

  Future<void> _reload() async {
    final f = widget.load(context.read<AppState>());
    setState(() => _future = f);
    await f;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    final key = '${state.month}|${state.revision}';
    if (key != _key) {
      _key = key;
      _future = widget.load(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: EmptyState(
              icon: Icons.cloud_off,
              message: '${snap.error}',
              action: FilledButton.tonal(onPressed: _reload, child: const Text('Tentar novamente')),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(onRefresh: _reload, child: widget.builder(context, snap.data as T, _reload));
      },
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$error'), backgroundColor: FFColors.danger, behavior: SnackBarBehavior.floating),
  );
}

Future<bool> confirm(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Converte texto digitado ("1.234,56" ou "1234.56") em número.
double? parseMoney(String text) {
  var t = text.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}
