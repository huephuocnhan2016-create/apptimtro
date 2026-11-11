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

/// Hồ sơ sau khi OTP đã xác minh. Sinh viên chỉ cần họ tên; chủ trọ khai thêm
/// email vì tin phòng và hợp đồng gửi qua đó, nên form dài hơn hẳn.
class RegisterFormScreen extends ConsumerStatefulWidget {
  const RegisterFormScreen({
    required this.phone,
    required this.verificationToken,
    required this.role,
    super.key,
  });

  final String phone;
  final String verificationToken;
  final UserRole role;

  @override
  ConsumerState<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends ConsumerState<RegisterFormScreen> {
  bool get _isStudent => widget.role == UserRole.student;

  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _showNameError = false;
  bool _showEmailError = false;

  bool get _nameInvalid => _name.text.trim().isEmpty;
  bool get _emailInvalid => !_email.text.contains('@');

  Future<void> _submit() async {
    final emailRequired = !_isStudent && _emailInvalid;
    if (_nameInvalid || emailRequired) {
      setState(() {
        _showNameError = _nameInvalid;
        _showEmailError = emailRequired;
      });
      return;
    }
    await _submitRegistration(
      context,
      ref,
      phone: widget.phone,
      verificationToken: widget.verificationToken,
      role: widget.role,
      fullName: _name.text.trim(),
      email: _isStudent ? null : _email.text.trim(),
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
    title: _isStudent ? 'Tạo hồ sơ sinh viên' : 'Tạo tài khoản chủ trọ',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerifiedNotice(phone: widget.phone),
        const SizedBox(height: AppSpace.xl),
        TextField(
          controller: _name,
          // Sinh viên chỉ có một ô nên focus luôn và phím "done" gửi form;
          // chủ trọ còn email phía sau nên "next" phải đưa sang ô đó.
          autofocus: _isStudent,
          textCapitalization: TextCapitalization.words,
          textInputAction: _isStudent
              ? TextInputAction.done
              : TextInputAction.next,
          onChanged: (_) {
            if (_showNameError) setState(() => _showNameError = false);
          },
          onSubmitted: _isStudent ? (_) => _submit() : null,
          decoration: InputDecoration(
            labelText: 'Họ và tên',
            errorText: _showNameError ? 'Vui lòng nhập họ tên.' : null,
          ),
        ),
        if (_isStudent)
          const SizedBox(height: AppSpace.xl)
        else ...[
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
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.lg),
        ],
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
          style: Theme.of(context).textTheme.bodyMedium,
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
