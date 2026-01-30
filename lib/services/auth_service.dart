import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// 인증 서비스
/// - Firebase Auth 기반 로그인/로그아웃
/// - Google, Apple, Email 로그인 지원
/// - 사용자 프로필 관리
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // 현재 사용자 캐시
  UserModel? _currentUser;

  /// 현재 로그인된 사용자
  UserModel? get currentUser => _currentUser;

  /// 로그인 여부
  bool get isLoggedIn => _currentUser != null;

  /// 현재 Firebase User
  User? get firebaseUser => _auth.currentUser;

  /// 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 초기화 - 저장된 세션 복원
  Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('bible_speak_userId');

      if (savedUserId != null && _auth.currentUser != null) {
        // Firestore에서 사용자 정보 로드
        final userDoc = await _firestore.collection('users').doc(savedUserId).get();
        if (userDoc.exists) {
          _currentUser = UserModel.fromFirestore(savedUserId, userDoc.data()!);
          print('✅ 세션 복원: ${_currentUser!.name}');
          return true;
        }
      }

      // Firebase 인증이 있지만 로컬 저장이 없는 경우 - 복원 시도
      if (_auth.currentUser != null) {
        final uid = _auth.currentUser!.uid;
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          _currentUser = UserModel.fromFirestore(uid, userDoc.data()!);
          await prefs.setString('bible_speak_userId', uid);
          print('✅ Firebase 세션 복원: ${_currentUser!.name}');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ AuthService 초기화 오류: $e');
      return false;
    }
  }

  // ============================================================
  // Google 로그인
  // ============================================================

  /// Google 로그인
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
      return _handleUserCredential(
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
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        displayName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
      }

      return _handleUserCredential(
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
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return _handleUserCredential(userCredential, email: email.trim());
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      print('❌ 이메일 로그인 오류: $e');
      return AuthResult.error('이메일 로그인에 실패했습니다.');
    }
  }

  /// 이메일 회원가입
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

      return _handleUserCredential(
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

    // Firestore에서 사용자 확인
    final userDoc = await _firestore.collection('users').doc(uid).get();

    if (userDoc.exists) {
      // 기존 사용자 - 로그인 완료
      _currentUser = UserModel.fromFirestore(uid, userDoc.data()!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bible_speak_userId', uid);

      print('✅ 로그인 완료: ${_currentUser!.name}');
      return AuthResult.success(user: _currentUser);
    } else {
      // 신규 사용자 - 프로필 설정 필요
      // 임시로 Firebase Auth 정보 저장
      await _saveTempUserInfo(uid, displayName, email, photoUrl);

      print('📝 신규 사용자 - 프로필 설정 필요');
      return AuthResult.success(needsProfile: true, tempUid: uid);
    }
  }

  /// 임시 사용자 정보 저장
  Future<void> _saveTempUserInfo(
    String uid,
    String? displayName,
    String? email,
    String? photoUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bible_speak_tempUid', uid);
    if (displayName != null) {
      await prefs.setString('bible_speak_tempName', displayName);
    }
    if (email != null) {
      await prefs.setString('bible_speak_tempEmail', email);
    }
    if (photoUrl != null) {
      await prefs.setString('bible_speak_tempPhoto', photoUrl);
    }
  }

  /// 임시 저장된 사용자 정보 가져오기
  Future<Map<String, String?>> getTempUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'uid': prefs.getString('bible_speak_tempUid'),
      'name': prefs.getString('bible_speak_tempName'),
      'email': prefs.getString('bible_speak_tempEmail'),
      'photo': prefs.getString('bible_speak_tempPhoto'),
    };
  }

  /// 프로필 설정 완료 (신규 사용자)
  Future<UserModel?> completeProfile({
    required String name,
    String? groupId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('bible_speak_tempUid') ?? _auth.currentUser?.uid;

    if (uid == null) {
      print('❌ 프로필 완료 오류: UID 없음');
      return null;
    }

    try {
      final email = prefs.getString('bible_speak_tempEmail');
      final photoUrl = prefs.getString('bible_speak_tempPhoto');

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

      // 그룹 멤버 수 증가
      if (groupId != null && groupId.isNotEmpty) {
        await _firestore.collection('groups').doc(groupId).update({
          'memberCount': FieldValue.increment(1),
        });
      }

      // 로컬 저장 정리
      await prefs.remove('bible_speak_tempUid');
      await prefs.remove('bible_speak_tempName');
      await prefs.remove('bible_speak_tempEmail');
      await prefs.remove('bible_speak_tempPhoto');
      await prefs.setString('bible_speak_userId', uid);

      _currentUser = UserModel(
        uid: uid,
        name: name.trim(),
        email: email,
        groupId: groupId ?? '',
        role: UserRole.member,
        talants: 0,
        createdAt: DateTime.now(),
      );

      print('✅ 프로필 설정 완료: $name');
      return _currentUser;
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

      // 그룹 멤버 수 증가
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(1),
      });

      // 로컬 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bible_speak_userId', uid);
      await prefs.setString('bible_speak_userName', name);
      await prefs.setString('bible_speak_groupId', groupId);

      _currentUser = UserModel(
        uid: uid,
        name: name,
        groupId: groupId,
        role: UserRole.member,
        talants: 0,
        createdAt: DateTime.now(),
      );

      print('✅ 익명 사용자 등록 완료: $name ($groupId)');
      return _currentUser;
    } catch (e) {
      print('❌ 익명 사용자 등록 오류: $e');
      return null;
    }
  }

  /// 익명 계정을 소셜 계정으로 연결
  Future<AuthResult> linkAnonymousToGoogle() async {
    if (_auth.currentUser == null || !_auth.currentUser!.isAnonymous) {
      return AuthResult.error('익명 계정이 아닙니다.');
    }

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.cancelled();
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.currentUser!.linkWithCredential(credential);

      // 사용자 정보 업데이트
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl,
        'isAnonymous': false,
      });

      print('✅ Google 계정 연결 완료');
      return AuthResult.success(user: _currentUser);
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
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _currentUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('bible_speak_userId');
      await prefs.remove('bible_speak_userName');
      await prefs.remove('bible_speak_groupId');

      print('✅ 로그아웃 완료');
    } catch (e) {
      print('❌ 로그아웃 오류: $e');
    }
  }

  /// 사용자 정보 새로고침
  Future<void> refreshUser() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        _currentUser = UserModel.fromFirestore(_currentUser!.uid, userDoc.data()!);
      }
    } catch (e) {
      print('❌ 사용자 정보 새로고침 오류: $e');
    }
  }

  /// 계정 삭제
  Future<bool> deleteAccount() async {
    if (_currentUser == null || _auth.currentUser == null) return false;

    try {
      // Firestore에서 사용자 삭제
      await _firestore.collection('users').doc(_currentUser!.uid).delete();

      // 그룹 멤버 수 감소
      if (_currentUser!.groupId.isNotEmpty) {
        await _firestore.collection('groups').doc(_currentUser!.groupId).update({
          'memberCount': FieldValue.increment(-1),
        });
      }

      // Firebase Auth에서 삭제
      await _auth.currentUser!.delete();

      // 로컬 저장 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _currentUser = null;

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
  Future<bool> addTalant(int verseNumber) async {
    if (_currentUser == null) return false;

    try {
      if (_currentUser!.completedVerses.contains(verseNumber)) {
        return false;
      }

      await _firestore.runTransaction((transaction) async {
        transaction.update(
          _firestore.collection('users').doc(_currentUser!.uid),
          {
            'talants': FieldValue.increment(1),
            'completedVerses': FieldValue.arrayUnion([verseNumber]),
          },
        );

        if (_currentUser!.groupId.isNotEmpty) {
          transaction.update(
            _firestore.collection('groups').doc(_currentUser!.groupId),
            {
              'totalTalants': FieldValue.increment(1),
            },
          );
        }
      });

      _currentUser = _currentUser!.copyWith(
        talants: _currentUser!.talants + 1,
        completedVerses: [..._currentUser!.completedVerses, verseNumber],
      );

      print('🏆 달란트 적립! 구절 $verseNumber');
      return true;
    } catch (e) {
      print('❌ 달란트 적립 오류: $e');
      return false;
    }
  }

  /// 달란트 차감
  Future<bool> deductTalant(int amount) async {
    if (_currentUser == null) return false;
    if (_currentUser!.talants < amount) return false;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'talants': FieldValue.increment(-amount),
      });

      _currentUser = _currentUser!.copyWith(
        talants: _currentUser!.talants - amount,
      );

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
    if (_currentUser == null) return 0;

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
        await _firestore.runTransaction((transaction) async {
          transaction.update(
            _firestore.collection('users').doc(_currentUser!.uid),
            {
              'talants': FieldValue.increment(earnedTalants),
            },
          );

          if (_currentUser!.groupId.isNotEmpty) {
            transaction.update(
              _firestore.collection('groups').doc(_currentUser!.groupId),
              {
                'totalTalants': FieldValue.increment(earnedTalants),
              },
            );
          }
        });

        _currentUser = _currentUser!.copyWith(
          talants: _currentUser!.talants + earnedTalants,
        );

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
    if (_currentUser == null) return false;

    try {
      const bonusTalants = 3;

      await _firestore.runTransaction((transaction) async {
        transaction.update(
          _firestore.collection('users').doc(_currentUser!.uid),
          {
            'talants': FieldValue.increment(bonusTalants),
          },
        );

        if (_currentUser!.groupId.isNotEmpty) {
          transaction.update(
            _firestore.collection('groups').doc(_currentUser!.groupId),
            {
              'totalTalants': FieldValue.increment(bonusTalants),
            },
          );
        }
      });

      _currentUser = _currentUser!.copyWith(
        talants: _currentUser!.talants + bonusTalants,
      );

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

  factory AuthResult.success({UserModel? user, bool needsProfile = false, String? tempUid}) {
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
