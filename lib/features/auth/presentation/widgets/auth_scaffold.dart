import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Khung chung của các màn đăng nhập/đăng ký.
///
/// Có [title] → nội dung cuộn được, nên bật bàn phím ở form đăng ký không còn
/// bị sọc vàng "RenderFlex overflowed"; ô đang nhập tự cuộn lên trên bàn phím.
/// Không có [title] (màn chào mừng) → giữ bố cục cố định để dùng được `Spacer`.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.child, this.title, super.key});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title)),
      body: SafeArea(
        child: title == null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
                child: child,
              )
            : SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xxl,
                  AppSpace.xl,
                  AppSpace.xxl,
                  AppSpace.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    child,
                  ],
                ),
              ),
      ),
    );
  }
}

/// Thẻ chọn vai trò (sinh viên / chủ trọ).
class RoleCard extends StatelessWidget {
  const RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(AppSpace.lg),
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
