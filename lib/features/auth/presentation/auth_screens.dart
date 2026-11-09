import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_api.dart';
import '../domain/user.dart';
import '../../../shared/widgets/app_button.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = user;
      context.go(user == null ? '/welcome' : '/home');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.house_rounded, size: 68, color: AppColors.brand),
          SizedBox(height: 12),
          Text(
            'Trọ Tốt',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => _AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const Icon(Icons.apartment_rounded, size: 74, color: AppColors.brand),
        const SizedBox(height: 28),
        Text(
          'Tìm trọ dễ dàng,\nan tâm bắt đầu',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text('Kết nối sinh viên với nơi ở phù hợp ngay gần trường.'),
        const Spacer(),
        AppButton(label: 'Đăng nhập', onPressed: () => context.go('/login')),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/register-role'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
          child: const Text('Tạo tài khoản'),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class AuthFlowExpiredScreen extends StatelessWidget {
  const AuthFlowExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Phiên xác thực đã hết',
    child: Column(
      children: [
        const SizedBox(height: 12),
        const Text('Vui lòng bắt đầu lại để xác thực số điện thoại.'),
        const SizedBox(height: 20),
        AppButton(label: 'Quay lại', onPressed: () => context.go('/welcome')),
      ],
    ),
  );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Chào mừng trở lại',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Đăng nhập bằng số điện thoại. Chúng tôi sẽ gửi mã xác thực OTP cho bạn.',
        ),
        const SizedBox(height: 28),
        AppButton(
          label: 'Tiếp tục với số điện thoại',
          onPressed: () => context.push('/phone?flow=login&role=STUDENT'),
        ),
        TextButton(
          onPressed: () => context.go('/register-role'),
          child: const Text('Bạn chưa có tài khoản? Đăng ký'),
        ),
      ],
    ),
  );
}

class RegisterRoleScreen extends StatelessWidget {
  const RegisterRoleScreen({super.key});
  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Bạn tham gia với vai trò nào?',
    child: Column(
      children: [
        const SizedBox(height: 24),
        _RoleCard(
          icon: Icons.school_rounded,
          title: 'Tôi là sinh viên',
          subtitle: 'Tìm kiếm phòng trọ phù hợp',
          onTap: () => context.push('/phone?role=STUDENT'),
        ),
        const SizedBox(height: 14),
        _RoleCard(
          icon: Icons.key_rounded,
          title: 'Tôi là chủ trọ',
          subtitle: 'Tạo tài khoản chủ nhà',
          onTap: () => context.push('/phone?role=LANDLORD'),
        ),
      ],
    ),
  );
}

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
  bool _busy = false;

  Future<void> _send() async {
    final phone = _phone.text.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+?[\d]{9,12}$').hasMatch(phone)) {
      _message('Vui lòng nhập số điện thoại hợp lệ.');
      return;
    }
    setState(() => _busy = true);
    try {
      final devOtp = await ref
          .read(authRepositoryProvider)
          .sendOtp(phone, widget.role);
      if (mounted) {
        context.push(
          '/otp?role=${widget.role.name.toUpperCase()}'
          '&flow=${widget.isLogin ? 'login' : 'register'}',
          extra: {
            'phone': phone,
            'devOtp': devOtp,
          },
        );
      }
    } on DioException catch (error) {
      if (mounted) _message(AuthException.fromDio(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Số điện thoại của bạn',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Mã xác thực sẽ được gửi đến số điện thoại này.'),
        const SizedBox(height: 22),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            prefixText: '+84  ',
          ),
        ),
        const SizedBox(height: 22),
        AppButton(label: 'Gửi mã xác thực', busy: _busy, onPressed: _send),
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
  final _pin = TextEditingController();
  bool _busy = false;

  Future<void> _verify() async {
    if (_pin.text.length != 6 || _busy) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final verificationToken = await repository.verifyOtp(
        widget.phone,
        _pin.text,
      );
      if (widget.isLogin) {
        final user = await repository.login(
          phone: widget.phone,
          verificationToken: verificationToken,
        );
        ref.read(currentUserProvider.notifier).state = user;
        if (mounted) context.go('/home');
      } else if (mounted) {
        final role = widget.role == UserRole.landlord ? 'landlord' : 'student';
        context.go(
          '/register/$role',
          extra: {
            'phone': widget.phone,
            'verificationToken': verificationToken,
          },
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthException.fromDio(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Nhập mã xác thực',
    child: Column(
      children: [
        const SizedBox(height: 10),
        Text('Mã OTP gồm 6 chữ số đã gửi đến ${widget.phone}'),
        if (widget.devOtp != null) ...[
          const SizedBox(height: 16),
          SelectableText(
            'Mã OTP phát triển: ${widget.devOtp}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 26),
        Pinput(
          length: 6,
          controller: _pin,
          keyboardType: TextInputType.number,
          onCompleted: (_) => _verify(),
        ),
        const SizedBox(height: 28),
        AppButton(label: 'Xác nhận', busy: _busy, onPressed: _verify),
      ],
    ),
  );
}

class StudentRegisterScreen extends ConsumerStatefulWidget {
  const StudentRegisterScreen({
    required this.phone,
    required this.verificationToken,
    super.key,
  });
  final String phone;
  final String verificationToken;
  @override
  ConsumerState<StudentRegisterScreen> createState() =>
      _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends ConsumerState<StudentRegisterScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .register(
            phone: widget.phone,
            verificationToken: widget.verificationToken,
            role: UserRole.student,
            fullName: _name.text.trim(),
          );
      ref.read(currentUserProvider.notifier).state = user;
      if (mounted) context.go('/home');
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthException.fromDio(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Tạo hồ sơ sinh viên',
    child: Column(
      children: [
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
        ),
        const SizedBox(height: 20),
        AppButton(label: 'Hoàn tất đăng ký', busy: _busy, onPressed: _submit),
      ],
    ),
  );
}

class LandlordRegisterScreen extends ConsumerStatefulWidget {
  const LandlordRegisterScreen({
    required this.phone,
    required this.verificationToken,
    super.key,
  });
  final String phone;
  final String verificationToken;
  @override
  ConsumerState<LandlordRegisterScreen> createState() =>
      _LandlordRegisterScreenState();
}

class _LandlordRegisterScreenState
    extends ConsumerState<LandlordRegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || !_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập họ tên và email hợp lệ.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .register(
            phone: widget.phone,
            verificationToken: widget.verificationToken,
            role: UserRole.landlord,
            fullName: _name.text.trim(),
            email: _email.text.trim(),
          );
      ref.read(currentUserProvider.notifier).state = user;
      if (mounted) context.go('/home');
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthException.fromDio(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Tạo tài khoản chủ trọ',
    child: Column(
      children: [
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 20),
        AppButton(label: 'Hoàn tất đăng ký', busy: _busy, onPressed: _submit),
      ],
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: AppColors.brandSoft,
        child: Icon(icon, color: AppColors.brand),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
    ),
  );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.child, this.title});
  final Widget child;
  final String? title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: title == null ? null : AppBar(title: Text(title!)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: title == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: child),
                ],
              ),
      ),
    ),
  );
}
