import 'package:apptimtro/core/theme/app_theme.dart';
import 'package:apptimtro/features/auth/domain/user.dart';
import 'package:apptimtro/features/auth/presentation/otp_screen.dart';
import 'package:apptimtro/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';

void main() {
  test('application theme uses Material 3', () {
    expect(AppTheme.light.useMaterial3, isTrue);
  });

  testWidgets('OTP input renders inside the application Material scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Pinput(length: 6)),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('development OTP is shown without filling the input', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: OtpVerificationScreen(
            phone: '+84987654321',
            role: UserRole.student,
            isLogin: false,
            devOtp: '123456',
          ),
        ),
      ),
    );

    final input = tester.widget<Pinput>(find.byType(Pinput));
    expect(find.text('Mã OTP phát triển: 123456'), findsOneWidget);
    expect(input.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nút gửi lại OTP bị khoá 60 giây rồi mới bấm được', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: OtpVerificationScreen(
            phone: '+84987654321',
            role: UserRole.student,
            isLogin: true,
          ),
        ),
      ),
    );

    expect(find.text('Gửi lại mã sau 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Gửi lại mã'), findsOneWidget);
    expect(find.text('Đổi số điện thoại'), findsOneWidget);
  });

  testWidgets('form đăng ký chủ trọ cuộn được trên màn hình thấp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RegisterFormScreen(
            phone: '+84987654321',
            verificationToken: 'token',
            role: UserRole.landlord,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Hoàn tất đăng ký'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hoàn tất đăng ký'), findsOneWidget);
  });

  testWidgets('form đăng ký sinh viên không có ô email', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RegisterFormScreen(
            phone: '+84987654321',
            verificationToken: 'token',
            role: UserRole.student,
          ),
        ),
      ),
    );

    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Hoàn tất đăng ký'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hoàn tất đăng ký'), findsOneWidget);
  });
}
