#!/bin/bash
# 웹 빌드 스크립트 - 비밀 키는 Firebase Functions Secret으로 관리

# 클라이언트에는 공개 가능한 서버 API 주소만 주입합니다.
flutter build web --release \
  --dart-define=API_BASE_URL=${API_BASE_URL:-https://asia-northeast3-bible-speak.cloudfunctions.net}

echo "Build complete! Deploy with: firebase deploy --only hosting"
