#!/bin/bash
# 웹 빌드 스크립트 - .env에서 API 키를 읽어 빌드 시 주입

# .env 파일 로드
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Flutter 웹 빌드 (환경변수 주입)
flutter build web --release \
  --dart-define=ESV_API_KEY=$ESV_API_KEY \
  --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY \
  --dart-define=ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY \
  --dart-define=AZURE_SPEECH_KEY=$AZURE_SPEECH_KEY \
  --dart-define=AZURE_SPEECH_REGION=$AZURE_SPEECH_REGION

echo "Build complete! Deploy with: firebase deploy --only hosting"
