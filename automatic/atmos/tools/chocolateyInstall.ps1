$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# atmos.exe is a single-binary CLI. Download into the package's tools directory;
# chocolatey auto-shims any .exe in tools/ for PATH resolution.
$packageArgs = @{
    packageName  = $env:ChocolateyPackageName
    fileFullPath = Join-Path $toolsDir 'atmos.exe'
    url          = 'https://github.com/cloudposse/atmos/releases/download/v1.216.0/atmos_1.216.0_windows_amd64.exe'
    checksum     = '01f55a1522044ad6a50ac6038c9889c4f2ae49db847d2df3a54ffe84485fe43e'
    checksumType = 'SHA256'
}
Get-ChocolateyWebFile @packageArgs
