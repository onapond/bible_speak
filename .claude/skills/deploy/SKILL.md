# Deploy Skill

프로젝트를 빌드하고 배포하는 전체 파이프라인을 실행한다.

## 단계

### 1. 프로젝트 감지
- `pubspec.yaml` 존재 → Flutter 프로젝트
- `package.json` 존재 → Node.js/React/Next.js 프로젝트
- `firebase.json` 존재 → Firebase 배포 대상
- `vercel.json` 또는 `.vercel/` 존재 → Vercel 배포 대상
- `netlify.toml` 존재 → Netlify 배포 대상
- 빌드 스크립트 (`build_web.ps1`, `build.sh` 등) 존재 시 해당 스크립트 우선 사용

### 2. 코드 분석 (필수)
- Flutter: `flutter analyze` 실행
- Node.js: `npm run lint` 또는 `npx tsc --noEmit` 실행
- error가 있으면 **즉시 중단**하고 수정 방법 안내
- info/warning은 통과 가능

### 3. 빌드 (필수)
- 프로젝트 루트에 커스텀 빌드 스크립트가 있으면 그것을 사용 (API 키 주입 등 포함)
  - Windows: `powershell -ExecutionPolicy Bypass -File build_web.ps1`
  - Unix: `bash build.sh`
- 커스텀 스크립트 없을 경우:
  - Flutter: `flutter build web --release`
  - Next.js: `npm run build`
  - React: `npm run build`
- 빌드 실패 시 **즉시 중단**

### 4. 커밋 & 푸시
- 변경사항이 있으면 `git add` → `git commit` → `git push`
- 커밋 메시지는 배포 내용 기반으로 자동 생성
- 변경사항이 없으면 이 단계 건너뛰기

### 5. 배포
- Firebase: `firebase deploy --only hosting`
- Vercel: `vercel --prod`
- Netlify: `netlify deploy --prod`
- 배포 완료 후 URL 기록

### 6. 배포 후 검증
- 배포된 URL에 접속하여 HTTP 200 응답 확인
- 주요 기능 동작 여부 간단히 확인
- 결과 리포트 출력:
  - 배포 URL
  - 빌드 시간
  - 성공/실패 여부

## 실패 시 행동
- 어떤 단계에서든 실패하면 **즉시 중단**
- 실패 원인과 수정 방법을 명확히 안내
- 절대 실패한 상태로 다음 단계 진행 금지

## 주의사항
- `.env` 파일은 절대 커밋하지 않는다
- 커스텀 빌드 스크립트가 있으면 반드시 그것을 사용한다 (API 키 누락 방지)
- Windows 환경에서는 PowerShell 호환 명령어를 사용한다
