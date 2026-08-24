# 개발·운영 환경 관리

## 환경 경계

| 구분 | Development | Production |
|------|-------------|------------|
| Git 브랜치 | `develop` | `master` |
| 작업 브랜치 | `codex/*`, `claude/*` → `develop` PR | 직접 작업 금지 |
| Firebase 프로젝트 | `bible-speak-dev` | `bible-speak` |
| Web | `bible-speak-dev.web.app` | `bible-speak.web.app` |
| Firestore | 서울 `asia-northeast3`, 개발 데이터 전용 | 실제 사용자 데이터 |
| 앱 설정 | `APP_ENV=development` | `APP_ENV=production` |
| GitHub Environment | `development` (`develop`만) | `production` (`master`만) |
| 배포 | 검증 성공 후 자동 | 수동 확인 후 실행 |

`.firebaserc`에는 기본 프로젝트가 없습니다. `firebase deploy`만 입력하면 대상이
결정되지 않아 실패해야 정상입니다. 항상 가드 스크립트 또는 프로젝트 ID가 고정된
CI만 사용합니다.

## 코드 승격 흐름

```text
codex/* 또는 claude/*
        │  PR + CI
        ▼
     develop ── 검증 성공 ──▶ Firebase Development
        │
        │  회귀·실기기·보안 검증 후 PR
        ▼
      master ── 수동 승인 ──▶ Firebase Production
```

개발 Firebase의 데이터는 운영에서 복사하지 않습니다. 테스트용 계정과 시드 데이터만
사용하고, 실제 사용자·구매·토큰·API 비밀은 가져오지 않습니다.

## 로컬 명령

```bash
# 개별 작업 브랜치 또는 develop에서 개발 빌드
./build_web.sh development

# develop의 검증된 커밋만 개발 Hosting에 배포
./scripts/deploy_environment.sh development hosting

# Firestore 규칙만 개발 환경에 배포
./scripts/deploy_environment.sh development firestore
```

운영 배포에는 다음 조건이 모두 필요합니다.

1. 현재 브랜치가 `master`이다.
2. 작업 트리가 깨끗하다.
3. HEAD에 `v*` 릴리스 태그가 있다.
4. `./bin/harness verify --lane full --target web`이 통과한다.
5. 빌드 메타데이터의 환경·Firebase 프로젝트·커밋이 HEAD와 일치한다.
6. `BIBLE_SPEAK_PROD_CONFIRM=bible-speak`가 명시되어 있다.

```bash
./build_web.sh production
BIBLE_SPEAK_PROD_CONFIRM=bible-speak \
  ./scripts/deploy_environment.sh production hosting
```

## GitHub 자동화

- `Environment Contract`: `develop`과 `master`의 하네스, Functions, Flutter 검증.
- `Deploy Development`: `develop` 검증 성공 커밋만 개발 Hosting과 규칙에 배포.
- `Deploy Production`: `master`에서 수동 실행하고 `DEPLOY bible-speak` 입력 필요.
- GitHub의 `development`와 `production` Environment에는 서로 다른 Firebase
  서비스 계정 Secret이 저장되어 있다.

## 현재 준비 상태

- 개발 Firebase 프로젝트, Web/Android/iOS 앱, Hosting, Firestore DB가 생성되어 있다.
- 개발/운영 GitHub 배포 자격 증명과 브랜치 제한이 분리되어 있다.
- 개발 프로젝트는 무료 요금제이므로 Cloud Functions 배포는 결제 연결 전까지
  의도적으로 비활성이다. 결제 연결은 비용 승인을 받은 별도 작업으로 진행한다.
- Firebase Authentication의 이메일·익명 제공자는 개발 Console에서 최초 시작이
  필요하다. 운영 계정과 다른 테스트 계정만 사용한다.
- 운영 Firestore의 기존 공개 규칙은 위험하다. 저장소의 규칙을 개발 환경에서 먼저
  회귀 검증하고, 기능 호환성이 확인된 뒤 운영에 승격한다.

## 금지 사항

- 작업 브랜치나 `develop`에서 `--project bible-speak` 사용
- `master`에서 `--project bible-speak-dev` 사용
- 실제 운영 사용자 데이터를 개발 Firestore로 복사
- 빌드와 배포를 `&&`로 한 명령에 연결
- 검증되지 않은 Firestore Rules 또는 Functions를 운영에 직접 배포
