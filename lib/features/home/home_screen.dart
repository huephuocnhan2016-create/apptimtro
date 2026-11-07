import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../auth/domain/user.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  static const _titles = ['Khám phá', 'Bản đồ', 'Yêu thích', 'Tài khoản'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[_index])),
    body: _index == 0
        ? _HomeLanding(
            isLandlord:
                ref.watch(currentUserProvider)?.role == UserRole.landlord,
          )
        : Center(
            child: Text(
              _titles[_index],
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (index) {
        setState(() => _index = index);
        if (index == 3) context.go('/profile');
        if (index == 1) context.go('/map');
        if (index == 2) context.go('/favorites');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Bản đồ'),
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

class _HomeLanding extends StatelessWidget {
  const _HomeLanding({required this.isLandlord});

  final bool isLandlord;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Text(
        'Tìm chỗ ở mới?',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text('Khám phá phòng trọ phù hợp với bạn.'),
      const SizedBox(height: 22),
      TextField(
        readOnly: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Tìm theo khu vực, trường học',
        ),
        onTap: () => context.push('/rooms/search'),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => context.push('/rooms/search'),
        icon: const Icon(Icons.search),
        label: const Text('Tìm phòng trọ'),
      ),
      OutlinedButton.icon(
        onPressed: () => context.push('/map'),
        icon: const Icon(Icons.map_outlined),
        label: const Text('Khám phá trên bản đồ'),
      ),
      OutlinedButton.icon(
        onPressed: () => context.push('/chats'),
        icon: const Icon(Icons.chat_outlined),
        label: const Text('Tin nhắn'),
      ),
      if (isLandlord) ...[
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.home_work_outlined),
            title: const Text('Quản lý phòng trọ'),
            subtitle: const Text('Đăng tin và quản lý phòng của bạn'),
            onTap: () => context.push('/landlord'),
          ),
        ),
      ],
    ],
  );
}
