$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

$packageArgs = @{
    packageName     = $env:ChocolateyPackageName
    softwareName    = 'MeshCommander*'
    version         = $env:ChocolateyPackageVersion
    unzipLocation   = $toolsDir
    installerType   = 'msi'
    url             = 'https://www.meshcommander.com/Releases/MeshCommander-0.9.7.msi'
    checksum        = 'ad8ddf812eaa3532ce3a63651cab0c8110d071412c366b3491c9ecd2d03adfb4'
    checksumType    = 'SHA256'
    silentArgs      = '/qn /norestart'
    validExitCodes  = @(
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
