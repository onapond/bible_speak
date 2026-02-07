#!/bin/bash
# Pre-deploy hook: firebase deploy 전에 빌드 확인

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).tool_input.command)}catch(e){}})" 2>/dev/null)

if echo "$COMMAND" | grep -q "firebase deploy"; then
  if [ ! -d "C:/dev/bible_speak/build/web" ]; then
    echo "build/web 없음! 먼저 빌드하세요: powershell -ExecutionPolicy Bypass -File build_web.ps1" >&2
    exit 2
  fi
fi
exit 0
