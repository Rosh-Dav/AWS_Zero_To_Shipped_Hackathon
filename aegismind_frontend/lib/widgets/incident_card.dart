import 'package:flutter/material.dart';
import '../models/incident.dart';
import 'urgency_badge.dart';
import 'glass_panel.dart';

class IncidentCard extends StatefulWidget {
  final Incident incident;
  final VoidCallback? onTap;
  final void Function(String, int?)? onStatusUpdate;

  const IncidentCard({
    super.key,
    required this.incident,
    this.onTap,
    this.onStatusUpdate,
  });

  @override
  State<IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<IncidentCard> {
  final TextEditingController _etaController = TextEditingController();

  @override
  void dispose() {
    _etaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final incident = widget.incident;
    final urgencyColor = incident.urgencyColor(context);

    return GlassPanel(
      onTap: widget.onTap,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Left urgency stripe ──
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: urgencyColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // ── Card content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row
                      Row(
                        children: [
                          UrgencyBadge(urgency: incident.urgency),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(incident.categoryIcon, size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  incident.category.toUpperCase(),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            incident.timeAgo,
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Summary
                      Text(
                        incident.summary,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),

                      // Resources chips
                      if (incident.requiredResources.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: incident.requiredResources
                              .take(4)
                              .map((resource) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      resource.toUpperCase(),
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 16),

                      // Bottom row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: incident.statusColor(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              incident.status,
                              style: TextStyle(
                                color: incident.statusColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (incident.nextStatus != null && widget.onStatusUpdate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (incident.nextStatus == 'DISPATCHED')
                                  Container(
                                    width: 70,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: TextField(
                                      controller: _etaController,
                                      decoration: InputDecoration(
                                        hintText: 'ETA (m)',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onSubmitted: (val) {
                                        final eta = int.tryParse(val);
                                        widget.onStatusUpdate!(incident.nextStatus!, eta);
                                      },
                                    ),
                                  ),
                                FilledButton.icon(
                                  onPressed: () {
                                    final eta = int.tryParse(_etaController.text);
                                    widget.onStatusUpdate!(incident.nextStatus!, eta);
                                  },
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                  label: Text(incident.nextStatusLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }
}
