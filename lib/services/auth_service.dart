import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_state.dart';
import '../models/user_model.dart';

typedef RemoteUserProfileLoader = Future<UserModel?> Function(String uid);

/// 계정 전환 전후의 비동기 결과를 구분하는 불변 토큰.
class SessionOperationToken {
  const SessionOperationToken._({
    required this.userId,
    required this.epoch,
  });

  final String userId;
  final int epoch;
}

/// A→B→A 전환에서도 이전 A 작업을 다시 활성화하지 않는 세대 가드.
class SessionOperationGuard {
  String? _activeUserId;
  var _epoch = 0;

  SessionOperationToken activate(String userId) {
    if (_activeUserId != userId) {
      _activeUserId = userId;
      _epoch++;
    }
    return SessionOperationToken._(userId: userId, epoch: _epoch);
  }

  SessionOperationToken? activateIfCurrent(
    String userId, {
    required String? firebaseUserId,
  }) {
    if (userId != firebaseUserId) return null;
    return activate(userId);
  }

  void invalidate() {
    _activeUserId = null;
    _epoch++;
  }

  bool isCurrent(
    SessionOperationToken operation, {
    required String? firebaseUserId,
  }) {
    return operation.epoch == _epoch &&
        operation.userId == _activeUserId &&
        operation.userId == firebaseUserId;
  }
}

/// 프로필 완료는 현재 Firebase 계정과 같은 임시 UID에만 허용한다.
String? resolveProfileCompletionUserId({
  required String? firebaseUserId,
  required String? temporaryUserId,
}) {
  if (firebaseUserId == null) return null;
  if (temporaryUserId != null && temporaryUserId != firebaseUserId) {
    return null;
  }
  return temporaryUserId ?? firebaseUserId;
}

/// AuthNotifier가 의존하는 인증 작업 경계. 테스트에서는 Firebase 없이 대체한다.
abstract interface class AuthSessionGateway {
  UserModel? get currentUser;

  Future<SessionState> restoreSession(String firebaseUserId);
  Future<void> clearLocalSession();
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> signInWithApple();
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  });
  Future<UserModel?> completeProfile({
    required String name,
    String? groupId,
  });
  Future<void> signOut();
  Future<void> refreshUser();
  Future<bool> addTalant({
    required String book,
    required int chapter,
    required int verse,
  });
  Future<bool> deductTalant(int amount);
}

