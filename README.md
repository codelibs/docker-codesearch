# Code Search on Fess

[Fess](https://fess.codelibs.org/) is an Enterprise Search Server. This Docker environment provides a Source Code Search Server using Fess.

## Public Site

* [codesearch.codelibs.org](https://codesearch.codelibs.org/)

## Architecture / Theme Model

- **Theme**: Fess 15.7 static theme system — `theme.default=codesearch` in `system.properties` selects the codesearch theme. No virtual-host routing is needed for theme activation.
- **Fess config**: Codesearch-specific settings are passed via `-Dfess.config.*` options in `FESS_JAVA_OPTS` (see `compose.yaml`). There is no `fess_config.properties` file.
- **system.properties**: The live file (`data/fess/opt/fess/system.properties`) is generated from `data/fess/opt/fess/system.properties.template` by `setup.sh` on first run. The live file is git-ignored so local edits (e.g. changing the cipher key) are not accidentally committed.
- **Theme files**: The codesearch static theme is fetched from the [fess-themes](https://github.com/codelibs/fess-themes) repository by `setup.sh` and stored in `data/fess/themes/codesearch/`. This directory is mounted into the container at `/usr/share/fess/app/themes/codesearch`.
- **index.filetype**: Dropped; Fess 15.7 default applies.

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
2. Download Fess plugins (fess-script-groovy, fess-ds-git)
3. Fetch the codesearch static theme from fess-themes (if not already present)
4. Generate `data/fess/opt/fess/system.properties` from the template (if not already present)

> **Note**: The codesearch theme must be merged into the `main` branch of [fess-themes](https://github.com/codelibs/fess-themes) before `setup.sh` can fetch it.

### Start the Server

To start the server, use Docker Compose:

```bash
docker compose -f compose.yaml up -d
```

Once the server is running, access it at [http://localhost:8080/](http://localhost:8080/).

> **Re-index required**: The Fess 15.7 + OpenSearch 3.6.0 version bump requires a full re-index on first run. Start the `Default Crawler` from the Admin Scheduler page to rebuild the index.

### Create an Access Token

To use the Admin API for Fess, create an access token with the `{role}admin-api` permission on the Admin Access Token page ([http://localhost:8080/admin/accesstoken/](http://localhost:8080/admin/accesstoken/)).

For more details, see the [Admin Access Token Guide](https://fess.codelibs.org/14.14/admin/accesstoken-guide.html).

### Register GitHub Repositories

You can create DataStore and Scheduler settings on Fess using the `bin/register_github.sh` script:

```bash
register_github.sh ACCESS_TOKEN FESS_URL REPO_DOMAIN REPO_ORG REPO_NAME

Example:
$ bash ./bin/register_github.sh ...token... http://localhost:8080 github.com codelibs fess
```

Check the created settings on the DataConfig page ([http://localhost:8080/admin/dataconfig/](http://localhost:8080/admin/dataconfig/)).

### Start the Crawler

To start the crawler, run `Default Crawler` or `Data Crawler - ...` on the Admin Scheduler page ([http://localhost:8080/admin/scheduler/](http://localhost:8080/admin/scheduler/)).

### Search

You can view search results at [http://localhost:8080/](http://localhost:8080/).

### Stop the Server

To stop the server, use the following command:

```bash
docker compose -f compose.yaml down
```

## Configuration

### Fess settings (FESS_JAVA_OPTS)

Codesearch-specific Fess configuration is passed as `-Dfess.config.*` options in `FESS_JAVA_OPTS` in `compose.yaml`. Edit `compose.yaml` to change these settings.

**Important**: Change the cipher key before deploying to production:
```yaml
-Dfess.config.app.cipher.key=your-secret-key-here
```

### system.properties

To modify system-level Fess settings, edit `data/fess/opt/fess/system.properties.template` and re-run `setup.sh`, or edit the live `data/fess/opt/fess/system.properties` directly. The live file is git-ignored.

## Optional: AI Chat (RAG)

To enable AI-powered chat on search results, add the following to `FESS_JAVA_OPTS` in `compose.yaml` and install an LLM plugin:

```yaml
-Dfess.config.rag.chat.enabled=true
```

AI chat is disabled by default. See [Fess LLM plugins](https://github.com/codelibs?q=fess-llm) for available LLM integrations.

## Updating

To update to the latest code, use plain `git pull`:

```bash
git pull
```

`bin/git_pull.sh` has been removed. Live data files (`system.properties`, theme assets) are git-ignored and will not be overwritten by `git pull`.

After updating, re-run `setup.sh` if plugin versions or theme assets have changed:

```bash
bash ./bin/setup.sh
```
