# mkopnsrc Chocolatey Packages

[![license](https://img.shields.io/badge/license-GPL2-blue.svg)](license.txt)

A maintained set of [Chocolatey](https://chocolatey.org) packages for Windows, with automated version backfill driven by GitHub Actions and the bundled [AU](https://github.com/majkinetor/au) framework.

## Install

```powershell
choco install <package-name>
```

To install a specific version:

```powershell
choco install <package-name> --version <X.Y.Z>
```

## Packages

| Package | Description | Updater | Backfill |
|---|---|---|---|
| [`auditbeat-oss`](https://community.chocolatey.org/packages/auditbeat-oss) | Elastic Auditbeat — file integrity & system audit shipper | auto | yes |
| [`dell-dract`](https://community.chocolatey.org/packages/dell-dract) | Dell Remote Access Configuration Tool | manual | — |
| [`filebeat-oss`](https://community.chocolatey.org/packages/filebeat-oss) | Elastic Filebeat — log shipper | auto | yes |
| [`fonts-poppins`](https://community.chocolatey.org/packages/fonts-poppins) | Poppins font family | broken | — |
| [`heartbeat-oss`](https://community.chocolatey.org/packages/heartbeat-oss) | Elastic Heartbeat — uptime probes | auto | yes |
| [`meshcommander`](https://community.chocolatey.org/packages/meshcommander) | Intel AMT (vPro) remote management console | auto | — |
| [`metricbeat-oss`](https://community.chocolatey.org/packages/metricbeat-oss) | Elastic Metricbeat — system & service metrics | auto | yes |
| [`moderncsv`](https://community.chocolatey.org/packages/moderncsv) | ModernCSV — CSV editor and viewer | broken | — |
| [`packetbeat-oss`](https://community.chocolatey.org/packages/packetbeat-oss) | Elastic Packetbeat — network packet shipper | auto | yes |
| [`pgptool`](https://community.chocolatey.org/packages/pgptool) | PGPTool — PGP/GPG GUI | auto | — |
| [`poly-lens`](https://community.chocolatey.org/packages/poly-lens) | Poly Lens Desktop (formerly Plantronics) | auto | — |
| [`refinitive-workspace`](https://community.chocolatey.org/packages/refinitive-workspace) | Refinitiv (LSEG) Workspace — financial data | auto | — |
| [`winlogbeat-oss`](https://community.chocolatey.org/packages/winlogbeat-oss) | Elastic Winlogbeat — Windows event log shipper | auto | yes |

**Updater**: `auto` packages have a working `update.ps1` that scrapes the vendor and refreshes URL/checksum on dispatch. `manual` packages have static metadata. `broken` packages need the `update.ps1` rewritten — vendor source moved, see open work.

**Backfill**: packages with `backfill.json` walk a curated version list one entry per cron tick, gated on chocolatey.org moderation status.

## Features

- Automated version checking against vendor pages with URL and checksum validation.
- Per-package multi-version backfill with chocolatey.org moderation-aware gating — each new version waits for the previous to clear moderation before advancing.
- Manual-dispatch testing via GitHub Actions Windows runners — pack, install, registry-verify, uninstall on a fresh VM per run.
- Force re-publish via Chocolatey fix notation (`X.Y.Z.YYYYMMDD`) when a version's content needs republishing without bumping the logical version.
- Bundled AU framework for vendor scrape, URL/checksum validation, and inline package edits — no external module install required.

## Automation

Two GitHub Actions workflows drive the publish loop:

### `package-build-test.yml` — manual dispatch

Builds, install-tests, and (optionally) publishes a single package.

```bash
gh workflow run package-build-test.yml \
  -f package=meshcommander \
  -f run_au=true \
  -f publish=true
```

Inputs:
| Name | Default | Purpose |
|---|---|---|
| `package` | `meshcommander` | Directory under `automatic/` |
| `run_au` | `true` | Run `update.ps1` first to refresh URL/checksum from vendor |
| `publish` | `false` | Push to chocolatey.org community feed after a successful test |
| `force_version` | (empty) | Pin to a specific version (sets `$global:au_Version`) |
| `force` | `false` | Re-publish via chocolatey fix notation (sets `$global:au_Force = $true`) |

### `backfill.yml` — cron + manual

Cron `0 */6 * * *` walks each package up its `backfill.json` version list, advancing one version per cycle and waiting on chocolatey moderation between pushes. Inputs `dry_run` and `filter_package` for controlled manual runs.

The plan job parses the public package detail page at `https://community.chocolatey.org/packages/<id>/<version>` for moderation status — the OData feed returns inconsistent data across CDN edges and is not reliable.

## Repo layout

```
.
├── automatic/                       # the chocolatey packages
│   └── <package>/
│       ├── <package>.nuspec
│       ├── update.ps1               # AU updater script
│       ├── backfill.json            # (optional) version backfill target list
│       └── tools/
│           ├── chocolateyInstall.ps1
│           ├── chocolateybeforemodify.ps1   # (optional) pre-modify hooks
│           └── helpers.ps1
├── AU/                              # bundled AU framework (frozen at upstream 2022.10.24)
├── .github/workflows/
│   ├── package-build-test.yml
│   └── backfill.yml
├── icons/                           # package icons referenced from nuspecs
├── chocolatey/                      # AU-as-a-chocolatey-package build (rarely used)
└── CLAUDE.md                        # repo orientation for AI assistants
```

## Adding a new package

1. **Create the package directory** under `automatic/<id>/`:
   - `<id>.nuspec` with metadata (id, version, description, license/release URLs, tags, icon)
   - `update.ps1` defining `au_GetLatest` and `au_SearchReplace`. If targeting backfill, the `au_GetLatest` must honor `$global:au_Version`.
   - `tools/chocolateyInstall.ps1` with the install logic
   - `tools/helpers.ps1` (copy from a sibling package)
   - `tools/chocolateybeforemodify.ps1` if a service/process needs stopping during upgrade

2. **(Optional) Add `backfill.json`** for multi-version backfill:
   ```json
   { "versions": ["X.Y.Z", "X.Y.Z+1", "..."] }
   ```
   The cron will pick this up automatically — no workflow edits needed.

3. **Test via manual dispatch** before merging to master:
   ```bash
   gh workflow run package-build-test.yml -f package=<id> -f publish=false
   ```

4. **Push to master** so the cron sees the new package on the next 6-hour tick.

5. **First-time submissions** to chocolatey.org go through the full id-name moderation review (one-time gate). Subsequent version bumps clear faster.

## AU framework

This repo bundles [AU (Chocolatey Automatic Package Updater)](https://github.com/majkinetor/au) from upstream `majkinetor/au`. Upstream development is finished as of `2022.10.24`. AU is used here for:

- Vendor page scraping for latest version detection
- URL existence and content-type validation
- Inline edits to `.nuspec` and `chocolateyInstall.ps1` via regex search/replace
- Multi-package update orchestration

For full AU documentation, see the [upstream README](https://github.com/majkinetor/au/blob/master/README.md). Local modifications are minimal — see `git log AU/`.

## License

GPL-2.0 inherited from AU upstream — see [`license.txt`](license.txt). Individual package contents and binaries are subject to their respective vendor licenses (see each package's `licenseUrl` in its nuspec).
