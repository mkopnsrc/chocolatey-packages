$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

$packageArgs = @{
	packageName     = $env:ChocolateyPackageName
	softwareName    = "Beats $($env:ChocolateyPackageName)*"
  version         = $env:ChocolateyPackageVersion
	unzipLocation   = $toolsDir
	installerType   = 'msi'
	url             = 'https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-oss-9.3.1-windows-x86_64.msi'
	url64bit        = 'https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-oss-9.3.1-windows-x86_64.msi'
	checksum        = 'd1d526b90882c3df6fc6e6cdf3baa23e58eaf068673fbeb0fde30700aea19585'
	checksumType    = 'SHA256'
	checksum64      = 'd1d526b90882c3df6fc6e6cdf3baa23e58eaf068673fbeb0fde30700aea19585'
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
  ###################### Metricbeat Configuration ########################
  Metricbeat Config File Location: 
    
    $env:programdata\Elastic\Beats\metricbeat\metricbeat.yml
    
    You can find the full configuration reference here:
    https://www.elastic.co/guide/en/beats/metricbeat/current/index.html
  ###################### ######################## ########################
  "
}
