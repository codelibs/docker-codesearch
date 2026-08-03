# Code Search on Fess

[Fess](https://fess.codelibs.org/) is an Enterprise Search Server. This Docker environment provides a Source Code Search Server using Fess.

## Public Site

* [codesearch.codelibs.org](https://codesearch.codelibs.org/)

## Architecture / Theme Model

- **Theme**: Fess 15.7 static theme system — `theme.default=codesearch` in `system.properties` selects the codesearch theme. No virtual-host routing is needed for theme activation.
- **Fess config (`fess_config.properties`)**: `setup.sh` generates `data/fess/opt/fess/fess_config.properties` from the upstream base for the pinned Fess version plus the codesearch overlay (`conf/fess_config.overlay.properties`) and an optional local override (`conf/fess_config.local.properties`). It is mounted at `/opt/fess`, which the image places ahead of its `/etc/fess` default on the classpath, so the generated file takes effect. Only the delta is tracked in git; the base auto-tracks the pinned version. See [Configuration](#configuration).
- **Version pins (`.env`)**: `FESS_VERSION` / `OPENSEARCH_VERSION` are the single source of truth for the image tags (`compose.yaml`) and the `fess_config.properties` base.
- **system.properties**: The live file (`data/fess/opt/fess/system.properties`) is generated from `data/fess/opt/fess/system.properties.template` by `setup.sh` on first run. The live file is git-ignored.
- **Theme files**: The codesearch static theme is fetched from the [fess-themes](https://github.com/codelibs/fess-themes) repository by `setup.sh` (re-fetched on every run; set `FESS_THEMES_SKIP_FETCH=1` to keep the local copy) and stored in `data/fess/themes/codesearch/`. This directory is mounted into the container at `/usr/share/fess/app/themes/codesearch`. The theme requires the facet fields configured in the overlay — see [Troubleshooting](#troubleshooting).
- **index.filetype**: Source-code aware mimetype→label map, maintained in `conf/fess_config.overlay.properties` (a multi-line value, so it lives in the file rather than a `-D` flag).
- **Management CLI (`fessctl`)**: Repositories are registered and crawls are triggered with [`fessctl`](https://github.com/codelibs/fessctl), the official Fess admin-API CLI (see [Install fessctl](#install-fessctl)).
- **Verification (`bin/verify.sh`)**: Checks at runtime that the generated config is in effect and that the live index has the codesearch fields mapped. Run it after `setup.sh` and after any version bump (see [Verify the Setup](#verify-the-setup)).

## Getting Started

### Setup

First, clone the repository and navigate into the directory:

```bash
$ git clone https://github.com/codelibs/docker-codesearch.git
$ cd docker-codesearch
$ bash ./bin/setup.sh
```

`setup.sh` will:
1. Create required data directories
2. Download the Fess data store plugin (fess-ds-git)
3. Fetch the codesearch static theme from fess-themes
4. Generate `data/fess/opt/fess/system.properties` from the template (if not already present)
5. Generate `data/fess/opt/fess/fess_config.properties` from the pinned base + codesearch overlay

`setup.sh` aborts on the first failure and exits non-zero. Do not start the stack after a failed run: a missing `fess_config.properties` boots a Fess that looks healthy but returns 0 hits for every search (see [Troubleshooting](#troubleshooting)).

### Start the Server

To start the server, use Docker Compose:

```bash
docker compose -f compose.yaml up -d
```

Once the server is running, access it at [http://localhost:8080/](http://localhost:8080/).

The first start initializes the search indices in OpenSearch (this can take a minute or two). The site has no documents until you register a repository and run a crawler (see below).

### Verify the Setup

The first start is also the only chance to get the index mapping right, so check it before crawling:

```bash
bash ./bin/verify.sh
```

It confirms that the generated `fess_config.properties` is in effect (including the facet allowlist the theme depends on) and that the live index really has the codesearch fields mapped. It prints the remedy for whatever it finds and exits non-zero on failure.

Once documents are indexed, it also probes the search API by comparing the theme's faceted request against the same query without facets — a rejected facet field makes only the faceted count collapse to 0. Set `VERIFY_QUERY` if `test` matches nothing in your repositories.

### Create an Access Token

`fessctl` (used in the next steps) authenticates to Fess with an access token. Create one with the `{role}admin-api` permission on the Admin Access Token page ([http://localhost:8080/admin/accesstoken/](http://localhost:8080/admin/accesstoken/)).

For more details, see the [Admin Access Token Guide](https://fess.codelibs.org/15.7/admin/accesstoken-guide.html).

### Install fessctl

Repositories are registered and crawls are triggered with [`fessctl`](https://github.com/codelibs/fessctl), the official CLI for the Fess Admin API:

```bash
pipx install fessctl      # or: uv tool install fessctl
```

`fessctl` requires Python 3.13+ (`pipx` / `uv` provide it automatically). Point it at the server and the access token created above:

```bash
export FESS_ENDPOINT=http://localhost:8080
export FESS_ACCESS_TOKEN=<your-access-token>
export FESS_VERSION=15.7.0
fessctl ping    # reports the search engine status (GREEN when ready)
```

> `fessctl` can also be run from its container image (`ghcr.io/codelibs/fessctl`); see the [fessctl README](https://github.com/codelibs/fessctl) for details.

### Register a Repository

Create a Git data store config for each repository you want to index. The `handler-script` maps Git metadata to the codesearch fields (`organization`, `repository`, `filetype`, …) that power the search facets. Replace `codelibs` / `fess-suggest` / `master` with your own organization, repository, and default branch. Set `commit_id` explicitly to that branch — left at the GitDataStore default (`HEAD`), the plugin's own HEAD-resolution fallback can fail against GitHub for repositories whose default branch isn't literally `master`:

```bash
fessctl dataconfig create \
  --name "github.com/codelibs/fess-suggest" \
  --handler-name GitDataStore \
  --handler-parameter 'uri=https://github.com/codelibs/fess-suggest.git
base_url=https://github.com/codelibs/fess-suggest/blob/master/
extractors=text/.*:textExtractor,application/xml:textExtractor,application/javascript:textExtractor,application/json:textExtractor,application/x-sh:textExtractor,application/x-bat:textExtractor,audio/.*:filenameExtractor,chemical/.*:filenameExtractor,image/.*:filenameExtractor,model/.*:filenameExtractor,video/.*:filenameExtractor,
delete_old_docs=false
repository_path=/home/fess/workspace/fess-suggest
commit_id=master' \
  --handler-script 'url=url
host="github.com"
site="github.com/codelibs/fess-suggest/" + path
title=name
content=container.getComponent("documentHelper").appendLineNumber("L", content)
digest=author.toExternalString()
content_length=contentLength
last_modified=timestamp
timestamp=timestamp
filename=name
mimetype=mimetype
domain="github.com"
organization="codelibs"
repository="fess-suggest"
path=path
repository_url="https://github.com/codelibs/fess-suggest"
filetype=container.getComponent("fileTypeHelper").get(mimetype)' \
  --permission "{role}guest"
```

Review the registered repositories on the [DataConfig page](http://localhost:8080/admin/dataconfig/).

### Run the Crawler

Trigger the built-in **Default Crawler**, which crawls every registered data store config:

```bash
fessctl scheduler start default_crawler
```

It also runs daily on its own schedule, so newly registered repositories are picked up automatically. Follow progress on the [Scheduler page](http://localhost:8080/admin/scheduler/) (Job Log), or watch results appear on the search page.

### Search

You can view search results at [http://localhost:8080/](http://localhost:8080/).

### Stop the Server

To stop the server, use the following command:

```bash
docker compose -f compose.yaml down
```

## Configuration

### Fess settings (fess_config.properties)

Codesearch-specific `fess_config.properties` settings are maintained as a small delta in `conf/fess_config.overlay.properties`. `setup.sh` (via `bin/render-fess-config.sh`) fetches the upstream base for the pinned `FESS_VERSION` and overlays this delta to generate `data/fess/opt/fess/fess_config.properties`. After editing the overlay, re-run `setup.sh` (or `bash ./bin/render-fess-config.sh`).

**Secrets / per-deployment values** (e.g. the cipher key, the initial admin password) must **not** go in the tracked overlay. Create `conf/fess_config.local.properties` (git-ignored) — its keys are applied last and win:

```properties
app.cipher.key=your-secret-key-here
index.user.initial_password=your-admin-password
```

> The cipher key encrypts stored credentials; set it **before first boot**, because changing it later invalidates already-encrypted data.

### system.properties

To modify system-level Fess settings, edit `data/fess/opt/fess/system.properties.template` and re-run `setup.sh`, or edit the live `data/fess/opt/fess/system.properties` directly. The live file is git-ignored.

## Optional: AI Chat (RAG)

To enable AI-powered chat on search results, add the following to `conf/fess_config.local.properties` (or the overlay) and install an LLM plugin, then re-run `setup.sh`:

```properties
rag.chat.enabled=true
```

AI chat is disabled by default. See [Fess LLM plugins](https://github.com/codelibs?q=fess-llm) for available LLM integrations.

## Updating

To update to the latest code, use plain `git pull`:

```bash
git pull
```

Live/generated files (`system.properties`, `fess_config.properties`, theme assets) are git-ignored and will not be overwritten by `git pull`.

To upgrade the Fess / OpenSearch version, edit the pins in `.env` (`FESS_VERSION`, `OPENSEARCH_VERSION`) and re-run `setup.sh`. The `fess_config.properties` base is re-fetched for the new version and the codesearch overlay is re-applied automatically:

```bash
bash ./bin/setup.sh
bash ./bin/verify.sh
docker compose -f compose.yaml up -d
```

`FESS_VERSION` is a `ghcr.io/codelibs/fess` image tag, and `render-fess-config.sh` maps it to the `codelibs/fess` git ref that holds the matching base config:

| `FESS_VERSION` | base ref |
|----------------|----------|
| `15.7.0`, `15.6.1`, … | `fess-<version>` (the release tag) |
| `15.7.0-noble`, `15.7.0-al2023` | `fess-<version>` (the OS suffix is dropped) |
| `snapshot`, `snapshot-noble`, `snapshot-al2023`, `15.8.0-SNAPSHOT` | `master` |
| anything else (`latest`, `15.7`, …) | **rejected** — pin an explicit release, or set `FESS_CONFIG_BASE_REF` |

Floating tags are rejected on purpose: `latest` has no matching source ref, so there is no way to render a base config that is guaranteed to match the running image. For a ref this mapping does not cover — an unreleased version, or a maintenance branch — name it explicitly:

```bash
FESS_CONFIG_BASE_REF=15.8.x bash ./bin/render-fess-config.sh
```

Plugin versions are **not** derived from `FESS_VERSION` — snapshot images have no matching plugin release. Override them per plugin if the pinned one is too old, e.g. `FESS_DS_GIT_VERSION=15.8.0 bash ./bin/setup.sh`.

### Index schema (`fess_indices/_codesearch`)

`data/fess/usr/share/fess/app/WEB-INF/classes/fess_indices/_codesearch/` is a **hand-maintained fork** of the upstream index schema, selected by `search_engine.type=codesearch`. It carries genuine codesearch tuning that has no upstream equivalent — the `line_number_filter` char filter that strips the `L<n>:` prefix added by the handler script, code-aware `operator_filter` / `dotnum_filter` / `code_stop_filter` tokenization, and the seven codesearch document fields (`domain`, `organization`, `repository`, `path`, `repository_url`, `owner`, `homepage`).

Unlike `fess_config.properties`, it is **not** regenerated per version, so it can drift from upstream. `bin/verify.sh` reports the dangerous direction (a core field the running Fess expects that the fork lacks) as an advisory `WARN`; it currently reports none for 15.7.0. Refresh it by hand when upstream adds document fields.

> **Re-index after a major version bump**: a Fess or OpenSearch major upgrade can change the index format. If search returns errors or stops returning results after upgrading, re-crawl your repositories with `fessctl scheduler start default_crawler` to rebuild the index.

## Troubleshooting

### Search returns no results at all

Every query comes back empty — from the top page, the result page and the help page alike — while the admin UI works and `fess.log` only shows:

```
WARN Main searcher failed to execute search for query: ...
org.codelibs.fess.exception.SearchQueryException: Invalid facet field: repository
```

Run `bash ./bin/verify.sh`; it distinguishes the two causes below. Both mean the generated `data/fess/opt/fess/fess_config.properties` was not in effect (a failed or skipped `setup.sh`), because that file is what carries the codesearch settings — Fess otherwise falls back to the stock config baked into the image.

1. **`query.additional.facet.fields` does not list the codesearch fields.** The theme facets on `repository`, `organization` and `filename` on every search, and Fess validates facet fields against that allowlist only — never against the index mapping. One unlisted field aborts the entire search, and older Fess versions report it as an empty result set instead of an error. Fix by re-running `setup.sh` and restarting the container.

2. **The index was created without the codesearch fields.** `search_engine.type=codesearch` selects the `_codesearch` index schema, and it is read only when the index is created. If the very first boot ran on stock defaults, correcting the config later does **not** repair the index — Fess applies a mapping only to an index that has none yet. Rebuild it:

   1. open [http://localhost:8080/admin/maintenance/](http://localhost:8080/admin/maintenance/) and run **Reindex**
   2. re-crawl with `fessctl scheduler start default_crawler`

   On a deployment with no documents worth keeping, deleting the `fess.*` indices and restarting `fess01` is equivalent and faster.
