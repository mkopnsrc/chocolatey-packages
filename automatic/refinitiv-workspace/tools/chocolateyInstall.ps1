$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

$UserTemp = $env:TEMP
$LogPath  = Join-Path $UserTemp $env:ChocolateyPackageName
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Name $env:ChocolateyPackageName -Path $UserTemp -Force | Out-Null
}

$packageArgs = @{
    PackageName    = $env:ChocolateyPackageName
    SoftwareName   = 'Refinitiv Workspace*'
    Version        = $env:ChocolateyPackageVersion
    FileType       = 'exe'
    Url            = 'https://cdn.refinitiv.com/public/packages/Workspace/RefinitivWorkspace-installer_1.26.602.exe'
    checksum       = '3ed94f04d14868df119b2f50de0397f12e0193b7465e5b06d0d71e85ca63b873'
    checksumType   = 'SHA256'
    SilentArgs     = "--silent --forceInstall --lang=en --machine-autoupdate-no --shortcut-workspace=TRUE --shortcut-excel=FALSE --installerlogpath='$LogPath'"
    validExitCodes = @(
        0,           # success
        3010,        # success, restart required
        2147781575,  # pending restart required
        2147205120   # pending restart required for setup update
    )
}

$alreadyInstalled = (AlreadyInstalled -AppName $packageArgs['softwareName'] -AppVersion $packageArgs['version'])

if ($alreadyInstalled -and ($env:ChocolateyForce -ne $true)) {
    Write-Output ($packageArgs['softwareName'] + ' is already installed. Use --force to re-install.')
} else {
    Install-ChocolateyPackage @packageArgs
}
