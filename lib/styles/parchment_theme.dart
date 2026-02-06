import 'package:flutter/material.dart';

/// Warm Parchment Light Theme - 전체 앱에 일관된 양피지 테마 적용
///
/// 사용 예시:
/// ```dart
/// MaterialApp(
///   theme: ParchmentTheme.lightTheme,
/// )
/// ```
class ParchmentTheme {
  ParchmentTheme._();

  // ============================================================
  // 색상 팔레트 (Aged Manuscript - Deep)
  // WCAG AA 대비율 충족: ancientInk 12.5:1, fadedScript 8.1:1, weatheredGray 5.4:1
  // ============================================================

  // 배경 - 깊고 따뜻한 고대 양피지
  static const Color softPapyrus = Color(0xFFF0E4CE);    // 에이지드 크림 (기존: #FDF8F3)
  static const Color agedParchment = Color(0xFFE3D4B8);  // 깊은 양피지 (기존: #F5EFE6)
  static const Color warmVellum = Color(0xFFD4C4A0);     // 따뜻한 벨럼 (기존: #EDE4D3)

  // 텍스트 - 깊은 세피아 잉크
  static const Color ancientInk = Color(0xFF261E15);     // 깊은 세피아 블랙 (기존: #3D3229)
  static const Color fadedScript = Color(0xFF4A3E30);    // 진한 세피아 (기존: #6B5D4D)
  static const Color weatheredGray = Color(0xFF6B5D4D);  // 중간 세피아 (기존: #8C7E6D)

  // 금박 - 고대 성경 금박
  static const Color manuscriptGold = Color(0xFF9E7B3C); // 고대 골드 (기존: #C9A857)
  static const Color goldHighlight = Color(0xFFB8923F);  // 밝은 고대 골드 (기존: #D4AF37)
  static const Color goldMuted = Color(0xFF7A6344);      // 브론즈 (기존: #B8956F)

  // 상태 색상
  static const Color success = Color(0xFF6B8E5D);        // 성공 (올리브 그린)
  static const Color error = Color(0xFFC75050);          // 에러 (부드러운 레드)
  static const Color warning = Color(0xFFD4A744);        // 경고 (앰버)
  static const Color info = Color(0xFF5D7B8E);           // 정보 (세피아 블루)

  // ============================================================
  // 텍스처 기본값
  // ============================================================

  /// 텍스처 활성화 기본값
  static const bool textureEnabledDefault = true;

  /// Perlin 노이즈 강도 기본값 (부드러운 얼룩)
  static const double textureCoarseOpacityDefault = 0.24;

  /// 그레인 노이즈 강도 기본값 (미세한 결)
  static const double textureFineOpacityDefault = 0.16;

  /// 카드용 Perlin 노이즈 강도 (배경보다 약간 약하게)
  static const double cardTextureCoarseOpacity = 0.16;

  /// 카드용 그레인 노이즈 강도
  static const double cardTextureFineOpacity = 0.12;

  // ============================================================
  // 그라데이션
  // ============================================================

