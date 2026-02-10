# Claude Code 개발 규칙

## 시니어 개발자 원칙 (최우선)

이 프로젝트의 사용자는 비전공자이다. 모든 기능 요청 뒤에는 "사용자 경험 향상"이라는
목적이 있다. 기능을 글자 그대로만 구현하지 말고, 다음을 항상 수행한다:

### 구현 전 — 영향 분석 (필수)
1. 이 변경이 영향을 미치는 모든 화면/위젯 목록을 먼저 파악
2. 공유 리소스(테마, 폰트, 서비스, 모델) 변경 시 → 사용처 전수 검색 필수
3. 영향 범위를 사용자에게 보고한 후 진행

### 구현 중 — 사용자 관점 사고 (필수)
- "이 화면을 처음 보는 사용자가 글씨를 읽을 수 있는가?"
- "로딩이 3초 이상 걸리면 사용자가 어떻게 느끼는가?"
- "에러가 나면 사용자가 무엇을 해야 하는지 알 수 있는가?"
- 기능 동작 여부가 아니라 사용자 체감 품질 기준으로 판단

### 구현 후 — 회귀 점검 (필수)
1. 변경한 파일이 import/사용하는 공유 컴포넌트 → 해당 컴포넌트를 쓰는 다른 화면 점검
2. 스타일/테마 변경 → 모든 화면에서 색상 대비, 폰트 렌더링 확인
3. "내가 건드리지 않은 화면이 깨지지 않았는가?" 반드시 확인

## 변경 유형별 필수 점검표

### 색상/테마 변경 시
- [ ] 변경한 색상을 사용하는 모든 파일 grep으로 전수 확인
- [ ] 각 화면에서 배경색 대비 텍스트 색상 가독성 확인 (밝은 배경+어두운 텍스트 / 어두운 배경+밝은 텍스트)
- [ ] `scripts/ui_check.dart` 실행하여 색상 대비 자동 검사

### 폰트 변경 시
- [ ] pubspec.yaml 폰트 에셋 경로 확인
- [ ] web/index.html 웹폰트 로딩 확인
- [ ] fontFamily가 실제 적용되는 위젯 범위 확인 (MaterialApp.theme vs 개별 TextStyle)
- [ ] 한글, 영문, 숫자, 특수문자 모두 렌더링 확인

### 서비스/로직 변경 시
- [ ] 해당 서비스를 호출하는 모든 화면 목록 확인
- [ ] 에러 케이스에서 사용자에게 보이는 메시지 확인
- [ ] 로딩 상태 UX 확인 (스피너, 스켈레톤 등)

### UI 위젯 변경 시
- [ ] 해당 위젯을 사용하는 모든 화면에서 렌더링 확인
- [ ] 다양한 데이터 상태(빈 값, 긴 텍스트, 큰 숫자) 대응 확인

## 환경
이 프로젝트는 Windows에서 개발한다. PowerShell 호환 명령어를 사용하고, Unix 전용 문법/심링크/인터랙티브 CLI를 사용하지 않는다. 쉘 명령에서 괄호, 한국어 등 특수문자는 적절히 이스케이프한다.

## 기술 스택
- 모바일/웹: Dart/Flutter
- 상태 관리: Riverpod
- 백엔드: Firebase (Firestore, Hosting, Functions)
- Flutter/Dart 파일명은 항상 snake_case 사용 (하이픈 금지)

## 디버깅 & 성능
성능 문제 진단 시, 실제 병목(네트워크 호출, DB 쿼리, API 지연)을 먼저 조사한 후 코드를 수정한다. 타임아웃 축소, 병렬화 등 표면적 최적화를 먼저 적용하지 않는다.

## 세션 시작 시 필수 읽기
새 세션을 시작할 때 다음 파일들을 먼저 읽어주세요:
1. `docs/dev/ARCHITECTURE.md` (아키텍처 규칙 - 가장 중요!)
2. `docs/dev/DEVELOPMENT_RULES.md` (통합 개발 규칙 - 필수!)
3. `docs/status/sessions/` (가장 최신 파일)
4. `docs/dev/BUG_FIXES.md` (버그 이력)
5. `docs/status/PROJECT_STATUS.md` (현재 상태)
6. `docs/status/PROGRESS.md` (개발 로드맵)

문서 전체 구조는 `docs/INDEX.md` 참조

## 컨텍스트 관리 규칙

### 80% 이하 컨텍스트 시 (우선)
컨텍스트가 80% 이하로 떨어지면 **즉시**:
1. 현재 진행 중인 작업 상태 요약
2. 다음 작업 목표 명확히 작성
3. `docs/status/sessions/YYYYMMDD.md` 파일 업데이트
4. 사용자에게 "컨텍스트 80% 도달, 새 세션 시작 권장" 알림

### 90% 이하 컨텍스트 시
컨텍스트가 90% 이하로 떨어지면:
1. 현재 작업 상태 요약
2. `docs/status/sessions/YYYYMMDD.md` 파일 생성/업데이트
3. 다음 세션에서 이어갈 수 있도록 상세 기록

### 세션 요약 파일 형식
```markdown
# 세션 요약 - YYYY년 MM월 DD일

## 완료된 작업
- 작업 내용

## 수정된 파일
- 파일 경로 및 변경 내용

## 발견된 버그 및 수정
- 버그 설명 및 해결 방법

## 다음 작업 (TODO)
- 남은 작업

## 다음 세션 시작 시 (80% 컨텍스트 도달 시 필수)
- 이어서 할 구체적인 작업
- 필요한 명령어/파일 경로
- 주의사항

## 중요 참고사항
- 주의할 점
```

## 빌드 및 배포 규칙
- 커밋이나 푸시 전에 반드시 빌드가 통과하는지 확인한다.
- 배포(Firebase, Vercel, Netlify) 후 라이브 사이트가 정상 로드되는지 확인한 후 작업을 완료한다.

### 웹 빌드 (필수!)
**항상 `build_web.ps1` 스크립트 사용** - API 키 주입 필수
```powershell
powershell -ExecutionPolicy Bypass -File build_web.ps1
```

절대로 `flutter build web --release --no-pub` 직접 사용 금지!
(ESV API 키 등이 누락됨)

### 배포 전 체크리스트
1. [ ] `flutter analyze` 에러 없음 확인
2. [ ] `build_web.ps1`로 빌드 (API 키 주입)
3. [ ] `firebase deploy --only hosting`
4. [ ] 배포 후 ESV API 동작 확인

## Firestore 업데이트 패턴

### 안전한 패턴 (권장)
```dart
await docRef.set({
  'field': FieldValue.increment(1),
}, SetOptions(merge: true));
```

### 위험한 패턴 (피하기)
```dart
// 문서/필드가 없으면 실패할 수 있음
transaction.update(docRef, {...});
await docRef.update({...});
```

## 버그 기록
모든 버그 수정은 `docs/dev/BUG_FIXES.md`에 기록

## Supabase (교회 관리 앱)
Supabase RLS 정책이 anon key 작업을 차단하면, 재시도하지 않는다. 대신 사용자가 Supabase 대시보드에서 직접 실행할 수 있는 정확한 SQL을 제공한다.

## 프로젝트 URL
- 웹앱: https://bible-speak.web.app
- Firebase: https://console.firebase.google.com/project/bible-speak
- GitHub: https://github.com/onapond/bible_speak
