import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_error_message.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_search_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late Future<List<Room>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = ref.read(roomRepositoryProvider).favorites();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Yêu thích'),
      actions: [
        IconButton(
          onPressed: () => setState(() {
            _favorites = ref.read(roomRepositoryProvider).favorites();
          }),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 2,
      onDestinationSelected: (index) {
        if (index == 0) context.go('/home');
        if (index == 1) context.go('/map');
        if (index == 3) context.go('/profile');
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
          selectedIcon: Icon(Icons.favorite),
          label: 'Yêu thích',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Cá nhân',
        ),
      ],
    ),
    body: FutureBuilder<List<Room>>(
      future: _favorites,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Không tải được mục yêu thích: ${apiErrorMessage(snapshot.error!)}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Bạn chưa lưu phòng yêu thích nào.'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final room = snapshot.data![index];
            return Dismissible(
              key: ValueKey(room.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.favorite_border, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                try {
                  await ref.read(roomRepositoryProvider).unfavorite(room.id);
                  return true;
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Không thể bỏ yêu thích: ${apiErrorMessage(error)}',
                        ),
                      ),
                    );
                  }
                  return false;
                }
              },
              child: RoomListTile(room: room),
            );
          },
        );
      },
    ),
  );
}
