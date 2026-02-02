# 웹 빌드 스크립트 (PowerShell) - .env에서 API 키를 읽어 빌드 시 주입
# iOS PWA 업데이트 문제 해결을 위한 최적화 포함

Write-Host "=== Bible Speak Web Build Script ===" -ForegroundColor Cyan

# .env 파일 로드
if (Test-Path .env) {
    Get-Content .env | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
    Write-Host "[OK] Environment variables loaded" -ForegroundColor Green
}

# 빌드 타임스탬프 생성
$buildTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "[INFO] Build timestamp: $buildTimestamp" -ForegroundColor Yellow

# Flutter 웹 빌드 (환경변수 주입 + PWA 전략 설정)
# --pwa-strategy=offline-first: 캐시 우선, 백그라운드에서 업데이트 확인
# iOS PWA에서 빠른 로딩 + 업데이트 감지 가능
Write-Host "[BUILD] Running flutter build web..." -ForegroundColor Yellow

flutter build web --release `
    --pwa-strategy=offline-first `
    --dart-define="ESV_API_KEY=$env:ESV_API_KEY" `
    --dart-define="GEMINI_API_KEY=$env:GEMINI_API_KEY" `
    --dart-define="ELEVENLABS_API_KEY=$env:ELEVENLABS_API_KEY" `
    --dart-define="AZURE_SPEECH_KEY=$env:AZURE_SPEECH_KEY" `
    --dart-define="AZURE_SPEECH_REGION=$env:AZURE_SPEECH_REGION" `
    --dart-define="BUILD_TIMESTAMP=$buildTimestamp"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Flutter build completed" -ForegroundColor Green

# index.html에 빌드 타임스탬프 삽입
$indexPath = "build/web/index.html"
if (Test-Path $indexPath) {
    (Get-Content $indexPath -Raw) -replace 'BUILD_TIMESTAMP', $buildTimestamp | Set-Content $indexPath
    Write-Host "[OK] Build timestamp injected into index.html" -ForegroundColor Green
}

# version.json 생성 (클라이언트에서 버전 확인용)
$versionInfo = @{
    version = $buildTimestamp
    buildDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    commit = (git rev-parse --short HEAD 2>$null) -or "unknown"
} | ConvertTo-Json

$versionInfo | Set-Content "build/web/version.json"
Write-Host "[OK] version.json created" -ForegroundColor Green

# 커스텀 서비스 워커 코드 추가 (iOS PWA 업데이트 지원)
$swPath = "build/web/flutter_service_worker.js"
$customSwPath = "web/custom_service_worker.js"
if ((Test-Path $swPath) -and (Test-Path $customSwPath)) {
    Add-Content -Path $swPath -Value "`n`n// === Custom Service Worker Additions ===`n"
    Get-Content $customSwPath | Add-Content -Path $swPath
    Write-Host "[OK] Custom service worker code appended" -ForegroundColor Green
}

# legal 폴더 복사 (이용약관, 개인정보처리방침)
if (Test-Path "docs/legal") {
    Copy-Item -Path "docs/legal" -Destination "build/web/legal" -Recurse -Force
    Write-Host "[OK] Legal documents copied" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Build Complete! ===" -ForegroundColor Cyan
Write-Host "Version: $buildTimestamp"
Write-Host ""
Write-Host "Deploy with:" -ForegroundColor Yellow
Write-Host "  firebase deploy --only hosting"
Write-Host ""
Write-Host "PWA Update Notes:" -ForegroundColor Magenta
Write-Host "  - Service Worker: offline-first strategy"
Write-Host "  - index.html & flutter_service_worker.js: no-cache"
Write-Host "  - Static assets: immutable cache (1 year)"
