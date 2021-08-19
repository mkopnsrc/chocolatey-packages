﻿$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

$packageArgs = @{
	packageName     = $env:ChocolateyPackageName
	softwareName    = "Beats $($env:ChocolateyPackageName)*"
  version         = $env:ChocolateyPackageVersion
	unzipLocation   = $toolsDir
	installerType   = 'msi'
	url             = 'https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-7.14.0-windows-x86.msi'
	url64bit        = 'https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-7.14.0-windows-x86_64.msi'
	checksum        = 'edab4249d88580016ea9b5a8b77a28de3ab5f3dd0c315b1921a0d3e79cab066b'
	checksumType    = 'SHA256'
	checksum64      = '7166051fae03699764a6be0e4be8ab1b0ad1451406e77cd8227ef484babb0bcb'
	checksumType64  = 'SHA256'
	silentArgs      = "/qn /norestart"
	#Exit codes for ms http://msdn.microsoft.com/en-us/library/aa368542(VS.85).aspx
  validExitCodes = @(
    0, # success
    3010, # success, restart required
    2147781575, # pending restart required
    2147205120  # pending restart required for setup update
  )
}

$alreadyInstalled = (AlreadyInstalled -AppName $packageArgs['softwareName'] -AppVersion $packageArgs['version'])

if ($alreadyInstalled -and ($env:ChocolateyForce -ne $true)) {
  Write-Output $(
    $packageArgs['softwareName']+" is already installed. " +
    'if you want to re-install, use "--force" option to re-install.'
  )
} else {
	Install-ChocolateyPackage @packageArgs
  
  Write-Output "
  ###################### Heartbeat Configuration ########################
  Heartbeat Config File Location: 
    
    $env:programdata\Elastic\Beats\heartbeat\heartbeat.yml
    
    You can find the full configuration reference here:
    https://www.elastic.co/guide/en/beats/heartbeat/current/index.html
  ###################### ######################## ########################
  "
}