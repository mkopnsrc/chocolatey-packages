$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Skip if the same product is already installed system-wide, unless the user
# explicitly passed --force. Chocolatey sets $env:ChocolateyForce='true' when
# --force is on the CLI.
$existing = Get-UninstallRegistryKey -SoftwareName 'thinkorswim*'
if ($existing -and ($env:ChocolateyForce -ne 'true')) {
    $displayVersion = ($existing | Select-Object -First 1).DisplayVersion
    Write-Host "thinkorswim $displayVersion is already installed (registry). Pass --force to re-install."
    return
}

# Build the install4j silent argument string. Defaults to '-q -overwrite';
# users can override the install directory via --params "/install-dir=<path>".
$silentArgs = '-q -overwrite'
$pp = Get-PackageParameters
if ($pp.ContainsKey('install-dir') -and $pp['install-dir']) {
    $silentArgs += ' -dir "{0}"' -f $pp['install-dir']
}

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    fileType       = 'EXE'
    url64bit       = 'https://tosmediaserver.schwab.com/installer/InstFiles/thinkorswim_x64_installer.exe'
    checksum64     = 'b562cf009d680a2d25a9129cfc1fc2784999521342d690d6cab3d9bfcce2a674'
    checksumType64 = 'SHA256'
    softwareName   = 'thinkorswim*'
    silentArgs     = $silentArgs
    validExitCodes = @(0)
}
Install-ChocolateyPackage @packageArgs
