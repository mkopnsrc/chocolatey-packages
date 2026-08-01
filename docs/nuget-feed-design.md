# Static NuGet v3 feed on GitHub Pages — design

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

**Sleet** (`emgarten/Sleet`) generates a fully-compliant NuGet v3 feed onto a filesystem folder. Serve that folder from a `gh-pages` orphan branch via GitHub Pages.

```
                                             gh-pages branch (orphan history)
                                             ┌──────────────────────────────┐
publish-nupkg-release.yml                    │ /nuget/                      │
  1. build nupkg                             │   index.json (service index) │
  2. attach to GitHub Release  ─── done ───► │   flatcontainer/             │
  3. push nupkg into Sleet feed  ────────► │     fluent-bit/              │
                                             │       index.json (versions)  │
                                             │       5.0.8/                 │
                                             │         fluent-bit.5.0.8.nupkg  │← duplicated storage
                                             │         fluent-bit.nuspec    │
                                             │   registration/…             │
                                             │   catalog/…                  │
                                             └──────────────────────────────┘
                                             ▲
                                             │ GitHub Pages serves this
                                             │
                             https://mkopnsrc.github.io/chocolatey-packages/nuget/
```

Users get a proper NuGet v3 feed URL. Chocolatey (2.x+ supports v3) can install, upgrade, search, list versions — the full feed API.

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

### Why an orphan `gh-pages` branch (not `docs/` on master)?

- **History**: `docs/`-on-master forces every published nupkg (25 MB × N versions × N packages) into main branch history forever. `gh-pages` as an orphan branch (`git checkout --orphan gh-pages` and re-created each cycle) keeps main lean and history-frozen at the current feed contents.
- **Isolation**: nothing on `gh-pages` will trigger `master` CI or vice versa.
- **Convention**: this is the standard GH Pages layout for tool-generated static sites (e.g. `mkdocs gh-deploy`, `sleet push`).

### Storage growth mitigation

`sleet retention` lets us cap versions per package. Proposed: **keep last 5 versions per package**, so `fluent-bit`'s footprint stays around 5 × 25 MB = 125 MB in the branch. Well under GH Pages's 1 GB soft limit even with more packages added later.

The `latest` moving pointer we already have on Releases (`<pkg>/latest`) serves the same "latest" convenience for users who don't want to install via the feed.

## Concrete file layout

Feed contents (all under `/nuget/` at the Pages root):

```
nuget/
├── index.json                                   # service index
├── flatcontainer/
│   └── fluent-bit/
│       ├── index.json                           # {"versions":["5.0.8"]}
│       └── 5.0.8/
│           ├── fluent-bit.5.0.8.nupkg           # the actual nupkg
│           └── fluent-bit.nuspec                # standalone nuspec
├── registration/
│   └── fluent-bit/
│       ├── index.json                           # paginated version list w/ metadata
│       └── 5.0.8.json                           # per-version registration blob
├── catalog/                                     # optional but sleet emits it
│   └── …
├── search/                                      # optional search index
│   └── query
└── sleet.settings.json                          # sleet metadata (not served)
```

## Workflow integration

Extend `publish-nupkg-release.yml` with a new step that runs **only when `publish_release=true`** (immediately after the Release is cut):

```yaml
- name: Publish to static NuGet feed on gh-pages
  if: ${{ inputs.publish_release && success() }}
  env:
    SLEET_FEED_URL: https://mkopnsrc.github.io/chocolatey-packages/nuget/
  run: |
    # 1. dotnet tool install --global sleet
    # 2. git worktree add ../feed gh-pages   (or checkout --orphan if empty)
    # 3. sleet init --config sleet.json      (idempotent — no-op if exists)
    # 4. sleet push $nupkg --config sleet.json
    # 5. sleet retention --config sleet.json --hours <cutoff-N-versions>
    # 6. commit + push gh-pages
```

Sleet's config file (`sleet.json`) is checked into master and points at the local worktree folder — the workflow orchestrates the branch checkout/commit. This keeps the feed-generation logic declarative.

## Rollout steps (once this design lands)

Split across two PRs to keep review chunks small:

1. **PR B.1 (this PR)** — design doc only. Get direction confirmed.
2. **PR B.2** — implement:
   - `sleet.json` config
   - `publish-nupkg-release.yml` new step
   - `gh-pages` branch bootstrapped with the current `fluent-bit/5.0.8` feed
   - GH Pages enabled on the repo (requires one manual click in Settings → Pages, source = `gh-pages` branch, root)
   - README updated to document the new `choco source add` install path
3. **PR B.3** — smoke test on a fresh Windows runner: `choco source add` + `choco install fluent-bit` against the live feed. Fold results back into README.

## Open questions

- **CCR packages on the feed too?** Currently only `fluent-bit` is a candidate (embedded binary). If we wanted `moderncsv` / `thinkorswim` / etc. also mirrored on the static feed, that's a straight extension: pack them same way, push to the same feed. Trade-off: mirror-lag vs. one-stop shopping. Default: no, keep CCR-only where CCR works.
- **Retention count.** 5 is a guess. `fluent-bit` releases every few months, so 5 = ~1-2 years of history. Adjust when we have more usage data.
- **Search endpoint.** Sleet generates a static search index by default. Works for `choco search fluent-bit`. No extra work.
