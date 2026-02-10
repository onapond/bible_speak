// ignore_for_file: avoid_print
/// UI 품질 자동 검사 스크립트
///
/// 실행: dart run scripts/ui_check.dart
/// 옵션: dart run scripts/ui_check.dart --summary  (요약만 출력)
///
/// 검사 항목:
/// 1. Colors.white 텍스트 색상으로 사용 (밝은 배경 파일에서 → error)
/// 2. Colors.white 기타 직접 사용 (→ warning)
/// 3. Colors.black 직접 사용 (→ warning)
/// 4. Color(0xFFFFFFFF) / Color(0xFF000000) 하드코딩 (→ warning)
///
/// 인라인 무시: 줄 끝에 // ui-check-ignore 추가
import 'dart:io';

// ============================================================
// 설정
// ============================================================

/// 투명도 허용 패턴 (오버레이, 글로우, 그림자 등)
final _opacityPatterns = [
  RegExp(r'Colors\.white\.withOpacity'),
  RegExp(r'Colors\.white\.withValues'),
  RegExp(r'Colors\.black\.withOpacity'),
  RegExp(r'Colors\.black\.withValues'),
];

/// 인라인 무시 패턴
final _ignorePattern = RegExp(r'//\s*ui-check-ignore');

/// 검사 제외 파일 패턴
const _excludedFiles = [
  'parchment_theme.dart',
  'ui_check.dart',
  'generated_plugin_registrant.dart',
  '.g.dart',
  '.freezed.dart',
];

/// 밝은 배경 색상 키워드 (이 배경을 쓰는 파일에서 Colors.white 텍스트는 위험)
const _lightBackgroundKeywords = [
  'softPapyrus',
  'agedParchment',
  'warmVellum',
  'Color(0xFFF0E4CE)',
  'Color(0xFFE3D4B8)',
  'Color(0xFFD4C4A0)',
];

/// 텍스트 색상 컨텍스트 패턴 (Colors.white가 텍스트 색상으로 쓰이는 경우)
final _textColorPatterns = [
  RegExp(r'TextStyle\([^)]*color:\s*Colors\.white'),
  RegExp(r'color:\s*Colors\.white'),          // 일반 color: 속성
  RegExp(r'foregroundColor:\s*Colors\.white'),
  RegExp(r'style:.*Colors\.white'),
];

/// 배경/장식 컨텍스트 패턴 (Colors.white가 배경으로 쓰이는 경우 → 덜 위험)
final _backgroundContextPatterns = [
  RegExp(r'backgroundColor:\s*Colors\.white'),
  RegExp(r'Container\(\s*color:\s*Colors\.white'),
  RegExp(r'ColoredBox\(\s*color:\s*Colors\.white'),
  RegExp(r'scaffoldBackgroundColor'),
  RegExp(r'fillColor.*Colors\.white'),
  RegExp(r'surfaceTintColor'),
];

// ============================================================
// 모델
// ============================================================

enum Severity { warning, error }

class Issue {
  final String file;
  final int line;
  final Severity severity;
  final String rule;
  final String message;
  final String suggestion;

  Issue({
    required this.file,
    required this.line,
    required this.severity,
    required this.rule,
    required this.message,
    required this.suggestion,
  });

  @override
  String toString() {
    final icon = severity == Severity.error ? '❌ ERROR' : '⚠ WARNING';
    return '$icon: $file:$line\n'
        '  $message\n'
        '  → $suggestion';
  }
}

// ============================================================
// 검사 로직
// ============================================================

class UiChecker {
  final List<Issue> issues = [];
  int filesScanned = 0;

  void run(String libPath) {
    final dir = Directory(libPath);
    if (!dir.existsSync()) {
      print('Error: $libPath 디렉토리가 존재하지 않습니다.');
      exit(1);
    }

    final dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_isExcluded(f.path))
        .toList();

