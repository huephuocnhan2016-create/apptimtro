class AppConstants {
  const AppConstants._();

  static const appName = 'Trọ Tốt';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  /// Ảnh do máy chủ phục vụ (`/uploads/...`) được lưu ở dạng đường dẫn tương
  /// đối, nên ghép lại theo nơi app đang gọi API: đổi cổng 3000 → 3300 hay
  /// lên tên miền thật đều không phải viết lại hàng trăm dòng trong DB.
  static String resolveAssetUrl(String url) {
    if (!url.startsWith('/')) return url;
    return '${Uri.parse(apiBaseUrl).origin}$url';
  }
}
