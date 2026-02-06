# Claude Code 개발 규칙

## 세션 시작 시 필수 읽기
새 세션을 시작할 때 다음 파일들을 먼저 읽어주세요:
1. `docs/dev/ARCHITECTURE.md` (아키텍처 규칙 - 가장 중요!)
2. `docs/status/sessions/` (가장 최신 파일)
3. `docs/dev/BUG_FIXES.md` (버그 이력)
4. `docs/status/PROJECT_STATUS.md` (현재 상태)

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

## 프로젝트 URL
- 웹앱: https://bible-speak.web.app
- Firebase: https://console.firebase.google.com/project/bible-speak
- GitHub: https://github.com/onapond/bible_speak
