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
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(
            radius: 38,
            child: Text(
              (user?.fullName?.isNotEmpty ?? false)
                  ? user!.fullName![0].toUpperCase()
                  : 'T',
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              user?.fullName ?? 'Thành viên Trọ Tốt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(child: Text(user?.phone ?? '')),
          const SizedBox(height: 26),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Vai trò'),
            subtitle: Text(user?.role.name.toUpperCase() ?? 'STUDENT'),
          ),
          if (user?.role == UserRole.student)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Phòng đã đặt cọc'),
              onTap: () => context.push('/deposits'),
            ),
          if (user?.role == UserRole.landlord)
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text('Quản lý phòng trọ'),
              onTap: () => context.push('/landlord'),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(currentUserProvider.notifier).state = null;
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/map');
          if (index == 2) context.go('/favorites');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Bản đồ',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Yêu thích',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
