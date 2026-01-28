import 'package:cloud_firestore/cloud_firestore.dart';

/// 일일 퀴즈 유형
enum DailyQuizType {
  fillBlank('빈칸 채우기', '구절의 빈칸을 채우세요'),
  verseOrder('순서 맞추기', '단어를 올바른 순서로 배열하세요'),
  reference('구절 찾기', '구절의 장절을 맞추세요'),
  meaning('의미 맞추기', '단어의 의미를 선택하세요');

  final String label;
  final String description;
  const DailyQuizType(this.label, this.description);
}

/// 일일 퀴즈 문제
class DailyQuizQuestion {
  final String id;
  final DailyQuizType type;
  final String question;
  final String? verseText;
  final String? verseReference;
  final List<String> options;
  final String correctAnswer;
  final int points;

  const DailyQuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.verseText,
    this.verseReference,
    required this.options,
    required this.correctAnswer,
    this.points = 10,
  });

  factory DailyQuizQuestion.fromFirestore(Map<String, dynamic> data) {
    return DailyQuizQuestion(
      id: data['id'] ?? '',
      type: DailyQuizType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => DailyQuizType.fillBlank,
      ),
      question: data['question'] ?? '',
      verseText: data['verseText'],
      verseReference: data['verseReference'],
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? '',
      points: data['points'] ?? 10,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type.name,
      'question': question,
      'verseText': verseText,
      'verseReference': verseReference,
      'options': options,
      'correctAnswer': correctAnswer,
      'points': points,
    };
  }
}

/// 일일 퀴즈
class DailyQuiz {
  final String id;
  final DateTime date;
  final String title;
  final List<DailyQuizQuestion> questions;
  final int totalPoints;
  final int bonusPoints; // 만점 보너스
  final DateTime expiresAt;

  const DailyQuiz({
    required this.id,
    required this.date,
    required this.title,
    required this.questions,
    required this.totalPoints,
    this.bonusPoints = 20,
    required this.expiresAt,
  });

  factory DailyQuiz.fromFirestore(String id, Map<String, dynamic> data) {
    final questions = (data['questions'] as List<dynamic>?)
            ?.map((q) => DailyQuizQuestion.fromFirestore(q as Map<String, dynamic>))
            .toList() ??
        [];

    return DailyQuiz(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title'] ?? '오늘의 퀴즈',
      questions: questions,
      totalPoints: data['totalPoints'] ?? questions.fold(0, (sum, q) => sum + q.points),
      bonusPoints: data['bonusPoints'] ?? 20,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 1)),
    );
  }

  /// 퀴즈가 만료되었는지 확인
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 문제 수
  int get questionCount => questions.length;
}

/// 사용자의 일일 퀴즈 결과
class DailyQuizResult {
  final String odId;
  final String odQuizId;
  final DateTime date;
  final int score;
  final int totalPoints;
  final int correctCount;
  final int totalQuestions;
  final bool isPerfect;
  final int bonusEarned;
  final int totalEarned;
  final Duration timeTaken;
  final DateTime completedAt;
  final List<QuizAnswer> answers;

  const DailyQuizResult({
    required this.odId,
    required this.odQuizId,
    required this.date,
    required this.score,
    required this.totalPoints,
    required this.correctCount,
    required this.totalQuestions,
    required this.isPerfect,
    required this.bonusEarned,
    required this.totalEarned,
    required this.timeTaken,
    required this.completedAt,
    this.answers = const [],
  });

  factory DailyQuizResult.fromFirestore(Map<String, dynamic> data) {
    return DailyQuizResult(
      odId: data['odId'] ?? '',
      odQuizId: data['quizId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      score: data['score'] ?? 0,
      totalPoints: data['totalPoints'] ?? 0,
      correctCount: data['correctCount'] ?? 0,
      totalQuestions: data['totalQuestions'] ?? 0,
      isPerfect: data['isPerfect'] ?? false,
      bonusEarned: data['bonusEarned'] ?? 0,
      totalEarned: data['totalEarned'] ?? 0,
      timeTaken: Duration(seconds: data['timeTakenSeconds'] ?? 0),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      answers: (data['answers'] as List<dynamic>?)
              ?.map((a) => QuizAnswer.fromFirestore(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'odId': odId,
      'quizId': odQuizId,
      'date': Timestamp.fromDate(date),
      'score': score,
      'totalPoints': totalPoints,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'isPerfect': isPerfect,
      'bonusEarned': bonusEarned,
      'totalEarned': totalEarned,
      'timeTakenSeconds': timeTaken.inSeconds,
      'completedAt': Timestamp.fromDate(completedAt),
      'answers': answers.map((a) => a.toFirestore()).toList(),
    };
  }

  /// 정답률
  double get accuracy => totalQuestions > 0 ? correctCount / totalQuestions : 0;

  /// 정답률 퍼센트
  int get accuracyPercent => (accuracy * 100).round();
}

/// 퀴즈 답변
class QuizAnswer {
  final String questionId;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;

  const QuizAnswer({
    required this.questionId,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
  });

  factory QuizAnswer.fromFirestore(Map<String, dynamic> data) {
    return QuizAnswer(
      questionId: data['questionId'] ?? '',
      userAnswer: data['userAnswer'] ?? '',
      correctAnswer: data['correctAnswer'] ?? '',
      isCorrect: data['isCorrect'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'questionId': questionId,
      'userAnswer': userAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
    };
  }
}

/// 일일 퀴즈 스트릭
class QuizStreak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastQuizDate;
  final int totalQuizzesTaken;
  final int perfectScores;

  const QuizStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastQuizDate,
    this.totalQuizzesTaken = 0,
    this.perfectScores = 0,
  });

  factory QuizStreak.fromFirestore(Map<String, dynamic> data) {
    return QuizStreak(
      currentStreak: data['currentStreak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      lastQuizDate: (data['lastQuizDate'] as Timestamp?)?.toDate(),
      totalQuizzesTaken: data['totalQuizzesTaken'] ?? 0,
      perfectScores: data['perfectScores'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastQuizDate': lastQuizDate != null ? Timestamp.fromDate(lastQuizDate!) : null,
      'totalQuizzesTaken': totalQuizzesTaken,
      'perfectScores': perfectScores,
    };
  }
}
