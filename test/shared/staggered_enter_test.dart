import 'package:apptimtro/core/theme/app_theme.dart';
import 'package:apptimtro/shared/widgets/staggered_enter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('vào màn trong MaterialApp không báo lỗi, hiện nội dung', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const StaggeredEnter(index: 2, child: Text('Gợi ý cho bạn'))),
    );
    expect(tester.takeException(), isNull);

    await tester.pump(AppMotion.stagger * 2);
    await tester.pump(AppMotion.enter);
    expect(find.text('Gợi ý cho bạn'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });

  testWidgets('tắt hiệu ứng hệ thống thì hiện ngay, không chờ', (tester) async {
    await tester.pumpWidget(
      _host(
        const StaggeredEnter(index: 4, child: Text('Ảnh phòng')),
        reduceMotion: true,
      ),
    );
    expect(find.text('Ảnh phòng'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });
}
