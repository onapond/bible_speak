param(
    [ValidateSet("development", "production")]
    [string]$Environment = "development"
)

$ErrorActionPreference = "Stop"
$branch = (git branch --show-current).Trim()

if ($Environment -eq "development") {
    if ($branch -eq "master") { throw "Development builds are blocked on master." }
    $projectId = "bible-speak-dev"
} else {
    if ($branch -ne "master") { throw "Production builds are allowed only on master." }
    $projectId = "bible-speak"
}

$apiUrl = if ($env:API_BASE_URL) {
    $env:API_BASE_URL
} else {
    "https://asia-northeast3-$projectId.cloudfunctions.net"
}

$buildId = Get-Date -Format "yyyyMMddHHmmss"
$commitSha = (git rev-parse HEAD).Trim()

flutter build web --release `
    --dart-define="APP_ENV=$Environment" `
    --dart-define="API_BASE_URL=$apiUrl"

$metadata = @{
    environment = $Environment
    projectId = $projectId
    commit = $commitSha
    buildId = $buildId
} | ConvertTo-Json
[IO.File]::WriteAllText("build/web/environment.json", $metadata, [Text.Encoding]::UTF8)

Write-Host "Built web environment=$Environment project=$projectId commit=$commitSha"
