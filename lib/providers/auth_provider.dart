import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'core_providers.dart';

part 'auth_provider.g.dart';

/// AuthService 싱글톤 인스턴스
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

/// Auth 상태 관리 Notifier
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  late final AuthService _authService;

  @override
  AsyncValue<UserModel?> build() {
    _authService = ref.watch(authServiceProvider);

    // Auth 상태 변화 감지
    ref.listen(authStateChangesProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user == null) {
            state = const AsyncValue.data(null);
          } else {
            _refreshUser();
          }
        },
        loading: () {},
        error: (e, st) => state = AsyncValue.error(e, st),
      );
    });

    // 초기 상태 로드
    _initializeAuth();
    return const AsyncValue.loading();
  }

  Future<void> _initializeAuth() async {
    try {
      final success = await _authService.init();
      if (success && _authService.currentUser != null) {
        state = AsyncValue.data(_authService.currentUser);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _refreshUser() async {
    try {
      await _authService.refreshUser();
      state = AsyncValue.data(_authService.currentUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Google 로그인
  Future<AuthResult> signInWithGoogle() async {
    state = const AsyncValue.loading();
    final result = await _authService.signInWithGoogle();

    if (result.success && !result.needsProfile) {
      state = AsyncValue.data(_authService.currentUser);
    } else if (!result.success) {
      state = const AsyncValue.data(null);
    }

    return result;
  }

  /// Apple 로그인
  Future<AuthResult> signInWithApple() async {
    state = const AsyncValue.loading();
    final result = await _authService.signInWithApple();

    if (result.success && !result.needsProfile) {
      state = AsyncValue.data(_authService.currentUser);
    } else if (!result.success) {
      state = const AsyncValue.data(null);
    }

    return result;
  }

  /// 이메일 로그인
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (result.success && !result.needsProfile) {
      state = AsyncValue.data(_authService.currentUser);
    } else if (!result.success) {
      state = const AsyncValue.data(null);
    }

    return result;
  }

  /// 이메일 회원가입
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      name: name,
    );

    if (result.success && !result.needsProfile) {
      state = AsyncValue.data(_authService.currentUser);
    } else if (!result.success) {
      state = const AsyncValue.data(null);
    }

    return result;
  }

  /// 프로필 설정 완료
  Future<UserModel?> completeProfile({
    required String name,
    String? groupId,
  }) async {
    final user = await _authService.completeProfile(
      name: name,
      groupId: groupId,
    );

    if (user != null) {
      state = AsyncValue.data(user);
    }

    return user;
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  /// 사용자 정보 새로고침
  Future<void> refreshUser() async {
    await _refreshUser();
  }

  /// 달란트 추가
  Future<bool> addTalant(int verseNumber) async {
    final success = await _authService.addTalant(verseNumber);
    if (success) {
      state = AsyncValue.data(_authService.currentUser);
    }
    return success;
  }

  /// 달란트 차감
  Future<bool> deductTalant(int amount) async {
    final success = await _authService.deductTalant(amount);
    if (success) {
      state = AsyncValue.data(_authService.currentUser);
    }
    return success;
  }
}

/// 현재 사용자 (편의용 Provider)
@riverpod
UserModel? currentUser(Ref ref) {
  return ref.watch(authNotifierProvider).valueOrNull;
}

/// 사용자 탈란트 (반응형)
@riverpod
int userTalants(Ref ref) {
  return ref.watch(currentUserProvider)?.talants ?? 0;
}

/// 사용자 이름
@riverpod
String? userName(Ref ref) {
  return ref.watch(currentUserProvider)?.name;
}

/// 사용자 그룹 ID
@riverpod
String userGroupId(Ref ref) {
  return ref.watch(currentUserProvider)?.groupId ?? '';
}
