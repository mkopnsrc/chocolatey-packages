$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1

# MSI verbose log captured to a known path so install failures can be
# diagnosed from the chocolatey log (and CI step output).
$msiLog = Join-Path $env:TEMP 'poly-lens-msi.log'

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    softwareName   = 'Poly Lens*'
    version        = $env:ChocolateyPackageVersion
    unzipLocation  = $toolsDir
    installerType  = 'msi'
    url            = 'https://swupdate.lens.poly.com/lens-desktop-windows/1.3.1/1.3.1/PolyLens-1.3.1.msi'
    checksum       = '7d0f781a48f00c6d215e51385660c80d9a94264ce3d541d48cc052795f8dcf20'
    checksumType   = 'SHA256'
    # ACCEPTEULA=YES propagates to chained child MSIs (LensControlService +
    # LensDesktop). Without it the chainer's children fail post-install and
    # return 1603 to the wrapper, even though the main MSI itself succeeds.
    silentArgs     = "/qn /norestart /l*v `"$msiLog`" ACCEPTEULA=YES"
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
    try {
        Install-ChocolateyPackage @packageArgs
    } catch {
        if (Test-Path $msiLog) {
            Write-Host ''
            Write-Host '===== MSI log: lines containing FAILURE/ERROR/Return Value/CustomAction ====='
            Select-String -Path $msiLog -Pattern '(?i)return value 3|action ended.*FAILURE|Internal Error|CustomAction.*returned|exception|did not succeed|launchcondition' |
                ForEach-Object { Write-Host $_.Line }
            Write-Host '===== last 500 lines of MSI log ====='
            Get-Content $msiLog -Tail 500 | ForEach-Object { Write-Host $_ }
            Write-Host '===== end MSI log ====='
        } else {
            Write-Host "MSI log not found at $msiLog"
        }
        throw
    }
}
