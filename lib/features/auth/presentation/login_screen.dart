import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_button.dart';
import 'widgets/auth_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Icon(
          Icons.apartment_rounded,
          size: 74,
          color: Theme.of(context).colorScheme.primary,
        ),
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
            minimumSize: const Size.fromHeight(48),
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
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Phiên xác thực đã hết',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Vui lòng bắt đầu lại để xác thực số điện thoại.'),
        const SizedBox(height: 24),
        AppButton(label: 'Quay lại', onPressed: () => context.go('/welcome')),
      ],
    ),
  );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Chào mừng trở lại',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Đăng nhập bằng số điện thoại. Chúng tôi sẽ gửi mã xác thực OTP cho bạn.',
        ),
        const SizedBox(height: 24),
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
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Bạn tham gia với vai trò nào?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        RoleCard(
          icon: Icons.school_outlined,
          title: 'Tôi là sinh viên',
          subtitle: 'Tìm kiếm phòng trọ phù hợp',
          onTap: () => context.push('/phone?role=STUDENT'),
        ),
        const SizedBox(height: 8),
        RoleCard(
          icon: Icons.key_outlined,
          title: 'Tôi là chủ trọ',
          subtitle: 'Tạo tài khoản chủ nhà',
          onTap: () => context.push('/phone?role=LANDLORD'),
        ),
      ],
    ),
  );
}
