# Check the official Codex Bridge stable release and update a Scoop manifest.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'bucket/codex-bridge.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'codex-bridge-scoop-updater'
}
if ($env:GITHUB_TOKEN) {
    $headers.Authorization = "Bearer $env:GITHUB_TOKEN"
}

$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Fanch-hui/codex-bridge/releases/latest' -Headers $headers
if ($release.draft -or $release.prerelease) {
    throw 'Latest release is not stable; refusing to update.'
}
if ($release.tag_name -notmatch '^v(\d+\.\d+\.\d+)$') {
    throw "Unexpected release tag: $($release.tag_name)"
}
$latestVersion = $Matches[1]
$currentVersion = [string]$manifest.version
if ([version]$latestVersion -lt [version]$currentVersion) {
    Write-Host "Upstream version $latestVersion is older than $currentVersion. No downgrade."
    exit 0
}

$changed = ($latestVersion -ne $currentVersion)
$targets = @{ '64bit' = 'x64'; 'arm64' = 'arm64' }
foreach ($arch in $targets.Keys) {
    $suffix = $targets[$arch]
    $assetName = "codex-bridge-windows-$suffix.zip"
    $assets = @($release.assets | Where-Object { $_.name -eq $assetName })
    if ($assets.Count -ne 1) {
        throw "Missing or duplicate official asset: $assetName"
    }
    $asset = $assets[0]
    $expectedUrl = "https://github.com/Fanch-hui/codex-bridge/releases/download/v$latestVersion/$assetName"
    if ($asset.browser_download_url -ne $expectedUrl) {
        throw "Unexpected official asset URL: $assetName"
    }
    if ($asset.digest -notmatch '^sha256:([0-9a-f]{64})$') {
        throw "Missing SHA256 digest in official release: $assetName"
    }
    $newHash = $Matches[1]

    $entry = $manifest.architecture.PSObject.Properties[$arch].Value
    $auto = $manifest.autoupdate.architecture.PSObject.Properties[$arch].Value
    if ($null -eq $entry -or $null -eq $auto) {
        throw "Missing manifest architecture: $arch"
    }
    $templateUrl = "https://github.com/Fanch-hui/codex-bridge/releases/download/v" + '$version' + "/$assetName"
    if ($entry.url -ne $templateUrl -or $auto.url -ne $templateUrl) {
        throw "Unexpected download URL template for $arch"
    }
    if ($entry.hash -ne $newHash) {
        $entry.hash = $newHash
        $changed = $true
    }
}

if (-not $changed) {
    Write-Host "Codex Bridge $currentVersion is current; official SHA256 digests match."
    exit 0
}

$manifest.version = $latestVersion
$json = $manifest | ConvertTo-Json -Depth 20
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($manifestPath, ($json.TrimEnd() + "`n"), $utf8NoBom)
Write-Host "Updated Codex Bridge manifest: $currentVersion -> $latestVersion"
