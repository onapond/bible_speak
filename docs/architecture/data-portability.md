# Data portability boundary

Bible Speak는 현재 Firebase Auth와 Firestore를 사용한다. 관계형 DB 전환은
일괄 재작성 대신 도메인별 저장소 계약을 추가하고 구현을 교체하는 방식으로
진행한다. 첫 기준 구현은 복습 도메인이다.

## Dependency boundary

```text
screens / preloaders
        |
        v
ReviewService                 Firebase와 무관한 유스케이스
        |
        v
ReviewRepository              저장소 계약
        |
        +-- FirestoreReviewRepository   현재 구현
        +-- SqlReviewRepository         향후 구현

review_service_factory.dart   현재 런타임 구현을 선택하는 유일한 조립 지점
```

도메인 모델과 서비스에는 `DocumentSnapshot`, `Timestamp`, `SetOptions` 또는
Firestore 경로를 노출하지 않는다. Firestore wire format 변환은 해당 adapter에
둔다. 새 기능도 같은 방향의 의존성만 허용한다.

## Stable identity and schema rules

- Firebase Auth는 DB와 별개로 유지할 수 있다. Firebase UID를 외부 사용자
  식별자로 보존하고, 향후 SQL `users` 테이블에서도 unique key로 사용한다.
- 기존 Firestore 문서 ID는 마이그레이션 중 SQL primary key 또는 unique
  migration key로 그대로 보존한다. dual-read 기간에 임의로 다시 생성하지 않는다.
- 새로 쓰는 복습 문서에는 `schemaVersion`을 기록한다. 구버전 문서는 버전이
  없어도 version 0으로 읽을 수 있어야 한다.
- 도메인에서는 `DateTime`, Firestore adapter에서는 `Timestamp`, SQL에서는
  UTC `timestamptz`를 사용한다. 변환 경계 밖으로 저장소 전용 날짜 타입을
  전달하지 않는다.
- 사용자 참조 필드 이름은 `userId`로 통일한다. 기존 Firestore 저장 키도
  `userId`이므로 이번 변경은 데이터 마이그레이션을 요구하지 않는다.

## Relational target for reviews

```sql
reviews (
  id text primary key,
  user_id text not null references users(firebase_uid),
  verse_reference text not null,
  book text not null,
  chapter integer not null,
  verse integer not null,
  verse_text text not null,
  easiness_factor double precision not null,
  interval_days integer not null,
  repetitions integer not null,
  next_review_at timestamptz not null,
  last_review_at timestamptz,
  total_reviews integer not null,
  correct_count integer not null,
  created_at timestamptz not null,
  unique (user_id, book, chapter, verse)
)
```

실제 SQL 도입 시 FK 대상은 내부 UUID를 사용할 수 있지만 Firebase UID unique
mapping은 유지한다. 서비스 계약은 이 내부 선택을 알지 못해야 한다.

Firestore의 신규 복습 문서 ID도 `userId + book:chapter:verse`의 SHA-256으로
결정한다. 생성은 트랜잭션으로 기존 문서를 먼저 확인하므로 두 기기에서 동시에
요청해도 누적 복습 상태를 덮어쓰지 않고 같은 문서에 수렴한다. 기존 random
document ID는 조회 호환성을 위해 그대로 유지하고 backfill 때 migration key로
보존한다.

Firestore 클라이언트 트랜잭션은 오프라인에서 완료되지 않는다. 신규 복습 등록의
오프라인 보장은 `progress` 저장소 경계와 sync queue를 함께 설계할 때 추가한다.
그 전에는 네트워크 오류를 성공으로 표시하거나 비트랜잭션 `set`으로 fallback해
기존 진도를 덮어쓰지 않는다.

## Migration sequence

1. 도메인별 Firestore 직접 호출을 저장소 계약 뒤로 이동한다.
2. export 검증 도구로 문서 수, 필수 필드, 고아 참조, 중복 키를 측정한다.
3. SQL schema와 API adapter를 만들고 Firestore 문서 ID를 보존해 backfill한다.
4. 서버에서만 dual-write한다. 모바일 클라이언트의 두 DB 직접 쓰기는 금지한다.
5. 문서 수, 사용자별 합계, 금액·재화 원장을 대조한 뒤 도메인별로 읽기를
   전환한다.
6. 안정화 기간 후 Firestore 쓰기를 중지하되 rollback 기간 동안 읽기 전용
   사본을 보존한다.

## Next boundaries

적용 순서는 데이터 위험과 결합도를 기준으로 한다.

1. `progress`와 퀴즈 결과: 사용자별 학습 기록 및 오프라인 동기화 계약
2. `purchases`, `subscription`, `talants`: Cloud Functions 전용 명령과 불변 원장
3. `groups`, membership, friends: 명시적 관계와 서버 집계
4. 채팅·활동 피드: 실시간 transport와 영속 저장을 별도 계약으로 분리
5. 성경 본문: 변경 빈도가 낮으므로 SQL 이전보다 정적 bundle/CDN 비용을 먼저 비교

결제·재화·보상은 클라이언트 저장소 구현을 교체하는 방식이 아니라 서버 명령
API를 먼저 경계로 삼는다. 운영 Firestore 규칙은 별도의 원격 회귀검증 없이
변경하지 않는다.

## Security gate

저장소 adapter의 `userId` 검사는 정상 앱 코드의 계정 혼선을 막는
defense-in-depth일 뿐 보안 경계가 아니다. 현재 저장소 규칙의 포괄 match는
인증 사용자에게 넓은 접근을 허용하고, 인계된 운영 라이브 규칙은 그보다 더
넓을 가능성이 있다.

따라서 `DATA-RULES-001`에서 다음 순서를 지킨다.

1. 운영 라이브 규칙을 읽기 전용으로 snapshot하고 저장소 규칙과 비교한다.
2. Emulator에서 복습 owner/non-owner의 read/create/update/delete를 모두 테스트한다.
3. 초기화된 development Auth에서 규칙과 로그인 흐름을 smoke test한다.
4. rollback 규칙과 영향 범위를 준비한 뒤 별도 승인으로 production을 변경한다.

이 gate가 끝나기 전에는 adapter 검사 통과를 데이터 보안 완료로 간주하지 않으며,
production Firestore 규칙을 배포하지 않는다.
