import 'user_model.dart';

/// 인증 세션이 앱 시작과 실행 중 가질 수 있는 단일 상태.
enum SessionStatus {
  loading,
  authenticated,
  needsProfile,
  signedOut,
  recoverableError,
}

/// 인증된 프로필을 가져온 위치.
enum SessionProfileSource {
  remote,
  cache,
}

/// Firebase 사용자, 로컬 세션 포인터, 프로필 로딩 결과를 함께 표현한다.
class SessionState {
  const SessionState._({
    required this.status,
    this.firebaseUserId,
    this.persistedUserId,
    this.user,
    this.profileSource,
    this.error,
    this.stackTrace,
  });

  const SessionState.loading({
    String? firebaseUserId,
    String? persistedUserId,
  }) : this._(
          status: SessionStatus.loading,
          firebaseUserId: firebaseUserId,
          persistedUserId: persistedUserId,
        );

  factory SessionState.authenticated({
    required UserModel user,
    required SessionProfileSource source,
    String? persistedUserId,
    Object? warning,
    StackTrace? warningStackTrace,
  }) {
    return SessionState._(
      status: SessionStatus.authenticated,
      firebaseUserId: user.uid,
      persistedUserId: persistedUserId ?? user.uid,
      user: user,
      profileSource: source,
      error: warning,
      stackTrace: warningStackTrace,
    );
  }

  const SessionState.needsProfile({
    required String firebaseUserId,
    String? persistedUserId,
  }) : this._(
          status: SessionStatus.needsProfile,
          firebaseUserId: firebaseUserId,
          persistedUserId: persistedUserId,
        );

  const SessionState.signedOut({String? persistedUserId})
      : this._(
          status: SessionStatus.signedOut,
          persistedUserId: persistedUserId,
        );

  const SessionState.recoverableError({
    String? firebaseUserId,
    String? persistedUserId,
    required Object error,
    StackTrace? stackTrace,
  }) : this._(
          status: SessionStatus.recoverableError,
          firebaseUserId: firebaseUserId,
          persistedUserId: persistedUserId,
          error: error,
          stackTrace: stackTrace,
        );

  final SessionStatus status;
  final String? firebaseUserId;
  final String? persistedUserId;
  final UserModel? user;
  final SessionProfileSource? profileSource;

  /// 인증된 캐시를 사용한 경우에는 경고가 함께 있을 수 있다.
  final Object? error;
  final StackTrace? stackTrace;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isDefinitive =>
      status == SessionStatus.authenticated ||
      status == SessionStatus.needsProfile ||
      status == SessionStatus.signedOut;
  bool get isOffline =>
      status == SessionStatus.authenticated &&
      profileSource == SessionProfileSource.cache;
}