    for (final file in dartFiles) {
      _checkFile(file);
    }

    filesScanned = dartFiles.length;
  }

  bool _isExcluded(String path) {
    final normalized = path.replaceAll('\\', '/');
    return _excludedFiles.any((pattern) => normalized.contains(pattern));
  }

  void _checkFile(File file) {
    final lines = file.readAsLinesSync();
    final relativePath = file.path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'.*/lib/'), 'lib/');

    // 파일 전체에서 밝은 배경 사용 여부 파악 (Colors.white 제외)
    final hasLightBackground = lines.any((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) return false;
      return _lightBackgroundKeywords.any((kw) => line.contains(kw));
    });

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      // 주석 라인 건너뛰기
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

      // 인라인 무시 체크
      if (_ignorePattern.hasMatch(line)) continue;

      // 규칙 1+2: Colors.white 사용
      _checkColorsWhite(relativePath, lineNum, line, hasLightBackground);

      // 규칙 3: Colors.black 직접 사용
      _checkColorsBlack(relativePath, lineNum, line);

      // 규칙 4: Color(0xFFFFFFFF) 또는 Color(0xFF000000) 하드코딩
      _checkHardcodedWhiteBlack(relativePath, lineNum, line);
    }
  }

  void _checkColorsWhite(
    String file,
    int line,
    String content,
    bool hasLightBackground,
  ) {
    if (!content.contains('Colors.white')) return;

    // 투명도 사용은 허용 (오버레이, 글로우 등)
    if (_opacityPatterns.any((p) => p.hasMatch(content))) return;

    // 배경/장식 컨텍스트는 warning만 (가독성 문제 아닌 경우가 많음)
    final isBackgroundUse =
        _backgroundContextPatterns.any((p) => p.hasMatch(content));

    if (isBackgroundUse) {
      issues.add(Issue(
        file: file,
        line: line,
        severity: Severity.warning,
        rule: 'hardcoded-white-bg',
        message: 'Colors.white 배경색 직접 사용 — 테마 상수 권장',
        suggestion: 'ParchmentTheme.softPapyrus 사용 권장',
      ));
      return;
    }

    // 텍스트 색상 컨텍스트인지 판별
    final isTextColorUse =
        _textColorPatterns.any((p) => p.hasMatch(content));

    if (hasLightBackground && isTextColorUse) {
      // 밝은 배경 파일 + 텍스트 색상으로 흰색 사용 → error (가독성 문제 확실)
      issues.add(Issue(
        file: file,
        line: line,
        severity: Severity.error,
        rule: 'bright-bg-white-text',
        message:
            '밝은 배경 파일에서 Colors.white를 텍스트 색상으로 사용 — 가독성 문제',
        suggestion:
            'ParchmentTheme.ancientInk, fadedScript, 또는 weatheredGray 사용',
      ));
    } else {
      // 기타 Colors.white 사용 → warning
      issues.add(Issue(
        file: file,
        line: line,
        severity: Severity.warning,
        rule: 'hardcoded-white',
        message: 'Colors.white 직접 사용 — 테마 상수 사용 권장',
        suggestion:
            'ParchmentTheme.softPapyrus (밝은 색) 또는 테마 색상 사용',
      ));
    }
  }

  void _checkColorsBlack(String file, int line, String content) {
    if (!content.contains('Colors.black')) return;

    // 투명도 사용은 허용
    if (_opacityPatterns.any((p) => p.hasMatch(content))) return;

    // 인라인 무시 체크
    if (_ignorePattern.hasMatch(content)) return;

    issues.add(Issue(
      file: file,
      line: line,
      severity: Severity.warning,
      rule: 'hardcoded-black',
      message: 'Colors.black 직접 사용 — 테마 상수 사용 권장',
      suggestion:
          'ParchmentTheme.ancientInk (진한 텍스트) 또는 fadedScript 사용',
    ));
  }

  void _checkHardcodedWhiteBlack(String file, int line, String content) {
    if (content.contains('Color(0xFFFFFFFF)')) {
      issues.add(Issue(
        file: file,
        line: line,
        severity: Severity.warning,
        rule: 'hardcoded-hex-white',
        message: 'Color(0xFFFFFFFF) 하드코딩 — Colors.white와 동일한 문제',
        suggestion: 'ParchmentTheme 색상 상수 사용',
      ));
    }

    if (content.contains('Color(0xFF000000)')) {
      issues.add(Issue(
        file: file,
        line: line,
        severity: Severity.warning,
        rule: 'hardcoded-hex-black',
        message: 'Color(0xFF000000) 하드코딩 — Colors.black과 동일한 문제',
        suggestion: 'ParchmentTheme.ancientInk 사용',
      ));
    }
  }
}

