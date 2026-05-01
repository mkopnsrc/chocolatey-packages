Import-Module au

# Source the 18 static .ttf files from the official Google Fonts repository at
# a pinned commit SHA. itfoundry/Poppins (v4.003, 2019-03-05) is the upstream
# foundry but is frozen, so google/fonts/ofl/poppins/ is the canonical mirror
# that still receives metadata refreshes.
$githubRepo  = 'google/fonts'
$ghPath      = 'ofl/poppins'

# Preserve the existing maintainer version lineage. Versions follow chocolatey
# fix-notation: <baseVersion>.<YYYYMMDD-of-pinned-commit>.
$baseVersion = '1.4.0'

$fontFiles = @(
    'Poppins-Black.ttf',         'Poppins-BlackItalic.ttf',
    'Poppins-Bold.ttf',          'Poppins-BoldItalic.ttf',
    'Poppins-ExtraBold.ttf',     'Poppins-ExtraBoldItalic.ttf',
    'Poppins-ExtraLight.ttf',    'Poppins-ExtraLightItalic.ttf',
    'Poppins-Italic.ttf',
    'Poppins-Light.ttf',         'Poppins-LightItalic.ttf',
    'Poppins-Medium.ttf',        'Poppins-MediumItalic.ttf',
    'Poppins-Regular.ttf',
    'Poppins-SemiBold.ttf',      'Poppins-SemiBoldItalic.ttf',
    'Poppins-Thin.ttf',          'Poppins-ThinItalic.ttf'
)

function global:au_BeforeUpdate {
    $toolsDir = Join-Path $PSScriptRoot 'tools'
    $fontsDir = Join-Path $toolsDir 'fonts'

    if (Test-Path $fontsDir) { Remove-Item $fontsDir -Recurse -Force }
    New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null

    $sha     = $Latest.CommitSha
    $rawBase = "https://raw.githubusercontent.com/$githubRepo/$sha/$ghPath"

    $verifyLines = @(
        'VERIFICATION',
        'Verification is intended to assist the Chocolatey moderators and community',
        "in verifying that this package's contents are trustworthy.",
        '',
        'The font files in tools\fonts\ and the LICENSE.txt are sourced from the',
        'official Google Fonts repository at the pinned commit shown below.',
        '',
        "Source repository: https://github.com/$githubRepo",
        "Source path:       $ghPath",
        "Pinned commit SHA: $sha",
        "Commit date:       $($Latest.CommitDate)",
        '',
        'Upstream foundry:  https://github.com/itfoundry/Poppins (v4.003 frozen 2019-03-05)',
        '',
        'To re-verify each embedded file, fetch the upstream URL and compare:',
        "  https://raw.githubusercontent.com/$githubRepo/$sha/$ghPath/<filename>",
        'against the matching file under tools\fonts\.',
        '',
        'File checksums (SHA256):'
    )

    foreach ($f in $fontFiles) {
        $dest = Join-Path $fontsDir $f
        Invoke-WebRequest -Uri "$rawBase/$f" -OutFile $dest -UseBasicParsing
        $hash = (Get-FileHash $dest -Algorithm SHA256).Hash
        $verifyLines += ('  {0,-32}  {1}' -f $f, $hash)
    }

    Invoke-WebRequest -Uri "$rawBase/OFL.txt" -OutFile (Join-Path $toolsDir 'LICENSE.txt') -UseBasicParsing

    $verifyLines += ''
    $verifyLines += 'License: SIL Open Font License v1.1 (see LICENSE.txt)'

    Set-Content -Path (Join-Path $toolsDir 'VERIFICATION.txt') -Value $verifyLines -Encoding UTF8
}

function global:au_GetLatest {
    $headers = @{ 'User-Agent' = 'AU-Chocolatey-Updater' }
    if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }

    $api = "https://api.github.com/repos/$githubRepo/commits?path=$ghPath&per_page=1"
    $commits = Invoke-RestMethod -Uri $api -Headers $headers -UseBasicParsing
    $sha  = $commits[0].sha
    $date = [DateTime]::Parse($commits[0].commit.author.date)

    @{
        Version    = "$baseVersion.$($date.ToString('yyyyMMdd'))"
        CommitSha  = $sha
        CommitDate = $date.ToString('yyyy-MM-dd')
    }
}

function global:au_SearchReplace {
    @{}
}

update -ChecksumFor none -NoCheckUrl
