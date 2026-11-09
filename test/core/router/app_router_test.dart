import 'package:apptimtro/core/router/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

String? go(
  String location, {
  bool restored = true,
  bool loggedIn = false,
}) {
  final uri = Uri.parse(location);
  return authRedirect(
    uri: uri,
    matchedLocation: uri.scheme == 'trotot' ? '' : uri.path,
    sessionRestored: restored,
    loggedIn: loggedIn,
  );
}

void main() {
  group('Guard khi chưa đăng nhập', () {
    test('vào /payment bị đưa về /login', () {
      expect(go('/payment?txnRef=abc'), '/login');
    });

    test('vào /deposits, /landlord, /home đều bị đưa về /login', () {
      for (final path in ['/deposits', '/landlord', '/home', '/profile']) {
        expect(go(path), '/login', reason: path);
      }
    });

    test('các màn đăng nhập/đăng ký vẫn mở được', () {
      for (final path in publicPaths) {
        expect(go(path), isNull, reason: path);
      }
    });
  });

  group('Khi đã đăng nhập', () {
    test('vào màn cần đăng nhập thì cho qua', () {
      expect(go('/deposits', loggedIn: true), isNull);
      expect(go('/payment?txnRef=abc', loggedIn: true), isNull);
    });

    test('mở lại /login hay /welcome thì về trang chủ', () {
      expect(go('/login', loggedIn: true), '/home');
      expect(go('/welcome', loggedIn: true), '/home');
    });
  });

  group('Deep link trotot://', () {
    const link = 'trotot://payment-return?txnRef=abc';

    test('chưa đăng nhập → /login, không vào màn thanh toán', () {
      expect(go(link), '/login');
    });

    test('đã đăng nhập → /payment?txnRef=', () {
      expect(go(link, loggedIn: true), '/payment?txnRef=abc');
    });

    test('thiếu txnRef → trang chủ', () {
      expect(go('trotot://payment-return', loggedIn: true), '/home');
    });

    test('app mở lạnh (chưa đọc phiên) → qua splash, giữ đích đến', () {
      final result = go(link, restored: false);
      final uri = Uri.parse(result!);
      expect(uri.path, '/splash');
      expect(uri.queryParameters['from'], '/payment?txnRef=abc');
    });
  });

  test('chưa đọc phiên thì đứng yên ở splash', () {
    expect(go('/splash', restored: false), isNull);
  });
}
