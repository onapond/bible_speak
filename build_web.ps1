# 웹 빌드 스크립트 (PowerShell) - .env에서 API 키를 읽어 빌드 시 주입

# .env 파일 로드
if (Test-Path .env) {
    Get-Content .env | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
}

# Flutter 웹 빌드 (환경변수 주입)
flutter build web --release `
    --dart-define="ESV_API_KEY=$env:ESV_API_KEY" `
    --dart-define="GEMINI_API_KEY=$env:GEMINI_API_KEY" `
    --dart-define="ELEVENLABS_API_KEY=$env:ELEVENLABS_API_KEY" `
    --dart-define="AZURE_SPEECH_KEY=$env:AZURE_SPEECH_KEY" `
    --dart-define="AZURE_SPEECH_REGION=$env:AZURE_SPEECH_REGION"

Write-Host "Build complete! Deploy with: firebase deploy --only hosting"
