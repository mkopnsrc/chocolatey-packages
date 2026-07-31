Import-Module au

# Charles Schwab serves a single, version-less URL for the latest thinkorswim
# Desktop installer. The version is embedded in the PE FileVersion resource
# of the .exe itself — au_GetLatest downloads the installer once, extracts
# the version, and computes the SHA256 from the same temp copy.
$url = 'https://tosmediaserver.schwab.com/installer/InstFiles/thinkorswim_x64_installer.exe'

function global:au_GetLatest {
    if ($global:au_Version) {
        # Manual override (workflow_dispatch force_version=...). We still
        # need the checksum, so we still download.
        $version = $global:au_Version
    }

    $tmp = Join-Path $env:TEMP ("tos_probe_{0}.exe" -f [guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        if (-not $version) {
            $version = (Get-Item $tmp).VersionInfo.FileVersion
            if (-not $version) { throw "Could not read FileVersion from $url" }
        }
        $checksum = (Get-FileHash $tmp -Algorithm SHA256).Hash
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    @{
        URL64          = $url
        Version        = $version
        ChecksumType64 = 'SHA256'
        Checksum64     = $checksum
    }
}

function global:au_SearchReplace {
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(?i)(^\s*url64bit\s*=\s*)('.*')"       = "`$1'$($Latest.URL64)'"
            "(?i)(^\s*checksum64\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum64)'"
            "(?i)(^\s*checksumType64\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType64)'"
        }
    }
}

update -ChecksumFor none -NoCheckUrl
