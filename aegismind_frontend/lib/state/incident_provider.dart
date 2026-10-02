import 'dart:async';
import 'package:flutter/material.dart';
import '../models/incident.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class IncidentProvider extends ChangeNotifier {
  List<Incident> _incidents = [];
  bool _isLoading = true;
  bool _isConnected = false;
  DateTime? _lastUpdated;
  Timer? _pollingTimer;

  List<Incident> get incidents => _incidents;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  DateTime? get lastUpdated => _lastUpdated;

  IncidentProvider() {
    fetchIncidents();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(ApiConfig.pollInterval, (_) => _silentFetch());
  }

  Future<void> fetchIncidents() async {
    _isLoading = true;
    notifyListeners();
    await _silentFetch();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _silentFetch() async {
    try {
      final newIncidents = await ApiService.fetchIncidents();
      
      // Basic check for new incidents (if first item's ID changed)
      bool hasNew = false;
      if (_incidents.isNotEmpty && newIncidents.isNotEmpty) {
        if (_incidents.first.incidentId != newIncidents.first.incidentId) {
          hasNew = true;
        }
      }

      _incidents = newIncidents;
      _isConnected = true;
      _lastUpdated = DateTime.now();
      
      if (hasNew) {
        // You could trigger a local notification here if desired
      }
      
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String incidentId, String newStatus, {int? etaMinutes}) async {
    try {
      await ApiService.updateStatus(incidentId: incidentId, status: newStatus, etaMinutes: etaMinutes);
      await _silentFetch();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
