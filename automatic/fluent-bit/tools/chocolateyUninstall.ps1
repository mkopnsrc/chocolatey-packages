$ErrorActionPreference = 'Stop'

$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$entry = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
         Where-Object { $_.DisplayName -like 'fluent-bit*' } |
         Select-Object -First 1

if (-not $entry) {
    Write-Warning 'fluent-bit not found in registry; it may already be uninstalled.'
    return
}

$productCode = $null
if ($entry.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') {
    $productCode = $entry.PSChildName
} elseif ($entry.UninstallString -match '\{[0-9A-Fa-f-]{36}\}') {
    $productCode = $matches[0]
}

if (-not $productCode) {
    throw "Could not resolve MSI product code from registry entry for fluent-bit. UninstallString: $($entry.UninstallString)"
}

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    fileType       = 'MSI'
    silentArgs     = "$productCode /quiet /norestart"
    validExitCodes = @(0, 1605, 1614, 1641, 3010)
}
Uninstall-ChocolateyPackage @packageArgs
