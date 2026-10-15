class AppConstants {
  const AppConstants._();

  static const appName = 'Trọ Tốt';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );
}
