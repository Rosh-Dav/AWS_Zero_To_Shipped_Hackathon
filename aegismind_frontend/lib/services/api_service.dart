import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/incident.dart';

/// Centralised HTTP service for all AegisMind API calls.
class ApiService {
  // ── GET /sos — Fetch all incidents ──────────────────────────────────────
  static Future<List<Incident>> fetchIncidents() async {
    final response = await http.get(Uri.parse(ApiConfig.baseUrl));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Incident.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load incidents: ${response.statusCode}');
    }
  } 

  // ── POST /sos — Submit a new SOS distress report ───────────────────────
  static Future<({Incident incident, bool merged})> submitSOS({
    required String message,
    double? latitude,
    double? longitude,
    String? locationText,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'message': message, // Changed to match backend expected field 'message'
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationText != null && locationText.isNotEmpty) 'locationText': locationText,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return (
        incident: Incident.fromJson(data['incident']),
        merged: data['merged'] as bool? ?? false,
      );
    } else {
      dynamic errorBody;
      try {
        errorBody = json.decode(response.body);
      } catch (_) {}
      
      throw Exception(
        (errorBody is Map && errorBody['error'] != null) ? errorBody['error'] : 'Failed to submit SOS',
      );
    }
  }

  // ── GET /sos/{incidentId} — Fetch specific incident status ───────────────
  static Future<Map<String, dynamic>> fetchStatus(String idOrRef) async {
    final normalizedId = idOrRef.trim().toLowerCase();
    final baseUrl = ApiConfig.baseUrl.endsWith('/') 
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) 
        : ApiConfig.baseUrl;
    final url = '$baseUrl/${Uri.encodeComponent(normalizedId)}';
    debugPrint('Fetching SOS status: $url');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'Failed to fetch status for ID $normalizedId: HTTP ${response.statusCode}',
      );
    }
  }

  // ── PATCH /sos/{incidentId} — Update incident status ───────────────────
  static Future<Incident> updateStatus({
    required String incidentId,
    required String status,
    int? etaMinutes,
  }) async {
    final baseUrl = ApiConfig.baseUrl.endsWith('/') 
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) 
        : ApiConfig.baseUrl;
        
    final Map<String, dynamic> body = {'status': status};
    if (etaMinutes != null) {
      body['etaMinutes'] = etaMinutes;
    }
    
    final response = await http.patch(
      Uri.parse('$baseUrl/$incidentId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Incident.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update status: ${response.statusCode}');
    }
  }
}
