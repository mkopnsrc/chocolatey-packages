# Static NuGet v3 feed on GitHub Pages — design (WITHDRAWN)

> **Status: withdrawn on 2026-08-01.** The plan below shipped as PRs #54 → #59 and produced a working Sleet-generated v3 feed at `https://mkopnsrc.github.io/chocolatey-packages/nuget/`, but the real-world target machines run **choco 0.10.15** (2019), which predates NuGet v3 client support (added in choco 2.0, 2023). Since upgrading the fleet isn't practical and adding a v2/OData feed adds significant hosted-infrastructure (Sleet is v3-only; a v2 server needs a running process like BaGetter, which doesn't fit GitHub Pages), we reverted to Releases-download-only distribution. Design retained for future reference in case the choco-version constraint changes.
>
> Reverted-by workflow change: removed the Sleet + `actions/deploy-pages` steps from `publish-nupkg-release.yml`. The `gh-pages` branch was already retired earlier in the same sequence.

## Goal

Let users install embedded-binary packages (currently just `fluent-bit`) by name from a Chocolatey source, without a personal access token and without the download-then-install-from-folder dance the current release notes require:

```powershell
# Current (Releases-only) — works but two steps, needs the version in the URL
Invoke-WebRequest 'https://github.com/mkopnsrc/chocolatey-packages/releases/download/fluent-bit/latest/fluent-bit.5.0.8.nupkg' -OutFile fluent-bit.nupkg
choco install fluent-bit --source '.'

# Target (feed on GH Pages) — one step, discovers latest itself
choco source add -n mkopnsrc -s https://mkopnsrc.github.io/chocolatey-packages/nuget/index.json
choco install fluent-bit
```

## Non-goals

- Replacing CCR distribution for the ~16 packages that already ship there. Those keep the `--source https://community.chocolatey.org/api/v2/` path (the choco default).
- A private/authenticated feed. This is a **public, read-only** distribution channel for content we're OK giving away.
- Search UI. `choco search` on this feed is nice-to-have but not blocking.

## Chosen architecture

**Sleet** (`emgarten/Sleet`) generates a fully-compliant NuGet v3 feed onto a runner-local folder. The `publish-nupkg-release.yml` workflow uploads that folder as a **GitHub Pages artifact** (`actions/upload-pages-artifact`) and a second job deploys it via `actions/deploy-pages`. No persistent branch.

```
publish-nupkg-release.yml
├── pack-and-release (windows-2022)
│    1. build nupkg
│    2. attach to GitHub Release
│    3. sleet init + push into $RUNNER_TEMP/pages-site/nuget/
│    4. actions/upload-pages-artifact  ─────────────┐
│                                                    │
└── deploy-pages (ubuntu-latest, needs: above)      │
     • actions/deploy-pages  ◄────────────────── artifact
     • Pages source = "GitHub Actions"

                                     served at
                                     ▼
                     https://mkopnsrc.github.io/chocolatey-packages/nuget/
```

Users get a proper NuGet v3 feed URL. Chocolatey (2.x+ supports v3) can install, upgrade, and search from it. Repo Pages source must be set to **"GitHub Actions"** in Settings → Pages.

### Version scope

