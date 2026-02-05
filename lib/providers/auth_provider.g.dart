// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authServiceHash() => r'21d842d4dceafa3d239c0196a0f2b890d37c0b71';

/// AuthService 싱글톤 인스턴스
///
/// Copied from [authService].
@ProviderFor(authService)
final authServiceProvider = Provider<AuthService>.internal(
  authService,
  name: r'authServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthServiceRef = ProviderRef<AuthService>;
String _$currentUserHash() => r'2ca9a9669a38594db1ca09455f01e023fa16d4ea';

/// 현재 사용자 (편의용 Provider)
///
/// Copied from [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = AutoDisposeProvider<UserModel?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserRef = AutoDisposeProviderRef<UserModel?>;
String _$userTalantsHash() => r'8ab1f43b268d73e0f7c67e3deac604e0200f276a';

/// 사용자 탈란트 (반응형)
///
/// Copied from [userTalants].
@ProviderFor(userTalants)
final userTalantsProvider = AutoDisposeProvider<int>.internal(
  userTalants,
  name: r'userTalantsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userTalantsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserTalantsRef = AutoDisposeProviderRef<int>;
String _$userNameHash() => r'c964c55be93b1e386fe204afa20352434963402b';

/// 사용자 이름
///
/// Copied from [userName].
@ProviderFor(userName)
final userNameProvider = AutoDisposeProvider<String?>.internal(
  userName,
  name: r'userNameProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userNameHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserNameRef = AutoDisposeProviderRef<String?>;
String _$userGroupIdHash() => r'24dda62c0e2cfa9890fc5422ca840438956638de';

/// 사용자 그룹 ID
///
/// Copied from [userGroupId].
@ProviderFor(userGroupId)
final userGroupIdProvider = AutoDisposeProvider<String>.internal(
  userGroupId,
  name: r'userGroupIdProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userGroupIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserGroupIdRef = AutoDisposeProviderRef<String>;
String _$authNotifierHash() => r'a1ba41d2fb61d6dcfc625db2a413543ccbb7c95b';

/// Auth 상태 관리 Notifier
///
/// Copied from [AuthNotifier].
@ProviderFor(AuthNotifier)
final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<UserModel?>>.internal(
  AuthNotifier.new,
  name: r'authNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthNotifier = Notifier<AsyncValue<UserModel?>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
