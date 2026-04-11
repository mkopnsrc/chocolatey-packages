# CLAUDE.md — AI Assistant Guide for chocolatey-packages

This repository is a collection of **Chocolatey packages** managed with the **AU (Automatic Updates)** PowerShell framework. It automates the detection of new software versions and updates Chocolatey package definitions accordingly.

---

## Repository Structure

```
chocolatey-packages/
├── AU/                      # AU PowerShell module (core update framework)
│   ├── Public/              # Public API: Update-Package, Get-RemoteChecksum, etc.
│   ├── Private/             # Internal helpers (validation, string utils)
│   └── Plugins/             # Extensibility plugins (Git, Gist, Report, Mail, etc.)
├── automatic/               # All managed packages (one subdirectory per package)
│   ├── dell-dract/
│   ├── filebeat-oss/
│   ├── fonts-poppins/
│   ├── heartbeat-oss/
│   ├── meshcommander/
│   ├── metricbeat-oss/
│   ├── moderncsv/
│   ├── packetbeat-oss/
│   ├── pgptool/
│   ├── poly-lens/
│   ├── refinitive-workspace/
│   └── winlogbeat-oss/
├── icons/                   # Package icon images (PNG)
├── scripts/                 # Developer helper scripts
├── tests/                   # Pester unit tests for the AU module
├── update_all.ps1           # Master script: updates all packages in parallel
├── test_all.ps1             # Force-updates all packages (for testing)
├── build.ps1                # Builds the AU module
├── install.ps1              # Installs the AU module to the system
├── publish.ps1              # Publishes to PSGallery / GitHub / Chocolatey
├── setup.ps1                # Installs all dependencies
├── test.ps1                 # Runs Pester tests
├── vars_default.ps1         # Template for environment variables (copy to vars.ps1)
├── DEVEL.md                 # Development workflow documentation
├── Plugins.md               # AU plugin system documentation
├── CHANGELOG.md             # AU module version history
└── README.md                # Primary AU module documentation
```

---

## Package Structure

Every package lives under `automatic/<package-name>/` and follows this layout:

```
automatic/<package-name>/
├── <package-name>.nuspec         # NuGet package manifest (XML)
├── update.ps1                    # AU update script (required)
├── README.md                     # Optional: description auto-copied to nuspec
└── tools/
    ├── chocolateyInstall.ps1     # Install logic (required)
    ├── chocolateyUninstall.ps1   # Uninstall logic (optional)
    └── helpers.ps1               # Shared helper functions (optional)
```

---

## Development Workflow

### Prerequisites

- PowerShell 5+
- Chocolatey installed
- PSParseHTML module (for HTML parsing in update scripts)

### Setup

```powershell
./setup.ps1   # Install all dependencies (run once)
```

### Build & Install AU Module

```powershell
./build.ps1                            # Build to _build/{version}/
./build.ps1 -Install -ShortVersion    # Build and install in system
./install.ps1                          # Install latest build
./install.ps1 -Remove                  # Uninstall
```

### Running Updates

```powershell
# Update all packages
./update_all.ps1

# Update a specific package by name
./update_all.ps1 -Name moderncsv

# Force update all packages (use for testing)
./test_all.ps1

# Force update a specific package with specific version
./update_all.ps1 -ForcedPackages "moderncsv:1.3.36"

# Force update with specific stream
./update_all.ps1 -ForcedPackages "packagename\stream:version"
```

### Testing

```powershell
./test.ps1              # Run all Pester tests
git clean -Xfd -e vars.ps1   # Clean build artifacts
```

### Publishing

```powershell
$v = ./build.ps1
./publish.ps1 -Version $v -Tag -Github -PSGallery -Chocolatey
```

Before publishing, update the `NEXT` section in `CHANGELOG.md` with release notes.

---

## Environment Variables

Copy `vars_default.ps1` to `vars.ps1` (git-ignored) and set:

| Variable | Purpose |
|---|---|
| `$Env:github_user_repo` | GitHub user/repo (e.g. `mkopnsrc/chocolatey-packages`) |
| `$Env:github_api_key` | GitHub API key for push/gist |
| `$Env:Chocolatey_ApiKey` | Chocolatey.org push key |
| `$Env:au_Push` | Set to `'true'` to push packages after update |
| `$Env:gist_id` | Gist ID for storing update reports |
| `$Env:mail_user` | Email notifications (optional) |

---

## AU Update Script Conventions

Each `update.ps1` implements three global functions consumed by the AU framework:

### `au_GetLatest()` — fetch latest version info

Returns a hashtable. Required keys: `Version`, `URL32`. Optional: `URL64`, `ChecksumType32`, `ChecksumType64`, any custom fields passed into `au_SearchReplace`.