**Only the currently-published version** lives in the feed at any time (`sleet init` runs fresh each publish, `sleet push` adds just this run's nupkg). For pinned older versions users install from the GitHub Release URL (`fluent-bit/<X.Y.Z>` tag) directly. Rationale: keeps the deploy trivially reproducible from CI, no state to preserve between runs. If we ever want history in the feed, add a step that downloads previous versions from Releases before `sleet init`.

### Why Sleet?

I considered three implementation paths. Summary:

| | Sleet | DIY minimal v3 | BaGetter |
|---|---|---|---|
| Correctness | battle-tested v3 output | risk of subtle bugs (registration blob is complex) | correct, official-ish |
| Storage | .nupkgs in Pages branch | .nupkgs in Pages branch | needs a persistent DB |
| Ops burden | Sleet binary + one-shot per publish | ~200 LoC PowerShell to maintain | requires a hosted server |
| Auth needed by clients | none | none | none, but the server is not free/static |
| Fits GH Pages | yes | yes | **no** — needs a running process |

Sleet + Pages wins on correctness for the least code.

### Why Actions Pages deploy (not a `gh-pages` branch)?

- **No branch clutter**: repo stays clean; no 25 MB nupkgs accumulating in `gh-pages` git history over time.
- **Matches repo's Pages source**: this repo's Pages source is set to "GitHub Actions" (chosen by the maintainer). A `gh-pages`-branch design would have required flipping that setting.
- **No `contents: write` needed on the token**: `deploy-pages` uses OIDC (`id-token: write`) + `pages: write`, so the workflow's GITHUB_TOKEN doesn't need repo-write scope for feed publishes.
- **Deployment tracking**: Pages shows deployment history + `page_url` output through the `github-pages` environment.

### Storage growth mitigation

Not needed under the current single-version design (feed is regenerated fresh each publish). If we later expand the feed to include historical versions, `sleet retention prune --stable 5 --prerelease 1` is already wired in and would apply automatically.

The `<pkg>/latest` rolling GitHub Release tag we already have serves the "latest" convenience for users who don't want to install via the feed.

## Concrete file layout

Contents of the Pages artifact (uploaded from `$RUNNER_TEMP/pages-site/`):

```
/                                                # Pages site root
├── index.html                                   # landing page (choco source add example)
└── nuget/
    ├── index.json                               # NuGet v3 service index
    ├── flatcontainer/
    │   └── fluent-bit/
    │       ├── index.json                       # {"versions":["5.0.8"]}
    │       └── 5.0.8/
    │           ├── fluent-bit.5.0.8.nupkg       # the actual nupkg (~24 MB)
    │           └── fluent-bit.nuspec            # standalone nuspec
    ├── registration/
    │   └── fluent-bit/
    │       ├── index.json                       # paginated version list w/ metadata
    │       └── 5.0.8.json                       # per-version registration blob
    ├── search/                                  # sleet-generated search index
    ├── autocomplete/                            # sleet-generated autocomplete
    └── sleet.settings.json                      # sleet internal metadata (harmless)
```

## Workflow integration

`publish-nupkg-release.yml` has two jobs:

```yaml
jobs:
  pack-and-release:              # windows-2022, unchanged core work
    steps:
      # (existing) build nupkg, install/uninstall test, GitHub Release
      - Generate Sleet feed into Pages-artifact folder
      - actions/upload-pages-artifact@v3  path: $RUNNER_TEMP/pages-site

  deploy-pages:                  # ubuntu-latest
    needs: pack-and-release
    permissions: { pages: write, id-token: write }
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - id: deploy
        uses: actions/deploy-pages@v4
```

`sleet.json` is generated inline in the workflow (path is runner-specific; baseURI is fixed).

## Rollout steps (once this design lands)

1. **PR B.1** ✅ — design doc.
2. **PR B.2** ✅ — initial Sleet + `gh-pages`-branch implementation (superseded below).
3. **PR B.2b** — refactor to Actions Pages deploy (this document version). Repo's Pages source must be set to "GitHub Actions" (already done). No branch bootstrap needed.
4. **PR B.3** — smoke test on a fresh Windows runner: `choco source add` + `choco install fluent-bit` against the live feed URL. Fold results back into README.

## Open questions

- **CCR packages on the feed too?** Currently only `fluent-bit` is a candidate (embedded binary). If we wanted `moderncsv` / `thinkorswim` / etc. also mirrored on the static feed, that's a straight extension: pack them same way, push to the same feed. Trade-off: mirror-lag vs. one-stop shopping. Default: no, keep CCR-only where CCR works.
- **Retention count.** 5 is a guess. `fluent-bit` releases every few months, so 5 = ~1-2 years of history. Adjust when we have more usage data.
- **Search endpoint.** Sleet generates a static search index by default. Works for `choco search fluent-bit`. No extra work.
