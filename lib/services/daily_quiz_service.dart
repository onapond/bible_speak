import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/daily_quiz.dart';

/// 일일 퀴즈 서비스
class DailyQuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 오늘 날짜 키 (YYYY-MM-DD)
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // 퀴즈 조회
  // ============================================================

  /// 오늘의 퀴즈 가져오기
  Future<DailyQuiz?> getTodayQuiz() async {
    try {
      final doc = await _firestore.collection('dailyQuizzes').doc(_todayKey).get();

      if (doc.exists) {
        return DailyQuiz.fromFirestore(doc.id, doc.data()!);
      }

      // 퀴즈가 없으면 자동 생성
      return await _generateTodayQuiz();
    } catch (e) {
      print('Get today quiz error: $e');
      return null;
    }
  }

  /// 오늘의 퀴즈 자동 생성
  Future<DailyQuiz?> _generateTodayQuiz() async {
    try {
      final questions = _generateQuestions();
      final now = DateTime.now();
      final expiresAt = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final quizData = {
        'date': Timestamp.fromDate(now),
        'title': '오늘의 퀴즈 - ${now.month}월 ${now.day}일',
        'questions': questions.map((q) => q.toFirestore()).toList(),
        'totalPoints': questions.fold(0, (sum, q) => sum + q.points),
        'bonusPoints': 20,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('dailyQuizzes').doc(_todayKey).set(quizData);

      return DailyQuiz(
        id: _todayKey,
        date: now,
        title: quizData['title'] as String,
        questions: questions,
        totalPoints: quizData['totalPoints'] as int,
        bonusPoints: 20,
        expiresAt: expiresAt,
      );
    } catch (e) {
      print('Generate quiz error: $e');
      return null;
    }
  }

  /// 퀴즈 문제 생성
  List<DailyQuizQuestion> _generateQuestions() {
    final random = Random();
    final questions = <DailyQuizQuestion>[];

    // 샘플 구절 데이터 (실제로는 Firestore에서 가져와야 함)
    final sampleVerses = [
      {
        'ref': 'John 3:16',
        'text': 'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
        'words': ['For', 'God', 'so', 'loved', 'the', 'world'],
      },
      {
        'ref': 'Philippians 4:13',
        'text': 'I can do all things through Christ who strengthens me.',
        'words': ['I', 'can', 'do', 'all', 'things', 'through', 'Christ'],
      },
      {
        'ref': 'Proverbs 3:5',
        'text': 'Trust in the LORD with all your heart and lean not on your own understanding.',
        'words': ['Trust', 'in', 'the', 'LORD', 'with', 'all', 'your', 'heart'],
      },
      {
        'ref': 'Romans 8:28',
        'text': 'And we know that in all things God works for the good of those who love him.',
        'words': ['And', 'we', 'know', 'that', 'in', 'all', 'things'],
      },
      {
        'ref': 'Jeremiah 29:11',
        'text': 'For I know the plans I have for you, declares the LORD, plans to prosper you.',
        'words': ['For', 'I', 'know', 'the', 'plans', 'I', 'have'],
      },
    ];

    // 문제 1: 빈칸 채우기
    final verse1 = sampleVerses[random.nextInt(sampleVerses.length)];
    final words1 = (verse1['words'] as List<String>);
    final blankIndex = random.nextInt(words1.length);
    final correctWord = words1[blankIndex];
    final text1 = (verse1['text'] as String).replaceFirst(correctWord, '_____');

    questions.add(DailyQuizQuestion(
      id: 'q1',
      type: DailyQuizType.fillBlank,
      question: '빈칸에 들어갈 단어는?',
      verseText: text1,
      verseReference: verse1['ref'] as String,
      options: _generateOptions(correctWord, ['God', 'Lord', 'Christ', 'love', 'faith', 'hope', 'all', 'the']),
      correctAnswer: correctWord,
      points: 10,
    ));

    // 문제 2: 구절 찾기
    final verse2 = sampleVerses[random.nextInt(sampleVerses.length)];
    final refs = sampleVerses.map((v) => v['ref'] as String).toList();

    questions.add(DailyQuizQuestion(
      id: 'q2',
      type: DailyQuizType.reference,
      question: '이 구절의 장절은?',
      verseText: verse2['text'] as String,
      options: _generateOptions(verse2['ref'] as String, refs),
      correctAnswer: verse2['ref'] as String,
      points: 10,
    ));

    // 문제 3: 의미 맞추기
    final wordMeanings = [
      {'word': 'perish', 'meaning': '멸망하다', 'wrongs': ['번영하다', '사랑하다', '믿다']},
      {'word': 'eternal', 'meaning': '영원한', 'wrongs': ['일시적인', '강한', '작은']},
      {'word': 'strengthens', 'meaning': '강하게 하다', 'wrongs': ['약하게 하다', '사랑하다', '믿다']},
      {'word': 'trust', 'meaning': '신뢰하다', 'wrongs': ['의심하다', '떠나다', '잊다']},
      {'word': 'prosper', 'meaning': '번영하다', 'wrongs': ['실패하다', '떠나다', '잊다']},
    ];
    final wordQ = wordMeanings[random.nextInt(wordMeanings.length)];

    questions.add(DailyQuizQuestion(
      id: 'q3',
      type: DailyQuizType.meaning,
      question: '"${wordQ['word']}"의 의미는?',
      options: _generateOptions(
        wordQ['meaning'] as String,
        wordQ['wrongs'] as List<String>,
      ),
      correctAnswer: wordQ['meaning'] as String,
      points: 10,
    ));

    // 문제 4: 빈칸 채우기 2
    final verse4 = sampleVerses[random.nextInt(sampleVerses.length)];
    final words4 = (verse4['words'] as List<String>);
    final blankIndex4 = random.nextInt(words4.length);
    final correctWord4 = words4[blankIndex4];
    final text4 = (verse4['text'] as String).replaceFirst(correctWord4, '_____');

    questions.add(DailyQuizQuestion(
      id: 'q4',
      type: DailyQuizType.fillBlank,
      question: '빈칸에 들어갈 단어는?',
      verseText: text4,
      verseReference: verse4['ref'] as String,
      options: _generateOptions(correctWord4, ['God', 'Lord', 'Christ', 'love', 'faith', 'hope', 'all', 'the', 'I', 'we']),
      correctAnswer: correctWord4,
      points: 10,
    ));

    // 문제 5: 구절 찾기 2
    final verse5 = sampleVerses[random.nextInt(sampleVerses.length)];

    questions.add(DailyQuizQuestion(
      id: 'q5',
      type: DailyQuizType.reference,
      question: '이 구절의 장절은?',
      verseText: verse5['text'] as String,
      options: _generateOptions(verse5['ref'] as String, refs),
      correctAnswer: verse5['ref'] as String,
      points: 10,
    ));

    return questions;
  }

  /// 옵션 생성 (정답 + 오답 3개)
  List<String> _generateOptions(String correct, List<String> pool) {
    final random = Random();
    final options = <String>{correct};

    final filteredPool = pool.where((p) => p != correct).toList();
    filteredPool.shuffle(random);

    for (final option in filteredPool) {
      if (options.length >= 4) break;
      options.add(option);
    }

    final list = options.toList();
    list.shuffle(random);
    return list;
  }

  // ============================================================
  // 퀴즈 제출
  // ============================================================

  /// 오늘 퀴즈를 이미 완료했는지 확인
  Future<bool> hasCompletedToday() async {
    final odId = currentUserId;
    if (odId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(odId)
          .collection('quizResults')
          .doc(_todayKey)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// 오늘의 결과 가져오기
  Future<DailyQuizResult?> getTodayResult() async {
    final odId = currentUserId;
    if (odId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(odId)
          .collection('quizResults')
          .doc(_todayKey)
          .get();

      if (doc.exists) {
        return DailyQuizResult.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Get today result error: $e');
      return null;
    }
  }

  /// 퀴즈 결과 제출
  Future<DailyQuizResult?> submitQuiz({
    required DailyQuiz quiz,
    required List<QuizAnswer> answers,
    required Duration timeTaken,
  }) async {
    final odId = currentUserId;
    if (odId == null) return null;

    try {
      // 이미 완료했는지 확인
      if (await hasCompletedToday()) {
        return await getTodayResult();
      }

      // 점수 계산
      int correctCount = 0;
      int score = 0;

      for (final answer in answers) {
        if (answer.isCorrect) {
          correctCount++;
          final question = quiz.questions.firstWhere(
            (q) => q.id == answer.questionId,
            orElse: () => quiz.questions.first,
          );
          score += question.points;
        }
      }

      final isPerfect = correctCount == quiz.questionCount;
      final bonusEarned = isPerfect ? quiz.bonusPoints : 0;
      final totalEarned = score + bonusEarned;

      final result = DailyQuizResult(
        odId: odId,
        odQuizId: quiz.id,
        date: quiz.date,
        score: score,
        totalPoints: quiz.totalPoints,
        correctCount: correctCount,
        totalQuestions: quiz.questionCount,
        isPerfect: isPerfect,
        bonusEarned: bonusEarned,
        totalEarned: totalEarned,
        timeTaken: timeTaken,
        completedAt: DateTime.now(),
        answers: answers,
      );

      // 결과 저장 (transaction 없이 개별 처리)
      final resultRef = _firestore
          .collection('users')
          .doc(odId)
          .collection('quizResults')
          .doc(_todayKey);
      await resultRef.set(result.toFirestore());

      // 탈란트 지급 (set + merge로 필드 없어도 안전)
      final userRef = _firestore.collection('users').doc(odId);
      await userRef.set({
        'talants': FieldValue.increment(totalEarned),
        'totalTalants': FieldValue.increment(totalEarned),
      }, SetOptions(merge: true));

      // 스트릭 업데이트
      await _updateStreakSimple(odId, isPerfect);

      return result;
    } catch (e) {
      print('Submit quiz error: $e');
      return null;
    }
  }

  /// 스트릭 업데이트 (transaction 없이)
  Future<void> _updateStreakSimple(String odId, bool isPerfect) async {
    final streakRef = _firestore.collection('users').doc(odId).collection('stats').doc('quizStreak');
    final streakDoc = await streakRef.get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (streakDoc.exists) {
      final streak = QuizStreak.fromFirestore(streakDoc.data()!);
      final lastDate = streak.lastQuizDate;

      int newStreak = streak.currentStreak;

      if (lastDate != null) {
        final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final diff = today.difference(lastDay).inDays;

        if (diff == 1) {
          // 연속
          newStreak = streak.currentStreak + 1;
        } else if (diff > 1) {
          // 연속 끊김
          newStreak = 1;
        }
        // diff == 0 이면 오늘 이미 했으므로 변경 없음
      } else {
        newStreak = 1;
      }

      await streakRef.set({
        'currentStreak': newStreak,
        'longestStreak': newStreak > streak.longestStreak ? newStreak : streak.longestStreak,
        'lastQuizDate': Timestamp.fromDate(today),
        'totalQuizzesTaken': FieldValue.increment(1),
        'perfectScores': isPerfect ? FieldValue.increment(1) : FieldValue.increment(0),
      }, SetOptions(merge: true));
    } else {
      await streakRef.set({
        'currentStreak': 1,
        'longestStreak': 1,
        'lastQuizDate': Timestamp.fromDate(today),
        'totalQuizzesTaken': 1,
        'perfectScores': isPerfect ? 1 : 0,
      });
    }
  }

  // ============================================================
  // 통계
  // ============================================================

  /// 퀴즈 스트릭 가져오기
  Future<QuizStreak> getQuizStreak() async {
    final odId = currentUserId;
    if (odId == null) return const QuizStreak();

    try {
      final doc = await _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('quizStreak')
          .get();

      if (doc.exists) {
        return QuizStreak.fromFirestore(doc.data()!);
      }
      return const QuizStreak();
    } catch (e) {
      print('Get quiz streak error: $e');
      return const QuizStreak();
    }
  }

  /// 최근 퀴즈 결과 가져오기
  Future<List<DailyQuizResult>> getRecentResults({int limit = 7}) async {
    final odId = currentUserId;
    if (odId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(odId)
          .collection('quizResults')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => DailyQuizResult.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Get recent results error: $e');
      return [];
    }
  }
}