// ============================================================
// 리포트 출력
// ============================================================

void printReport(UiChecker checker, {bool summaryOnly = false}) {
  final errors = checker.issues.where((i) => i.severity == Severity.error).toList();
  final warnings = checker.issues.where((i) => i.severity == Severity.warning).toList();

  print('');
  print('=' * 60);
  print('  UI 품질 검사 결과');
  print('=' * 60);
  print('');

  if (checker.issues.isEmpty) {
    print('✅ 문제 없음! 모든 파일이 UI 품질 기준을 충족합니다.');
  } else if (!summaryOnly) {
    // 에러 먼저 출력
    if (errors.isNotEmpty) {
      print('--- ERRORS (커밋 차단) ---');
      print('');
      for (final issue in errors) {
        print(issue);
        print('');
      }
    }

    // 경고 출력
    if (warnings.isNotEmpty) {
      print('--- WARNINGS (권장 수정) ---');
      print('');
      for (final issue in warnings) {
        print(issue);
        print('');
      }
    }
  }

  print('=' * 60);
  print(
    '  스캔: ${checker.filesScanned} files | '
    '${errors.length} errors | ${warnings.length} warnings',
  );
  print('=' * 60);
  print('');

  // 규칙별 요약
  if (checker.issues.isNotEmpty) {
    final ruleCount = <String, int>{};
    for (final issue in checker.issues) {
      ruleCount[issue.rule] = (ruleCount[issue.rule] ?? 0) + 1;
    }

    print('규칙별 요약:');
    for (final entry in ruleCount.entries) {
      print('  ${'${entry.key}:'.padRight(25)} ${entry.value}건');
    }
    print('');

    // 파일별 에러 요약 (에러가 있을 때만)
    if (errors.isNotEmpty) {
      final fileErrors = <String, int>{};
      for (final issue in errors) {
        fileErrors[issue.file] = (fileErrors[issue.file] ?? 0) + 1;
      }

      print('에러 파일별 요약:');
      final sorted = fileErrors.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        print('  ${entry.value}건  ${entry.key}');
      }
      print('');
    }
  }
}

// ============================================================
// main
// ============================================================

void main(List<String> args) {
  final summaryOnly = args.contains('--summary');
  final positionalArgs = args.where((a) => !a.startsWith('--')).toList();

  // 프로젝트 루트의 lib/ 디렉토리 경로 결정
  String libPath;

  if (positionalArgs.isNotEmpty) {
    libPath = positionalArgs[0];
  } else {
    final cwd = Directory.current.path;
    libPath = '$cwd/lib';
    if (!Directory(libPath).existsSync()) {
      libPath = '$cwd/../lib';
    }
  }

  print('UI 품질 검사 시작...');
  print('검사 경로: $libPath');

  final checker = UiChecker();
  checker.run(libPath);

  printReport(checker, summaryOnly: summaryOnly);

  // 에러가 있으면 exit 1 (커밋 차단용)
  final hasErrors = checker.issues.any((i) => i.severity == Severity.error);
  if (hasErrors) {
    exit(1);
  }
}
