import 'package:apptimtro/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application theme uses Material 3', () {
    expect(AppTheme.light.useMaterial3, isTrue);
  });
}
