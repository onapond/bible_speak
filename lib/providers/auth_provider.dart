import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/session_state.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'core_providers.dart';

part 'auth_provider.g.dart';

/// AuthService 싱글톤 인스턴스
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

/// AuthNotifier가 사용하는 테스트 가능한 세션 작업 경계.
final authSessionGatewayProvider = Provider<AuthSessionGateway>(
  (ref) => ref.watch(authServiceProvider),
  name: 'authSessionGatewayProvider',
);

final sessionNotifierProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
  name: 'sessionNotifierProvider',
);

/// Firebase 인증, 로컬 UID, 프로필 복원을 하나의 상태로 관리한다.
class SessionNotifier extends Notifier<SessionState> {
  late final AuthSessionGateway _authService;
  var _operationEpoch = 0;

  @override
  SessionState build() {
    _authService = ref.watch(authSessionGatewayProvider);

    ref.listen(
      authUserIdChangesProvider,
      (previous, next) {
        next.when(
          data: (userId) => unawaited(
            Future<void>.microtask(() => _handleFirebaseUserId(userId)),
          ),
          loading: () {},
          error: (error, stackTrace) => scheduleMicrotask(
            () => _handleAuthStreamError(error, stackTrace),
          ),
        );
      },
      fireImmediately: true,
    );
    ref.onDispose(() => _operationEpoch++);

    // Firebase authStateChanges의 첫 확정 이벤트 전에는 절대 로그아웃으로
    // 간주하지 않는다.
    return const SessionState.loading();
  }

