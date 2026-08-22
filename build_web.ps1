# Web build script - English comments only to avoid encoding issues

$ts = Get-Date -Format "yyyyMMddHHmmss"
Write-Host "Build: $ts"

flutter build web --release --pwa-strategy=offline-first `
    --dart-define="API_BASE_URL=$(if ($env:API_BASE_URL) { $env:API_BASE_URL } else { 'https://asia-northeast3-bible-speak.cloudfunctions.net' })"

# version.json
$vj = @{ version = $ts; buildDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") } | ConvertTo-Json
[IO.File]::WriteAllText("build/web/version.json", $vj, [Text.Encoding]::UTF8)

# Inject timestamp into index.html
$idx = "build/web/index.html"
$c = [IO.File]::ReadAllText($idx, [Text.Encoding]::UTF8)
$c = $c -replace "BUILD_TIMESTAMP", $ts
[IO.File]::WriteAllText($idx, $c, [Text.Encoding]::UTF8)

# Append custom service worker
$sw = "build/web/flutter_service_worker.js"
$csw = "web/custom_service_worker.js"
if ((Test-Path $sw) -and (Test-Path $csw)) {
    $custom = [IO.File]::ReadAllText($csw, [Text.Encoding]::UTF8)
    [IO.File]::AppendAllText($sw, "`n`n$custom", [Text.Encoding]::UTF8)
}

Write-Host "Done! Deploy: firebase deploy --only hosting"
