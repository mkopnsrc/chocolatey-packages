$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# crank.exe is a single-binary CLI. Download into the package's tools directory;
# chocolatey auto-shims any .exe in tools/ for PATH resolution.
$packageArgs = @{
    packageName  = $env:ChocolateyPackageName
    fileFullPath = Join-Path $toolsDir 'crank.exe'
    url          = 'https://releases.crossplane.io/stable/v2.2.1/bin/windows_amd64/crank.exe'
    checksum     = 'dd33976f4f32f10792018d0964a8ee64b58e7f966d90947fa2e61bf7dd707da9'
    checksumType = 'SHA256'
}
Get-ChocolateyWebFile @packageArgs
