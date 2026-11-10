import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/staggered_enter.dart';
import 'widgets/auth_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          StaggeredEnter(
            index: 0,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.apartment_rounded,
                size: 38,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          StaggeredEnter(
            index: 1,
            child: Text(
              'Tìm trọ dễ dàng,\nan tâm bắt đầu',
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEnter(
            index: 2,
            child: Text(
              'Kết nối sinh viên với nơi ở phù hợp ngay gần trường.',
              style: text.bodyLarge?.copyWith(color: AppColors.muted),
            ),
          ),
          const Spacer(),
          StaggeredEnter(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Đăng nhập',
                  onPressed: () => context.go('/login'),
                ),
                const SizedBox(height: AppSpace.md),
                OutlinedButton(
                  onPressed: () => context.go('/register-role'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Tạo tài khoản'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
        ],
      ),
    );
  }
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
        const SizedBox(height: AppSpace.xl),
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
        Text(
          'Đăng nhập bằng số điện thoại. Chúng tôi sẽ gửi mã xác thực OTP cho bạn.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.xl),
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
        RoleCard(
          icon: Icons.school_outlined,
          title: 'Tôi là sinh viên',
          subtitle: 'Tìm kiếm phòng trọ phù hợp',
          onTap: () => context.push('/phone?role=STUDENT'),
        ),
        const SizedBox(height: AppSpace.md),
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
