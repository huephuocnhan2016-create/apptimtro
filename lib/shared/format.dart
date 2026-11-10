import 'package:intl/intl.dart';

final _vnd = NumberFormat.decimalPattern('vi_VN');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final _time = DateFormat.Hm();

/// 1400000 → "1.400.000 đ". Màn thanh toán dùng `unit: 'VND'`.
String formatVnd(num amount, {String unit = 'đ'}) =>
    '${_vnd.format(amount)} $unit';

/// 30 → "30", 30.5 → "30,5" — số đo không kèm đơn vị (diện tích).
String formatNumber(num value) => _vnd.format(value);

/// "dd/MM/yyyy HH:mm" theo giờ máy.
String formatDateVn(DateTime value) => _dateTime.format(value.toLocal());

/// "HH:mm" theo giờ máy.
String formatTimeVn(DateTime value) => _time.format(value.toLocal());
