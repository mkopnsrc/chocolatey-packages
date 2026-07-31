Import-Module au

# Fluent Bit publishes Windows binaries at https://packages.fluentbit.io/windows/
# alongside a version-in-URL scheme. The docs page names the current version.
#
# Design: we sync the embedded MSI (download + refresh VERIFICATION/LICENSE)
# BEFORE calling AU's `update`, because AU short-circuits `au_BeforeUpdate`
# when nuspec version already matches remote — and we still want the binary
# present in tools\ every time the workflow runs (fresh runner starts empty).

$docsPage    = 'https://docs.fluentbit.io/manual/installation/downloads/windows'
$cdnBase     = 'https://packages.fluentbit.io/windows'
$licenseUrl  = 'https://raw.githubusercontent.com/fluent/fluent-bit/master/LICENSE'

function Get-FluentBitVersion {
    if ($global:au_Version) { return $global:au_Version }
    $page = Invoke-WebRequest -Uri $docsPage -UseBasicParsing
    $m = [regex]::Match($page.Content, 'fluent-bit-(\d+\.\d+\.\d+)-win64\.msi')
    if (-not $m.Success) { throw "Could not locate a win64 MSI version on $docsPage" }
    return $m.Groups[1].Value
}

# --- Sync embedded binary + auxiliary files (always runs) -------------------

$version     = Get-FluentBitVersion
$msiFilename = "fluent-bit-$version-win64.msi"
$msiUrl      = "$cdnBase/$msiFilename"

$toolsDir = Join-Path $PSScriptRoot 'tools'
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }

# Purge any stale MSI(s) from a prior version.
Get-ChildItem -Path $toolsDir -Filter 'fluent-bit-*-win64.msi' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne $msiFilename } |
    Remove-Item -Force

$msiPath = Join-Path $toolsDir $msiFilename
Write-Host "Downloading $msiUrl -> $msiPath"
Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing

$sha = (Get-FileHash -Path $msiPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "SHA256($msiFilename) = $sha"

# Refresh Apache 2.0 license bundled with the package.
Invoke-WebRequest -Uri $licenseUrl -OutFile (Join-Path $toolsDir 'LICENSE.txt') -UseBasicParsing

# Regenerate VERIFICATION.txt so the recorded SHA always matches the embedded MSI.
$verification = @"
VERIFICATION
Verification is intended to assist reviewers in confirming that this
package's embedded binary is trustworthy.

The MSI shipped inside this package's tools\ directory was downloaded at
build time directly from the Fluent Bit project's official CDN:

  Upstream MSI URL:
    $msiUrl

  Vendor:         Chronosphere Inc. (Author field of the MSI)
  Vendor page:    https://docs.fluentbit.io/manual/installation/downloads/windows
  Installer tech: Windows Installer XML (WiX) Toolset

  SHA256 (win64 MSI, embedded at pack time):
    $sha

To reproduce the SHA256 locally:

  PowerShell:
    `$u = '$msiUrl'
    `$t = Join-Path `$env:TEMP 'fluent-bit.msi'
    Invoke-WebRequest -Uri `$u -OutFile `$t -UseBasicParsing
    Get-FileHash `$t -Algorithm SHA256

  Linux/macOS:
    curl -sLO '$msiUrl'
    sha256sum $msiFilename

Note: the vendor does not publish an official .sha256 sidecar for the
.msi variant (only for the .exe variant). The hash above was computed
locally against the MSI as served by the CDN at package build time.

License: Apache License 2.0 (see LICENSE.txt bundled in this package
and the canonical text at https://github.com/fluent/fluent-bit/blob/master/LICENSE).
"@
Set-Content -Path (Join-Path $toolsDir 'VERIFICATION.txt') -Value $verification -Encoding UTF8

# --- AU version bump for the nuspec ----------------------------------------

function global:au_GetLatest {
    @{
        Version = $version
        URL64   = $msiUrl
    }
}

function global:au_SearchReplace {
    # No install-script edits needed — chocolateyInstall.ps1 glob-discovers
    # the MSI. AU handles the nuspec version bump automatically.
    @{}
}

update -ChecksumFor none -NoCheckUrl -NoCheckChocoVersion
