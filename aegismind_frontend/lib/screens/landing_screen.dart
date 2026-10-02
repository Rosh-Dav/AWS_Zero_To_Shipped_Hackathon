import 'package:flutter/material.dart';
import '../screens/sos_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/tracker_screen.dart';
import '../widgets/glass_panel.dart';
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _refController = TextEditingController();
  static String? _lastReferenceId;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  void _trackReport(String refId) {
    final normalizedId = refId.trim().toLowerCase();
    if (normalizedId.isEmpty) return;
    _lastReferenceId = normalizedId;
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackerScreen(referenceId: normalizedId)));
  }

  String _displayReferenceId(String id) {
    final trimmed = id.trim();
    return trimmed.length >= 8 ? trimmed.substring(0, 8).toUpperCase() : trimmed.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.shield_rounded, size: 80, color: cs.primary),
              const SizedBox(height: 24),
              Text(
                'AegisMind',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'AI-Powered Emergency SOS Triage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 60),
              
              // SOS Button
              SizedBox(
                height: 70,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final refId = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen()));
                    if (refId != null && refId is String) {
                      _lastReferenceId = refId;
                      setState(() {});
                      _trackReport(refId);
                    }
                  },
                  icon: const Icon(Icons.warning_amber_rounded, size: 28),
                  label: const Text(
                    'I NEED HELP',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              // Tracker section
              Text(
                'Track my report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _refController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Enter Reference ID',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _trackReport(_refController.text),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Track'),
                    ),
                  ],
                ),
              ),
              if (_lastReferenceId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton.icon(
                    onPressed: () => _trackReport(_lastReferenceId!),
                    icon: const Icon(Icons.history),
                    label: Text('Check your last report (${_displayReferenceId(_lastReferenceId!)})'),
                  ),
                ),
              
              const SizedBox(height: 40),
              
              // Dispatcher Button
              SizedBox(
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                  },
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text(
                    'Dispatcher Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