  Future<void> _handleFirebaseUserId(String? firebaseUserId) async {
    final operation = ++_operationEpoch;

    if (firebaseUserId == null) {
      state = const SessionState.loading();
      try {
        await _authService.clearLocalSession();
      } catch (error, stackTrace) {
        if (operation == _operationEpoch) {
          state = SessionState.recoverableError(
            error: error,
            stackTrace: stackTrace,
          );
        }
        return;
      }
      if (operation == _operationEpoch) {
        state = const SessionState.signedOut();
      }
      return;
    }

    final persistedUserId = state.persistedUserId;
    state = SessionState.loading(
      firebaseUserId: firebaseUserId,
      persistedUserId: persistedUserId,
    );
    try {
      final restored = await _authService.restoreSession(firebaseUserId);
      if (operation == _operationEpoch &&
          restored.firebaseUserId == firebaseUserId) {
        state = restored;
      }
    } catch (error, stackTrace) {
      if (operation == _operationEpoch) {
        state = SessionState.recoverableError(
          firebaseUserId: firebaseUserId,
          persistedUserId: persistedUserId,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    _operationEpoch++;
    final current = state;
    final user = current.user;
    if (current.isAuthenticated && user != null) {
      state = SessionState.authenticated(
        user: user,
        source: current.profileSource ?? SessionProfileSource.cache,
        persistedUserId: current.persistedUserId,
        warning: error,
        warningStackTrace: stackTrace,
      );
      return;
    }
    state = SessionState.recoverableError(
      firebaseUserId: current.firebaseUserId,
      persistedUserId: current.persistedUserId,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<AuthResult> _runAuthentication(
    Future<AuthResult> Function() authenticate,
  ) async {
    final previous = state;
    final operation = ++_operationEpoch;
    state = SessionState.loading(
      firebaseUserId: previous.firebaseUserId,
      persistedUserId: previous.persistedUserId,
    );

    final result = await authenticate();
    if (operation != _operationEpoch) return result;

    if (result.success && result.needsProfile) {
      final uid = result.tempUid;
      state = uid == null
          ? SessionState.recoverableError(
              error: StateError('프로필 설정에 필요한 Firebase UID가 없습니다.'),
            )
          : SessionState.needsProfile(firebaseUserId: uid);
      return result;
    }

    final user = result.user ?? _authService.currentUser;
    if (result.success && user != null) {
      state = SessionState.authenticated(
        user: user,
        source: SessionProfileSource.remote,
      );
    } else {
      state = previous;
    }
    return result;
  }

  /// Google 로그인
  Future<AuthResult> signInWithGoogle() async {
    return _runAuthentication(_authService.signInWithGoogle);
  }

  /// Apple 로그인
  Future<AuthResult> signInWithApple() async {
    return _runAuthentication(_authService.signInWithApple);
  }

  /// 이메일 로그인
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _runAuthentication(
      () => _authService.signInWithEmail(
        email: email,
        password: password,
      ),
    );
  }

  /// 이메일 회원가입
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    return _runAuthentication(
      () => _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      ),
    );
  }

  /// 프로필 설정 완료
  Future<UserModel?> completeProfile({
    required String name,
    String? groupId,
  }) async {
    final operation = ++_operationEpoch;
    final user = await _authService.completeProfile(
      name: name,
      groupId: groupId,
    );

    if (operation == _operationEpoch && user != null) {
      state = SessionState.authenticated(
        user: user,
        source: SessionProfileSource.remote,
      );
    }

    return user;
  }

  /// 로그아웃
  Future<void> signOut() async {
    final operation = ++_operationEpoch;
    state = const SessionState.loading();
    await _authService.signOut();
    if (operation == _operationEpoch) {
      state = const SessionState.signedOut();
    }
  }

  /// 사용자 정보 새로고침
  Future<void> refreshUser() async {
    final firebaseUserId = state.firebaseUserId;
    if (firebaseUserId == null) return;

    final operation = ++_operationEpoch;
    state = SessionState.loading(
      firebaseUserId: firebaseUserId,
      persistedUserId: state.persistedUserId,
    );
    try {
      final restored = await _authService.restoreSession(firebaseUserId);
      if (operation == _operationEpoch &&
          restored.firebaseUserId == firebaseUserId) {
        state = restored;
      }
    } catch (error, stackTrace) {
      if (operation == _operationEpoch) {
        state = SessionState.recoverableError(
          firebaseUserId: firebaseUserId,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// 달란트 추가
  Future<bool> addTalant({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final success = await _authService.addTalant(
      book: book,
      chapter: chapter,
      verse: verse,
    );
    if (success) {
      final user = _authService.currentUser;
      if (user != null) {
        state = SessionState.authenticated(
          user: user,
          source: SessionProfileSource.remote,
        );
      }
    }
    return success;
  }

  /// 달란트 차감
  Future<bool> deductTalant(int amount) async {
    final success = await _authService.deductTalant(amount);
    if (success) {
      final user = _authService.currentUser;
      if (user != null) {
        state = SessionState.authenticated(
          user: user,
          source: SessionProfileSource.remote,
        );
      }
    }
    return success;
  }
}

/// 기존 화면 API를 유지하는 SessionState의 호환 어댑터.
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  SessionNotifier get _session => ref.read(sessionNotifierProvider.notifier);

  @override
  AsyncValue<UserModel?> build() {
    final session = ref.watch(sessionNotifierProvider);
    switch (session.status) {
      case SessionStatus.loading:
        return const AsyncValue.loading();
      case SessionStatus.authenticated:
        return AsyncValue.data(session.user);
      case SessionStatus.needsProfile:
      case SessionStatus.signedOut:
        return const AsyncValue.data(null);
      case SessionStatus.recoverableError:
        return AsyncValue.error(
          session.error ?? StateError('세션 복구 오류'),
          session.stackTrace ?? StackTrace.empty,
        );
    }
  }

  Future<AuthResult> signInWithGoogle() => _session.signInWithGoogle();

  Future<AuthResult> signInWithApple() => _session.signInWithApple();

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _session.signInWithEmail(email: email, password: password);
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) {
    return _session.signUpWithEmail(
      email: email,
      password: password,
      name: name,
    );
  }

  Future<UserModel?> completeProfile({
    required String name,
    String? groupId,
  }) {
    return _session.completeProfile(name: name, groupId: groupId);
  }

  Future<void> signOut() => _session.signOut();

  Future<void> refreshUser() => _session.refreshUser();

  Future<bool> addTalant({
    required String book,
    required int chapter,
    required int verse,
  }) {
    return _session.addTalant(
      book: book,
      chapter: chapter,
      verse: verse,
    );
  }

  Future<bool> deductTalant(int amount) => _session.deductTalant(amount);
}

/// 현재 사용자 (편의용 Provider)
@riverpod
UserModel? currentUser(Ref ref) {
  final session = ref.watch(sessionNotifierProvider);
  return session.isAuthenticated ? session.user : null;
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
