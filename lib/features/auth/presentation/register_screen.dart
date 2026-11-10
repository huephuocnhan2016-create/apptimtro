import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../domain/user.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Gửi đăng ký rồi về trang chủ; lỗi thì hiện SnackBar.
Future<void> _submitRegistration(
  BuildContext context,
  WidgetRef ref, {
  required String phone,
  required String verificationToken,
  required UserRole role,
  required String fullName,
  String? email,
}) async {
  final user = await ref
      .read(authControllerProvider.notifier)
      .register(
        phone: phone,
        verificationToken: verificationToken,
        role: role,
        fullName: fullName,
        email: email,
      );
  if (!context.mounted) return;
  if (user == null) {
    showAuthError(context, ref);
    return;
  }
  context.go('/home');
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
  bool _showError = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    await _submitRegistration(
      context,
      ref,
      phone: widget.phone,
      verificationToken: widget.verificationToken,
      role: UserRole.student,
      fullName: _name.text.trim(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Tạo hồ sơ sinh viên',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerifiedNotice(phone: widget.phone),
        const SizedBox(height: AppSpace.xl),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Họ và tên',
            errorText: _showError ? 'Vui lòng nhập họ tên.' : null,
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          label: 'Hoàn tất đăng ký',
          busy: ref.watch(authControllerProvider).isLoading,
          onPressed: _submit,
        ),
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
  bool _showNameError = false;
  bool _showEmailError = false;

  bool get _nameInvalid => _name.text.trim().isEmpty;
  bool get _emailInvalid => !_email.text.contains('@');

  Future<void> _submit() async {
    if (_nameInvalid || _emailInvalid) {
      setState(() {
        _showNameError = _nameInvalid;
        _showEmailError = _emailInvalid;
      });
      return;
    }
    await _submitRegistration(
      context,
      ref,
      phone: widget.phone,
      verificationToken: widget.verificationToken,
      role: UserRole.landlord,
      fullName: _name.text.trim(),
      email: _email.text.trim(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Tạo tài khoản chủ trọ',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerifiedNotice(phone: widget.phone),
        const SizedBox(height: AppSpace.xl),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_showNameError) setState(() => _showNameError = false);
          },
          decoration: InputDecoration(
            labelText: 'Họ và tên',
            errorText: _showNameError ? 'Vui lòng nhập họ tên.' : null,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_showEmailError) setState(() => _showEmailError = false);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: _showEmailError ? 'Email chưa đúng.' : null,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'Bạn sẽ dùng tài khoản này để đăng và quản lý phòng trọ.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.lg),
        AppButton(
          label: 'Hoàn tất đăng ký',
          busy: ref.watch(authControllerProvider).isLoading,
          onPressed: _submit,
        ),
      ],
    ),
  );
}

/// Dấu xác minh đã hoàn tất — bước cuối của đăng ký nên nói cho người dùng biết
/// họ đã đi được tới đâu thay vì để form tự hỏi.
class _VerifiedNotice extends StatelessWidget {
  const _VerifiedNotice({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Text(
          'Đã xác minh số điện thoại',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
      ),
      Text(
        phone,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontFeatures: AppTypography.tabularFigures),
      ),
    ],
  );
}
