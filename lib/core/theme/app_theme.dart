import 'package:flutter/material.dart';

/// Nguồn màu duy nhất của app. Mọi screen dùng `AppColors.x` hoặc
/// `Theme.of(context).colorScheme` — không viết `Color(0x...)` ngoài file này.
abstract final class AppColors {
  // Thương hiệu
  static const brand = Color(0xFF1769E0);
  static const brandDark = Color(0xFF0B4FB8); // điểm cuối gradient
  static const brandSoft = Color(0xFFEAF2FF); // nền nhạt sau icon / ô được chọn
  static const onBrand = Colors.white;
  static const onBrandMuted = Color(0xCCFFFFFF); // chữ phụ trên nền brand
  static const onBrandOverlay = Color(0x33FFFFFF); // pill trong suốt trên nền brand

  // MoMo (màu đối tác, giữ đúng nhận diện)
  static const momo = Color(0xFFD1001B);
  static const momoDark = Color(0xFF9E0014);

  // Chữ & nền trung tính
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const surface = Color(0xFFF8FAFD);
  static const surfaceAlt = Color(0xFFF2F5FB);
  static const neutralSoft = Color(0xFFF1F5F9);
  static const shadow = Color(0x0F0F172A);
  static const scrim = Color(0x22000000);

  // Trạng thái
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFECFDF5);
  static const failure = Color(0xFFDC2626);
  static const failureSoft = Color(0xFFFEE2E2);
  static const warningSoft = Color(0xFFFEF3C7);
  static const warningSurface = Color(0xFFFFFBE6);
  static const warningIcon = Color(0xFFB45309);
  static const warningInk = Color(0xFF92400E);

  // Bản đồ
  static const mapCurrentLocation = brand;
}

/// Bo góc dùng chung (đang có 8/12/14/16/18/999 rải rác trong code).
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const input = 14.0;
  static const lg = 16.0;
  static const xl = 18.0;
  static const pill = 999.0;
}

/// Khoảng cách dùng chung.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        onPrimary: AppColors.onBrand,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }
}
