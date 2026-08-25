# Production Firestore Rules snapshot

- Project: `bible-speak`
- Database: `(default)` (`asia-northeast3`)
- Captured at: `2026-08-25T17:55:48+09:00`
- Capture mode: Firebase Console, read-only inspection
- Source: `production-firestore-20260825T175548+0900.rules`
- Source SHA-256: `952e896720400bca9941992f0bba30bcc17c345f1c18ee2e7567dc97294e185b`
- Repository `firestore.rules` SHA-256 at capture: `aa302c144cfb65bd6570dc5cae2b244cead521c10355698c1c951de297086ab3`
- Active Ruleset name: unavailable; the Console displayed the active editor source but reported
  `규칙 버전을 로드하는 중에 오류가 발생했습니다.` while loading version history.
- Production mutation: none. Publish was not selected and no production command was run.

## Risk recorded at capture

The live source contains a recursive `allow read, write: if true` rule. It is intentionally
preserved byte-for-byte as the rollback baseline and is not safe as a target security policy.
The hardened repository Rules must complete the documented production approval and regression
process before replacing it.

## Integrity check

```sh
shasum -a 256 docs/deploy/snapshots/production-firestore-20260825T175548+0900.rules
```

Expected digest:

```text
952e896720400bca9941992f0bba30bcc17c345f1c18ee2e7567dc97294e185b
```
