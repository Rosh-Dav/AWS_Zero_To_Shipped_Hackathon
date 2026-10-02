import 'package:flutter/material.dart';
import '../models/incident.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/glass_panel.dart';

class IncidentDetailScreen extends StatelessWidget {
  final Incident incident;

  const IncidentDetailScreen({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              UrgencyBadge(urgency: incident.urgency),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(incident.categoryIcon, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      incident.category,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Raw SOS Message',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.surface),
            ),
            child: Text(
              '"${incident.rawMessage}"',
              style: TextStyle(color: cs.onSurface, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Location',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
          ),
              const SizedBox(height: 8),
          if (incident.latitude != null && incident.longitude != null)
            Row(
              children: [
                Icon(Icons.location_on, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${incident.latitude!.toStringAsFixed(4)}, ${incident.longitude!.toStringAsFixed(4)}',
                    style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            )
          else
            Text('Not provided', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 20),
          if (incident.requiredResources.isNotEmpty) ...[
            Text(
              'Required Resources',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: incident.requiredResources
                  .map((res) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${res.replaceAll(' ', '').toLowerCase()}',
                          style: TextStyle(color: cs.primary.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
