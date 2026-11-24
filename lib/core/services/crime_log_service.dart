// SentinelX - Crime Log API Service
// Wraps CrimeLog CRUD endpoints from the Node.js backend.

import 'package:sentinel_x/core/services/api_service.dart';

class CrimeLogService {
  final ApiService _api;

  CrimeLogService(this._api);

  /// Fetch paginated crime logs with optional filters.
  Future<Map<String, dynamic>?> getLogs({
    int page = 1,
    int limit = 20,
    String? severity,
    String? threatClass,
    String? cameraId,
    bool? acknowledged,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (severity != null) params['severity'] = severity;
    if (threatClass != null) params['threatClass'] = threatClass;
    if (cameraId != null) params['cameraId'] = cameraId;
    if (acknowledged != null) params['acknowledged'] = acknowledged.toString();
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();

    final response = await _api.get('/api/logs', queryParams: params);
    if (response.isOk) return response.data;
    return null;
  }

  /// Fetch aggregate stats (by severity, by class, last 24h count).
  Future<Map<String, dynamic>?> getStats() async {
    final response = await _api.get('/api/logs/stats');
    if (response.isOk) return response.data;
    return null;
  }

  /// Acknowledge a crime log entry.
  Future<bool> acknowledgeLog(String logId) async {
    final response = await _api.patch('/api/logs/$logId/acknowledge');
    return response.success;
  }

  /// Delete a log entry (admin only).
  Future<bool> deleteLog(String logId) async {
    final response = await _api.delete('/api/logs/$logId');
    return response.success;
  }

  /// Create a new crime log directly.
  Future<Map<String, dynamic>?> createCrimeLog(Map<String, dynamic> logData) async {
    final response = await _api.post('/api/logs', body: logData);
    if (response.isOk) return response.data?['data'] as Map<String, dynamic>?;
    return null;
  }

  /// Update dispatch status (e.g. assigned_police, en_route, on_scene, resolved).
  Future<bool> updateDispatchStatus(
    String logId, {
    required String status,
    String? assignedTo,
    String? notes,
    bool? isSimulatedUnit,
  }) async {
    final body = <String, dynamic>{
      'dispatchStatus': status,
    };
    if (assignedTo != null) body['assignedTo'] = assignedTo;
    if (notes != null) body['policeNotes'] = notes;
    if (isSimulatedUnit != null) body['isSimulatedUnit'] = isSimulatedUnit;

    final response = await _api.patch('/api/logs/$logId/dispatch', body: body);
    return response.success;
  }

  /// Submit a new detection payload directly to the ML endpoint.
  Future<Map<String, dynamic>?> runDetection({
    required String cameraId,
    String? location,
    String? frameTimestamp,
  }) async {
    final response = await _api.post(
      '/api/detect',
      body: {
        'cameraId': cameraId,
        'location': location,
        'frameTimestamp': frameTimestamp ?? DateTime.now().toIso8601String(),
      },
      timeout: ApiConfig.detectTimeout,
    );
    if (response.isOk) return response.data?['data'] as Map<String, dynamic>?;
    return null;
  }
}