```powershell
function global:au_GetLatest() {
    $download_page = Invoke-WebRequest $releases -UseBasicParsing
    $url    = $download_page.links | Where-Object href -match '.msi$' | Select-Object -First 1 -ExpandProperty href
    $version = $url -split '/' | Select-Object -Last 1 -Skip 1
    return @{
        URL32          = $url
        URL64          = $url
        Version        = $version
        ChecksumType32 = 'SHA256'
        ChecksumType64 = 'SHA256'
    }
}
```

Alternative fetch strategies seen in this repo:
- **HTML scraping** with `Invoke-WebRequest` + regex or `ConvertFrom-Html` (PSParseHTML)
- **REST/GraphQL API** with `Invoke-RestMethod` (e.g., `poly-lens`)
- **Link extraction** from vendor download pages (e.g., `pgptool`, `moderncsv`)

### `au_BeforeUpdate()` — compute checksums before files are modified

```powershell
function global:au_BeforeUpdate {
    $Latest.Checksum32 = Get-RemoteChecksum $Latest.URL32 -Algorithm $Latest.ChecksumType32
    $Latest.Checksum64 = Get-RemoteChecksum $Latest.URL64 -Algorithm $Latest.ChecksumType64
}
```

### `au_SearchReplace()` — define regex substitutions in package files

Returns a hashtable of `{ filepath = @{ regex_pattern = replacement } }`. Use PowerShell regex capture groups for precision.

```powershell
function global:au_SearchReplace {
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(?i)(^\s*url\s*=\s*)('.*')"           = "`$1'$($Latest.URL32)'"
            "(?i)(^\s*url64bit\s*=\s*)('.*')"      = "`$1'$($Latest.URL64)'"
            "(?i)(^\s*checksum\s*=\s*)('.*')"      = "`$1'$($Latest.Checksum32)'"
            "(?i)(^\s*checksumType\s*=\s*)('.*')"  = "`$1'$($Latest.ChecksumType32)'"
            "(?i)(^\s*checksum64\s*=\s*)('.*')"    = "`$1'$($Latest.Checksum64)'"
            "(?i)(^\s*checksumType64\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType64)'"
        }
        "$($Latest.PackageName).nuspec" = @{
            "(<releaseNotes.*?)(\d+\.\d+)(.*?releaseNotes>)" = "`${1}$([regex]::match($Latest.Version, '\d+\.\d+').Value)`${3}"
        }
    }
}
```

### Invocation

End every `update.ps1` with:

```powershell
update -ChecksumFor none   # Checksums handled manually in au_BeforeUpdate
```

---

## chocolateyInstall.ps1 Conventions

```powershell
$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. $toolsDir\helpers.ps1   # Source shared helpers if present

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    softwareName   = 'Display Name as shown in Add/Remove Programs'
    version        = $env:ChocolateyPackageVersion
    installerType  = 'msi'      # msi | exe | zip
    url            = '<url32>'
    url64bit       = '<url64>'
    checksum       = '<sha256>'
    checksumType   = 'SHA256'
    checksum64     = '<sha256>'
    checksumType64 = 'SHA256'
    silentArgs     = "/qn /norestart"
    validExitCodes = @(0, 3010, 2147781575, 2147205120)
}

# Use AlreadyInstalled helper when available to avoid redundant installs
$alreadyInstalled = AlreadyInstalled -AppName $packageArgs['softwareName'] -AppVersion $packageArgs['version']
if ($alreadyInstalled -and ($env:ChocolateyForce -ne $true)) {
    Write-Output "$($packageArgs['softwareName']) is already installed. Use --force to reinstall."
} else {
    Install-ChocolateyPackage @packageArgs
}
```

**MSI silent args standard exit codes:**
- `0` — Success
- `3010` — Success, restart required
- `2147781575` — Pending restart required
- `2147205120` — Pending restart required for setup update

---

## helpers.ps1 — Available Shared Functions

These are dot-sourced into install scripts. Not all packages include helpers.ps1 — only copy/create it when needed.

| Function | Purpose |
|---|---|
| `AlreadyInstalled -AppName -AppVersion` | Returns `$true` if the exact version is installed (queries Windows registry) |
| `GetUninstallPath -AppName -AppVersion` | Returns the uninstall string from the registry |
| `GetLocale -localeFile -product` | Determines best locale for localized installers |
| `Get-32bitOnlyInstalled -product` | Returns `$true` if only the 32-bit version is installed on a 64-bit OS |
| `GetChecksums -language -checksumFile` | Parses a `language|arch|checksum` file and returns a hashtable |

---

## Nuspec Conventions

```xml
<metadata>
    <id>package-id</id>                    <!-- Chocolatey ID: lowercase, hyphens -->
    <version>1.0.0</version>               <!-- Updated automatically by AU -->
    <title>Display Name</title>
    <authors>Original Software Authors</authors>
    <owners>opnsrc.dev</owners>            <!-- Always: opnsrc.dev -->
    <projectUrl>https://vendor.com/</projectUrl>
    <iconUrl>https://rawcdn.githack.com/mkopnsrc/chocolatey-packages/{commit-sha}/icons/{icon}.png</iconUrl>
    <packageSourceUrl>https://github.com/mkopnsrc/chocolatey-packages/tree/master/automatic/{package-id}</packageSourceUrl>
    <licenseUrl>https://vendor.com/license</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <releaseNotes>https://vendor.com/changelog</releaseNotes>
    <bugTrackerUrl>https://vendor.com/issues</bugTrackerUrl>
    <tags>keyword1 keyword2 vendorname</tags>
    <description>Markdown content here</description>
    <summary>Single-line summary</summary>
