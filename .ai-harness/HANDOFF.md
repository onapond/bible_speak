# AI handoff

- Task: DATA-PORTABILITY-001 — Firestore 전환 경계와 복습 저장소 포트 도입
- From/To: codex -> human
- State: review
- Summary: 복습 도메인을 ReviewRepository와 Firestore adapter로 분리하고 안정 ID·transaction·복합 index·계약 테스트·SQL 전환 원칙을 추가함. 운영 rules는 변경하지 않음.
- Changed: docs/architecture/data-portability.md, firebase.json, firestore.indexes.json, lib/data/repositories/firestore_review_repository.dart, lib/data/repositories/review_repository.dart, lib/data/repositories/review_service_factory.dart, lib/models/review_item.dart, lib/screens/home/main_menu_screen.dart, lib/screens/practice/verse_practice_redesigned.dart, lib/screens/practice/verse_practice_screen.dart, lib/screens/review/review_screen.dart, lib/screens/study/learning_center_screen.dart
- Verification: 01d3c34-a8ca7517-standard-1787622024 (pass)
- Next: 변경 검토 후 PR로 develop에 반영. 이후 TOOLCHAIN-001을 진행하고, 운영 규칙은 DATA-RULES-001의 emulator/dev 검증 뒤 별도 승인으로 처리.
