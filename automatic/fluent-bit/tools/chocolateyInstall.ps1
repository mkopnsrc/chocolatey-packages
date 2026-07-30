$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$msi = Get-ChildItem -Path $toolsDir -Filter 'fluent-bit-*-win64.msi' | Select-Object -First 1
if (-not $msi) { throw "No embedded fluent-bit MSI found under $toolsDir. Package is malformed." }

$silentArgs = '/quiet /norestart'
$pp = Get-PackageParameters
if ($pp.ContainsKey('install-dir') -and $pp['install-dir']) {
    $silentArgs += ' INSTALLDIR="{0}"' -f $pp['install-dir']
}

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    fileType       = 'MSI'
    file           = $msi.FullName
    softwareName   = 'fluent-bit*'
    silentArgs     = $silentArgs
    validExitCodes = @(0, 1641, 3010)
}
Install-ChocolateyInstallPackage @packageArgs
