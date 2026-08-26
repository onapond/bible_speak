# Development toolchain

Bible Speak의 로컬 개발 도구는 루트 `mise.toml`에 고정한다.

| Tool | Version | Purpose |
|---|---:|---|
| Flutter | 3.47.1 | iOS, Android, web 앱 |
| Node.js | 22.23.2 | Firebase Functions Node 22 runtime |
| Firebase CLI | 15.28.1 | Emulator와 개발·운영 환경 관리 |
| Temurin Java | 21.0.12+8 | Android와 Firestore Emulator runtime |

iOS 검증 기준은 Xcode 26.6, iOS Simulator 26.5, CocoaPods 1.17.0이다. 앱의
최소 지원 버전은 iOS 15이다.

## First setup

```sh
brew install mise
```

`~/.zshrc`에 다음 줄을 한 번만 추가한다.

```sh
eval "$(mise activate zsh)"
```

저장소 루트에서 설치와 네이티브 설정을 실행한다.

```sh
mise trust
./scripts/prepare_native_toolchain.sh
./bin/harness doctor --strict
```

준비 스크립트는 mise의 Temurin 21 경로를 Flutter Android JDK로 고정하고 잠긴
Flutter 패키지를 복원한다. macOS에서는 Xcode, CocoaPods, 설치된 iOS Simulator
runtime도 확인한다. Simulator runtime이 없으면 다음 명령으로 설치한 뒤 다시 실행한다.

```sh
xcodebuild -downloadPlatform iOS
```

Android Studio의 `SDK Tools`에서 `Android SDK Command-line Tools (latest)`를
설치한 뒤 SDK 라이선스는 개발자가 직접 검토하고 승인한다.

새 셸을 열기 전에는 다음처럼 동일한 도구를 실행할 수 있다.

```sh
mise exec -- flutter --version
mise exec -- node --version
mise exec -- firebase --version
mise exec -- java -version
```

버전을 갱신할 때는 `mise.toml`, Functions runtime, CI workflow의 버전을 함께
검토한다. 임시 디렉터리의 Flutter SDK나 시스템 기본 Node에 의존하지 않는다.

Firebase 로그인과 프로젝트 권한은 버전 관리 대상이 아니다. 로컬 사용자 인증과
GitHub environment credentials를 계속 분리한다.

Apple Silicon에서는 Firebase standalone 바이너리 대신 mise의
`npm:firebase-tools` backend를 사용한다. 이 구성은 지원 중인 Node 22 LTS와 함께
실행되어 x86 전용 바이너리 호환성 문제를 피한다. Node 20은 2026년 3월 EOL이고
현재 Functions 의존성의 엔진 범위에서도 제외되므로 사용하지 않는다.

Firebase CLI 15 Emulator는 Java 21 미만을 지원하지 않는다. 시스템 `JAVA_HOME`과
무관하게 저장소 안에서는 mise의 Temurin 21을 사용한다.

## Dependency audit note

2026-08-25 기준 `npm audit`은 Functions의 Google/Firebase 전이 의존성에서 moderate
등급 7건을 보고한다. 현재 제안되는 `npm audit fix --force`는 `firebase-admin`과
`firebase-functions`를 오래된 호환 불가 버전으로 내리므로 적용하지 않는다. high 또는
critical 항목은 없으며, 상위 패키지의 호환 수정 릴리스를 정기적으로 확인한다.
