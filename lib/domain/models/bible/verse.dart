import 'package:cloud_firestore/cloud_firestore.dart';

/// 성경 구절 모델 (Firestore 연동)
class Verse {
  final String bookId;
  final int chapter;
  final int verse;
  final String textEn;
  final String textKo;
  final String? audioUrl;
  final double? audioStart; // 초 단위 (챕터 오디오 내 시작점)
  final double? audioEnd; // 초 단위 (챕터 오디오 내 종료점)
  final int? audioDurationMs;
  final List<String> keyWords;
  final int difficulty; // 1-5
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Verse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.textEn,
    required this.textKo,
    this.audioUrl,
    this.audioStart,
    this.audioEnd,
    this.audioDurationMs,
    this.keyWords = const [],
    this.difficulty = 2,
    this.createdAt,
    this.updatedAt,
  });

  /// Firestore Document → Verse
  factory Verse.fromFirestore(
    DocumentSnapshot doc, {
    required String bookId,
    required int chapter,
  }) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Verse(
      bookId: bookId,
      chapter: chapter,
      verse: int.tryParse(doc.id) ?? data['verse'] ?? 0,
      textEn: data['textEn'] ?? '',
      textKo: data['textKo'] ?? '',
      audioUrl: data['audioUrl'],
      audioStart: (data['audioStart'] as num?)?.toDouble(),
      audioEnd: (data['audioEnd'] as num?)?.toDouble(),
      audioDurationMs: data['audioDurationMs'],
      keyWords: List<String>.from(data['keyWords'] ?? []),
      difficulty: data['difficulty'] ?? 2,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Verse → Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'verse': verse,
      'textEn': textEn,
      'textKo': textKo,
      'audioUrl': audioUrl,
      'audioStart': audioStart,
      'audioEnd': audioEnd,
      'audioDurationMs': audioDurationMs,
      'keyWords': keyWords,
      'difficulty': difficulty,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 고유 키
  String get key => '${bookId}_${chapter}_$verse';

  /// 참조 텍스트 (예: "말라기 1:1")
  String reference(String bookNameKo) => '$bookNameKo $chapter:$verse';

  /// ESV 참조 형식 (예: "Malachi 1:1")
  String esvReference(String bookNameEn) => '$bookNameEn $chapter:$verse';

  /// 영문 텍스트 단어 수
  int get wordCount => textEn.split(RegExp(r'\s+')).length;

  /// 짧은 구절 여부 (10단어 이하)
  bool get isShort => wordCount <= 10;

  /// 긴 구절 여부 (30단어 이상)
  bool get isLong => wordCount >= 30;

  /// 복사본 생성
  Verse copyWith({
    String? bookId,
    int? chapter,
    int? verse,
    String? textEn,
    String? textKo,
    String? audioUrl,
    double? audioStart,
    double? audioEnd,
    int? audioDurationMs,
    List<String>? keyWords,
    int? difficulty,
  }) {
    return Verse(
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      textEn: textEn ?? this.textEn,
      textKo: textKo ?? this.textKo,
      audioUrl: audioUrl ?? this.audioUrl,
      audioStart: audioStart ?? this.audioStart,
      audioEnd: audioEnd ?? this.audioEnd,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      keyWords: keyWords ?? this.keyWords,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'Verse($bookId $chapter:$verse)';
}
