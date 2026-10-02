import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/incident.dart';
import '../state/incident_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stats_header.dart';
import '../widgets/incident_card.dart';
import 'incident_detail_screen.dart';
import '../widgets/glass_panel.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedStatus = 'OPEN';

  @override
  void initState() {
    super.initState();
    // Fetch data when dashboard is first opened if needed, 
    // although the provider starts fetching when it's created.
  }

  Future<void> _updateStatus(String incidentId, String newStatus, [int? etaMinutes]) async {
    try {
      await context.read<IncidentProvider>().updateStatus(incidentId, newStatus, etaMinutes: etaMinutes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Theme.of(context).dangerColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = context.watch<IncidentProvider>();
    final incidents = provider.incidents;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 250,
            child: GlassPanel(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.zero,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded, color: cs.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'AegisHQ',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: cs.surfaceContainerHighest, thickness: 2, height: 2),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'DISPATCH QUEUES',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                _SidebarItem(
                  icon: Icons.error_outline,
                  label: 'Open Incidents',
                  isActive: _selectedStatus == 'OPEN',
                  onTap: () => setState(() => _selectedStatus = 'OPEN'),
                ),
                _SidebarItem(
                  icon: Icons.fire_truck,
                  label: 'Dispatched',
                  isActive: _selectedStatus == 'DISPATCHED',
                  onTap: () => setState(() => _selectedStatus = 'DISPATCHED'),
                ),
                _SidebarItem(
                  icon: Icons.check_circle_outline,
                  label: 'Resolved',
                  isActive: _selectedStatus == 'RESOLVED',
                  onTap: () => setState(() => _selectedStatus = 'RESOLVED'),
                ),
              ],
              ),
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: ColoredBox(
              color: cs.surfaceContainer.withValues(alpha: 0.42),
              child: Column(
                children: [
                  // Header
                  SizedBox(
                    height: 70,
                    child: GlassPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      borderRadius: BorderRadius.zero,
                      child: Row(
                      children: [
                        Icon(Icons.tag, color: cs.onSurfaceVariant, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedStatus.toLowerCase(),
                          style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        if (provider.lastUpdated != null)
                          Text(
                            'Last updated: ${provider.lastUpdated!.hour}:${provider.lastUpdated!.minute.toString().padLeft(2, '0')}:${provider.lastUpdated!.second.toString().padLeft(2, '0')}',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          provider.isConnected ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: provider.isConnected ? theme.successColor : theme.dangerColor,
                        ),
                        const Spacer(),
                        StatsHeader(incidents: incidents),
                        const SizedBox(width: 16),
                        Container(width: 1, height: 32, color: cs.surfaceContainerHighest),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
                          color: cs.onSurfaceVariant,
                          onPressed: () {
                            themeNotifier.value = theme.brightness == Brightness.dark
                                ? ThemeMode.light
                                : ThemeMode.dark;
                          },
                        ),
                      ],
                      ),
                    ),
                  ),
                  
                  // Incident List
                  Expanded(
                    child: !provider.isConnected && incidents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load incidents. Check connection.', 
                                  style: TextStyle(color: cs.onSurface, fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => provider.fetchIncidents(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
                                  ),
                                )
                              ],
                            ),
                          )
                        : provider.isLoading && incidents.isEmpty
                            ? Center(child: CircularProgressIndicator(color: cs.primary))
                            : RefreshIndicator(
                                onRefresh: () => provider.fetchIncidents(),
                                color: cs.primary,
                                child: _buildList(incidents),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Incident> incidents) {
    final filtered = incidents.where((i) => i.status == _selectedStatus).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Theme.of(context).idleColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No $_selectedStatus incidents.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return IncidentCard(
          incident: filtered[index],
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SafeArea(
              child: SingleChildScrollView(
                child: IncidentDetailScreen(incident: filtered[index]),
              ),
            ),
          ),
          onStatusUpdate: (newStatus, eta) => _updateStatus(filtered[index].incidentId, newStatus, eta),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? cs.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isActive ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
