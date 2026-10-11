import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';

/// Barras de receitas (verde) x despesas (azul) por mês.
class CashflowChart extends StatelessWidget {
  const CashflowChart({super.key, required this.data});

  final List<dynamic> data;

  @override
  Widget build(BuildContext context) {
    final maxY = data.fold<double>(0, (m, e) => [m, toDouble(e['income']), toDouble(e['expense'])].reduce((a, b) => a > b ? a : b));
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 100 : maxY * 1.15,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: muted.withValues(alpha: 0.15), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (v, meta) => v == meta.max
                        ? const SizedBox.shrink()
                        : Text(moneyCompact(v), style: TextStyle(fontSize: 10, color: muted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(monthShort(data[v.toInt()]['month']), style: TextStyle(fontSize: 11, color: muted)),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => FFColors.navy,
                  getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                    '${rodIndex == 0 ? 'Receitas' : 'Despesas'}\n${money(rod.toY)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(toY: toDouble(data[i]['income']), color: FFColors.income, width: 10, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: toDouble(data[i]['expense']), color: FFColors.expense, width: 10, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LegendDot(color: FFColors.income, label: 'Receitas'),
            SizedBox(width: 16),
            LegendDot(color: FFColors.expense, label: 'Despesas'),
          ],
        ),
      ],
    );
  }
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class DonutSlice {
  DonutSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Gráfico de rosca com legenda (usado para categorias e alocação de investimentos).
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.center});

  final List<DonutSlice> slices;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(value: s.value, color: s.color, radius: 22, showTitle: false),
                  ],
                ),
              ),
              ?center,
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      Text(percent(total > 0 ? s.value / total : 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (slices.length > 6)
                Text('+ ${slices.length - 6} outras', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Medidor circular da saúde financeira (0–100).
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.score, this.size = 140, this.light = false});

  final int? score;
  final double size;
  final bool light;

  static Color colorFor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 80) return FFColors.green;
    if (score >= 60) return FFColors.blue;
    if (score >= 40) return FFColors.warning;
    return FFColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : colorFor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (score ?? 0) / 100,
            strokeWidth: size * 0.08,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: color.withValues(alpha: 0.18),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(score?.toString() ?? '--', style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: light ? Colors.white : null)),
                Text('de 100', style: TextStyle(fontSize: size * 0.09, color: light ? Colors.white70 : Theme.of(context).hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
