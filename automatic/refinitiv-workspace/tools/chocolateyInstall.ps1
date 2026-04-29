$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

# ---------------------------------------------------------------------------
# Detect physical machine vs virtual machine.
# Refinitiv Workspace's installer accepts --mode=machine and --mode=vdi.
# Auto-select based on detected hypervisor presence.
# ---------------------------------------------------------------------------
function Test-IsVirtualMachine {
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    } catch {
        return $false
    }
    # Common hypervisor / virtualization markers in Manufacturer or Model.
    $vmPatterns = '(?i)VMware|VirtualBox|innotek|Xen|HVM domU|KVM|QEMU|Parallels|Citrix|Bochs'
    if ($cs.Model -match $vmPatterns)        { return $true }
    if ($cs.Manufacturer -match $vmPatterns) { return $true }
    # Hyper-V / Azure: Microsoft Corporation + 'Virtual Machine' model
    if ($cs.Manufacturer -eq 'Microsoft Corporation' -and $cs.Model -match 'Virtual Machine') {
        return $true
    }
    return $false
}

$installMode = if (Test-IsVirtualMachine) { 'vdi' } else { 'machine' }
Write-Host "Detected install mode: --mode=$installMode"

# ---------------------------------------------------------------------------
# User-supplied chocolatey package parameters.
#
# By default Excel and Chrome integration are NOT installed (faster install,
# fewer side effects). Users can opt-in via:
#
#   choco install refinitiv-workspace --params "/include-excel /include-chrome-extension"
#
# A SSO endpoint URL can also be provided to pre-configure Single Sign-On for
# Workspace for Web (vendor flag --client-sso, documented in the LSEG
# Workspace Desktop Installation Guide):
#
#   choco install refinitiv-workspace --params "/client-sso=https://sso.example.com/auth"
#
# Parameter keys accept both kebab-case (include-excel, client-sso) and
# PascalCase (IncludeExcel, ClientSso) forms.
# ---------------------------------------------------------------------------
$pp = Get-PackageParameters
$includeExcel  = $pp.ContainsKey('include-excel')           -or $pp.ContainsKey('IncludeExcel')
$includeChrome = $pp.ContainsKey('include-chrome-extension') -or $pp.ContainsKey('IncludeChromeExtension')

# client-sso accepts a value: /client-sso=<URL>
$clientSsoUrl = $null
foreach ($k in 'client-sso','clientsso','ClientSso','ClientSSO') {
    if ($pp.ContainsKey($k) -and $pp[$k]) { $clientSsoUrl = $pp[$k]; break }
}

Write-Host ("Excel integration:  " + $(if ($includeExcel)  { 'ENABLED  (--params /include-excel)' }           else { 'disabled (default; pass /include-excel to enable)' }))
Write-Host ("Chrome extension:   " + $(if ($includeChrome) { 'ENABLED  (--params /include-chrome-extension)' } else { 'disabled (default; pass /include-chrome-extension to enable)' }))
Write-Host ("Client SSO URL:     " + $(if ($clientSsoUrl)  { "configured ($clientSsoUrl)" }                    else { 'not set (pass /client-sso=<URL> to configure)' }))

# ---------------------------------------------------------------------------
# Build silent-install args.
# ---------------------------------------------------------------------------
$UserTemp = $env:TEMP
$LogPath  = Join-Path $UserTemp $env:ChocolateyPackageName
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Name $env:ChocolateyPackageName -Path $UserTemp -Force | Out-Null
}

$silentArgList = @(
    '--silent',
    '--forceInstall',
    '--lang=en',
    '--no-update',
    '--machine-autoupdate-no',
    "--mode=$installMode",
    '--shortcut-workspace=true',
    '--shortcut-messenger=false',
    "--installerlogpath=`"$LogPath`""
)
if (-not $includeExcel)  { $silentArgList += '--no-excel'; $silentArgList += '--shortcut-excel=false' } else { $silentArgList += '--shortcut-excel=true' }
if (-not $includeChrome) { $silentArgList += '--no-chrome-extension' }
if ($clientSsoUrl)       { $silentArgList += "--client-sso=`"$clientSsoUrl`"" }

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
