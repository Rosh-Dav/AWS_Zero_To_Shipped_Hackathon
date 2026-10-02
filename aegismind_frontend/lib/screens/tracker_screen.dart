import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/glass_panel.dart';

class TrackerScreen extends StatefulWidget {
  final String referenceId;
  const TrackerScreen({super.key, required this.referenceId});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  Timer? _pollTimer;
  Map<String, dynamic>? _statusData;
  String? _error;
  bool _isLoading = true;
  String _lastStatus = '';

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final data = await ApiService.fetchStatus(widget.referenceId);
      if (!mounted) return;
      
      final currentStatus = data['status'] as String? ?? '';
      
      if (_lastStatus.isNotEmpty && _lastStatus != currentStatus) {
        // Status changed, vibrate
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to: $currentStatus'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      setState(() {
        _statusData = data;
        _isLoading = false;
        _error = null;
        _lastStatus = currentStatus;
      });

      if (currentStatus == 'RESOLVED') {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Status Tracker')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading && _statusData == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _buildTrackerCard(context, cs),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorSection(theme),
                  ],
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildErrorSection(ThemeData theme) {
    return GlassPanel(
      tint: theme.colorScheme.errorContainer.withValues(alpha: 0.62),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unable to refresh status', style: TextStyle(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchStatus();
              },
              child: const Text('Retry'),
            ),
          ],
      ),
    );
  }

  Widget _buildTrackerCard(BuildContext context, ColorScheme cs) {
    final data = _statusData;
    final status = data?['status'] as String? ?? 'UNKNOWN';
    final ref = data?['referenceId'] ?? widget.referenceId;
    final urgency = data?['urgency'] ?? 'UNKNOWN';
    final category = data?['category'] ?? 'UNKNOWN';
    final resources = (data?['assignedResources'] as List?)?.cast<String>() ?? [];
    final eta = data?['etaMinutes'] as int?;

    int step = 0;
    if (status == 'OPEN') step = 0;
    if (status == 'DISPATCHED') step = 1;
    if (status == 'RESOLVED') step = 2;

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report ID: $ref', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              data == null
                  ? 'Your SOS report was submitted. Its current status could not be loaded.'
                  : 'Category: $category  •  Urgency: $urgency',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const Divider(height: 32),
            
            _buildStep(
              title: 'Received',
              subtitle: 'Your report has been logged.',
              isActive: step >= 0,
              isLast: false,
              cs: cs,
            ),
            _buildStep(
              title: 'Help dispatched',
              subtitle: step >= 1 
                  ? 'Help is on the way.' + (eta != null ? '\nEstimated arrival: about $eta minutes' : '')
                  : 'Waiting for dispatcher...',
              isActive: step >= 1,
              isLast: false,
              cs: cs,
              extra: step >= 1 && resources.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      children: resources.map((r) => Chip(
                        label: Text(r, style: const TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                      )).toList(),
                    )
                  : null,
            ),
            _buildStep(
              title: 'Resolved',
              subtitle: step >= 2 ? 'Emergency marked as resolved.' : '',
              isActive: step >= 2,
              isLast: true,
              cs: cs,
            ),
          ],
      ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isLast,
    required ColorScheme cs,
    Widget? extra,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? cs.primary : cs.surfaceContainerHighest,
              ),
              child: isActive ? Icon(Icons.check, size: 16, color: cs.onPrimary) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isActive ? cs.primary : cs.surfaceContainerHighest,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? cs.onSurface : cs.onSurfaceVariant)),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                ),
              if (extra != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: extra,
                ),
              if (!isLast) const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