  /// 메인 배경 그라데이션 (수직)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [softPapyrus, agedParchment, warmVellum],
    stops: [0.0, 0.5, 1.0],
  );

  /// 카드용 미묘한 그라데이션
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [softPapyrus, agedParchment],
  );

  /// 골드 버튼 그라데이션
  static const LinearGradient goldButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldHighlight, manuscriptGold],
  );

  // ============================================================
  // 박스 그림자
  // ============================================================

  /// 카드 그림자
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: warmVellum.withValues(alpha: 0.5),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// 버튼 그림자
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: manuscriptGold.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// 골드 글로우 효과
  static List<BoxShadow> goldGlow = [
    BoxShadow(
      color: manuscriptGold.withValues(alpha: 0.4),
      blurRadius: 28,
      spreadRadius: 6,
    ),
  ];

  // ============================================================
  // 테두리
  // ============================================================

  /// 카드 테두리
  static Border cardBorder = Border.all(
    color: manuscriptGold.withValues(alpha: 0.3),
    width: 1,
  );

  /// 강조 테두리
  static Border accentBorder = Border.all(
    color: manuscriptGold.withValues(alpha: 0.6),
    width: 2,
  );

  // ============================================================
  // 테두리 반경
  // ============================================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // ============================================================
  // 텍스트 스타일
  // ============================================================

  /// 제목 스타일 (큰 제목)
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: ancientInk,
    height: 1.2,
  );

  /// 제목 스타일 (중간)
  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: ancientInk,
    height: 1.3,
  );

  /// 제목 스타일 (작은)
  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: ancientInk,
    height: 1.3,
  );

  /// 본문 스타일
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: fadedScript,
    height: 1.5,
  );

  /// 본문 스타일 (작은)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: fadedScript,
    height: 1.5,
  );

  /// 보조 텍스트 스타일
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: weatheredGray,
    height: 1.4,
  );

  /// 버튼 텍스트 스타일
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: softPapyrus,
    letterSpacing: 0.5,
  );

  /// 골드 강조 텍스트
  static const TextStyle goldAccent = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: manuscriptGold,
  );

  // ============================================================
  // ThemeData
  // ============================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // 색상 스키마
      colorScheme: const ColorScheme.light(
        primary: manuscriptGold,
        onPrimary: softPapyrus,
        secondary: goldHighlight,
        onSecondary: ancientInk,
        surface: agedParchment,
        onSurface: ancientInk,
        error: error,
        onError: softPapyrus,
      ),

      // 배경색
      scaffoldBackgroundColor: agedParchment,

      // AppBar 테마
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: ancientInk),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ancientInk,
        ),
      ),

      // 카드 테마
      cardTheme: CardThemeData(
        color: softPapyrus,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(
            color: manuscriptGold.withValues(alpha: 0.3),
          ),
        ),
      ),

      // ElevatedButton 테마 (Primary)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: manuscriptGold,
          foregroundColor: softPapyrus,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton 테마 (Secondary)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ancientInk,
          side: const BorderSide(color: manuscriptGold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // TextButton 테마
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: manuscriptGold,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softPapyrus,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: warmVellum),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: warmVellum),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: manuscriptGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: const TextStyle(color: weatheredGray),
        labelStyle: const TextStyle(color: fadedScript),
      ),

      // BottomNavigationBar 테마
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: softPapyrus,
        selectedItemColor: manuscriptGold,
        unselectedItemColor: weatheredGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // FloatingActionButton 테마
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: manuscriptGold,
        foregroundColor: softPapyrus,
        elevation: 4,
      ),

      // Chip 테마
      chipTheme: ChipThemeData(
        backgroundColor: warmVellum,
        selectedColor: manuscriptGold,
        labelStyle: const TextStyle(color: ancientInk),
        secondaryLabelStyle: const TextStyle(color: softPapyrus),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // Divider 테마
      dividerTheme: const DividerThemeData(
        color: warmVellum,
        thickness: 1,
        space: 24,
      ),

      // ProgressIndicator 테마
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: manuscriptGold,
        linearTrackColor: warmVellum,
        circularTrackColor: warmVellum,
      ),

      // Snackbar 테마
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ancientInk,
        contentTextStyle: const TextStyle(color: softPapyrus),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog 테마
      dialogTheme: DialogThemeData(
        backgroundColor: softPapyrus,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: headingSmall,
        contentTextStyle: bodyMedium,
      ),

      // BottomSheet 테마
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: softPapyrus,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),

      // 텍스트 테마
      textTheme: const TextTheme(
        displayLarge: headingLarge,
        displayMedium: headingMedium,
        displaySmall: headingSmall,
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        titleLarge: headingSmall,
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ancientInk,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ancientInk,
        ),
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: caption,
        labelLarge: button,
        labelMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ancientInk,
        ),
        labelSmall: caption,
      ),

      // Icon 테마
      iconTheme: const IconThemeData(
        color: ancientInk,
        size: 24,
      ),

      // ListTile 테마
      listTileTheme: const ListTileThemeData(
        iconColor: manuscriptGold,
        textColor: ancientInk,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Switch 테마
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return manuscriptGold;
          }
          return weatheredGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return manuscriptGold.withValues(alpha: 0.3);
          }
          return warmVellum;
        }),
      ),

      // Checkbox 테마
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return manuscriptGold;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(softPapyrus),
        side: const BorderSide(color: manuscriptGold, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Radio 테마
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return manuscriptGold;
          }
          return weatheredGray;
        }),
      ),

      // Slider 테마
      sliderTheme: SliderThemeData(
        activeTrackColor: manuscriptGold,
        inactiveTrackColor: warmVellum,
        thumbColor: manuscriptGold,
        overlayColor: manuscriptGold.withValues(alpha: 0.2),
      ),

      // TabBar 테마
      tabBarTheme: const TabBarThemeData(
        labelColor: manuscriptGold,
        unselectedLabelColor: weatheredGray,
        indicatorColor: manuscriptGold,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}

// ============================================================
// 편의 확장 메서드
// ============================================================

extension ParchmentContext on BuildContext {
  /// ParchmentTheme의 색상에 쉽게 접근
  ParchmentColors get parchment => const ParchmentColors();
}

/// ParchmentTheme 색상 접근을 위한 헬퍼 클래스
class ParchmentColors {
  const ParchmentColors();

  Color get softPapyrus => ParchmentTheme.softPapyrus;
  Color get agedParchment => ParchmentTheme.agedParchment;
  Color get warmVellum => ParchmentTheme.warmVellum;
  Color get ancientInk => ParchmentTheme.ancientInk;
  Color get fadedScript => ParchmentTheme.fadedScript;
  Color get weatheredGray => ParchmentTheme.weatheredGray;
  Color get manuscriptGold => ParchmentTheme.manuscriptGold;
  Color get goldHighlight => ParchmentTheme.goldHighlight;
  Color get goldMuted => ParchmentTheme.goldMuted;
  Color get success => ParchmentTheme.success;
  Color get error => ParchmentTheme.error;
  Color get warning => ParchmentTheme.warning;
  Color get info => ParchmentTheme.info;
}
