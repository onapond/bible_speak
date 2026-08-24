#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
ENVIRONMENT=${1:-development}
BRANCH=${GITHUB_REF_NAME:-$(git -C "$ROOT" branch --show-current)}

case "$ENVIRONMENT" in
  development|dev)
    ENVIRONMENT=development
    PROJECT_ID=bible-speak-dev
    if [ "$BRANCH" = "master" ]; then
      echo "Refusing a development build from the production branch master." >&2
      exit 2
    fi
    ;;
  production|prod)
    ENVIRONMENT=production
    PROJECT_ID=bible-speak
    if [ "$BRANCH" != "master" ]; then
      echo "Production builds are allowed only from master (current: $BRANCH)." >&2
      exit 2
    fi
    ;;
  *)
    echo "Usage: ./build_web.sh development|production" >&2
    exit 2
    ;;
esac

API_URL=${API_BASE_URL:-https://asia-northeast3-${PROJECT_ID}.cloudfunctions.net}
BUILD_ID=$(date -u +%Y%m%d%H%M%S)
COMMIT_SHA=$(git -C "$ROOT" rev-parse HEAD)

cd "$ROOT"
if [ -n "${FLUTTER_BIN:-}" ] && [ -x "$FLUTTER_BIN" ]; then
  FLUTTER_CMD=$FLUTTER_BIN
elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  FLUTTER_CMD=$FLUTTER_ROOT/bin/flutter
else
  FLUTTER_CMD=flutter
fi

"$FLUTTER_CMD" build web --release \
  --dart-define=APP_ENV="$ENVIRONMENT" \
  --dart-define=API_BASE_URL="$API_URL"

node -e "const fs=require('fs');fs.writeFileSync('build/web/environment.json',JSON.stringify({environment:process.argv[1],projectId:process.argv[2],commit:process.argv[3],buildId:process.argv[4]},null,2)+'\\n')" "$ENVIRONMENT" "$PROJECT_ID" "$COMMIT_SHA" "$BUILD_ID"

echo "Built web environment=$ENVIRONMENT project=$PROJECT_ID commit=$COMMIT_SHA"
echo "Deploy separately with: ./scripts/deploy_environment.sh ${ENVIRONMENT/development/dev} hosting"
