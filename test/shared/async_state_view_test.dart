import 'package:apptimtro/shared/widgets/async_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('lỗi → hiện lý do và nút Thử lại gọi lại được', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<int>>(
          snapshot: AsyncStateView.snapshotOf<List<int>>(
            AsyncError(Exception('mất mạng'), StackTrace.empty),
          ),
          errorPrefix: 'Không tải được phòng',
          onRetry: () => retried++,
          builder: (_, _) => const Text('data'),
        ),
      ),
    );

    expect(find.textContaining('Không tải được phòng'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retried, 1);
  });

  testWidgets('danh sách rỗng → hiện thông báo rỗng', (tester) async {
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<int>>(
          snapshot: AsyncStateView.snapshotOf(const AsyncData(<int>[])),
          emptyMessage: 'Chưa có gì.',
          builder: (_, _) => const Text('data'),
        ),
      ),
    );
    expect(find.text('Chưa có gì.'), findsOneWidget);
  });

  testWidgets('có dữ liệu → vẽ builder; đang tải → vòng xoay', (tester) async {
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<int>>(
          snapshot: AsyncStateView.snapshotOf(const AsyncData([1, 2])),
          builder: (_, data) => Text('${data.length} phòng'),
        ),
      ),
    );
    expect(find.text('2 phòng'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        AsyncStateView<List<int>>(
          snapshot: AsyncStateView.snapshotOf<List<int>>(const AsyncLoading()),
          builder: (_, _) => const Text('data'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
