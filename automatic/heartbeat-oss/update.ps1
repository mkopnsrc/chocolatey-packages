Import-Module au

$releases = 'https://www.elastic.co/downloads/beats/heartbeat-oss'
$ChecksumType = 'SHA256'
function global:au_BeforeUpdate {
    $Latest.Checksum32 = Get-RemoteChecksum $Latest.URL32 -Algorithm $Latest.ChecksumType32
    $Latest.Checksum64 = Get-RemoteChecksum $Latest.URL64 -Algorithm $Latest.ChecksumType64

    #AU function Get-RemoteFiles can download files and save them in the package's tools directory. It does that by using the $Latest.URL32 and/or $Latest.URL64.
    #Get-RemoteFiles -Purge
}
function global:au_GetLatest() {
    if ($global:au_Version) {
        $version = $global:au_Version
    } else {
        $download_page = Invoke-WebRequest $releases
        $parsedHtml = ConvertFrom-Html -Content $download_page.RawContent
        $version = (($parsedHtml.SelectNodes('//p') | ? { $_.InnerText -match 'Version:'}).InnerText | Select-String '\d+(?:\.\d+)+').Matches.Value
    }

    $url   = "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-$($version)-windows-x86_64.msi"
    $url64 = "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-$($version)-windows-x86_64.msi"
    
    $Latest = @{
        URL32     = $url
        URL64     = $url64
        Version   = $version
        ChecksumType32 = $ChecksumType
        ChecksumType64 = $ChecksumType
    }
    return $Latest
}
function global:au_SearchReplace {
    @{
      ".\tools\chocolateyInstall.ps1" = @{
        "(?i)(^\s*url\s*=\s*)('.*')" = "`$1'$($Latest.URL32)'"
        "(?i)(^\s*url64bit\s*=\s*)('.*')" = "`$1'$($Latest.URL64)'"
        "(?i)(^\s*checksum\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"
        "(?i)(^\s*checksumType\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
        "(?i)(^\s*checksum64\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
        "(?i)(^\s*checksumType64\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType64)'"
      };

      "$($Latest.PackageName).nuspec" = @{
        "(<licenseUrl.*?)(\d+\.\d+)(.*?licenseUrl>)"    = "`${1}$([regex]::match($Latest.Version, "\d+\.\d+").Value)`${3}"
        "(<releaseNotes.*?)(\d+\.\d+)(.*?releaseNotes>)"    = "`${1}$([regex]::match($Latest.Version, "\d+\.\d+").Value)`${3}"
      };
    }
}
update -ChecksumFor none #-NoCheckChocoVersion