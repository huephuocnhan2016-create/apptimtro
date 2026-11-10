import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../auth/domain/user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                radius: 28,
                child: Text(
                  (user?.fullName?.isNotEmpty ?? false)
                      ? user!.fullName!.characters.first.toUpperCase()
                      : 'T',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              title: Text(
                user?.fullName ?? 'Thành viên Trọ Tốt',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(user?.phone ?? ''),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Vai trò'),
                  subtitle: Text(user?.role.name.toUpperCase() ?? 'STUDENT'),
                ),
                if (user?.role == UserRole.student)
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Phòng đã đặt cọc'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/deposits'),
                  ),
                if (user?.role == UserRole.landlord)
                  ListTile(
                    leading: const Icon(Icons.home_work_outlined),
                    title: const Text('Quản lý phòng trọ'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/landlord'),
                  ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
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
