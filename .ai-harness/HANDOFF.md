# AI handoff

현재 작성자 lease는 없습니다. 다음 권장 작업은 `TOOLCHAIN-001`입니다.

- 기준 브랜치: `codex/stabilize-core`
- 공통 진입점: `./bin/harness`
- 계획: `.ai-harness/plan.json`
- 검증 원장과 상세 로그: `.ai-harness/runtime/` (Git 제외)
- 알려진 blocker: Flutter SDK가 `/private/tmp`에 있어 비영구적이며, Node 24와 Functions Node 20이 불일치합니다.
- 다음 명령: `./bin/harness claim TOOLCHAIN-001 --agent codex`

이 파일에는 세션 전문을 복사하지 않습니다. 결정 5개, blocker, 다음 명령만 유지합니다.
