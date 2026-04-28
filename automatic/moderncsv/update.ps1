Import-Module au

$domain       = 'https://www.moderncsv.com'
$releases     = "$domain/download-windows"
$ChecksumType = 'SHA256'

function global:au_BeforeUpdate {
    $Latest.Checksum32 = Get-RemoteChecksum $Latest.URL32 -Algorithm $Latest.ChecksumType32
    $Latest.Checksum64 = Get-RemoteChecksum $Latest.URL64 -Algorithm $Latest.ChecksumType64
}

function global:au_GetLatest {
    if ($global:au_Version) {
        $version = $global:au_Version
    } else {
        # /download-windows 307-redirects to /release/ModernCSV-Win-v<version>.exe.
        # We capture the redirect target without following so we can parse the
        # version out of the filename. The vendor dropped 32-bit and switched
        # from .msi to .exe in v2.x, so we no longer scrape /download/ links.
        try {
            $null = Invoke-WebRequest -Uri $releases -UseBasicParsing -Method Head -MaximumRedirection 0
            throw "Expected a redirect from $releases — vendor URL pattern may have changed"
        } catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $location = [string]$_.Exception.Response.Headers.Location
        }
        $version = ($location | Select-String '\d+(?:\.\d+)+').Matches.Value
        if (-not $version) { throw "Could not parse version from redirect target: $location" }
    }

    $url = "$domain/release/ModernCSV-Win-v$version.exe"
    @{
        URL32          = $url
        URL64          = $url
        Version        = $version
        ChecksumType32 = $ChecksumType
        ChecksumType64 = $ChecksumType
    }
}

function global:au_SearchReplace {
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(?i)(^\s*url\s*=\s*)('.*')"            = "`$1'$($Latest.URL32)'"
            "(?i)(^\s*url64bit\s*=\s*)('.*')"       = "`$1'$($Latest.URL64)'"
            "(?i)(^\s*checksum\s*=\s*)('.*')"       = "`$1'$($Latest.Checksum32)'"
            "(?i)(^\s*checksumType\s*=\s*)('.*')"   = "`$1'$($Latest.ChecksumType32)'"
            "(?i)(^\s*checksum64\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum64)'"
            "(?i)(^\s*checksumType64\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType64)'"
        }
    }
}

update -ChecksumFor none
