import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shop_item.dart';
import 'accessibility_service.dart';

/// 앱 테마 정의
class AppTheme {
  final String id;
  final String name;
  final String emoji;
  final Color primaryColor;
  final Color accentColor;
  final Color bgColor;
  final Color cardColor;

  const AppTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.accentColor,
    required this.bgColor,
    required this.cardColor,
  });

  /// 기본 테마
  static const defaultTheme = AppTheme(
    id: 'default',
    name: '기본 테마',
    emoji: '🎨',
    primaryColor: Color(0xFF6C63FF),
    accentColor: Color(0xFF6C63FF),
    bgColor: Color(0xFF0F0F1A),
    cardColor: Color(0xFF1E1E2E),
  );

  /// 샵 아이템에서 테마 생성
  factory AppTheme.fromShopItem(ShopItem item) {
    final properties = item.properties ?? {};
    final primaryColorValue = properties['primaryColor'] ?? 0xFF6C63FF;
    final accentColorValue = properties['accentColor'] ?? primaryColorValue;

    return AppTheme(
      id: item.id,
      name: item.name,
      emoji: item.emoji,
      primaryColor: Color(primaryColorValue),
      accentColor: Color(accentColorValue),
      bgColor: const Color(0xFF0F0F1A),
      cardColor: const Color(0xFF1E1E2E),
    );
  }

  /// 인벤토리 아이템에서 테마 생성
  factory AppTheme.fromInventoryData(Map<String, dynamic> data) {
    final properties = data['properties'] as Map<String, dynamic>? ?? {};
    final primaryColorValue = properties['primaryColor'] ?? 0xFF6C63FF;
    final accentColorValue = properties['accentColor'] ?? primaryColorValue;

    return AppTheme(
      id: data['itemId'] ?? 'default',
      name: data['itemName'] ?? '기본 테마',
      emoji: data['emoji'] ?? '🎨',
      primaryColor: Color(primaryColorValue),
      accentColor: Color(accentColorValue),
      bgColor: const Color(0xFF0F0F1A),
      cardColor: const Color(0xFF1E1E2E),
    );
  }
}

