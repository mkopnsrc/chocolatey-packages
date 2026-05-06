$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fontsDir = Join-Path $toolsDir 'fonts'

Install-ChocolateyFont $fontsDir -multiple
