/// Central API configuration for the AegisMind frontend.
class ApiConfig {
  /// Base URL for the deployed AWS API Gateway endpoint.
  /// Set this via --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://y27bidor5b.execute-api.ap-south-1.amazonaws.com/prod/sos');

  /// Polling interval for the dispatch dashboard auto-refresh.
  static const Duration pollInterval = Duration(seconds: 5); // Changed to 5s as per prompt
}