/// 테마 관리 서비스
class ThemeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppTheme _currentTheme = AppTheme.defaultTheme;
  bool _isLoading = false;

  /// 현재 테마
  AppTheme get currentTheme => _currentTheme;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 현재 사용자 ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// 사용 가능한 테마 목록 (기본 + 샵 테마)
  static List<AppTheme> get availableThemes => [
    AppTheme.defaultTheme,
    const AppTheme(
      id: 'theme_ocean',
      name: '오션 테마',
      emoji: '🌊',
      primaryColor: Color(0xFF0077B6),
      accentColor: Color(0xFF00B4D8),
      bgColor: Color(0xFF0F0F1A),
      cardColor: Color(0xFF1E1E2E),
    ),
    const AppTheme(
      id: 'theme_sunset',
      name: '선셋 테마',
      emoji: '🌅',
      primaryColor: Color(0xFFFF6B35),
      accentColor: Color(0xFFFFA500),
      bgColor: Color(0xFF0F0F1A),
      cardColor: Color(0xFF1E1E2E),
    ),
    const AppTheme(
      id: 'theme_forest',
      name: '포레스트 테마',
      emoji: '🌲',
      primaryColor: Color(0xFF2D6A4F),
      accentColor: Color(0xFF40916C),
      bgColor: Color(0xFF0F0F1A),
      cardColor: Color(0xFF1E1E2E),
    ),
    const AppTheme(
      id: 'theme_royal',
      name: '로얄 테마',
      emoji: '👑',
      primaryColor: Color(0xFF7B2CBF),
      accentColor: Color(0xFF9D4EDD),
      bgColor: Color(0xFF0F0F1A),
      cardColor: Color(0xFF1E1E2E),
    ),
  ];

  /// 테마 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    await loadActiveTheme();
  }

  /// 활성화된 테마 로드
  Future<void> loadActiveTheme() async {
    final userId = _currentUserId;
    if (userId == null) {
      _currentTheme = AppTheme.defaultTheme;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 활성화된 테마 찾기
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .where('category', isEqualTo: 'theme')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();

        // properties가 없으면 기본 테마 목록에서 찾기
        if (data['properties'] == null) {
          final itemId = data['itemId'] ?? '';
          final foundTheme = availableThemes.firstWhere(
            (t) => t.id == itemId,
            orElse: () => AppTheme.defaultTheme,
          );
          _currentTheme = foundTheme;
        } else {
          _currentTheme = AppTheme.fromInventoryData(data);
        }
      } else {
        _currentTheme = AppTheme.defaultTheme;
      }
    } catch (e) {
      print('Load active theme error: $e');
      _currentTheme = AppTheme.defaultTheme;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 테마 적용 (인벤토리에서 활성화할 때)
  Future<bool> applyTheme(String themeId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      // 기존 활성 테마 비활성화
      final activeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .where('category', isEqualTo: 'theme')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in activeSnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // 새 테마 활성화
      final newThemeRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(themeId);

      batch.update(newThemeRef, {'isActive': true});

      await batch.commit();

      // 테마 다시 로드
      await loadActiveTheme();

      return true;
    } catch (e) {
      print('Apply theme error: $e');
      return false;
    }
  }

  /// 기본 테마로 리셋
  Future<bool> resetToDefault() async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      // 모든 테마 비활성화
      final activeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .where('category', isEqualTo: 'theme')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in activeSnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      await batch.commit();

      _currentTheme = AppTheme.defaultTheme;
      notifyListeners();

      return true;
    } catch (e) {
      print('Reset theme error: $e');
      return false;
    }
  }

  /// Flutter ThemeData 생성
  ThemeData toThemeData() {
    final a11y = AccessibilityService();
    final highContrast = a11y.highContrastMode;

    // 고대비 모드 색상
    final bgColor = highContrast ? HighContrastColors.background : _currentTheme.bgColor;
    final cardColor = highContrast ? HighContrastColors.surface : _currentTheme.cardColor;
    final primaryColor = highContrast ? HighContrastColors.primary : _currentTheme.primaryColor;
    final accentColor = highContrast ? HighContrastColors.primary : _currentTheme.accentColor;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: cardColor,
        onPrimary: highContrast ? HighContrastColors.onPrimary : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast
              ? const BorderSide(color: HighContrastColors.border, width: 1)
              : BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: highContrast ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: highContrast
              ? const BorderSide(color: HighContrastColors.border)
              : BorderSide.none,
        ),
        enabledBorder: highContrast
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: HighContrastColors.border),
              )
            : null,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // 접근성 텍스트 크기 지원
      textTheme: _buildTextTheme(a11y.textScaleFactor),
    );
  }

  /// 텍스트 테마 생성 (텍스트 크기 스케일 적용)
  TextTheme _buildTextTheme(double scaleFactor) {
    return TextTheme(
      headlineLarge: TextStyle(fontSize: 32 * scaleFactor, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontSize: 28 * scaleFactor, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(fontSize: 24 * scaleFactor, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 20 * scaleFactor, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 18 * scaleFactor, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16 * scaleFactor),
      bodyMedium: TextStyle(fontSize: 14 * scaleFactor),
      bodySmall: TextStyle(fontSize: 12 * scaleFactor),
      labelLarge: TextStyle(fontSize: 14 * scaleFactor, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12 * scaleFactor, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 11 * scaleFactor, fontWeight: FontWeight.w500),
    );
  }
}

/// 테마 확장 - 앱 전체에서 쉽게 접근할 수 있도록
extension ThemeContextExtension on BuildContext {
  AppTheme get appTheme {
    // Provider를 사용하는 경우
    // return Provider.of<ThemeService>(this, listen: false).currentTheme;
    // 현재는 기본 테마 반환
    return AppTheme.defaultTheme;
  }
}
