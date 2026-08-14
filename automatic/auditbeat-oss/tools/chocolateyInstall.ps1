$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

$packageArgs = @{
    packageName     = $env:ChocolateyPackageName
    softwareName    = 'Beats auditbeat-oss*'
    version         = $env:ChocolateyPackageVersion
    unzipLocation   = $toolsDir
    installerType   = 'msi'
    url             = 'https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-oss-9.3.3-windows-x86_64.msi'
    url64bit        = 'https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-oss-9.3.3-windows-x86_64.msi'
    checksum        = '59ab039991e4a9482a611f40f0c1543c18cd96a3fc8dd3c12df81713b3e6cb63'
    checksumType    = 'SHA256'
    checksum64      = '59ab039991e4a9482a611f40f0c1543c18cd96a3fc8dd3c12df81713b3e6cb63'
    checksumType64  = 'SHA256'
    silentArgs      = "/qn /norestart"
    #Exit codes for ms http://msdn.microsoft.com/en-us/library/aa368542(VS.85).aspx
    validExitCodes = @(
        0,           # success
        3010,        # success, restart required
        2147781575,  # pending restart required
        2147205120   # pending restart required for setup update
    )
}

$alreadyInstalled = (AlreadyInstalled -AppName $packageArgs['softwareName'] -AppVersion $packageArgs['version'])

if ($alreadyInstalled -and ($env:ChocolateyForce -ne $true)) {
    Write-Output ($packageArgs['softwareName'] + " is already installed. Use --force to re-install.")
} else {
    Install-ChocolateyPackage @packageArgs

    Write-Output "
    ###################### Auditbeat Configuration ########################
      Auditbeat Config File Location:

      $env:programdata\Elastic\Beats\auditbeat\auditbeat.yml

      You can find the full configuration reference here:
      https://www.elastic.co/guide/en/beats/auditbeat/index.html
    ###################### ######################## ########################
    "
}
