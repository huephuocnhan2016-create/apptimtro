import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập họ tên.')),
      );
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
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Họ và tên'),
        ),
        const SizedBox(height: 20),
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

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || !_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập họ tên và email hợp lệ.')),
      );
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
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Hoàn tất đăng ký',
          busy: ref.watch(authControllerProvider).isLoading,
          onPressed: _submit,
        ),
      ],
    ),
  );
}
