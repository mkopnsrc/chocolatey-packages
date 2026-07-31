Import-Module au

# Fluent Bit publishes Windows binaries at https://packages.fluentbit.io/windows/
# alongside a version-in-URL scheme. The docs page names the current version.
# We scrape that page for the version, download the win64 .msi at build time,
# embed it inside tools\, and record its SHA256 in VERIFICATION.txt.
$docsPage = 'https://docs.fluentbit.io/manual/installation/downloads/windows'
$cdnBase  = 'https://packages.fluentbit.io/windows'
$licenseUrl = 'https://raw.githubusercontent.com/fluent/fluent-bit/master/LICENSE'

function global:au_GetLatest {
    if ($global:au_Version) {
        $version = $global:au_Version
    } else {
        $page = Invoke-WebRequest -Uri $docsPage -UseBasicParsing
        $m = [regex]::Match($page.Content, 'fluent-bit-(\d+\.\d+\.\d+)-win64\.msi')
        if (-not $m.Success) { throw "Could not locate a win64 MSI version on $docsPage" }
        $version = $m.Groups[1].Value
    }

    $msiFilename = "fluent-bit-$version-win64.msi"
    $url         = "$cdnBase/$msiFilename"

    # Fail loudly if the CDN doesn't actually have this version's binary yet
    # (vendor sometimes tags a version on GitHub before publishing binaries).
    try {
        $head = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
        if ($head.StatusCode -ne 200) { throw "HEAD $url returned $($head.StatusCode)" }
    } catch {
        throw "Vendor CDN does not yet serve $msiFilename — skipping this cycle. $_"
    }

    @{
        URL64        = $url
        Version      = $version
        MsiFilename  = $msiFilename
    }
}

function global:au_BeforeUpdate {
    $toolsDir = Join-Path $PSScriptRoot 'tools'
    if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }

    # Purge any prior MSI so we don't ship two.
    Get-ChildItem -Path $toolsDir -Filter 'fluent-bit-*-win64.msi' -ErrorAction SilentlyContinue |
        Remove-Item -Force

    $msiPath = Join-Path $toolsDir $Latest.MsiFilename
    Write-Host "Downloading $($Latest.URL64) -> $msiPath"
    Invoke-WebRequest -Uri $Latest.URL64 -OutFile $msiPath -UseBasicParsing

    $sha = (Get-FileHash -Path $msiPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $Latest.Checksum64 = $sha
    Write-Host "SHA256($($Latest.MsiFilename)) = $sha"

    # Refresh Apache 2.0 license text bundled with the package.
    $licensePath = Join-Path $toolsDir 'LICENSE.txt'
    Invoke-WebRequest -Uri $licenseUrl -OutFile $licensePath -UseBasicParsing

    # Regenerate VERIFICATION.txt with the fresh URL + SHA so it always matches
    # the currently-embedded MSI.
    $verification = @"
VERIFICATION
Verification is intended to assist reviewers in confirming that this
package's embedded binary is trustworthy.

The MSI shipped inside this package's tools\ directory was downloaded at
build time directly from the Fluent Bit project's official CDN:

  Upstream MSI URL:
    $($Latest.URL64)

  Vendor:         Chronosphere Inc. (Author field of the MSI)
  Vendor page:    https://docs.fluentbit.io/manual/installation/downloads/windows
  Installer tech: Windows Installer XML (WiX) Toolset

  SHA256 (win64 MSI, embedded at pack time):
    $sha

To reproduce the SHA256 locally:

  PowerShell:
    `$u = '$($Latest.URL64)'
    `$t = Join-Path `$env:TEMP 'fluent-bit.msi'
    Invoke-WebRequest -Uri `$u -OutFile `$t -UseBasicParsing
    Get-FileHash `$t -Algorithm SHA256

  Linux/macOS:
    curl -sLO '$($Latest.URL64)'
    sha256sum $($Latest.MsiFilename)

Note: the vendor does not publish an official .sha256 sidecar for the
.msi variant (only for the .exe variant). The hash above was computed
locally against the MSI as served by the CDN at package build time.

License: Apache License 2.0 (see LICENSE.txt bundled in this package
and the canonical text at https://github.com/fluent/fluent-bit/blob/master/LICENSE).
"@
    $verification | Set-Content -Path (Join-Path $toolsDir 'VERIFICATION.txt') -Encoding UTF8
}

function global:au_SearchReplace {
    # Nuspec version is auto-updated by AU. Nothing to rewrite in install/uninstall
    # scripts because they globbing-discover the MSI (`fluent-bit-*-win64.msi`).
    @{}
}

update -ChecksumFor none -NoCheckUrl -NoCheckChocoVersion
