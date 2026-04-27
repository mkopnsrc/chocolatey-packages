Import-Module au

$domain       = 'https://www.meshcommander.com'
$releases     = "$domain/"
$ChecksumType = 'SHA256'

function global:au_BeforeUpdate {
    $Latest.Checksum32 = Get-RemoteChecksum $Latest.URL32 -Algorithm $Latest.ChecksumType32
}

function global:au_GetLatest() {
    $download_page = Invoke-WebRequest $releases -UseBasicParsing
    $href = $download_page.Links |
        Where-Object href -match 'Releases/MeshCommander-\d+(?:\.\d+)+\.msi$' |
        Select-Object -First 1 -ExpandProperty href
    if (-not $href) { throw "No MeshCommander MSI link found on $releases" }

    $url     = "$domain/$($href.TrimStart('/'))"
    $version = ($href | Select-String '\d+(?:\.\d+)+').Matches.Value

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
