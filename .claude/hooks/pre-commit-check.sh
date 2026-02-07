#!/bin/bash
# Pre-commit hook: git commit 전에 flutter analyze 실행

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).tool_input.command)}catch(e){}})" 2>/dev/null)

if echo "$COMMAND" | grep -q "git commit"; then
  cd "C:/dev/bible_speak"
  RESULT=$(flutter analyze 2>&1)
  if [ $? -ne 0 ]; then
    echo "flutter analyze 실패! 커밋 전에 에러를 수정하세요:" >&2
    echo "$RESULT" | tail -20 >&2
    exit 2
  fi
  echo "flutter analyze 통과" >&2
fi
exit 0
