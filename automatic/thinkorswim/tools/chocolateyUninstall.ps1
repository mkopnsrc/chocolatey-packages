$ErrorActionPreference = 'Stop'

# Find the install4j-generated uninstaller via the Uninstall registry entries.
# thinkorswim registers a DisplayName matching 'thinkorswim*' under HKLM (when
# installed system-wide) or HKCU (when installed per-user).
$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$entry = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
         Where-Object { $_.DisplayName -like 'thinkorswim*' } |
         Select-Object -First 1

if (-not $entry -or -not $entry.UninstallString) {
    Write-Warning 'thinkorswim uninstaller not found in registry; it may already be uninstalled.'
    return
}

# UninstallString is typically a quoted path to ${INSTALL_DIR}\uninstall.exe.
# install4j supports '-q' for quiet uninstall.
$uninstallExe = $entry.UninstallString.Trim('"')
Write-Host "Running: `"$uninstallExe`" -q"

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    fileType       = 'EXE'
    file           = $uninstallExe
    silentArgs     = '-q'
    validExitCodes = @(0)
}
Uninstall-ChocolateyPackage @packageArgs
