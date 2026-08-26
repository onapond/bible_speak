# Native development and smoke test

Bible Speak의 네이티브 빌드는 개발 Firebase 프로젝트 `bible-speak-dev`만 사용한다.
운영 프로젝트, 운영 계정, 운영 데이터로 smoke test하지 않는다. 로컬 빌드는 별도
정의가 없으면 development 환경을 사용한다.

## Fresh checkout build

macOS fresh checkout에서 다음 순서로 실행한다.

```sh
mise trust
./scripts/prepare_native_toolchain.sh
mise exec -- flutter build ios --simulator --debug --no-pub
mise exec -- flutter build apk --debug --no-pub
./bin/harness verify --lane full --target ios
```

의존성 재현 기준은 `pubspec.lock`, `ios/Podfile.lock`, 두 Xcode 진입점의
`Package.resolved`이다. Flutter가 SwiftPM과 미지원 플러그인의 CocoaPods fallback을
함께 구성하므로 `pod install`을 별도로 선행하지 않는다. Pods, `.symlinks`, Flutter
ephemeral 디렉터리는 생성물이므로 커밋하지 않는다. full iOS lane은 iOS Simulator
debug, Android APK debug, unsigned iOS release를 모두 검사한다.

## Real-device smoke procedure

준비 사항:

- iOS 15 이상 iPhone 1대와 지원 중인 Android 기기 1대를 사용한다.
- 개발용 Apple/Google 로그인 계정과 서로 다른 Firebase 테스트 계정 A/B를 준비한다.
- 커밋 SHA, 기기 모델, OS 버전, 결과를 `PASS`, `FAIL`, `BLOCKED`로 기록한다.

각 기기에서 다음 명령으로 development 빌드를 실행한다.

```sh
mise exec -- flutter devices
mise exec -- flutter run -d DEVICE_ID --dart-define=APP_ENV=development
```

다음 핵심 흐름을 순서대로 확인한다.

1. 첫 실행의 loading/empty 상태와 Email, Apple 또는 Google 로그인 및 로그아웃이 정상이다.
2. 테스트 계정 A의 암송·복습 데이터를 생성, 수정, 삭제하고 앱 재시작 뒤 유지되는지 확인한다.
3. 계정 B로 전환했을 때 계정 A의 데이터가 보이거나 수정되지 않는지 확인한다.
4. 네트워크를 끊고 기존 데이터를 열어 offline 상태를 확인한 뒤, 다시 연결해 동기화와 오류 복구를 확인한다.
5. 마이크·음성 인식 권한을 허용/거부 각각 시험하고 녹음, 재생, 백그라운드 복귀 뒤 오디오 상태를 확인한다.
6. 알림 권한을 허용/거부 각각 시험하고 로컬 알림 예약과 탭 후 앱 복귀를 확인한다.
7. iOS는 Apple 로그인과 sandbox 결제 진입, Android는 Google 로그인과 test 결제 진입을 확인한다. 실제 결제는 하지 않는다.
8. 로그인 중 계정 변경, 강제 네트워크 오류, 앱 background/resume에서 crash나 다른 계정 데이터 노출이 없는지 확인한다.

실패 기록에는 재현 단계, 기대/실제 결과, 관련 로그와 스크린샷 경로만 남긴다. 비밀번호,
토큰, Firebase 자격 증명, 결제 정보는 기록하지 않는다.
