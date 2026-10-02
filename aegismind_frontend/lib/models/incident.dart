import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Incident {
  final String incidentId;
  final String timestamp;
  final String rawMessage;
  final double? latitude;
  final double? longitude;
  final String urgency;
  final String category;
  final String summary;
  final List<String> requiredResources;
  final String status;
  final String? updatedAt;
  final String safetyAdvice; // NEW

  Incident({
    required this.incidentId,
    required this.timestamp,
    required this.rawMessage,
    required this.latitude,
    required this.longitude,
    required this.urgency,
    required this.category,
    required this.summary,
    required this.requiredResources,
    required this.status,
    this.updatedAt,
    this.safetyAdvice = '', // NEW
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      incidentId: json['incidentId'] ?? '',
      timestamp: json['timestamp'] ?? '',
      rawMessage: json['rawMessage'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      urgency: json['urgency'] ?? 'MEDIUM',
      category: json['category'] ?? 'General',
      summary: json['summary'] ?? '',
      requiredResources: List<String>.from(json['requiredResources'] ?? []),
      status: json['status'] ?? 'OPEN',
      updatedAt: json['updatedAt'],
      safetyAdvice: json['safetyAdvice'] ?? '', // NEW
    );
  }

  String get referenceId => incidentId.isNotEmpty && incidentId.length >= 8 
      ? incidentId.substring(0, 8).toUpperCase() 
      : incidentId;

  String get timeAgo {
    final now = DateTime.now().toUtc();
    final then = DateTime.tryParse(timestamp)?.toUtc() ?? now;
    final diff = now.difference(then);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool get isCritical => urgency == 'CRITICAL';
  bool get isOpen => status == 'OPEN';

  String? get nextStatus {
    switch (status) {
      case 'OPEN':
        return 'DISPATCHED';
      case 'DISPATCHED':
        return 'RESOLVED';
      default:
        return null;
    }
  }

  String get nextStatusLabel {
    switch (nextStatus) {
      case 'DISPATCHED':
        return 'Mark Dispatched';
      case 'RESOLVED':
        return 'Mark Resolved';
      default:
        return 'Resolved';
    }
  }

  Color urgencyColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (urgency) {
      case 'CRITICAL': return theme.dangerColor;
      case 'HIGH': return theme.warningColor;
      case 'MEDIUM': return theme.successColor;
      default: return theme.idleColor;
    }
  }

  Color statusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case 'OPEN': return theme.dangerColor;
      case 'DISPATCHED': return theme.warningColor;
      case 'RESOLVED': return theme.successColor;
      default: return theme.idleColor;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'medical': return Icons.local_hospital_rounded;
      case 'rescue': return Icons.support_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      default: return Icons.warning_amber_rounded;
    }
  }
}
