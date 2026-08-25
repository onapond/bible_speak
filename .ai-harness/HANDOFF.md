# AI handoff

- Task: TOOLCHAIN-001 — Mac Flutter·Node·Firebase 툴체인 영구 설치 및 버전 고정
- From/To: codex -> human
- State: review
- Summary: mise로 Flutter 3.47.1, Node 20.20.2, Firebase CLI 15.28.1을 영구 설치·고정하고 하네스가 프로젝트 도구를 우선 해석하도록 보강함
- Changed: .ai-harness/config.json, docs/dev/AI_HARNESS.md, docs/dev/TOOLCHAIN.md, mise.toml, tool/agent_harness.py, tool/tests/test_agent_harness.py
- Verification: baa312e-ceb496fc-standard-1787625408 (pass)
- Next: 보호 브랜치 PR 상태검사 통과 후 develop에 병합하고 DATA-RULES-001을 시작
