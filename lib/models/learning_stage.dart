/// 3단계 학습 스테이지
enum LearningStage {
  /// Stage 1: 듣고 따라하기 (전체 자막 표시)
  listenRepeat(1, '듣고 따라하기', 'Listen & Repeat', 70.0),

  /// Stage 2: 핵심 표현 (빈칸 채우기)
  keyExpressions(2, '핵심 표현', 'Key Expressions', 80.0),

  /// Stage 3: 실전 암송 (자막 없음)
  realSpeak(3, '실전 암송', 'Real Speak', 85.0);

  const LearningStage(
    this.stageNumber,
    this.koreanName,
    this.englishName,
    this.passThreshold,
  );

  /// 스테이지 번호 (1, 2, 3)
  final int stageNumber;

  /// 한글 이름
  final String koreanName;

  /// 영문 이름
  final String englishName;

  /// 통과 기준 점수
  final double passThreshold;

  /// 스테이지 번호로 enum 찾기
  static LearningStage fromNumber(int number) {
    return LearningStage.values.firstWhere(
      (stage) => stage.stageNumber == number,
      orElse: () => LearningStage.listenRepeat,
    );
  }

  /// 다음 스테이지 반환 (마지막이면 null)
  LearningStage? get nextStage {
    if (this == LearningStage.realSpeak) return null;
    return LearningStage.fromNumber(stageNumber + 1);
  }

  /// 이전 스테이지 반환 (첫번째면 null)
  LearningStage? get previousStage {
    if (this == LearningStage.listenRepeat) return null;
    return LearningStage.fromNumber(stageNumber - 1);
  }

  /// 마지막 스테이지인지 확인
  bool get isFinalStage => this == LearningStage.realSpeak;

  /// 첫번째 스테이지인지 확인
  bool get isFirstStage => this == LearningStage.listenRepeat;

  /// 점수가 통과 기준을 넘었는지 확인
  bool isPassed(double score) => score >= passThreshold;
}
