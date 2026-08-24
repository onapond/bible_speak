#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
ENVIRONMENT=${1:-}
TARGET=${2:-hosting}
CHECK_ONLY=${3:-}
BRANCH=${GITHUB_REF_NAME:-$(git -C "$ROOT" branch --show-current)}

case "$ENVIRONMENT" in
  development|dev)
    ENVIRONMENT=development
    EXPECTED_BRANCH=develop
    PROJECT_ID=bible-speak-dev
    PROJECT_ALIAS=dev
    ;;
  production|prod)
    ENVIRONMENT=production
    EXPECTED_BRANCH=master
    PROJECT_ID=bible-speak
    PROJECT_ALIAS=prod
    ;;
  *)
    echo "Usage: ./scripts/deploy_environment.sh development|production web|hosting|functions|firestore|all [--check]" >&2
    exit 2
    ;;
esac

case "$TARGET" in
  web) FIREBASE_TARGET=hosting,firestore:rules ;;
  hosting) FIREBASE_TARGET=hosting ;;
  functions) FIREBASE_TARGET=functions ;;
  firestore) FIREBASE_TARGET=firestore:rules ;;
  all) FIREBASE_TARGET=hosting,functions,firestore:rules ;;
  *)
    echo "Unsupported target: $TARGET" >&2
    exit 2
    ;;
esac

if [ "$BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "$ENVIRONMENT deployments require branch $EXPECTED_BRANCH (current: $BRANCH)." >&2
  exit 3
fi

if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
  echo "Deployment requires a clean worktree." >&2
  exit 3
fi

node -e "const c=require(process.argv[1]);if(c.projects?.[process.argv[2]]!==process.argv[3]){throw Error('Firebase alias mismatch')}" "$ROOT/.firebaserc" "$PROJECT_ALIAS" "$PROJECT_ID"

if [ "$ENVIRONMENT" = "production" ]; then
  if ! git -C "$ROOT" describe --exact-match --match 'v*' HEAD >/dev/null 2>&1; then
    echo "Production deployment requires a v* release tag on HEAD." >&2
    exit 5
  fi
  if [ "${BIBLE_SPEAK_PROD_CONFIRM:-}" != "$PROJECT_ID" ]; then
    echo "Set BIBLE_SPEAK_PROD_CONFIRM=$PROJECT_ID for an authorized production deployment." >&2
    exit 5
  fi
fi

echo "Environment contract OK: branch=$BRANCH environment=$ENVIRONMENT project=$PROJECT_ID target=$FIREBASE_TARGET"
if [ "$CHECK_ONLY" = "--check" ]; then
  exit 0
fi

cd "$ROOT"
./bin/harness verify --lane full --target web

if [[ "$FIREBASE_TARGET" == *hosting* ]]; then
  METADATA="$ROOT/build/web/environment.json"
  if [ ! -f "$METADATA" ]; then
    echo "Full verification did not produce build/web/environment.json." >&2
    exit 4
  fi
  node -e "const m=require(process.argv[1]);if(m.environment!==process.argv[2]||m.projectId!==process.argv[3]||m.commit!==process.argv[4]){throw Error('Build metadata does not match deployment environment or HEAD')}" "$METADATA" "$ENVIRONMENT" "$PROJECT_ID" "$(git -C "$ROOT" rev-parse HEAD)"
fi

npx --yes firebase-tools@15.28.1 deploy \
  --project "$PROJECT_ID" \
  --only "$FIREBASE_TARGET"
