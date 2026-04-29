Import-Module au

$githubRepo   = 'crossplane/crossplane'
$ChecksumType = 'SHA256'

function global:au_BeforeUpdate {
    $Latest.Checksum32 = Get-RemoteChecksum $Latest.URL32 -Algorithm $Latest.ChecksumType32
}

function global:au_GetLatest {
    if ($global:au_Version) {
        $version = $global:au_Version
    } else {
        $api = Invoke-RestMethod -Uri "https://api.github.com/repos/$githubRepo/releases/latest" -UseBasicParsing
        $version = $api.tag_name -replace '^v', ''
    }

    # Crossplane CLI ('crank') ships from releases.crossplane.io rather than
    # GitHub release assets. The versioned URL pattern:
    $url = "https://releases.crossplane.io/stable/v$version/bin/windows_amd64/crank.exe"

    @{
        URL32          = $url
        Version        = $version
        ChecksumType32 = $ChecksumType
    }
}

function global:au_SearchReplace {
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(?i)(^\s*url\s*=\s*)('.*')"          = "`$1'$($Latest.URL32)'"
            "(?i)(^\s*checksum\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum32)'"
            "(?i)(^\s*checksumType\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
        }
    }
}

update -ChecksumFor none
