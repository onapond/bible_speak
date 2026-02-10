#!/bin/bash
# Pre-commit hook: git commit 전에 flutter analyze + UI 품질 검사 실행

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).tool_input.command)}catch(e){}})" 2>/dev/null)

if echo "$COMMAND" | grep -q "git commit"; then
  cd "C:/dev/bible_speak"

  # Step 1: flutter analyze
  RESULT=$(flutter analyze 2>&1)
  if [ $? -ne 0 ]; then
    echo "flutter analyze 실패! 커밋 전에 에러를 수정하세요:" >&2
    echo "$RESULT" | tail -20 >&2
    exit 2
  fi
  echo "flutter analyze 통과" >&2

  # Step 2: UI 품질 검사 (errors만 커밋 차단, warnings는 표시만)
  UI_RESULT=$(dart run scripts/ui_check.dart --summary 2>&1)
  UI_EXIT=$?
  if [ $UI_EXIT -ne 0 ]; then
    echo "" >&2
    echo "UI 품질 검사에서 ERROR 감지! 커밋 전에 수정하세요:" >&2
    echo "$UI_RESULT" >&2
    exit 2
  fi
  echo "UI 품질 검사 통과" >&2

  # warnings가 있으면 표시만 (차단하지 않음)
  if echo "$UI_RESULT" | grep -q "warnings"; then
    echo "" >&2
    echo "$UI_RESULT" | tail -10 >&2
  fi
fi
exit 0
