Import-Module au

$URL          = 'https://www.lseg.com/en/data-analytics/products/workspace/download-workspace'
$ChecksumType = 'SHA256'

function global:au_BeforeUpdate {
    $Latest.Checksum32 = Get-RemoteChecksum $Latest.URL32 -Algorithm $Latest.ChecksumType32
}

function global:au_GetLatest {
    if ($global:au_Version) {
        $version = $global:au_Version
        $url     = "https://cdn.refinitiv.com/public/packages/Workspace/RefinitivWorkspace-installer_$version.exe"
    } else {
        $download_page = Invoke-WebRequest $URL -UseBasicParsing
        $exeLink = $download_page.Links |
            Where-Object href -match '\.exe$' |
            Select-Object -First 1 -ExpandProperty href
        if (-not $exeLink) { throw "No .exe link found on $URL — vendor page format may have changed" }

        $url = $exeLink
        $versionMatch = ($url | Select-String '(\d+(?:\.\d+)+)').Matches.Value
        if (-not $versionMatch) { throw "Could not parse version from URL: $url" }
        $version = $versionMatch
    }

    @{
        InstallerType  = 'exe'
        URL32          = $url
        Version        = $version
        ChecksumType32 = $ChecksumType
    }
}

function global:au_SearchReplace {
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(?i)(^\s*FileType\s*=\s*)('.*')"     = "`$1'$($Latest.InstallerType)'"
            "(?i)(^\s*Url\s*=\s*)('.*')"          = "`$1'$($Latest.URL32)'"
            "(?i)(^\s*Checksum\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum32)'"
            "(?i)(^\s*ChecksumType\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    update -ChecksumFor none
}
