// Luật chuyển hướng của router, tách thành hàm thuần để test không cần app.

/// Màn mở được khi chưa đăng nhập.
const publicPaths = {
  '/splash',
  '/welcome',
  '/login',
  '/register-role',
  '/phone',
  '/otp',
  '/register/student',
  '/register/landlord',
};

/// Màn chỉ dành cho khách — đã đăng nhập thì về trang chủ.
const _guestOnlyPaths = {'/welcome', '/login'};

/// Trả về đường dẫn cần chuyển tới, hoặc `null` nếu cho đi tiếp.
///
/// - [sessionRestored]: splash đã đọc xong phiên đăng nhập cũ chưa. Chưa xong
///   thì mọi đường dẫn đều đi qua `/splash?from=...` để không đẩy nhầm người
///   đã đăng nhập về màn login (ví dụ khi app mở lạnh từ deep link).
/// - Deep link `trotot://...?txnRef=` cũng phải qua bước kiểm tra đăng nhập.
String? authRedirect({
  required Uri uri,
  required String matchedLocation,
  required bool sessionRestored,
  required bool loggedIn,
}) {
  final isDeepLink = uri.scheme == 'trotot';
  final target = isDeepLink ? _deepLinkTarget(uri) : uri.toString();

  if (!sessionRestored) {
    if (!isDeepLink && matchedLocation == '/splash') return null;
    return Uri(path: '/splash', queryParameters: {'from': target}).toString();
  }
  if (!loggedIn) {
    if (!isDeepLink && publicPaths.contains(matchedLocation)) return null;
    return '/login';
  }
  if (isDeepLink) return target;
  if (_guestOnlyPaths.contains(matchedLocation)) return '/home';
  return null;
}

String _deepLinkTarget(Uri uri) {
  final txnRef = uri.queryParameters['txnRef'];
  return txnRef == null
      ? '/home'
      : Uri(path: '/payment', queryParameters: {'txnRef': txnRef}).toString();
}
