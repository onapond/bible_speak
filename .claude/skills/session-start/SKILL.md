# Session Start Skill

새 세션을 시작할 때 프로젝트 상태를 파악하고 이전 작업을 이어간다.

## 단계

### 1. 프로젝트 문서 읽기
다음 파일을 순서대로 찾아서 읽는다 (존재하는 것만):
- `CLAUDE.md` — 프로젝트 규칙
- `docs/dev/ARCHITECTURE.md` 또는 `ARCHITECTURE.md` — 아키텍처
- `docs/status/PROJECT_STATUS.md` 또는 `PROJECT_STATUS.md` — 현재 상태
- `docs/status/PROGRESS.md` 또는 `PROGRESS.md` — 로드맵
- `CHANGELOG.md` — 최근 변경 이력

### 2. 최근 세션 노트 확인
- `docs/status/sessions/` 또는 `docs/sessions/` 디렉토리에서 가장 최신 파일을 읽는다
- 세션 노트가 없으면 `git log --oneline -10`으로 최근 커밋 확인

### 3. 현재 상태 점검
- `git status`로 미커밋 변경사항 확인
- `git log --oneline -5`로 최근 커밋 확인
- 진행 중이던 브랜치가 있는지 확인

### 4. 브리핑 보고
사용자에게 다음을 보고한다:
- **현재 페이즈**: 프로젝트가 어떤 단계에 있는지
- **지난 세션 요약**: 마지막으로 완료한 작업
- **남은 작업**: TODO 또는 다음 할 일
- **미커밋 변경**: 있으면 알림
- **이번 세션 제안**: 이어서 할 작업 제안

### 5. 사용자 확인
- 제안한 작업을 진행할지 사용자 확인을 기다린다
- 확인 전에 코드 수정을 시작하지 않는다
