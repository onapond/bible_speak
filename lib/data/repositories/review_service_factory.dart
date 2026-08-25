import 'package:firebase_auth/firebase_auth.dart';

import '../../services/review_service.dart';
import 'firestore_review_repository.dart';
import 'review_repository.dart';

export '../../services/review_service.dart';

/// 현재 앱 런타임의 복습 서비스를 조립하는 composition root.
///
/// 관계형 저장소로 전환할 때 UI나 [ReviewService]를 수정하지 않고 이 생성
/// 지점에 새 [ReviewRepository] 구현을 주입한다.
ReviewService createReviewService({
  FirebaseAuth? auth,
  ReviewRepository? repository,
}) {
  final resolvedAuth = auth ?? FirebaseAuth.instance;
  return ReviewService(
    repository: repository ?? FirestoreReviewRepository(),
    currentUserId: () => resolvedAuth.currentUser?.uid,
  );
}