/// UID와 프로필을 한 묶음으로 저장하는 로컬 세션 캐시.
class SessionProfileCache {
  SessionProfileCache({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const userIdKey = 'bible_speak_userId';
  static const profileKey = 'bible_speak_sessionProfile';
  static const tempUserIdKey = 'bible_speak_tempUid';
  static const _tempNameKey = 'bible_speak_tempName';
  static const _tempEmailKey = 'bible_speak_tempEmail';
  static const _tempPhotoKey = 'bible_speak_tempPhoto';
  static const _cacheVersion = 1;

  final Future<SharedPreferences> Function() _loadPreferences;
  Future<void> _mutationQueue = Future<void>.value();

  Future<T> _mutate<T>(Future<T> Function() mutation) {
    final result = _mutationQueue.then((_) => mutation());
    _mutationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<String?> readPersistedUserId() async {
    final preferences = await _loadPreferences();
    return preferences.getString(userIdKey);
  }

  Future<UserModel?> readProfile(String firebaseUserId) async {
    final preferences = await _loadPreferences();
    final encoded = preferences.getString(profileKey);
    if (encoded == null) return null;

    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return null;
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['version'] != _cacheVersion ||
        envelope['uid'] != firebaseUserId ||
        envelope['profile'] is! Map) {
      return null;
    }

    final profile = UserModel.fromSessionCache(
      Map<String, dynamic>.from(envelope['profile'] as Map),
    );
    return profile.uid == firebaseUserId ? profile : null;
  }

  Future<bool> writeProfile(
    UserModel user, {
    bool Function()? isCurrent,
  }) {
    return _mutate(() async {
      bool operationIsCurrent() => isCurrent?.call() ?? true;
      if (!operationIsCurrent()) return false;

      final preferences = await _loadPreferences();
      if (!operationIsCurrent()) return false;

      final envelope = jsonEncode({
        'version': _cacheVersion,
        'uid': user.uid,
        'profile': user.toSessionCache(),
      });

      // 프로필 묶음을 먼저 기록해 UID 포인터가 앞서가는 상태를 피한다.
      await preferences.setString(profileKey, envelope);
      if (!operationIsCurrent()) return false;
      await preferences.setString(userIdKey, user.uid);
      return operationIsCurrent();
    });
  }

  Future<bool> clearActiveSession({bool Function()? isCurrent}) {
    return _mutate(() async {
      bool operationIsCurrent() => isCurrent?.call() ?? true;
      if (!operationIsCurrent()) return false;

      final preferences = await _loadPreferences();
      if (!operationIsCurrent()) return false;

      await _removeActiveSession(preferences);
      return operationIsCurrent();
    });
  }

  /// 로그아웃 시 활성 캐시와 임시 프로필을 같은 큐 작업에서 정리한다.
  Future<bool> clearSessionData({bool Function()? isCurrent}) {
    return _mutate(() async {
      bool operationIsCurrent() => isCurrent?.call() ?? true;
      if (!operationIsCurrent()) return false;

      final preferences = await _loadPreferences();
      if (!operationIsCurrent()) return false;

      await _removeActiveSession(preferences);
      await _removeTemporaryProfile(preferences);
      return operationIsCurrent();
    });
  }

  Future<Map<String, String?>> readTemporaryProfile() async {
    final preferences = await _loadPreferences();
    return {
      'uid': preferences.getString(tempUserIdKey),
      'name': preferences.getString(_tempNameKey),
      'email': preferences.getString(_tempEmailKey),
      'photo': preferences.getString(_tempPhotoKey),
    };
  }

  Future<bool> writeTemporaryProfile({
    required String userId,
    String? name,
    String? email,
    String? photo,
    bool Function()? isCurrent,
  }) {
    return _mutate(() async {
      bool operationIsCurrent() => isCurrent?.call() ?? true;
      if (!operationIsCurrent()) return false;

      final preferences = await _loadPreferences();
      if (!operationIsCurrent()) return false;

      await preferences.setString(tempUserIdKey, userId);
      if (name != null) await preferences.setString(_tempNameKey, name);
      if (email != null) await preferences.setString(_tempEmailKey, email);
      if (photo != null) await preferences.setString(_tempPhotoKey, photo);

      if (operationIsCurrent()) return true;
      if (preferences.getString(tempUserIdKey) == userId) {
        await _removeTemporaryProfile(preferences);
      }
      return false;
    });
  }

  Future<bool> clearTemporaryProfile({
    String? expectedUserId,
    bool Function()? isCurrent,
  }) {
    return _mutate(() async {
      bool operationIsCurrent() => isCurrent?.call() ?? true;
      if (!operationIsCurrent()) return false;

      final preferences = await _loadPreferences();
      if (!operationIsCurrent()) return false;
      if (expectedUserId != null &&
          preferences.getString(tempUserIdKey) != expectedUserId) {
        return false;
      }

      await _removeTemporaryProfile(preferences);
      return operationIsCurrent();
    });
  }

  static Future<void> _removeTemporaryProfile(
    SharedPreferences preferences,
  ) async {
    await preferences.remove(tempUserIdKey);
    await preferences.remove(_tempNameKey);
    await preferences.remove(_tempEmailKey);
    await preferences.remove(_tempPhotoKey);
  }

  static Future<void> _removeActiveSession(
    SharedPreferences preferences,
  ) async {
    await preferences.remove(profileKey);
    await preferences.remove(userIdKey);
    await preferences.remove('bible_speak_userName');
    await preferences.remove('bible_speak_groupId');
  }
}

/// 원격 프로필과 UID 검증 로컬 캐시를 하나의 SessionState로 결합한다.
class SessionRestorer {
  SessionRestorer({
    required SessionProfileCache cache,
    required RemoteUserProfileLoader loadRemoteProfile,
    bool Function()? isCurrent,
  })  : _cache = cache,
        _loadRemoteProfile = loadRemoteProfile,
        _isCurrent = isCurrent ?? _alwaysCurrent;

  final SessionProfileCache _cache;
  final RemoteUserProfileLoader _loadRemoteProfile;
  final bool Function() _isCurrent;

  static bool _alwaysCurrent() => true;

  Future<SessionState> restore(String firebaseUserId) async {
    String? persistedUserId;
    UserModel? cachedUser;

    try {
      persistedUserId = await _cache.readPersistedUserId();
      cachedUser = await _cache.readProfile(firebaseUserId);
    } catch (_) {
      // 원격 프로필은 로컬 저장소 오류와 독립적으로 복원할 수 있다.
    }

    try {
      final remoteUser = await _loadRemoteProfile(firebaseUserId);
      if (remoteUser == null) {
        if (_isCurrent()) {
          try {
            await _cache.clearActiveSession(isCurrent: _isCurrent);
          } catch (_) {
            // 원격의 프로필 없음 판정은 로컬 정리 실패보다 우선한다.
          }
        }
        return SessionState.needsProfile(
          firebaseUserId: firebaseUserId,
        );
      }
      if (remoteUser.uid != firebaseUserId) {
        throw StateError('Firebase UID와 원격 프로필 UID가 일치하지 않습니다.');
      }

      Object? cacheWarning;
      StackTrace? cacheWarningStackTrace;
      if (_isCurrent()) {
        try {
          final written = await _cache.writeProfile(
            remoteUser,
            isCurrent: _isCurrent,
          );
          if (written) persistedUserId = firebaseUserId;
        } catch (error, stackTrace) {
          cacheWarning = error;
          cacheWarningStackTrace = stackTrace;
        }
      }

      return SessionState.authenticated(
        user: remoteUser,
        source: SessionProfileSource.remote,
        persistedUserId: persistedUserId,
        warning: cacheWarning,
        warningStackTrace: cacheWarningStackTrace,
      );
    } catch (error, stackTrace) {
      if (cachedUser != null) {
        if (_isCurrent()) {
          try {
            final written = await _cache.writeProfile(
              cachedUser,
              isCurrent: _isCurrent,
            );
            if (written) persistedUserId = firebaseUserId;
          } catch (_) {
            // 유효한 UID 캐시가 있으면 저장소 갱신 실패에도 세션을 유지한다.
          }
        }
        return SessionState.authenticated(
          user: cachedUser,
          source: SessionProfileSource.cache,
          persistedUserId: persistedUserId,
          warning: error,
          warningStackTrace: stackTrace,
        );
      }

      return SessionState.recoverableError(
        firebaseUserId: firebaseUserId,
        persistedUserId: persistedUserId,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// 인증 서비스
/// - Firebase Auth 기반 로그인/로그아웃
/// - Google, Apple, Email 로그인 지원
/// - 사용자 프로필 관리
class AuthService implements AuthSessionGateway {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SessionProfileCache _sessionCache = SessionProfileCache();
  final SessionOperationGuard _operationGuard = SessionOperationGuard();
  int _sessionEpoch = 0;

  // GoogleSignIn 지연 초기화 (웹에서 Client ID 에러 방지)
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn(
      scopes: ['email', 'profile'],
    );
    return _googleSignInInstance!;
  }

  // 현재 사용자 캐시
  UserModel? _currentUser;

  /// 현재 로그인된 사용자
  @override
  UserModel? get currentUser => _currentUser;

  /// 로그인 여부
  bool get isLoggedIn => _currentUser != null;

  /// 현재 Firebase User
  User? get firebaseUser => _auth.currentUser;

  /// 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 초기화 - 저장된 세션 복원
  Future<bool> init() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final restored = await restoreSession(uid);
    return restored.isAuthenticated;
  }

  @override
  Future<SessionState> restoreSession(String firebaseUserId) async {
    final accountOperation = _operationGuard.activateIfCurrent(
      firebaseUserId,
      firebaseUserId: _auth.currentUser?.uid,
    );
    if (accountOperation == null) {
      return SessionState.loading(firebaseUserId: _auth.currentUser?.uid);
    }
    final operation = ++_sessionEpoch;
    final restored = await SessionRestorer(
      cache: _sessionCache,
      loadRemoteProfile: _loadRemoteProfile,
      isCurrent: () =>
          operation == _sessionEpoch && _isOperationCurrent(accountOperation),
    ).restore(firebaseUserId);

    if (operation != _sessionEpoch || !_isOperationCurrent(accountOperation)) {
      return SessionState.loading(
        firebaseUserId: _auth.currentUser?.uid,
        persistedUserId: restored.persistedUserId,
      );
    }

    if (restored.isAuthenticated) {
      _currentUser = restored.user;
      print('✅ 세션 복원: ${_currentUser!.name}');
    } else if (restored.status == SessionStatus.needsProfile) {
      _currentUser = null;
    }
    return restored;
  }

  Future<UserModel?> _loadRemoteProfile(String uid) async {
    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (!userDoc.exists || userDoc.data() == null) return null;
    return UserModel.fromFirestore(uid, userDoc.data()!);
  }

  @override
  Future<void> clearLocalSession() async {
    final operation = ++_sessionEpoch;
    _operationGuard.invalidate();
    _currentUser = null;
    try {
      await _sessionCache.clearSessionData(
        isCurrent: () =>
            operation == _sessionEpoch && _auth.currentUser == null,
      );
    } catch (error) {
      print('⚠️ 로컬 세션 정리 오류: $error');
    }
  }

  SessionOperationToken? _beginCurrentUserOperation(UserModel? user) {
    if (user == null) return null;
    return _operationGuard.activateIfCurrent(
      user.uid,
      firebaseUserId: _auth.currentUser?.uid,
    );
  }

  bool _isOperationCurrent(SessionOperationToken operation) {
    return _operationGuard.isCurrent(
      operation,
      firebaseUserId: _auth.currentUser?.uid,
    );
  }

  // ============================================================
  // Google 로그인
  // ============================================================

  /// Google 로그인
  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        googleUser = await _googleSignIn.signInSilently();
        googleUser ??= await _googleSignIn.signIn();
      } else {
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        return AuthResult.cancelled();
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return await _handleUserCredential(
        userCredential,
        displayName: googleUser.displayName,
        email: googleUser.email,
        photoUrl: googleUser.photoUrl,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      print('❌ Google 로그인 오류: $e');
      return AuthResult.error('Google 로그인에 실패했습니다.');
    }
  }

  // ============================================================
  // Apple 로그인
  // ============================================================

  /// Apple 로그인 가능 여부
  Future<bool> isAppleSignInAvailable() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isMacOS) return false;
    return await SignInWithApple.isAvailable();
  }

  /// Apple 로그인
  @override
  Future<AuthResult> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple은 첫 로그인 시에만 이름을 제공
      String? displayName;
      if (appleCredential.givenName != null ||
          appleCredential.familyName != null) {
        displayName =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
      }

      return await _handleUserCredential(
        userCredential,
        displayName: displayName,
        email: appleCredential.email,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.cancelled();
      }
      return AuthResult.error('Apple 로그인에 실패했습니다.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      print('❌ Apple 로그인 오류: $e');
      return AuthResult.error('Apple 로그인에 실패했습니다.');
    }
  }

