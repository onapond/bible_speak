# Development toolchain

Bible Speak의 로컬 개발 도구는 루트 `mise.toml`에 고정한다.

| Tool | Version | Purpose |
|---|---:|---|
| Flutter | 3.47.1 | iOS, Android, web 앱 |
| Node.js | 20.20.2 | Firebase Functions Node 20 runtime |
| Firebase CLI | 15.28.1 | Emulator와 개발·운영 환경 관리 |

## First setup

```sh
brew install mise
```

`~/.zshrc`에 다음 줄을 한 번만 추가한다.

```sh
eval "$(mise activate zsh)"
```

저장소 루트에서 설치와 검증을 실행한다.

```sh
mise trust
mise install
./bin/harness doctor --strict
```

새 셸을 열기 전에는 다음처럼 동일한 도구를 실행할 수 있다.

```sh
mise exec -- flutter --version
mise exec -- node --version
mise exec -- firebase --version
```

버전을 갱신할 때는 `mise.toml`, Functions runtime, CI workflow의 버전을 함께
검토한다. 임시 디렉터리의 Flutter SDK나 시스템 기본 Node에 의존하지 않는다.

Firebase 로그인과 프로젝트 권한은 버전 관리 대상이 아니다. 로컬 사용자 인증과
GitHub environment credentials를 계속 분리한다.

Apple Silicon에서는 Firebase standalone 바이너리 대신 mise의
`npm:firebase-tools` backend를 사용한다. Firebase CLI의 직접 의존성은 Node 20을
지원하며, 설치 중 더 높은 Node 버전을 권고하는 전이 의존성 경고가 표시될 수 있다.
실제 호환성은 `doctor --strict`와 CLI 버전 실행으로 검증한다. 이 구성은 Node 20과 함께
실행되어 x86 전용 바이너리 호환성 문제를 피한다.
