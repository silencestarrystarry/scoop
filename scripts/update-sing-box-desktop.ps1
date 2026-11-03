# Update the sing-box for Desktop nonportable Scoop manifest from official stable release metadata.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'bucket/sing-box-desktop.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'starry-scoop-updater' }
if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/SagerNet/sing-box/releases/latest' -Headers $headers
if ($release.draft -or $release.prerelease) { throw 'Latest sing-box release is not stable.' }
$tagMatch = [regex]::Match([string]$release.tag_name, '^v(\d+\.\d+\.\d+)$')
if (-not $tagMatch.Success) { throw "Unexpected release tag: $($release.tag_name)" }
$latestVersion = $tagMatch.Groups[1].Value
$currentVersion = [string]$manifest.version
if ([version]$latestVersion -lt [version]$currentVersion) {
    Write-Host "sing-box $latestVersion older than current $currentVersion; skipping downgrade."
    exit 0
}
$changed = ($latestVersion -ne $currentVersion)
$architectures = @{ '64bit' = 'x64'; '32bit' = 'x86'; 'arm64' = 'arm64' }
foreach ($arch in $architectures.Keys) {
    $suffix = $architectures[$arch]
    $assetName = "SFW-$latestVersion-$suffix.exe"
    $assets = @($release.assets | Where-Object { $_.name -eq $assetName })
    if ($assets.Count -ne 1) { throw "Missing or duplicate SFW release asset: $assetName" }
    $asset = $assets[0]
    $expectedUrl = "https://github.com/SagerNet/sing-box/releases/download/v$latestVersion/$assetName"
    if ($asset.browser_download_url -ne $expectedUrl) { throw "Unexpected SFW asset URL: $assetName" }
    $digestMatch = [regex]::Match([string]$asset.digest, '^sha256:([0-9a-f]{64})$')
    if (-not $digestMatch.Success) { throw "Missing official SHA256 for $assetName" }
    $newHash = $digestMatch.Groups[1].Value
    $entry = $manifest.architecture.PSObject.Properties[$arch].Value
    $auto = $manifest.autoupdate.architecture.PSObject.Properties[$arch].Value
    if ($null -eq $entry -or $null -eq $auto) { throw "Missing architecture in manifest: $arch" }
    $templateUrl = 'https://github.com/SagerNet/sing-box/releases/download/v$version/SFW-$version-' + $suffix + '.exe#/setup.exe'
    if ($auto.url -ne $templateUrl) { throw "Unexpected autoupdate template for $arch" }
    $oldUrl = $templateUrl.Replace('$version', $currentVersion)
    if ($entry.url -ne $oldUrl) { throw "Unexpected active download URL for $arch" }
    $newUrl = $templateUrl.Replace('$version', $latestVersion)
    if ($entry.url -ne $newUrl) { $entry.url = $newUrl; $changed = $true }
    if ($entry.hash -ne $newHash) { $entry.hash = $newHash; $changed = $true }
}
if (-not $changed) {
    Write-Host "sing-box for Desktop $currentVersion is current; official SHA256 digests match."
    exit 0
}
$manifest.version = $latestVersion
$json = $manifest | ConvertTo-Json -Depth 20
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($manifestPath, ($json.TrimEnd() + "`n"), $utf8NoBom)
Write-Host "Updated sing-box for Desktop manifest: $currentVersion -> $latestVersion"
