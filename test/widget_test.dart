import 'package:apptimtro/core/theme/app_theme.dart';
import 'package:apptimtro/features/auth/domain/user.dart';
import 'package:apptimtro/features/auth/presentation/auth_screens.dart';
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
}
