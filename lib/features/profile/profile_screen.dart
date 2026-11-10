import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/section_card.dart';
import '../auth/domain/user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;
    final entries = <Widget>[
      if (user?.role == UserRole.student)
        _Menu(
          icon: Icons.receipt_long_outlined,
          title: 'Phòng đã đặt cọc',
          onTap: () => context.push('/deposits'),
        ),
      if (user?.role == UserRole.landlord)
        _Menu(
          icon: Icons.home_work_outlined,
          title: 'Quản lý phòng trọ',
          onTap: () => context.push('/landlord'),
        ),
      _Menu(
        icon: Icons.favorite_border,
        title: 'Phòng đã yêu thích',
        // /favorites là một tab: chuyển tab (go) để thanh điều hướng sáng đúng.
        onTap: () => context.go('/favorites'),
      ),
      _Menu(
        icon: Icons.chat_bubble_outline,
        title: 'Cuộc trò chuyện',
        onTap: () => context.go('/chats'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.brandSoft,
                    child: Text(
                      (user?.fullName?.isNotEmpty ?? false)
                          ? user!.fullName!.characters.first.toUpperCase()
                          : 'T',
                      style: text.headlineSmall?.copyWith(
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Thành viên Trọ Tốt',
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(user?.phone ?? '', style: text.bodyMedium),
                        const SizedBox(height: AppSpace.sm),
                        StatusPill(
                          label: user?.role == UserRole.landlord
                              ? 'Chủ trọ'
                              : 'Sinh viên',
                          background: AppColors.surfaceAlt,
                          foreground: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          if (entries.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < entries.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    entries[index],
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.failure),
              title: Text(
                'Đăng xuất',
                style: text.bodyLarge?.copyWith(color: AppColors.failure),
              ),
              onTap: () async {
                final users = ref.read(currentUserProvider.notifier);
                await ref.read(authRepositoryProvider).logout();
                // Xoá user là đủ: router tự đưa về màn đăng nhập.
                users.clearUser();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.brand),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
