import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'core_providers.g.dart';

/// Firebase Auth 인스턴스 (싱글톤)
@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

/// Firestore 인스턴스 (싱글톤)
@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

/// SharedPreferences 인스턴스 (비동기 초기화)
@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return await SharedPreferences.getInstance();
}

/// Firebase Auth 상태 스트림
@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(Ref ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}

/// Firebase 인증 복원이 확정된 뒤 방출되는 UID 스트림.
/// 테스트에서 Firebase User 객체 없이 지연·계정 전환을 재현할 수 있다.
Stream<String?> authUserIdChanges(Ref ref) {
  return ref
      .watch(firebaseAuthProvider)
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct();
}

final authUserIdChangesProvider = StreamProvider<String?>(
  authUserIdChanges,
  name: 'authUserIdChangesProvider',
);

/// 현재 Firebase User (동기적 접근)
@riverpod
User? firebaseUser(Ref ref) {
  return ref.watch(firebaseAuthProvider).currentUser;
}

/// 로그인 여부 (단순 체크)
@riverpod
bool isLoggedIn(Ref ref) {
  final authState = ref.watch(authUserIdChangesProvider);
  return authState.when(
    data: (userId) => userId != null,
    loading: () => false,
    error: (_, __) => false,
  );
}
