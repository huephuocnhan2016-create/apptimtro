import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../domain/user.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({
    required this.role,
    required this.isLogin,
    super.key,
  });
  final UserRole role;
  final bool isLogin;
  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _phone = TextEditingController();

  Future<void> _send() async {
    final phone = _phone.text.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+?[\d]{9,12}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại hợp lệ.')),
      );
      return;
    }
    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendOtp(phone, widget.role);
    if (!mounted) return;
    if (sent == null) {
      showAuthError(context, ref);
      return;
    }
    context.push(
      '/otp?role=${widget.role.name.toUpperCase()}'
      '&flow=${widget.isLogin ? 'login' : 'register'}',
      extra: {'phone': phone, 'devOtp': sent.devOtp},
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Số điện thoại của bạn',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Mã xác thực sẽ được gửi đến số điện thoại này.'),
        const SizedBox(height: AppSpace.xl),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          onSubmitted: (_) => _send(),
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            prefixText: '+84  ',
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          label: 'Gửi mã xác thực',
          busy: ref.watch(authControllerProvider).isLoading,
          onPressed: _send,
        ),
      ],
    ),
  );
}

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    required this.phone,
    required this.role,
    required this.isLogin,
    this.devOtp,
    super.key,
  });
  final String phone;
  final UserRole role;
  final bool isLogin;
  final String? devOtp;
  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  /// Số giây phải chờ trước khi được gửi lại mã.
  static const _resendAfter = 60;

  final _pin = TextEditingController();
  late String? _devOtp = widget.devOtp;
  Timer? _timer;
  int _secondsLeft = _resendAfter;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = _resendAfter;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsLeft <= 1) timer.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify() async {
    if (_pin.text.length != 6 || ref.read(authControllerProvider).isLoading) {
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    final verificationToken = await controller.verifyOtp(
      widget.phone,
      _pin.text,
    );
    if (!mounted) return;
    if (verificationToken == null) {
      showAuthError(context, ref);
      return;
    }
    if (!widget.isLogin) {
      final role = widget.role == UserRole.landlord ? 'landlord' : 'student';
      context.go(
        '/register/$role',
        extra: {'phone': widget.phone, 'verificationToken': verificationToken},
      );
      return;
    }
    final user = await controller.login(
      phone: widget.phone,
      verificationToken: verificationToken,
    );
    if (!mounted) return;
    if (user == null) {
      showAuthError(context, ref);
      return;
    }
    context.go('/home');
  }

  Future<void> _resend() async {
    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendOtp(widget.phone, widget.role);
    if (!mounted) return;
    if (sent == null) {
      showAuthError(context, ref);
      return;
    }
    _pin.clear();
    setState(() {
      _devOtp = sent.devOtp;
      _startCountdown();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã gửi lại mã OTP.')));
  }

  void _changePhone() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    final devOtp = _devOtp;
    return AuthScaffold(
      title: 'Nhập mã xác thực',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: 'Mã OTP gồm 6 chữ số đã gửi đến ',
              children: [
                TextSpan(
                  text: widget.phone,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontFeatures: AppTypography.tabularFigures),
                ),
              ],
            ),
          ),
          if (devOtp != null) ...[
            const SizedBox(height: AppSpace.lg),
            _DevOtpBanner(devOtp: devOtp),
          ],
          const SizedBox(height: AppSpace.xxl),
          Pinput(
            length: 6,
            controller: _pin,
            keyboardType: TextInputType.number,
            onCompleted: (_) => _verify(),
          ),
          const SizedBox(height: AppSpace.xxl),
          AppButton(label: 'Xác nhận', busy: busy, onPressed: _verify),
          Row(
            children: [
              TextButton(
                onPressed: busy || _secondsLeft > 0 ? null : _resend,
                child: Text(
                  _secondsLeft > 0
                      ? 'Gửi lại mã sau ${_secondsLeft}s'
                      : 'Gửi lại mã',
                ),
              ),
              TextButton(
                onPressed: busy ? null : _changePhone,
                child: const Text('Đổi số điện thoại'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mã OTP bản dev hiện ngay trên màn hình — bấm để copy, khỏi phải nhìn hai
/// lần giữa ứng dụng và backend.
class _DevOtpBanner extends StatelessWidget {
  const _DevOtpBanner({required this.devOtp});

  final String devOtp;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.lg,
      vertical: AppSpace.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.warningSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.warningSoft),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.vpn_key_outlined,
          size: 18,
          color: AppColors.warningInk,
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: SelectableText(
            'Mã OTP phát triển: $devOtp',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.warningInk,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy mã',
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          color: AppColors.warningInk,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: devOtp));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Đã copy mã OTP.')));
          },
        ),
      ],
    ),
  );
}
