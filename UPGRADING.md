# Upgrading

Steps for moving an existing Code Search deployment to a newer version. For a fresh install, see [README.md](README.md).

## Upgrading from Fess 15.8 to 15.9

Fess 15.9 moved the Groovy script engine out of core into the `fess-script-groovy` plugin and made JavaScript the default script type. An upgrade does not rewrite stored settings, so a 15.8 install keeps Groovy on all of its scheduled jobs, and the data configs `register_github.sh` created on 15.8 carry no `script_type` — which also means Groovy. This deployment does not install `fess-script-groovy` (the `WEB-INF/plugin` bind mount hides the copy baked into the image, and `setup.sh` removes plugin jars it did not download), so on 15.9 those settings cannot run: the Default Crawler ends with `fail`, and `fess.log` shows `Settings use the script engine groovy, which is not registered` at startup and `groovy is not found` per job.

Switch them to JavaScript once, right after the upgrade:

```bash
# 1. set FESS_VERSION=15.9.x in .env, then
bash ./bin/setup.sh
docker compose -f compose.yaml up -d
# 2. once Fess is up (the documents in the index are kept as they are)
bash ./bin/migrate-to-javascript.sh --dry-run   # lists what would change
bash ./bin/migrate-to-javascript.sh
docker compose -f compose.yaml restart fess01   # optional: clears the startup warning
```

`migrate-to-javascript.sh` uses `fessctl` (same `FESS_ENDPOINT` / `FESS_ACCESS_TOKEN` as above) and:

* sets every scheduled job whose script type is Groovy to JavaScript. The two Groovy-only constructs in the bundled 15.8 jobs are rewritten on the way — the `1000L` long literal in *Thumbnail Purger* and the `org.opensearch` package Fess 15.9 renamed in *Index Exporter* — so the result is the job set Fess 15.9 ships;
* adds `script_type=javascript` to the Parameter of every data config that has none (or `groovy`). The handler script `register_github.sh` writes is valid JavaScript as is.

It prints every setting it changes. A job or handler script you customized with other Groovy syntax is switched as well and has to be rewritten by hand. The alternative is to keep Groovy: add `fess-script-groovy` to `fess_plugins` in `setup.sh`. On 15.9, `register_github.sh` records `script_type=javascript` itself, so repositories registered after the upgrade need nothing.

## Re-indexing after an upgrade

The schema and fields referred to below are described under [Index schema](README.md#index-schema-fess_indices_codesearch) in the README.

> **Existing indexes**: analyzer and mapping changes to this schema apply only to a newly created index. After updating from a version whose language analyzers lacked `line_number_filter`, run **Reindex** on [http://localhost:8080/admin/maintenance/](http://localhost:8080/admin/maintenance/) (it rebuilds the index from the current schema and keeps the documents), or delete the `fess.*` indices, restart `fess01` and re-crawl.

> **Re-index after a major version bump**: a Fess or OpenSearch major upgrade can change the index format. If search returns errors or stops returning results after upgrading, re-crawl your repositories with `fessctl scheduler start default_crawler` to rebuild the index. An index created by an older version keeps its original mapping — Fess applies a mapping only to an index that has none yet — so an in-place upgrade will not pick up the fields above until the index is rebuilt.
