// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$progressServiceHash() => r'0a0392b1be4d6ae3517a5b9c8795123bed377397';

/// ProgressService 싱글톤 인스턴스
///
/// Copied from [progressService].
@ProviderFor(progressService)
final progressServiceProvider = Provider<ProgressService>.internal(
  progressService,
  name: r'progressServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$progressServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProgressServiceRef = ProviderRef<ProgressService>;
String _$verseProgressHash() => r'0ee9da23affa4f441a621f43a2f959435e406fae';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 특정 구절의 진행 상태 (Family Provider)
///
/// Copied from [verseProgress].
@ProviderFor(verseProgress)
const verseProgressProvider = VerseProgressFamily();

/// 특정 구절의 진행 상태 (Family Provider)
///
/// Copied from [verseProgress].
class VerseProgressFamily extends Family<AsyncValue<VerseProgress>> {
  /// 특정 구절의 진행 상태 (Family Provider)
  ///
  /// Copied from [verseProgress].
  const VerseProgressFamily();

  /// 특정 구절의 진행 상태 (Family Provider)
  ///
  /// Copied from [verseProgress].
  VerseProgressProvider call({
    required String book,
    required int chapter,
    required int verse,
  }) {
    return VerseProgressProvider(
      book: book,
      chapter: chapter,
      verse: verse,
    );
  }

  @override
  VerseProgressProvider getProviderOverride(
    covariant VerseProgressProvider provider,
  ) {
    return call(
      book: provider.book,
      chapter: provider.chapter,
      verse: provider.verse,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'verseProgressProvider';
}

/// 특정 구절의 진행 상태 (Family Provider)
///
/// Copied from [verseProgress].
class VerseProgressProvider extends AutoDisposeFutureProvider<VerseProgress> {
  /// 특정 구절의 진행 상태 (Family Provider)
  ///
  /// Copied from [verseProgress].
  VerseProgressProvider({
    required String book,
    required int chapter,
    required int verse,
  }) : this._internal(
          (ref) => verseProgress(
            ref as VerseProgressRef,
            book: book,
            chapter: chapter,
            verse: verse,
          ),
          from: verseProgressProvider,
          name: r'verseProgressProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$verseProgressHash,
          dependencies: VerseProgressFamily._dependencies,
          allTransitiveDependencies:
              VerseProgressFamily._allTransitiveDependencies,
          book: book,
          chapter: chapter,
          verse: verse,
        );

  VerseProgressProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.book,
    required this.chapter,
    required this.verse,
  }) : super.internal();

  final String book;
  final int chapter;
  final int verse;

  @override
  Override overrideWith(
    FutureOr<VerseProgress> Function(VerseProgressRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VerseProgressProvider._internal(
        (ref) => create(ref as VerseProgressRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        book: book,
        chapter: chapter,
        verse: verse,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<VerseProgress> createElement() {
    return _VerseProgressProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VerseProgressProvider &&
        other.book == book &&
        other.chapter == chapter &&
        other.verse == verse;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, book.hashCode);
    hash = _SystemHash.combine(hash, chapter.hashCode);
    hash = _SystemHash.combine(hash, verse.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VerseProgressRef on AutoDisposeFutureProviderRef<VerseProgress> {
  /// The parameter `book` of this provider.
  String get book;

  /// The parameter `chapter` of this provider.
  int get chapter;

  /// The parameter `verse` of this provider.
  int get verse;
}

class _VerseProgressProviderElement
    extends AutoDisposeFutureProviderElement<VerseProgress>
    with VerseProgressRef {
  _VerseProgressProviderElement(super.provider);

  @override
  String get book => (origin as VerseProgressProvider).book;
  @override
  int get chapter => (origin as VerseProgressProvider).chapter;
  @override
  int get verse => (origin as VerseProgressProvider).verse;
}

String _$chapterProgressHash() => r'0ded783894fbd65ae8af085f07dd4e68b0b816b6';

/// 챕터 진행 상태 (Family Provider)
///
/// Copied from [chapterProgress].
@ProviderFor(chapterProgress)
const chapterProgressProvider = ChapterProgressFamily();

/// 챕터 진행 상태 (Family Provider)
///
/// Copied from [chapterProgress].
class ChapterProgressFamily extends Family<AsyncValue<ChapterProgress>> {
  /// 챕터 진행 상태 (Family Provider)
  ///
  /// Copied from [chapterProgress].
  const ChapterProgressFamily();

  /// 챕터 진행 상태 (Family Provider)
  ///
  /// Copied from [chapterProgress].
  ChapterProgressProvider call({
    required String book,
    required int chapter,
    required int totalVerses,
  }) {
    return ChapterProgressProvider(
      book: book,
      chapter: chapter,
      totalVerses: totalVerses,
    );
  }

  @override
  ChapterProgressProvider getProviderOverride(
    covariant ChapterProgressProvider provider,
  ) {
    return call(
      book: provider.book,
      chapter: provider.chapter,
      totalVerses: provider.totalVerses,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chapterProgressProvider';
}

/// 챕터 진행 상태 (Family Provider)
///
/// Copied from [chapterProgress].
class ChapterProgressProvider
    extends AutoDisposeFutureProvider<ChapterProgress> {
  /// 챕터 진행 상태 (Family Provider)
  ///
  /// Copied from [chapterProgress].
  ChapterProgressProvider({
    required String book,
    required int chapter,
    required int totalVerses,
  }) : this._internal(
          (ref) => chapterProgress(
            ref as ChapterProgressRef,
            book: book,
            chapter: chapter,
            totalVerses: totalVerses,
          ),
          from: chapterProgressProvider,
          name: r'chapterProgressProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chapterProgressHash,
          dependencies: ChapterProgressFamily._dependencies,
          allTransitiveDependencies:
              ChapterProgressFamily._allTransitiveDependencies,
          book: book,
          chapter: chapter,
          totalVerses: totalVerses,
        );

  ChapterProgressProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.book,
    required this.chapter,
    required this.totalVerses,
  }) : super.internal();

  final String book;
  final int chapter;
  final int totalVerses;

  @override
  Override overrideWith(
    FutureOr<ChapterProgress> Function(ChapterProgressRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChapterProgressProvider._internal(
        (ref) => create(ref as ChapterProgressRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        book: book,
        chapter: chapter,
        totalVerses: totalVerses,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ChapterProgress> createElement() {
    return _ChapterProgressProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChapterProgressProvider &&
        other.book == book &&
        other.chapter == chapter &&
        other.totalVerses == totalVerses;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, book.hashCode);
    hash = _SystemHash.combine(hash, chapter.hashCode);
    hash = _SystemHash.combine(hash, totalVerses.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChapterProgressRef on AutoDisposeFutureProviderRef<ChapterProgress> {
  /// The parameter `book` of this provider.
  String get book;

  /// The parameter `chapter` of this provider.
  int get chapter;

  /// The parameter `totalVerses` of this provider.
  int get totalVerses;
}

class _ChapterProgressProviderElement
    extends AutoDisposeFutureProviderElement<ChapterProgress>
    with ChapterProgressRef {
  _ChapterProgressProviderElement(super.provider);

  @override
  String get book => (origin as ChapterProgressProvider).book;
  @override
  int get chapter => (origin as ChapterProgressProvider).chapter;
  @override
  int get totalVerses => (origin as ChapterProgressProvider).totalVerses;
}

String _$chapterScoresHash() => r'96fcb3acf0110df77f6cd37ca44101525452dbdd';

/// 챕터별 점수 맵 (Family Provider)
///
/// Copied from [chapterScores].
@ProviderFor(chapterScores)
const chapterScoresProvider = ChapterScoresFamily();

/// 챕터별 점수 맵 (Family Provider)
///
/// Copied from [chapterScores].
class ChapterScoresFamily extends Family<AsyncValue<Map<int, double>>> {
  /// 챕터별 점수 맵 (Family Provider)
  ///
  /// Copied from [chapterScores].
  const ChapterScoresFamily();

  /// 챕터별 점수 맵 (Family Provider)
  ///
  /// Copied from [chapterScores].
  ChapterScoresProvider call({
    required String book,
    required int chapter,
    required int totalVerses,
  }) {
    return ChapterScoresProvider(
      book: book,
      chapter: chapter,
      totalVerses: totalVerses,
    );
  }

  @override
  ChapterScoresProvider getProviderOverride(
    covariant ChapterScoresProvider provider,
  ) {
    return call(
      book: provider.book,
      chapter: provider.chapter,
      totalVerses: provider.totalVerses,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chapterScoresProvider';
}

/// 챕터별 점수 맵 (Family Provider)
///
/// Copied from [chapterScores].
class ChapterScoresProvider
    extends AutoDisposeFutureProvider<Map<int, double>> {
  /// 챕터별 점수 맵 (Family Provider)
  ///
  /// Copied from [chapterScores].
  ChapterScoresProvider({
    required String book,
    required int chapter,
    required int totalVerses,
  }) : this._internal(
          (ref) => chapterScores(
            ref as ChapterScoresRef,
            book: book,
            chapter: chapter,
            totalVerses: totalVerses,
          ),
          from: chapterScoresProvider,
          name: r'chapterScoresProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chapterScoresHash,
          dependencies: ChapterScoresFamily._dependencies,
          allTransitiveDependencies:
              ChapterScoresFamily._allTransitiveDependencies,
          book: book,
          chapter: chapter,
          totalVerses: totalVerses,
        );

  ChapterScoresProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.book,
    required this.chapter,
    required this.totalVerses,
  }) : super.internal();

  final String book;
  final int chapter;
  final int totalVerses;

  @override
  Override overrideWith(
    FutureOr<Map<int, double>> Function(ChapterScoresRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChapterScoresProvider._internal(
        (ref) => create(ref as ChapterScoresRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        book: book,
        chapter: chapter,
        totalVerses: totalVerses,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<int, double>> createElement() {
    return _ChapterScoresProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChapterScoresProvider &&
        other.book == book &&
        other.chapter == chapter &&
        other.totalVerses == totalVerses;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, book.hashCode);
    hash = _SystemHash.combine(hash, chapter.hashCode);
    hash = _SystemHash.combine(hash, totalVerses.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChapterScoresRef on AutoDisposeFutureProviderRef<Map<int, double>> {
  /// The parameter `book` of this provider.
  String get book;

  /// The parameter `chapter` of this provider.
  int get chapter;

  /// The parameter `totalVerses` of this provider.
  int get totalVerses;
}

class _ChapterScoresProviderElement
    extends AutoDisposeFutureProviderElement<Map<int, double>>
    with ChapterScoresRef {
  _ChapterScoresProviderElement(super.provider);

  @override
  String get book => (origin as ChapterScoresProvider).book;
  @override
  int get chapter => (origin as ChapterScoresProvider).chapter;
  @override
  int get totalVerses => (origin as ChapterScoresProvider).totalVerses;
}

String _$progressNotifierHash() => r'0e92fbc0ea671f93f1a22f1e3be582205cfe7324';

/// Progress 관리 Notifier
///
/// Copied from [ProgressNotifier].
@ProviderFor(ProgressNotifier)
final progressNotifierProvider =
    AsyncNotifierProvider<ProgressNotifier, void>.internal(
  ProgressNotifier.new,
  name: r'progressNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$progressNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ProgressNotifier = AsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
