$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

# ---------------------------------------------------------------------------
# Install mode selection
#
# Default: --machine-autoupdate-no (system-wide install to %ProgramFiles%,
# no Refinitiv auto-updater). This matches typical IT mass-deployment
# expectations — chocolatey runs Install-ChocolateyPackage as Administrator
# via Start-ChocolateyProcessAsAdmin, so a system-wide install is the
# correct fit (a --user install would land in the admin's %LocalAppData%,
# not the calling user's profile, which is wrong for chocolatey's model).
#
# Users can override via /install-mode=<mode>:
#   user, user-no-update, machine, machine-autoupdate-no, machine-service
#
# Valid modes verified via the installer's app.asar argv-key extraction.
# (Note: VDI mode in the installer is triggered only by --isContinue, not
# by VM auto-detection, so the System Test skip via --forceInstall works
# in all default paths.)
# ---------------------------------------------------------------------------
$pp = Get-PackageParameters

$installModeOverride = $null
foreach ($k in 'install-mode','installmode','InstallMode') {
    if ($pp.ContainsKey($k) -and $pp[$k]) { $installModeOverride = $pp[$k]; break }
}

$validInstallModes = @('user','user-no-update','machine','machine-autoupdate-no','machine-service')
if ($installModeOverride -and $validInstallModes -notcontains $installModeOverride) {
    throw "Invalid /install-mode='$installModeOverride'. Valid values: $($validInstallModes -join ', ')"
}
$installMode = if ($installModeOverride) { $installModeOverride } else { 'machine-autoupdate-no' }

Write-Host "Install mode: --$installMode"

# ---------------------------------------------------------------------------
# Other user-supplied package parameters
#
#   /include-excel               — opt in to Refinitiv Excel addin
#   /include-chrome-extension    — opt in to Chrome native messaging host
#   /client-sso=<URL>            — pre-configure Single Sign-On endpoint
#                                   (LSEG Installation Guide, Appendix C)
#   /install-mode=<mode>         — override default install mode
#
# Parameter keys accept both kebab-case and PascalCase forms.
# ---------------------------------------------------------------------------
$includeExcel  = $pp.ContainsKey('include-excel')            -or $pp.ContainsKey('IncludeExcel')
$includeChrome = $pp.ContainsKey('include-chrome-extension') -or $pp.ContainsKey('IncludeChromeExtension')

$clientSsoUrl = $null
foreach ($k in 'client-sso','clientsso','ClientSso','ClientSSO') {
    if ($pp.ContainsKey($k) -and $pp[$k]) { $clientSsoUrl = $pp[$k]; break }
}

Write-Host ("Excel integration:  " + $(if ($includeExcel)  { 'ENABLED  (--params /include-excel)' }           else { 'disabled (default; pass /include-excel to enable)' }))
Write-Host ("Chrome extension:   " + $(if ($includeChrome) { 'ENABLED  (--params /include-chrome-extension)' } else { 'disabled (default; pass /include-chrome-extension to enable)' }))
Write-Host ("Client SSO URL:     " + $(if ($clientSsoUrl)  { "configured ($clientSsoUrl)" }                    else { 'not set (pass /client-sso=<URL> to configure)' }))

# ---------------------------------------------------------------------------
# Build silent-install args.
#
# Verified-valid argv keys from the installer's app.asar:
#   silent, forceInstall, lang, user/machine/<install-mode>, excel,
#   shortcuts, messengeronly, installerlogpath, machine-autoupdate-no,
#   machine-service, user-no-update, machine-no-update
#
# Removed flags from previous package versions that are NOT recognized as
# argv keys by the inner Electron arg parser (silently ignored):
#   --mode=vdi, --no-update, --no-excel, --no-chrome-extension,
#   --shortcut-workspace, --shortcut-excel, --shortcut-messenger
# ---------------------------------------------------------------------------
$UserTemp = $env:TEMP
$LogPath  = Join-Path $UserTemp $env:ChocolateyPackageName
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Name $env:ChocolateyPackageName -Path $UserTemp -Force | Out-Null
}

$silentArgList = @(
    '--silent',
    '--forceInstall',          # bypasses System Test on the regular install path
    "--$installMode",          # explicit install-mode (default: machine-autoupdate-no)
    '--lang=en',
    "--installerlogpath=`"$LogPath`""
)
if ($includeExcel)  { $silentArgList += '--excel' }
if ($includeChrome) { $silentArgList += '--enable-chrome-extension' }
if ($clientSsoUrl)  { $silentArgList += "--client-sso=`"$clientSsoUrl`"" }

$silentArgs = $silentArgList -join ' '
Write-Host "Silent args: $silentArgs"

$packageArgs = @{
    PackageName    = $env:ChocolateyPackageName
    SoftwareName   = 'Refinitiv Workspace*'
    Version        = $env:ChocolateyPackageVersion
    FileType       = 'exe'
    Url            = 'https://cdn.refinitiv.com/public/packages/Workspace/RefinitivWorkspace-installer_1.26.602.exe'
    checksum       = '3ed94f04d14868df119b2f50de0397f12e0193b7465e5b06d0d71e85ca63b873'
    checksumType   = 'SHA256'
    SilentArgs     = $silentArgs
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
