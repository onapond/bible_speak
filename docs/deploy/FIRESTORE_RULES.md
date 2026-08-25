# Firestore Rules verification and rollout

`firestore.rules`는 개발과 운영이 공유하는 원본이지만 두 환경에 자동으로 동시에
배포하지 않는다. 로컬 Emulator, development, production 순서로 승격한다.

## Local regression

Rules 테스트는 실제 프로젝트에 연결되지 않는 `demo-bible-speak-rules` ID를 사용한다.

```sh
mise install
npm --prefix functions install
npm --prefix functions run test:rules
```

`npm --prefix functions test`와 필수 CI도 동일한 owner/non-owner CRUD 테스트를 실행한다.
Firebase CLI 15 Emulator에는 Java 21 이상이 필요하며 `mise.toml`이 이를 고정한다.

## Development smoke test

1. Firebase Console의 `bible-speak-dev` Authentication에서 **Get started**를 실행하고
   Email/Password와 Anonymous provider를 활성화한다. 이 Console 경로는 Blaze 요금제가
   필요하지 않다. billing-enabled 프로젝트 전용인 Identity Platform
   `identityPlatform:initializeAuth` API로 대신 초기화하지 않는다.
2. 변경이 `develop`에 병합되고 development 자동 배포가 성공한 뒤 다음 workflow를
   실행한다. 이 workflow는 `development` environment secret만 사용하며 프로젝트 ID를
   `bible-speak-dev`로 고정한다.

   ```sh
   gh workflow run development-auth-smoke.yml \
     --ref develop \
     -f confirmation='SMOKE bible-speak-dev'
   ```

   workflow는 Email/Password와 Anonymous 실제 sign-up을 수행하므로 provider가 아직
   비활성화된 경우 실패한다. Google·Apple provider는 각 개발 OAuth 설정이 준비된 뒤
   별도로 검증한다.
3. 인증 토큰을 출력하는 `firebase login:list --json`은 사용하지 않는다. 필요하면
   `firebase login --non-interactive`로 로그인하고 일반 `firebase login:list`로
   계정 이메일만 확인한다.
4. 로컬 Rules 테스트가 통과한 커밋에서만 development Rules를 배포한다.
5. workflow는 임시 Email/Password owner와 Anonymous 비소유자를 생성해 자신의
   `reviews` CRUD 성공 및 다른 사용자의 read/create/update/delete 거부를 확인한다.
6. workflow의 `finally` cleanup이 임시 사용자와 테스트 문서를 삭제한다. Actions run의
   수행 시각·commit SHA를 handoff에 기록한다.

## Production snapshot and rollback

운영 변경 전 Firebase Rules REST API의 다음 읽기 전용 순서로 현재 Ruleset을
snapshot한다.

1. `projects/bible-speak/releases/cloud.firestore`를 GET해 활성 `rulesetName`을 얻는다.
2. 해당 `projects/bible-speak/rulesets/{id}`를 GET해 source를 저장한다.
3. source의 SHA-256, ruleset 이름, 조회 시각을 함께 기록하고 저장소 Rules와 비교한다.

운영 배포는 `master`의 승인된 `v*` 릴리스에서만 수행한다. 장애 시에는 직전 snapshot
source를 임시 규칙 파일로 복원하고, 동일한 Emulator 테스트와 명시적 운영 확인을
거친 뒤에만 다음 명령을 실행한다.

```sh
BIBLE_SPEAK_PROD_CONFIRM=bible-speak \
  ./scripts/deploy_environment.sh production firestore
```

snapshot 조회와 rollback 준비는 배포 승인이 아니다. `DATA-RULES-001`에서는 production
Rules를 배포하거나 활성 Ruleset을 변경하지 않는다.
