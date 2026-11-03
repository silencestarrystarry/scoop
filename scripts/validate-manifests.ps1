# Validate all Starry Scoop manifests against official release metadata.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'starry-scoop-validation' }
if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }

foreach ($script in (Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' -File)) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw "PowerShell parser error in $($script.Name): $($errors -join '; ')" }
}

$packages = @(
    @{
        name = 'codex-bridge'
        upstream = 'Fanch-hui/codex-bridge'
        checkver = 'https://github.com/Fanch-hui/codex-bridge'
        license = 'Apache-2.0'
        suffix = ''
        arches = @{ '64bit' = 'x64'; 'arm64' = 'arm64' }
    },
    @{
        name = 'sing-box-desktop'
        upstream = 'SagerNet/sing-box'
        checkver = 'https://github.com/SagerNet/sing-box'
        license = 'GPL-3.0-or-later'
        suffix = '#/setup.exe'
        arches = @{ '64bit' = 'x64'; '32bit' = 'x86'; 'arm64' = 'arm64' }
    }
)

foreach ($package in $packages) {
    $path = Join-Path $repoRoot ("bucket/" + $package.name + '.json')
    if (!(Test-Path -LiteralPath $path)) { throw "Missing manifest: $path" }
    $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $version = [string]$manifest.version
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid version: $($package.name) $version" }
    if ($manifest.license -ne $package.license) { throw "Unexpected license: $($package.name)" }
    if ($manifest.checkver.github -ne $package.checkver) { throw "Incorrect checkver: $($package.name)" }
    $releaseUrl = "https://api.github.com/repos/$($package.upstream)/releases/tags/v$version"
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
    if ($release.draft -or $release.prerelease) { throw "Not a stable release: $($package.name)" }
    foreach ($arch in $package.arches.Keys) {
        $target = $package.arches[$arch]
        if ($package.name -eq 'codex-bridge') { $assetName = "codex-bridge-windows-$target.zip" }
        else { $assetName = "SFW-$version-$target.exe" }
        $entry = $manifest.architecture.PSObject.Properties[$arch].Value
        $auto = $manifest.autoupdate.architecture.PSObject.Properties[$arch].Value
        if ($null -eq $entry -or $null -eq $auto) { throw "Missing architecture ${arch}: $($package.name)" }
        if ($entry.url -ne $auto.url) { throw "Autoupdate URL mismatch for ${arch}: $($package.name)" }
        $actualUrl = $entry.url.Replace('$version', $version)
        $expectedUrl = "https://github.com/$($package.upstream)/releases/download/v$version/$assetName$($package.suffix)"
        if ($actualUrl -ne $expectedUrl) { throw "Unexpected $arch URL: $actualUrl" }
        $assets = @($release.assets | Where-Object { $_.name -eq $assetName })
        if ($assets.Count -ne 1) { throw "Missing official release asset: $assetName" }
        if ($entry.hash -notmatch '^[0-9a-f]{64}$' -or $assets[0].digest -ne "sha256:$($entry.hash)") {
            throw "SHA256 mismatch for $($package.name) $arch"
        }
        Write-Host "Validated $($package.name) $version [$arch]"
    }
    if ($package.name -eq 'codex-bridge') {
        if ($manifest.shortcuts[0][0] -ne 'codex-bridge-windows-app.exe') { throw 'Wrong Codex Bridge executable' }
    } else {
        if (!$manifest.installer.script -or !$manifest.uninstaller.script) { throw 'SFW nonportable installer/uninstaller missing' }
    }
}
Write-Host 'Both Starry Scoop manifests validated against official GitHub release metadata.'
