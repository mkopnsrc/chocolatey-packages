$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

$packageArgs = @{
	packageName     = $env:ChocolateyPackageName
	softwareName    = 'MeshCommander*'
  version         = $env:ChocolateyPackageVersion
	unzipLocation   = $toolsDir
	installerType   = 'msi'
	url             = 'https://info.meshcentral.com/downloads/mdtk/MeshCommander.msi'
	#url64bit        = ''
	checksum        = 'E284FA77A20B57D62A998078142EECD9F2C985BEFE32B948BD69E2D355ECF9E1'
	checksumType    = 'SHA256'
	#checksum64      = ''
	#checksumType64  = 'SHA256'
	silentArgs      = '/qn /norestart ADDLOCAL="MeshCommanderConsoleSccmExt"'
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

}
