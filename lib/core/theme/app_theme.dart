import 'package:flutter/material.dart';

/// Nguồn màu duy nhất của app. Mọi screen dùng `AppColors.x` hoặc
/// `Theme.of(context).colorScheme` — không viết `Color(0x...)` ngoài file này.
///
/// Bảng màu theo tỉ lệ 60/30/10: nền giấy ấm chiếm phần lớn, mực đen cho chữ,
/// một màu brand teal đậm dành riêng cho hành động chính (10%). Các màu trạng
/// thái giữ số ít vai trò: xanh lá = xong, đỏ = lỗi, hổ phách = sao/ cảnh báo.
abstract final class AppColors {
  // Thương hiệu
  static const brand = Color(0xFF0F5C6B);
  static const brandDark = Color(0xFF0A4552); // điểm cuối gradient
  static const brandSoft = Color(0xFFE7F1F3); // nền nhạt sau icon / ô được chọn
  static const onBrand = Colors.white;
  static const onBrandMuted = Color(0xCCFFFFFF); // chữ phụ trên nền brand

  // MoMo (màu đối tác, giữ đúng nhận diện)
  static const momo = Color(0xFFD1001B);

  // Chữ & nền trung tính ấm
  static const ink = Color(0xFF1A1D1B);
  static const muted = Color(0xFF5C6360);
  static const subtle = Color(0xFF8A918D);
  static const border = Color(0xFFE3E1DB);
  static const surface = Color(0xFFFFFFFF); // thẻ, input, sheet
  static const surfaceAlt = Color(0xFFEFEDE8); // nền phân khu, placeholder
  static const neutralSoft = Color(0xFFE9E7E1);
  static const shadow = Color(0x143A3226); // bóng ám nâu, khớp nền giấy
  static const scrim = Color(0x66000000); // lớp phủ chữ trên ảnh

  // Nền app: hơi ngà, không trắng lạnh — ăn ảnh phòng trọ và giảm chói
  static const canvas = Color(0xFFF7F6F3);

  // Đánh giá sao: hổ phách, chỉ dùng cho sao
  static const star = Color(0xFFF5A524);

  // Trạng thái
  static const success = Color(0xFF1B8A4C);
  static const successSoft = Color(0xFFE9F6EE);
  static const failure = Color(0xFFDC2626);
  static const failureSoft = Color(0xFFFDECEC);
  static const warningSoft = Color(0xFFFEF3C7);
  static const warningSurface = Color(0xFFFFFBE6);
  static const warningIcon = Color(0xFFB45309);
  static const warningInk = Color(0xFF92400E);

  // Bản đồ
  static const mapCurrentLocation = brand;
}

/// Bo góc dùng chung: một nhịp duy nhất, thẻ 16 / sheet & dialog 24 / input
/// và ảnh 12 / chip & nút 999.
abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 12.0;
  static const input = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

/// Khoảng cách theo lưới 8 điểm (chỉ 4 là ước số nhỏ nhất).
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

/// Nhịp động dùng chung. Quy tắc: phản hồi bấm <160ms, phần tử vào màn
/// ~220ms; không bao giờ animate hành động lặp nhiều lần/ngày.
abstract final class AppMotion {
  static const press = Duration(milliseconds: 140);
  static const enter = Duration(milliseconds: 220);
  static const stagger = Duration(milliseconds: 40);

  /// ease-out mạnh: bắt đầu nhanh, người dùng thấy hệ thống nghe mình ngay.
  static const easeOut = Cubic(0.23, 1, 0.32, 1);
}

abstract final class AppTypography {
  static const family = 'BeVietnam';

  /// Chữ số tiền/thống kê dùng khoảng đều để không "nhảy" khi tải lại.
  static const tabularFigures = [FontFeature.tabularFigures()];
}

class AppTheme {
  const AppTheme._();

  static TextTheme _textTheme(Color ink, Color muted) {
    // 4 cỡ duy nhất (32 / 20 / 15 / 12) + 2 weight (400 / 600); phần còn lại
    // của phân cấp đến từ màu và khoảng cách, không từ cỡ chữ.
    TextStyle s(
      double size, {
      FontWeight weight = FontWeight.w400,
      Color? color,
    }) => TextStyle(
      fontFamily: AppTypography.family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: size >= 20 ? 1.25 : 1.45,
      letterSpacing: size >= 20 ? -0.2 : 0,
    );

    const semi = FontWeight.w600;

    return TextTheme(
      displayLarge: s(32, weight: semi, color: ink),
      displayMedium: s(32, weight: semi, color: ink),
      displaySmall: s(28, weight: semi, color: ink),
      headlineLarge: s(20, weight: semi, color: ink),
      headlineMedium: s(20, weight: semi, color: ink),
      headlineSmall: s(20, weight: semi, color: ink),
      titleLarge: s(20, weight: semi, color: ink),
      titleMedium: s(15, weight: semi, color: ink),
      titleSmall: s(12, weight: semi, color: muted),
      bodyLarge: s(15, color: ink),
      bodyMedium: s(12, color: muted),
      bodySmall: s(12, color: muted),
      labelLarge: s(15, weight: semi, color: ink),
      labelMedium: s(12, weight: semi, color: muted),
      labelSmall: s(12, weight: FontWeight.w500, color: muted),
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      primaryContainer: AppColors.brandSoft,
      onPrimaryContainer: AppColors.brandDark,
      secondary: AppColors.brand,
      onSecondary: AppColors.onBrand,
      secondaryContainer: AppColors.brandSoft,
      onSecondaryContainer: AppColors.brandDark,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.canvas,
      surfaceContainer: AppColors.canvas,
      surfaceContainerHigh: AppColors.surfaceAlt,
      surfaceContainerHighest: AppColors.surfaceAlt,
      outline: AppColors.border,
      outlineVariant: AppColors.neutralSoft,
      error: AppColors.failure,
      shadow: AppColors.shadow,
      scrim: AppColors.scrim,
    );
    final text = _textTheme(scheme.onSurface, scheme.onSurfaceVariant);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: text,
      // Icon mặc định nhỏ hơn một chút để cân với chữ 15px.
      iconTheme: const IconThemeData(size: 20, color: AppColors.muted),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: const IconThemeData(size: 24, color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        // Bóng ám nâu rất nhẹ + viền tóc: thẻ nổi lên nền giấy mà không nặng.
        elevation: 1,
        shadowColor: AppColors.shadow,
        margin: const EdgeInsets.only(bottom: AppSpace.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandSoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.brand
                : AppColors.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall!.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.brand
                : AppColors.muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onBrand,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 52), // vùng ngón cái: cao >= 52dp
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.muted,
          // Đủ 44dp cho mọi ô bấm.
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.brandSoft,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium!.copyWith(color: AppColors.ink),
        secondaryLabelStyle: text.labelMedium!.copyWith(
          color: AppColors.brandDark,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: text.bodyLarge?.copyWith(color: AppColors.subtle),
        labelStyle: text.bodyMedium,
        // Nhãn float để trung tính: brand chỉ còn trên viền lúc focus, nếu
        // không cả form toàn nhãn xanh và ô nào cũng như đang được gõ.
        floatingLabelStyle: text.bodyMedium?.copyWith(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.lg,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.failure),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.failure, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.muted,
        textColor: AppColors.ink,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.sm,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.headlineMedium,
        contentTextStyle: text.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyLarge?.copyWith(color: AppColors.surface),
        actionTextColor: AppColors.brandSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.brand,
        unselectedLabelColor: AppColors.muted,
        labelStyle: text.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 2,
      ),
    );
  }
}
