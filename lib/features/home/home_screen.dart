import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../auth/domain/user.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Khám phá')),
    body: _HomeLanding(
      isLandlord: ref.watch(currentUserProvider)?.role == UserRole.landlord,
    ),
  );
}

/// Trang đầu theo kiểu Android: ô tìm kiếm ở trên, bên dưới là danh sách
/// `ListTile` trong `Card` dẫn tới các chức năng.
class _HomeLanding extends StatelessWidget {
  const _HomeLanding({required this.isLandlord});

  final bool isLandlord;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Tìm chỗ ở mới?',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        'Khám phá phòng trọ phù hợp với bạn.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        readOnly: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Tìm theo khu vực, trường học',
        ),
        onTap: () => context.push('/rooms/search'),
      ),
      const SizedBox(height: 16),
      _MenuTile(
        icon: Icons.search,
        title: 'Tìm phòng trọ',
        subtitle: 'Lọc theo giá, diện tích, tiện ích',
        onTap: () => context.push('/rooms/search'),
      ),
      _MenuTile(
        icon: Icons.map_outlined,
        title: 'Khám phá trên bản đồ',
        subtitle: 'Phòng trọ gần vị trí của bạn',
        // /map là một tab: chuyển tab (go) để thanh điều hướng sáng đúng.
        onTap: () => context.go('/map'),
      ),
      _MenuTile(
        icon: Icons.chat_outlined,
        title: 'Tin nhắn',
        subtitle: 'Trao đổi với chủ trọ',
        onTap: () => context.push('/chats'),
      ),
      if (isLandlord)
        _MenuTile(
          icon: Icons.home_work_outlined,
          title: 'Quản lý phòng trọ',
          subtitle: 'Đăng tin và quản lý phòng của bạn',
          onTap: () => context.push('/landlord'),
        ),
    ],
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
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
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
