import 'package:cloud_firestore/cloud_firestore.dart';

/// 성경책 모델 (Firestore 연동)
class Book {
  final String id;
  final String nameKo;
  final String nameEn;
  final String nameEsv;
  final String testament; // "OT" | "NT"
  final int chapterCount;
  final int totalVerses;
  final int order;
  final String? audioBaseUrl;
  final bool isFree;
  final bool isPremium;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Book({
    required this.id,
    required this.nameKo,
    required this.nameEn,
    required this.nameEsv,
    required this.testament,
    required this.chapterCount,
    required this.totalVerses,
    required this.order,
    this.audioBaseUrl,
    this.isFree = false,
    this.isPremium = false,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  /// Firestore Document → Book
  factory Book.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Book(
      id: doc.id,
      nameKo: data['nameKo'] ?? '',
      nameEn: data['nameEn'] ?? '',
      nameEsv: data['nameEsv'] ?? data['nameEn'] ?? '',
      testament: data['testament'] ?? 'OT',
      chapterCount: data['chapterCount'] ?? 0,
      totalVerses: data['totalVerses'] ?? 0,
      order: data['order'] ?? 0,
      audioBaseUrl: data['audioBaseUrl'],
      isFree: data['isFree'] ?? false,
      isPremium: data['isPremium'] ?? false,
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Book → Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'nameKo': nameKo,
      'nameEn': nameEn,
      'nameEsv': nameEsv,
      'testament': testament,
      'chapterCount': chapterCount,
      'totalVerses': totalVerses,
      'order': order,
      'audioBaseUrl': audioBaseUrl,
      'isFree': isFree,
      'isPremium': isPremium,
      'description': description,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 구약 여부
  bool get isOldTestament => testament == 'OT';

  /// 신약 여부
  bool get isNewTestament => testament == 'NT';

  /// 복사본 생성
  Book copyWith({
    String? id,
    String? nameKo,
    String? nameEn,
    String? nameEsv,
    String? testament,
    int? chapterCount,
    int? totalVerses,
    int? order,
    String? audioBaseUrl,
    bool? isFree,
    bool? isPremium,
    String? description,
  }) {
    return Book(
      id: id ?? this.id,
      nameKo: nameKo ?? this.nameKo,
      nameEn: nameEn ?? this.nameEn,
      nameEsv: nameEsv ?? this.nameEsv,
      testament: testament ?? this.testament,
      chapterCount: chapterCount ?? this.chapterCount,
      totalVerses: totalVerses ?? this.totalVerses,
      order: order ?? this.order,
      audioBaseUrl: audioBaseUrl ?? this.audioBaseUrl,
      isFree: isFree ?? this.isFree,
      isPremium: isPremium ?? this.isPremium,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'Book($id: $nameKo)';
}