</metadata>
<files>
    <file src="tools\**" target="tools" />
</files>
```

**Key rules:**
- `owners` is always `opnsrc.dev`
- Icon URLs use `rawcdn.githack.com` with a pinned commit SHA for cache stability
- `packageSourceUrl` always points to the `/automatic/<id>` subdirectory on GitHub master
- Description field supports Markdown
- If a `README.md` exists at the package root, its content (after the first 2 header lines) can be auto-propagated to `<description>` via `Set-DescriptionFromReadme`

---

## update_all.ps1 Configuration

Key settings in `update_all.ps1`:

| Setting | Default | Purpose |
|---|---|---|
| `Threads` | `10` | Parallel background jobs |
| `Timeout` | `100` sec | HTTP connection timeout |
| `UpdateTimeout` | `1200` sec | Max time per package update |
| `Push` | `$Env:au_Push -eq 'true'` | Whether to push to Chocolatey |
| `PushAll` | `$true` | Allow multiple pushes per run |
| `IgnoreOn` | SSL/TLS errors, timeouts | Errors that set a package to ignored status |
| `RepeatOn` | Network errors, choco pack failures | Errors that trigger a retry |

**Plugins configured:** Report (markdown), History, Gist (upload to GitHub), Git (commit changes), GitReleases, RunInfo (XML dump), Mail (optional).

---

## Adding a New Package

1. Create directory: `automatic/<new-package-name>/`
2. Create `<new-package-name>.nuspec` following the nuspec conventions above
3. Create `tools/chocolateyInstall.ps1` following the install script conventions
4. Create `update.ps1` implementing `au_GetLatest`, `au_BeforeUpdate`, `au_SearchReplace`
5. Add package icon to `icons/` and reference it in the nuspec using a pinned `rawcdn.githack.com` URL
6. Test with: `cd automatic/<new-package-name> && Import-Module au && update`
7. Verify the nuspec and install script were correctly updated by the `au_SearchReplace` patterns

---

## Checksums

- **Default algorithm:** SHA256 everywhere
- Checksums are computed in `au_BeforeUpdate` using `Get-RemoteChecksum`
- Checksums are embedded directly in `chocolateyInstall.ps1` (not separate files, except for locale-based packages)
- Never use MD5; prefer SHA256 or SHA512

---

## Git Workflow

- Default development branch: `master`
- Feature/fix branches follow the naming convention seen in history (e.g., `claude/add-claude-documentation-Qtgbo`)
- Commit messages are imperative, lowercase, descriptive (e.g., `updated elastic oss packages`, `added feature to enable force for single package update`)
- The `.gitignore` excludes: `/_build`, `/chocolatey/tools/AU`, `*.nupkg`, `/vars.ps1`, `update_info.xml`

---

## AU Module Notes

- The AU module in `/AU/` is **archived** (last release: 2022.10.24). Do not expect upstream updates.
- The module is sourced from `majkinetor/au` (originally). This repo vendors a customized copy.
- When working on update scripts, `Import-Module au` must be run from the package directory or from the root after the module is installed/built.
- The `$Latest` hashtable is the primary communication channel between `au_GetLatest`, `au_BeforeUpdate`, and `au_SearchReplace`.

---

## Common Pitfalls

- **`-UseBasicParsing`**: Add this to `Invoke-WebRequest` calls when full HTML parsing is not needed (faster, no IE dependency).
- **HTML parsing**: Use `ConvertFrom-Html` (PSParseHTML module) for XPath-based parsing instead of regex on raw HTML.
- **URL construction**: When building URLs from a version string, test with multiple version formats (e.g., `8.14` vs `8.14.1`).
- **`au_SearchReplace` regex**: Patterns are case-insensitive (`(?i)`) and match entire lines. Always anchor with `^\s*` for variable assignments.
- **Version comparison**: AU compares versions semantically. Do not return version strings with leading zeros or extra dots that break `[version]` casting.
- **Icon URL**: Use a pinned commit SHA in the `rawcdn.githack.com` URL — using `master` or `HEAD` can cause caching issues on Chocolatey.org.
- **`$MyInvocation.InvocationName -ne '.'` guard**: Use this pattern when code outside of functions should only run when the script is invoked directly (not dot-sourced in tests).
