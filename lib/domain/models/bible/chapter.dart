import 'package:cloud_firestore/cloud_firestore.dart';

/// 성경 챕터 모델 (Firestore 연동)
class Chapter {
  final String bookId;
  final int chapter;
  final int verseCount;
  final String? audioUrl;
  final int? audioDurationMs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Chapter({
    required this.bookId,
    required this.chapter,
    required this.verseCount,
    this.audioUrl,
    this.audioDurationMs,
    this.createdAt,
    this.updatedAt,
  });

  /// Firestore Document → Chapter
  factory Chapter.fromFirestore(DocumentSnapshot doc, {required String bookId}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Chapter(
      bookId: bookId,
      chapter: int.tryParse(doc.id) ?? data['chapter'] ?? 0,
      verseCount: data['verseCount'] ?? 0,
      audioUrl: data['audioUrl'],
      audioDurationMs: data['audioDurationMs'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Chapter → Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'chapter': chapter,
      'verseCount': verseCount,
      'audioUrl': audioUrl,
      'audioDurationMs': audioDurationMs,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 고유 키
  String get key => '${bookId}_$chapter';

  /// 복사본 생성
  Chapter copyWith({
    String? bookId,
    int? chapter,
    int? verseCount,
    String? audioUrl,
    int? audioDurationMs,
  }) {
    return Chapter(
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verseCount: verseCount ?? this.verseCount,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'Chapter($bookId:$chapter, verses: $verseCount)';
}
