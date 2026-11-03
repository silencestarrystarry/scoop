# Update Codex Bridge Scoop manifest from the upstream stable release.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'bucket/codex-bridge.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'starry-scoop-updater'
}
if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }

$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Fanch-hui/codex-bridge/releases/latest' -Headers $headers
if ($release.draft -or $release.prerelease) { throw 'Latest Codex Bridge release is not stable.' }
$tagMatch = [regex]::Match([string]$release.tag_name, '^v(\d+\.\d+\.\d+)$')
if (-not $tagMatch.Success) { throw "Unexpected release tag: $($release.tag_name)" }
$latestVersion = $tagMatch.Groups[1].Value
$currentVersion = [string]$manifest.version
if ([version]$latestVersion -lt [version]$currentVersion) {
    Write-Host "Codex Bridge $latestVersion older than current $currentVersion; skipping downgrade."
    exit 0
}

$changed = ($latestVersion -ne $currentVersion)
$targets = @{ '64bit' = 'x64'; 'arm64' = 'arm64' }
foreach ($arch in $targets.Keys) {
    $suffix = $targets[$arch]
    $assetName = "codex-bridge-windows-$suffix.zip"
    $assets = @($release.assets | Where-Object { $_.name -eq $assetName })
    if ($assets.Count -ne 1) { throw "Missing or duplicate release asset: $assetName" }
    $asset = $assets[0]
    $expectedUrl = "https://github.com/Fanch-hui/codex-bridge/releases/download/v$latestVersion/$assetName"
    if ($asset.browser_download_url -ne $expectedUrl) { throw "Unexpected asset URL: $assetName" }
    $digestMatch = [regex]::Match([string]$asset.digest, '^sha256:([0-9a-f]{64})$')
    if (-not $digestMatch.Success) { throw "Missing official SHA256 for $assetName" }
    $newHash = $digestMatch.Groups[1].Value
    $entry = $manifest.architecture.PSObject.Properties[$arch].Value
    $auto = $manifest.autoupdate.architecture.PSObject.Properties[$arch].Value
    if ($null -eq $entry -or $null -eq $auto) { throw "Missing architecture in manifest: $arch" }
    $templateUrl = 'https://github.com/Fanch-hui/codex-bridge/releases/download/v$version/' + $assetName
    if ($entry.url -ne $templateUrl -or $auto.url -ne $templateUrl) {
        throw "Unexpected URL template for $arch"
    }
    if ($entry.hash -ne $newHash) { $entry.hash = $newHash; $changed = $true }
}

if (-not $changed) {
    Write-Host "Codex Bridge $currentVersion is current; both official SHA256 digests match."
    exit 0
}
$manifest.version = $latestVersion
$json = $manifest | ConvertTo-Json -Depth 20
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($manifestPath, ($json.TrimEnd() + "`n"), $utf8NoBom)
Write-Host "Updated Codex Bridge manifest: $currentVersion -> $latestVersion"
