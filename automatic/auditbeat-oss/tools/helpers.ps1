function GetUninstallPath() {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    [Parameter(Mandatory = $true)]
    [string]$AppVersion
  )
  
  $AppsObject=(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
  
  $AppUninstallPath = $AppsObject| ? {($_.DisplayName -like "*$AppName*") -and ([version]$_.DisplayVersion -eq [version]"$AppVersion" )}
  
  if ( $AppUninstallPath ) {
    return $AppUninstallPath.UninstallString
  }

}

function GetLocale {
  param(
    [Parameter(Mandatory = $true)]
    [string]$localeFile,
    [Parameter(Mandatory = $true)]
    [string]$product
  )
  #$availableLocales = Get-WebContent $localeUrl 2>$null
  $availableLocales = Get-Content $localeFile | ForEach-Object { $_ -split '\|' | Select-Object -first 1 } | Select-Object -Unique

  $packageParameters = $env:chocolateyPackageParameters

  $packageParameters = if ($packageParameters -ne $null) { $packageParameters } else { "" }

  $argumentMap = ConvertFrom-StringData $packageParameters
  $localeFromPackageParameters = $argumentMap.Item('l')
  Write-Verbose "User chooses '$localeFromPackageParameters' as a locale..."
  $localeFromPackageParametersTwoLetter = $localeFromPackageParameters -split '\-' | Select-Object -first 1
  Write-Verbose "With fallback to '$localeFromPackageParametersTwoLetter' as locale..."

  $uninstallPath = GetUninstallPath -product $product

  $alreadyInstalledLocale = $uninstallPath -replace ".+\s([a-zA-Z\-]+)\)",'$1'
  Write-Verbose "Installed locale is: '$alreadyInstalledLocale'..."

  $systemLocalizeAndCountry = (Get-UICulture).Name
  $systemLocaleTwoLetter = (Get-UICulture).TwoLetterISOLanguageName
  Write-Verbose "System locale is: '$locale'..."
  $fallbackLocale = 'en-US'

  $locales = $localeFromPackageParameters,$localeFromPackageParametersTwoLetter, `
    $alreadyInstalledLocale, $systemLocalizeAndCountry, $systemLocaleTwoLetter, `
    $fallbackLocale

    foreach ($locale in $locales) {
      $localeMatch = $availableLocales | Where-Object { $_ -eq $locale } | Select-Object -first 1
      if ($localeMatch -and $locale -ne $null) {
        Write-Verbose "Using locale '$locale'..."
        break
      }
    }

    return $locale
}

function AlreadyInstalled() {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    [Parameter(Mandatory = $true)]
    [string]$AppVersion
  )
  
  $AppsObject=(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
  
  if ( $AppsObject| ? {($_.DisplayName -like "*$AppName*") -and ([version]$_.DisplayVersion -eq [version]"$AppVersion" )} ) {
    return $true
  }
  else {return $false }
}

function Get-32bitOnlyInstalled() {
  param(
    [Parameter(Mandatory = $true)]
    [string]$product
  )
  $systemIs64bit = Get-OSArchitectureWidth 64

  if (-Not $systemIs64bit) {
    return $false
  }

  $registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
  )

  $installedVersions = Get-ChildItem $registryPaths | Where-Object { $_.Name -match "$product [\d\.]+ \(x(64|86)" }

  if (
    $installedVersions -match 'x86' `
    -and $installedVersions -notmatch 'x64' `
    -and $systemIs64bit
  ) {
    return $true
  }
}

function GetChecksums() {
  param(
    [Parameter(Mandatory = $true)]
    [string]$language,
    [Parameter(Mandatory = $true)]
    $checksumFile
  )
  Write-Debug "Loading checksums from: $checksumFile"
  $checksumContent = Get-Content $checksumFile
  $checksum32 = ($checksumContent -match "$language\|32") -split '\|' | Select-Object -last 1
  $checksum64 = ($checksumContent -match "$language\|64") -split '\|' | Select-Object -last 1

  return @{
    "Win32" = $checksum32
    "Win64" = $checksum64
  }
}
