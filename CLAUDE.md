# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This repo bundles **two related concerns**:

1. **The `AU/` PowerShell module** — Chocolatey Automatic Package Updater framework (forked from majkinetor/au; upstream development finished at `2022.10.24`).
2. **`automatic/` Chocolatey packages** that consume the AU module to keep themselves up-to-date (e.g. `filebeat-oss`, `dell-dract`, `meshcommander`, `fonts-poppins`, ...).

When making changes, keep clear which side you're touching: the framework code (`AU/`, `tests/`, `build.ps1`, `publish.ps1`) versus an individual package's `update.ps1` and `tools/` scripts.

## Common commands

All scripts run from the repo root and require **PowerShell 5+** (PowerShell 7 / pwsh works on Linux too — `update_all.ps1` already uses pwsh-only ternary syntax).

| Task                                              | Command                                |
| :------------------------------------------------ | :------------------------------------- |
| One-time dev setup (chocolatey, pester, etc.)     | `./setup.ps1`                          |
| Build module → `_build/<version>/`                | `./build.ps1`                          |
| Build with explicit version                       | `./build.ps1 -Version 0.0.1`           |
| Build + install in system                         | `./build.ps1 -Install -ShortVersion`   |
| Install latest build                              | `./install.ps1`                        |
| Uninstall module                                  | `./install.ps1 -Remove`                |
| Run all tests (Pester + Chocolatey package test)  | `./test.ps1`                           |
| Pester tests only                                 | `./test.ps1 -Pester`                   |
| Pester with tag filter / coverage                 | `./test.ps1 -Pester -Tag <tag> -CodeCoverage` |
| Update all packages in `automatic/`               | `./update_all.ps1`                     |
| Force-update specific packages (smoke test)       | `./test_all.ps1 -ForcedPackages 'pkg1 pkg2'` |
| Update one package                                | `cd automatic/<pkg>; ./update.ps1`     |
| Force one package update                          | `$au_Force = $true; ./update.ps1`      |
| Preview changes without writing                   | `$au_WhatIf = $true; ./update.ps1`     |
| Clean build artifacts                             | `git clean -Xfd -e vars.ps1`           |

`./test.ps1` requires a build to exist first (it reads `_build/*`). Run `./build.ps1` before testing.

Publishing (rare, framework only): `./publish.ps1 -Version <v> -Tag -Github -PSGallery -Chocolatey`. Requires `vars.ps1` (copy from `vars_default.ps1`) with API keys, and a `## <version>` section in `CHANGELOG.md` for release notes.

## AU module architecture

The module loads via `AU/AU.psm1`, which dot-sources every `.ps1` under `AU/Private/` then `AU/Public/`. Public functions are the user-facing API; Private files are helpers (`check_url.ps1`, `is_version.ps1`, `AUVersion.ps1`, `AUPackage.ps1`, ...).

### The two-function contract every package follows

A package's `update.ps1` defines two `global:au_*` functions and then calls `update` (alias for `Update-Package`):

