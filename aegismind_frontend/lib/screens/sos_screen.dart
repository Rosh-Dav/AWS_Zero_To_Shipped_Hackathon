import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/incident.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../widgets/glass_panel.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController(); // NEW
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;
  Position? _currentPosition;

  @override
  void dispose() {
    _messageController.dispose();
    _locationController.dispose(); // NEW
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on location services, then try again.')),
          );
        }
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is needed to attach your location.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) await _showLocationSettingsDialog();
        return;
      }
      
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _showLocationSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined),
        title: const Text('Allow location access'),
        content: const Text(
          'Location permission was previously blocked. Open app settings and allow location access, then return here and tap Auto again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Geolocator.openAppSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSOS() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.submitSOS(
        message: _messageController.text.trim(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        locationText: _locationController.text.trim(), // NEW
      );

      if (mounted) {
        _messageController.clear();
        _locationController.clear(); // NEW
        _currentPosition = null;
        await _showReportSummary(result.incident, result.merged);
        if (!mounted) return;
        // Keep the full stored ID for automatic tracking. The short uppercase
        // reference ID is shown in the confirmation and tracker instead.
        Navigator.pop(context, result.incident.incidentId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Theme.of(context).dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showReportSummary(Incident incident, bool merged) async {
    final guidance = _guidanceFor(incident.category);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.health_and_safety_rounded, color: incident.urgencyColor(context), size: 36),
        title: const Text('SOS report received'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Risk ID: ${incident.referenceId}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Severity: ${incident.urgency}  •  ${incident.category}', style: TextStyle(color: incident.urgencyColor(context), fontWeight: FontWeight.bold)),
              if (merged) ...[
                const SizedBox(height: 12),
                Text('Your report has been added to an existing nearby incident.', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
              if (incident.summary.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(incident.summary),
              ],
              if (incident.safetyAdvice.isNotEmpty) ...[
                const SizedBox(height: 16),
                _GuidanceBlock(title: 'Safety advice', icon: Icons.info_outline, color: cs.primary, messages: [incident.safetyAdvice]),
              ],
              const SizedBox(height: 16),
              _GuidanceBlock(title: 'Do now', icon: Icons.check_circle_outline, color: theme.successColor, messages: guidance.doNow),
              const SizedBox(height: 12),
              _GuidanceBlock(title: 'Avoid', icon: Icons.do_not_disturb_on_outlined, color: theme.dangerColor, messages: guidance.avoid),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.track_changes),
            label: const Text('Track report'),
          ),
        ],
      ),
    );
  }

  _EmergencyGuidance _guidanceFor(String category) {
    switch (category.toUpperCase()) {
      case 'FIRE':
        return const _EmergencyGuidance(
          doNow: ['Move everyone to a safe area away from smoke and flames.', 'Call local emergency services when it is safe to do so.'],
          avoid: ['Do not re-enter the building.', 'Do not use lifts or open hot doors.'],
        );
      case 'MEDICAL':
        return const _EmergencyGuidance(
          doNow: ['Keep the person calm and monitor breathing.', 'Call local emergency services if there is immediate danger.'],
          avoid: ['Do not give food, drink, or medication unless instructed.', 'Do not move someone with a possible neck or spine injury.'],
        );
      case 'FLOOD':
        return const _EmergencyGuidance(
          doNow: ['Move to higher ground and stay away from floodwater.', 'Turn off electricity only if it is safe to reach the switch.'],
          avoid: ['Do not walk or drive through moving water.', 'Do not touch damaged electrical equipment.'],
        );
      case 'ACCIDENT':
        return const _EmergencyGuidance(
          doNow: ['Move to a safe location if there is ongoing traffic danger.', 'Keep injured people still and call emergency services.'],
          avoid: ['Do not move seriously injured people unless there is immediate danger.', 'Do not block emergency access.'],
        );
      default:
        return const _EmergencyGuidance(
          doNow: ['Move to a safer area and wait for assistance.', 'Share accurate updates if the situation changes.'],
          avoid: ['Do not put yourself or others at further risk.', 'Do not return to an unsafe area.'],
        );
    }
  }

  void _addTemplate(String text) {
    setState(() {
      _messageController.text = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Text(
              'AegisMind SOS',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Describe your emergency',
                style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Type clearly or use the quick tags below.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Quick tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickTag(icon: Icons.local_fire_department, label: 'Fire', onTap: () => _addTemplate('Fire break out!')),
                  _QuickTag(icon: Icons.medical_services, label: 'Medical', onTap: () => _addTemplate('Need an ambulance!')),
                  _QuickTag(icon: Icons.car_crash, label: 'Accident', onTap: () => _addTemplate('Car accident!')),
                  _QuickTag(icon: Icons.warning, label: 'Danger', onTap: () => _addTemplate('I am in danger!')),
                ],
              ),
              const SizedBox(height: 24),

              // Large Input Area
              Expanded(
                child: GlassPanel(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(color: cs.onSurface, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'What is happening? (e.g. Someone is hurt, car crash on highway...)',
                      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location Bar
              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Icon(
                      _currentPosition != null ? Icons.location_on : Icons.location_off,
                      color: _currentPosition != null ? theme.successColor : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _currentPosition != null
                          ? Text(
                              'Location Attached',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : TextField(
                              controller: _locationController,
                              style: TextStyle(color: cs.onSurface, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter location manually...',
                                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                    ),
                    if (_currentPosition == null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _isFetchingLocation ? null : _getLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.surfaceContainerHighest,
                            foregroundColor: cs.onSurface,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _isFetchingLocation
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Auto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSOS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.dangerColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SEND EMERGENCY SOS',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyGuidance {
  final List<String> doNow;
  final List<String> avoid;

  const _EmergencyGuidance({required this.doNow, required this.avoid});
}

class _GuidanceBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> messages;

  const _GuidanceBlock({
    required this.title,
    required this.icon,
    required this.color,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ...messages.map((message) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $message'),
            )),
      ],
    );
  }
}

class _QuickTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickTag({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.surfaceContainerHighest),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
