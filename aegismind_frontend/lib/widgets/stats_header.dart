import 'package:flutter/material.dart';
import '../models/incident.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

class StatsHeader extends StatelessWidget {
  final List<Incident> incidents;

  const StatsHeader({super.key, required this.incidents});

  @override
  Widget build(BuildContext context) {
    final critical = incidents.where((i) => i.urgency == 'CRITICAL').length;
    final high = incidents.where((i) => i.urgency == 'HIGH').length;
    final medium = incidents.where((i) => i.urgency == 'MEDIUM').length;

    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniStat(label: 'CRITICAL', count: critical, color: theme.dangerColor),
        const SizedBox(width: 12),
        _MiniStat(label: 'HIGH', count: high, color: theme.warningColor),
        const SizedBox(width: 12),
        _MiniStat(label: 'MEDIUM', count: medium, color: theme.successColor),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: BorderRadius.circular(10),
      tint: color.withValues(alpha: 0.16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
