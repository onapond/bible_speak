import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// 인증 서비스
/// - Firebase Auth 기반 로그인/로그아웃
/// - 사용자 프로필 관리
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      // 저장된 세션이 있지만 Firebase 인증이 안된 경우 - 익명 로그인 시도
      if (savedUserId != null && _auth.currentUser == null) {
        await _auth.signInAnonymously();
        final userDoc = await _firestore.collection('users').doc(savedUserId).get();
        if (userDoc.exists) {
          _currentUser = UserModel.fromFirestore(savedUserId, userDoc.data()!);
          print('✅ 익명 로그인 후 세션 복원: ${_currentUser!.name}');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ AuthService 초기화 오류: $e');
      return false;
    }
  }

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

      print('✅ 사용자 등록 완료: $name ($groupId)');
      return _currentUser;
    } catch (e) {
      print('❌ 사용자 등록 오류: $e');
      return null;
    }
  }

  /// 이메일 로그인 (추후 확장용)
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        _currentUser = UserModel.fromFirestore(uid, userDoc.data()!);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bible_speak_userId', uid);

        return _currentUser;
      }
      return null;
    } catch (e) {
      print('❌ 이메일 로그인 오류: $e');
      return null;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
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

  /// 달란트 추가
  Future<bool> addTalant(int verseNumber) async {
    if (_currentUser == null) return false;

    try {
      // 이미 완료한 구절인지 확인
      if (_currentUser!.completedVerses.contains(verseNumber)) {
        return false;
      }

      await _firestore.runTransaction((transaction) async {
        // 사용자 달란트 증가
        transaction.update(
          _firestore.collection('users').doc(_currentUser!.uid),
          {
            'talants': FieldValue.increment(1),
            'completedVerses': FieldValue.arrayUnion([verseNumber]),
          },
        );

        // 그룹 달란트 증가
        transaction.update(
          _firestore.collection('groups').doc(_currentUser!.groupId),
          {
            'totalTalants': FieldValue.increment(1),
          },
        );
      });

      // 로컬 캐시 업데이트
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
}
