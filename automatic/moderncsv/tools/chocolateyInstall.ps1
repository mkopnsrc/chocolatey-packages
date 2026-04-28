$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

# Modern CSV v2.x is 64-bit-only and ships as an Inno Setup .exe.
# The vendor dropped the 32-bit MSI in v2.0; both `url` and `url64bit`
# point at the same x64 installer for chocolatey-side compatibility.
$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    softwareName   = 'Modern CSV*'
    version        = $env:ChocolateyPackageVersion
    unzipLocation  = $toolsDir
    installerType  = 'exe'
    url            = 'https://www.moderncsv.com/release/ModernCSV-Win-v2.4.1.exe'
    url64bit       = 'https://www.moderncsv.com/release/ModernCSV-Win-v2.4.1.exe'
    checksum       = 'c999dd1650d4482419b3dbd395f63c8970fffbc10dd9934cd9ecb5fa7b595858'
    checksumType   = 'SHA256'
    checksum64     = 'c999dd1650d4482419b3dbd395f63c8970fffbc10dd9934cd9ecb5fa7b595858'
    checksumType64 = 'SHA256'
    silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
    validExitCodes = @(0, 3010)
}

$alreadyInstalled = (AlreadyInstalled -AppName $packageArgs['softwareName'] -AppVersion $packageArgs['version'])

if ($alreadyInstalled -and ($env:ChocolateyForce -ne $true)) {
    Write-Output ($packageArgs['softwareName'] + ' is already installed. Use --force to re-install.')
} else {
    Install-ChocolateyPackage @packageArgs
}