- **`au_GetLatest`** — fetches remote info; returns a hashtable with at least `Version` and one of `URL32`/`URL64`. Optional `Checksum32/64`, `ChecksumType32/64`. May return `Streams = [ordered]@{ ... }` for multi-version packages — stream state persists in `<package>.json`.
- **`au_SearchReplace`** — returns `@{ "<file>" = @{ "<regex>" = "<replacement>" } }`. Regex match is **per-line** (multi-line regex won't work). The nuspec version is replaced automatically — don't include it.

Optional hooks: `au_BeforeUpdate` (runs after fetch, before file edits — common place to call `Get-RemoteFiles -Purge` for embedded packages or `Get-RemoteChecksum` for manual hashing) and `au_AfterUpdate`.

`Update-Package` performs validation (URL existence + MIME type, regex pattern existence, Chocolatey gallery duplicate check) before writing. Failure of any check aborts the update — this is a feature, not a bug. Disable selectively with `-NoCheckUrl`, `-NoCheckChocoVersion`, `-ChecksumFor none`.

### Automatic checksums caveat

`-ChecksumFor all|32|64` works by **monkey-patching `Get-ChocolateyWebFile`** and invoking `tools/chocolateyInstall.ps1`. The install script is **terminated** at the first call to `Get-ChocolateyWebFile` — anything after that line will not run during checksum calculation. If `chocolateyInstall.ps1` does meaningful work before the download call, use `-ChecksumFor none` plus `Get-RemoteChecksum` in `au_BeforeUpdate` instead. On Linux, **always** use `-ChecksumFor none`.

### Global override variables

Any `Update-Package` parameter can be set via `$global:au_<ParamName>` (e.g. `$au_Force`, `$au_WhatIf`, `$au_NoCheckUrl`, `$au_IncludeStream`, `$au_Version`). Used heavily for ad-hoc overrides without editing `update.ps1`. `$au_Root` sets where `updateall` searches for packages (`update_all.ps1` and `test_all.ps1` set it to `$PSScriptRoot/automatic`).

### Plugins (`AU/Plugins/`)

`Update-AUPackages` (alias `updateall`) runs after a multi-package update. Any key in the `$Options` hashtable whose value is itself a `[HashTable]` and which matches a `.ps1` filename in `AU/Plugins/` (or a path in `$Options.PluginPath`) is treated as a plugin. Order in `[ordered]@{}` is the execution order. Plugins receive their hashtable plus an injected `$Info` argument with run results. Built-ins: `Gist`, `Git`, `GitLab`, `GitReleases`, `Gitter`, `History`, `Mail`, `PullRequest`, `Report`, `RunInfo`, `Snippet`. Most are configured via `$Env:*` variables (see `update_all.ps1` and `Plugins.md`).

`Report` has its own subdirectory (`AU/Plugins/Report/`) with `markdown.ps1` / `text.ps1` formatters and embedded status icons.

### Package conventions

- Prefix a package directory with `_` to exclude it from `updateall`.
- An `update.ps1` returning the literal string `'ignore'` (or `au_GetLatest` returning `'ignore'` for a stream) flags that run as ignored rather than failed — used for known transient errors. `IgnoreOn` / `RepeatOn` arrays in `$Options` apply this globally by error-message substring without per-package changes.
- For metapackages depending on another AU package, dot-source the dependency's `update.ps1` and override `au_SearchReplace`. The dependent script must guard its `update` call: `if ($MyInvocation.InvocationName -ne '.') { update ... }`.

### chocolateyInstall.ps1 standards

Every `chocolateyInstall.ps1` for an app package (i.e. anything that shows up in Programs & Features) MUST include an already-installed short-circuit before invoking the installer, with a `--force` escape hatch:

```powershell
$existing = Get-UninstallRegistryKey -SoftwareName '<display-name-pattern>*'
if ($existing -and ($env:ChocolateyForce -ne 'true')) {
    $displayVersion = ($existing | Select-Object -First 1).DisplayVersion
    Write-Host "<pkg> $displayVersion is already installed (registry). Pass --force to re-install."
    return
}
```

Rationale: prevents silent reinstalls that might overwrite user config or waste bandwidth. `Get-UninstallRegistryKey` ships with Chocolatey's built-in helpers — no per-package `helpers.ps1` needed. Chocolatey sets `$env:ChocolateyForce='true'` when `--force` is passed on the CLI.

Font-only packages (`fonts-*`) and metapackages don't map to an Uninstall registry entry and are exempt from this rule.

## Testing

Pester tests live in `tests/` and exercise the framework, not the packages:

- `Update-Package.Tests.ps1`, `Update-Package.Streams.Tests.ps1` — single-package update behavior.
- `Update-AUPackages.Tests.ps1`, `Update-AUPackages.Streams.Tests.ps1` — multi-package orchestration.
- `Get-Version.Tests.ps1`, `AUPackage.Tests.ps1`, `General.Tests.ps1` — units.
- Fixture directories `tests/test_package/` and `tests/test_package_with_streams/` are scaffolds the tests copy and mutate.

Tests are pinned to **Pester 4.10.1** (see `setup.ps1`). Pester 5 syntax will not work.

`Test-Package` (in `AU/Public/`) is a runtime helper for maintainers to dry-run a package's install/uninstall — it's also used by `test.ps1`'s `-Chocolatey` mode against the latest build.

## Chocolatey package of AU itself

`chocolatey/` packages the AU module for distribution via `cinst au`. `build.ps1` invokes `chocolatey/build-package.ps1` and moves the resulting `.nupkg` into `_build/<version>/`.