  // ============================================================
  // 이메일 로그인
  // ============================================================

  /// 이메일 로그인
  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return await _handleUserCredential(userCredential, email: email.trim());
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      print('❌ 이메일 로그인 오류: $e');
      return AuthResult.error('이메일 로그인에 실패했습니다.');
    }
  }

  /// 이메일 회원가입
  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return await _handleUserCredential(
        userCredential,
        displayName: name.trim(),
        email: email.trim(),
        isNewUser: true,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      print('❌ 이메일 회원가입 오류: $e');
      return AuthResult.error('회원가입에 실패했습니다.');
    }
  }

  /// 비밀번호 재설정 이메일 발송
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(needsProfile: false);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('비밀번호 재설정 이메일 발송에 실패했습니다.');
    }
  }

  // ============================================================
  // 공통 처리
  // ============================================================

  /// UserCredential 처리 - 기존 사용자 or 신규 사용자 구분
  Future<AuthResult> _handleUserCredential(
    UserCredential userCredential, {
    String? displayName,
    String? email,
    String? photoUrl,
    bool isNewUser = false,
  }) async {
    final uid = userCredential.user!.uid;
    final accountOperation = _operationGuard.activateIfCurrent(
      uid,
      firebaseUserId: _auth.currentUser?.uid,
    );
    if (accountOperation == null) return AuthResult.cancelled();
    bool operationIsCurrent() => _isOperationCurrent(accountOperation);
    if (!operationIsCurrent()) return AuthResult.cancelled();

    // 1. UID로 사용자 확인
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!operationIsCurrent()) return AuthResult.cancelled();

    if (userDoc.exists) {
      // 기존 사용자 - 로그인 완료
      final user = UserModel.fromFirestore(uid, userDoc.data()!);
      await _cacheUser(user, isCurrent: operationIsCurrent);
      if (!operationIsCurrent()) return AuthResult.cancelled();
      _currentUser = user;

      print('✅ 로그인 완료: ${user.name}');
      return AuthResult.success(user: user);
    }

    // 2. 이메일로 기존 사용자 찾기 (익명 계정으로 가입한 경우)
    if (email != null && email.isNotEmpty) {
      try {
        final emailQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (!operationIsCurrent()) return AuthResult.cancelled();

        if (emailQuery.docs.isNotEmpty) {
          // 이메일로 기존 사용자 발견 - 문서를 새 UID로 마이그레이션
          final oldDoc = emailQuery.docs.first;
          final oldData = oldDoc.data();

          // 새 UID로 문서 생성
          await _firestore.collection('users').doc(uid).set({
            ...oldData,
            'migratedFrom': oldDoc.id,
            'migratedAt': FieldValue.serverTimestamp(),
          });
          if (!operationIsCurrent()) return AuthResult.cancelled();

          final user = UserModel.fromFirestore(uid, oldData);
          await _cacheUser(user, isCurrent: operationIsCurrent);
          if (!operationIsCurrent()) return AuthResult.cancelled();
          _currentUser = user;

          print('✅ 기존 사용자 마이그레이션 완료: ${user.name}');
          return AuthResult.success(user: user);
        }
      } catch (e) {
        print('⚠️ 이메일 검색 오류 (무시하고 계속): $e');
      }
    }

    // 3. 신규 사용자 - 프로필 설정 필요
    final saved = await _saveTempUserInfo(
      uid,
      displayName,
      email,
      photoUrl,
      isCurrent: operationIsCurrent,
    );
    if (!saved || !operationIsCurrent()) {
      await _sessionCache.clearTemporaryProfile(expectedUserId: uid);
      return AuthResult.cancelled();
    }

    print('📝 신규 사용자 - 프로필 설정 필요');
    return AuthResult.success(needsProfile: true, tempUid: uid);
  }

  /// 임시 사용자 정보 저장
  Future<bool> _saveTempUserInfo(
    String uid,
    String? displayName,
    String? email,
    String? photoUrl, {
    bool Function()? isCurrent,
  }) async {
    return _sessionCache.writeTemporaryProfile(
      userId: uid,
      name: displayName,
      email: email,
      photo: photoUrl,
      isCurrent: isCurrent,
    );
  }

  /// 임시 저장된 사용자 정보 가져오기
  Future<Map<String, String?>> getTempUserInfo() async {
    return _sessionCache.readTemporaryProfile();
  }

  Future<void> _cacheUser(
    UserModel user, {
    bool Function()? isCurrent,
  }) async {
    try {
      await _sessionCache.writeProfile(user, isCurrent: isCurrent);
    } catch (error) {
      print('⚠️ 세션 프로필 캐시 저장 오류: $error');
    }
  }

  /// 프로필 설정 완료 (신규 사용자)
  @override
  Future<UserModel?> completeProfile({
    required String name,
    String? groupId,
  }) async {
    try {
      final temporaryProfile = await _sessionCache.readTemporaryProfile();
      final firebaseUid = _auth.currentUser?.uid;
      final tempUid = temporaryProfile['uid'];
      final uid = resolveProfileCompletionUserId(
        firebaseUserId: firebaseUid,
        temporaryUserId: tempUid,
      );

      if (uid == null && tempUid != null) {
        await _sessionCache.clearTemporaryProfile(expectedUserId: tempUid);
        print('❌ 프로필 완료 오류: Firebase UID와 임시 UID 불일치');
        return null;
      }

      if (uid == null) {
        print('❌ 프로필 완료 오류: UID 없음');
        return null;
      }

      final accountOperation = _operationGuard.activateIfCurrent(
        uid,
        firebaseUserId: _auth.currentUser?.uid,
      );
      if (accountOperation == null) return null;
      bool operationIsCurrent() => _isOperationCurrent(accountOperation);

      final email = temporaryProfile['email'];
      final photoUrl = temporaryProfile['photo'];

      // 사용자 문서 생성
      final userData = {
        'name': name.trim(),
        'email': email,
        'photoUrl': photoUrl,
        'groupId': groupId ?? '',
        'role': 'member',
        'talants': 0,
        'completedVerses': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(userData);
      if (!operationIsCurrent()) return null;

      // 그룹 멤버 수 증가 (set + merge로 안전하게)
      if (groupId != null && groupId.isNotEmpty) {
        await _firestore.collection('groups').doc(groupId).set({
          'memberCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
        if (!operationIsCurrent()) return null;
      }

      // 로컬 저장 정리
      await _sessionCache.clearTemporaryProfile(
        expectedUserId: uid,
        isCurrent: operationIsCurrent,
      );
      if (!operationIsCurrent()) return null;

      final user = UserModel(
        uid: uid,
        name: name.trim(),
        email: email,
        groupId: groupId ?? '',
        role: UserRole.member,
        talants: 0,
        createdAt: DateTime.now(),
      );
      await _cacheUser(user, isCurrent: operationIsCurrent);
      if (!operationIsCurrent()) return null;
      _currentUser = user;

      print('✅ 프로필 설정 완료: $name');
      return user;
    } catch (e) {
      print('❌ 프로필 설정 오류: $e');
      return null;
    }
  }

  // ============================================================
  // 익명 로그인 (레거시 호환)
  // ============================================================

  /// 익명 로그인 + 프로필 등록
  Future<UserModel?> registerAnonymous({
    required String name,
    required String groupId,
  }) async {
    try {
      // 익명 로그인
      final credential = await _auth.signInAnonymously();
      final uid = credential.user!.uid;
      final accountOperation = _operationGuard.activateIfCurrent(
        uid,
        firebaseUserId: _auth.currentUser?.uid,
      );
      if (accountOperation == null) return null;
      bool operationIsCurrent() => _isOperationCurrent(accountOperation);

      // 사용자 문서 생성
      final userData = {
        'name': name,
        'groupId': groupId,
        'role': 'member',
        'talants': 0,
        'completedVerses': [],
        'createdAt': FieldValue.serverTimestamp(),
        'isAnonymous': true,
      };

      await _firestore.collection('users').doc(uid).set(userData);
      if (!operationIsCurrent()) return null;

      // 그룹 멤버 수 증가 (set + merge로 안전하게)
      await _firestore.collection('groups').doc(groupId).set({
        'memberCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      if (!operationIsCurrent()) return null;

      final user = UserModel(
        uid: uid,
        name: name,
        groupId: groupId,
        role: UserRole.member,
        talants: 0,
        createdAt: DateTime.now(),
      );
      await _cacheUser(user, isCurrent: operationIsCurrent);
      if (!operationIsCurrent()) return null;
      _currentUser = user;

      print('✅ 익명 사용자 등록 완료: $name ($groupId)');
      return user;
    } catch (e) {
      print('❌ 익명 사용자 등록 오류: $e');
      return null;
    }
  }

  /// 익명 계정을 소셜 계정으로 연결
  Future<AuthResult> linkAnonymousToGoogle() async {
    final firebaseUser = _auth.currentUser;
    final user = _currentUser;
    final accountOperation = _beginCurrentUserOperation(user);
    if (firebaseUser == null ||
        !firebaseUser.isAnonymous ||
        user == null ||
        accountOperation == null) {
      return AuthResult.error('익명 계정이 아닙니다.');
    }
    bool operationIsCurrent() => _isOperationCurrent(accountOperation);

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.cancelled();
      }
      if (!operationIsCurrent()) return AuthResult.cancelled();

      final googleAuth = await googleUser.authentication;
      if (!operationIsCurrent()) return AuthResult.cancelled();
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await firebaseUser.linkWithCredential(credential);
      if (!operationIsCurrent()) return AuthResult.cancelled();

      // 사용자 정보 업데이트 (set + merge로 안전하게)
      await _firestore.collection('users').doc(user.uid).set({
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl,
        'isAnonymous': false,
      }, SetOptions(merge: true));
      if (!operationIsCurrent()) return AuthResult.cancelled();

      print('✅ Google 계정 연결 완료');
      return AuthResult.success(user: user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        return AuthResult.error('이미 다른 계정에 연결된 Google 계정입니다.');
      }
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      print('❌ Google 계정 연결 오류: $e');
      return AuthResult.error('계정 연결에 실패했습니다.');
    }
  }

  // ============================================================
  // 로그아웃 및 기타
  // ============================================================

  /// 로그아웃
  @override
  Future<void> signOut() async {
    final signingOutUserId = _auth.currentUser?.uid;
    final operation = ++_sessionEpoch;
    _operationGuard.invalidate();
    _currentUser = null;

    bool cleanupIsCurrent() {
      final currentFirebaseUserId = _auth.currentUser?.uid;
      return operation == _sessionEpoch &&
          (currentFirebaseUserId == null ||
              currentFirebaseUserId == signingOutUserId);
    }

    try {
      // Google 로그아웃 (실패해도 계속 진행)
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('⚠️ Google 로그아웃 스킵: $e');
      }

      // Firebase 로그아웃
      await _auth.signOut();
    } catch (e) {
      print('❌ 로그아웃 오류: $e');
    } finally {
      // 인증 작업이 늦게 끝나더라도 명시적 로그아웃 뒤에는 복원하지 않는다.
      try {
        await _sessionCache.clearSessionData(
          isCurrent: cleanupIsCurrent,
        );
      } catch (error) {
        print('⚠️ 로컬 세션 정리 오류: $error');
      }
      print('✅ 로컬 로그아웃 정리 완료');
    }
  }

  /// 사용자 정보 새로고침
  @override
  Future<void> refreshUser() async {
    final firebaseUid = _auth.currentUser?.uid;
    if (firebaseUid == null) return;
    await restoreSession(firebaseUid);
  }

  /// 계정 삭제
  Future<bool> deleteAccount() async {
    final user = _currentUser;
    final firebaseUser = _auth.currentUser;
    final accountOperation = _beginCurrentUserOperation(user);
    if (user == null || firebaseUser == null || accountOperation == null) {
      return false;
    }
    bool operationIsCurrent() => _isOperationCurrent(accountOperation);

    try {
      // Firestore에서 사용자 삭제
      await _firestore.collection('users').doc(user.uid).delete();
      if (!operationIsCurrent()) return false;

      // 그룹 멤버 수 감소 (set + merge로 안전하게)
      if (user.groupId.isNotEmpty) {
        await _firestore.collection('groups').doc(user.groupId).set({
          'memberCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
        if (!operationIsCurrent()) return false;
      }

      // Firebase Auth에서 삭제
      await firebaseUser.delete();
      final remainingFirebaseUid = _auth.currentUser?.uid;
      if (remainingFirebaseUid != null && remainingFirebaseUid != user.uid) {
        return false;
      }

      // 로컬 저장 삭제
      _sessionEpoch++;
      _operationGuard.invalidate();
      _currentUser = null;
      await _sessionCache.clearSessionData(
        isCurrent: () => _auth.currentUser == null,
      );

      print('✅ 계정 삭제 완료');
      return true;
    } catch (e) {
      print('❌ 계정 삭제 오류: $e');
      return false;
    }
  }

  /// Firebase 에러 메시지 변환
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. (6자 이상)';
      case 'operation-not-allowed':
        return '이 로그인 방식은 현재 사용할 수 없습니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'too-many-requests':
        return '너무 많은 시도입니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 오류가 발생했습니다.';
      default:
        return '로그인에 실패했습니다. ($code)';
    }
  }

  // ============================================================
  // 달란트 관련 (기존 코드 유지)
  // ============================================================

  /// 달란트 추가
  @override
  Future<bool> addTalant({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final startingUser = _currentUser;
    final accountOperation = _beginCurrentUserOperation(startingUser);
    if (startingUser == null || accountOperation == null) {
      print('❌ 달란트 적립 실패: 사용자 없음');
      return false;
    }
    bool operationIsCurrent() => _isOperationCurrent(accountOperation);

    try {
      final verseId = UserModel.completedVerseId(
        book: book,
        chapter: chapter,
        verse: verse,
      );
      final userRef = _firestore.collection('users').doc(startingUser.uid);
      final added = await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(userRef);
        final completed =
            ((snapshot.data()?['completedVerses'] as List?) ?? const [])
                .map((value) => value is String ? value : 'legacy:$value')
                .toSet();

        if (completed.contains(verseId)) return false;

        transaction.set(
            userRef,
            {
              'talants': FieldValue.increment(1),
              'completedVerses': FieldValue.arrayUnion([verseId]),
            },
            SetOptions(merge: true));

        if (startingUser.groupId.isNotEmpty) {
          final groupRef =
              _firestore.collection('groups').doc(startingUser.groupId);
          transaction.set(
              groupRef,
              {
                'totalTalants': FieldValue.increment(1),
              },
              SetOptions(merge: true));
        }

        return true;
      });

      if (!added) {
        print('ℹ️ 이미 완료한 구절: $verseId');
        return false;
      }
      if (!operationIsCurrent()) return false;

      final currentUser = _currentUser;
      if (currentUser == null || currentUser.uid != startingUser.uid) {
        return false;
      }
      final updatedUser = currentUser.copyWith(
        talants: currentUser.talants + 1,
        completedVerses: [...currentUser.completedVerses, verseId],
      );
      _currentUser = updatedUser;
      await _cacheUser(updatedUser, isCurrent: operationIsCurrent);
      if (!operationIsCurrent()) return false;

      print('🏆 달란트 적립 완료! 구절 $verseId, 총 ${updatedUser.talants} 달란트');
      return true;
    } catch (e) {
      print('❌ 달란트 적립 오류: $e');
      return false;
    }
  }

  /// 달란트 차감
  @override
  Future<bool> deductTalant(int amount) async {
    final startingUser = _currentUser;
    final accountOperation = _beginCurrentUserOperation(startingUser);
    if (startingUser == null || accountOperation == null) return false;
    if (startingUser.talants < amount) return false;
    bool operationIsCurrent() => _isOperationCurrent(accountOperation);

    try {
      // set + merge로 안전하게 업데이트
      await _firestore.collection('users').doc(startingUser.uid).set({
        'talants': FieldValue.increment(-amount),
      }, SetOptions(merge: true));
      if (!operationIsCurrent()) return false;

      final currentUser = _currentUser;
      if (currentUser == null || currentUser.uid != startingUser.uid) {
        return false;
      }
      final updatedUser = currentUser.copyWith(
        talants: currentUser.talants - amount,
      );
      _currentUser = updatedUser;
      await _cacheUser(updatedUser, isCurrent: operationIsCurrent);
      if (!operationIsCurrent()) return false;

      print('💸 달란트 차감: -$amount');
      return true;
    } catch (e) {
      print('❌ 달란트 차감 오류: $e');
      return false;
    }
  }

  /// 단어 학습 달란트 적립
  Future<int> earnWordStudyTalant({
    required String activityType,
    required int totalWords,
    required int correctCount,
    int bonusMultiplier = 1,
  }) async {
    final startingUser = _currentUser;
    final accountOperation = _beginCurrentUserOperation(startingUser);
    if (startingUser == null || accountOperation == null) return 0;
    bool operationIsCurrent() => _isOperationCurrent(accountOperation);

    try {
      int earnedTalants = 0;

      if (activityType == 'flashcard') {
        final masteryRate = totalWords > 0 ? correctCount / totalWords : 0;
        earnedTalants = 2;
        if (masteryRate >= 0.8) earnedTalants += 2;
        if (masteryRate >= 1.0) earnedTalants += 1;
      } else if (activityType == 'quiz') {
        final accuracy = totalWords > 0 ? correctCount / totalWords : 0;
        if (accuracy >= 0.9) {
          earnedTalants = 5;
        } else if (accuracy >= 0.7) {
          earnedTalants = 3;
        } else if (accuracy >= 0.5) {
          earnedTalants = 2;
        } else {
          earnedTalants = 1;
        }
      }

      earnedTalants *= bonusMultiplier;

      if (earnedTalants > 0) {
        // set + merge로 필드 없어도 안전하게 업데이트
        await _firestore.collection('users').doc(startingUser.uid).set({
          'talants': FieldValue.increment(earnedTalants),
        }, SetOptions(merge: true));
        if (!operationIsCurrent()) return 0;

        if (startingUser.groupId.isNotEmpty) {
          await _firestore.collection('groups').doc(startingUser.groupId).set({
            'totalTalants': FieldValue.increment(earnedTalants),
          }, SetOptions(merge: true));
          if (!operationIsCurrent()) return 0;
        }

        final currentUser = _currentUser;
        if (currentUser == null || currentUser.uid != startingUser.uid) {
          return 0;
        }
        final updatedUser = currentUser.copyWith(
          talants: currentUser.talants + earnedTalants,
        );
        _currentUser = updatedUser;
        await _cacheUser(updatedUser, isCurrent: operationIsCurrent);
        if (!operationIsCurrent()) return 0;

        print('🏆 단어 학습 달란트 적립! +$earnedTalants ($activityType)');
      }

      return earnedTalants;
    } catch (e) {
      print('❌ 단어 학습 달란트 적립 오류: $e');
      return 0;
    }
  }

  /// 일일 목표 달성 보너스
  Future<bool> addDailyGoalBonus() async {
    final startingUser = _currentUser;
    final accountOperation = _beginCurrentUserOperation(startingUser);
    if (startingUser == null || accountOperation == null) return false;
    bool operationIsCurrent() => _isOperationCurrent(accountOperation);

    try {
      const bonusTalants = 3;

      // set + merge로 필드 없어도 안전하게 업데이트
      await _firestore.collection('users').doc(startingUser.uid).set({
        'talants': FieldValue.increment(bonusTalants),
      }, SetOptions(merge: true));
      if (!operationIsCurrent()) return false;

      if (startingUser.groupId.isNotEmpty) {
        await _firestore.collection('groups').doc(startingUser.groupId).set({
          'totalTalants': FieldValue.increment(bonusTalants),
        }, SetOptions(merge: true));
        if (!operationIsCurrent()) return false;
      }

      final currentUser = _currentUser;
      if (currentUser == null || currentUser.uid != startingUser.uid) {
        return false;
      }
      final updatedUser = currentUser.copyWith(
        talants: currentUser.talants + bonusTalants,
      );
      _currentUser = updatedUser;
      await _cacheUser(updatedUser, isCurrent: operationIsCurrent);
      if (!operationIsCurrent()) return false;

      print('🎯 일일 목표 달성 보너스! +$bonusTalants');
      return true;
    } catch (e) {
      print('❌ 일일 목표 보너스 오류: $e');
      return false;
    }
  }
}

/// 인증 결과
class AuthResult {
  final bool success;
  final bool cancelled;
  final bool needsProfile;
  final String? errorMessage;
  final UserModel? user;
  final String? tempUid;

  const AuthResult._({
    required this.success,
    this.cancelled = false,
    this.needsProfile = false,
    this.errorMessage,
    this.user,
    this.tempUid,
  });

  factory AuthResult.success(
      {UserModel? user, bool needsProfile = false, String? tempUid}) {
    return AuthResult._(
      success: true,
      user: user,
      needsProfile: needsProfile,
      tempUid: tempUid,
    );
  }

  factory AuthResult.error(String message) {
    return AuthResult._(success: false, errorMessage: message);
  }

  factory AuthResult.cancelled() {
    return AuthResult._(success: false, cancelled: true);
  }
}
