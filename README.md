# Code Search on Fess

[Fess](https://fess.codelibs.org/) is an Enterprise Search Server. This Docker environment provides a Source Code Search Server using Fess.

## Public Site

* [codesearch.codelibs.org](https://codesearch.codelibs.org/)

## Architecture / Theme Model

- **Theme**: Fess 15.7 static theme system — `theme.default=codesearch` in `system.properties` selects the codesearch theme. No virtual-host routing is needed for theme activation.
- **Fess config (`fess_config.properties`)**: `setup.sh` generates `data/fess/opt/fess/fess_config.properties` from the upstream base for the pinned Fess version plus the codesearch overlay (`conf/fess_config.overlay.properties`) and an optional local override (`conf/fess_config.local.properties`). It is mounted at `/opt/fess`, which the image places ahead of its `/etc/fess` default on the classpath, so the generated file takes effect. Only the delta is tracked in git; the base auto-tracks the pinned version. See [Configuration](#configuration).
- **Version pins (`.env`)**: `FESS_VERSION` / `OPENSEARCH_VERSION` are the single source of truth for the image tags (`compose.yaml`) and the `fess_config.properties` base.
- **system.properties**: The live file (`data/fess/opt/fess/system.properties`) is generated from `data/fess/opt/fess/system.properties.template` by `setup.sh` on first run. The live file is git-ignored.
- **Theme files**: The codesearch static theme is fetched from the [fess-themes](https://github.com/codelibs/fess-themes) repository by `setup.sh` and stored in `data/fess/themes/codesearch/`. This directory is mounted into the container at `/usr/share/fess/app/themes/codesearch`.
- **index.filetype**: Source-code aware mimetype→label map, maintained in `conf/fess_config.overlay.properties` (a multi-line value, so it lives in the file rather than a `-D` flag).
- **Management CLI (`fessctl`)**: Repositories are registered and crawls are triggered with [`fessctl`](https://github.com/codelibs/fessctl), the official Fess admin-API CLI (see [Install fessctl](#install-fessctl)).

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
3. Fetch the codesearch static theme from fess-themes (if not already present)
4. Generate `data/fess/opt/fess/system.properties` from the template (if not already present)
5. Generate `data/fess/opt/fess/fess_config.properties` from the pinned base + codesearch overlay

### Start the Server

To start the server, use Docker Compose:

```bash
docker compose -f compose.yaml up -d
```

Once the server is running, access it at [http://localhost:8080/](http://localhost:8080/).

The first start initializes the search indices in OpenSearch (this can take a minute or two). The site has no documents until you register a repository and run a crawler (see below).

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

Create a Git data store config for each repository you want to index. The `handler-script` maps Git metadata to the codesearch fields (`organization`, `repository`, `filetype`, …) that power the search facets. Replace `codelibs` / `fess-suggest` / `master` with your own organization, repository, and default branch:

```bash
fessctl dataconfig create \
  --name "github.com/codelibs/fess-suggest" \
  --handler-name GitDataStore \
  --handler-parameter 'uri=https://github.com/codelibs/fess-suggest.git
base_url=https://github.com/codelibs/fess-suggest/blob/master/
extractors=text/.*:textExtractor,application/xml:textExtractor,application/javascript:textExtractor,application/json:textExtractor,application/x-sh:textExtractor,application/x-bat:textExtractor,audio/.*:filenameExtractor,chemical/.*:filenameExtractor,image/.*:filenameExtractor,model/.*:filenameExtractor,video/.*:filenameExtractor,
delete_old_docs=false
repository_path=/home/fess/workspace/fess-suggest' \
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
docker compose -f compose.yaml up -d
```

> **Re-index after a major version bump**: a Fess or OpenSearch major upgrade can change the index format. If search returns errors or stops returning results after upgrading, re-crawl your repositories with `fessctl scheduler start default_crawler` to rebuild the index.
