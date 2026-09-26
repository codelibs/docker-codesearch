#!/usr/bin/env bash
#
# migrate-to-javascript.sh — switch the scripts a Fess 15.8 install stored to
# JavaScript after upgrading it to Fess 15.9 (via fessctl).
#
# Fess 15.9 moved Groovy out of core into the fess-script-groovy plugin and made
# JavaScript the default. An upgrade does not rewrite what is stored in the index,
# so a 15.8 install keeps Groovy on every scheduled job and on every data config
# registered without a script_type (an unset type means Groovy). This deployment
# does not install fess-script-groovy (the WEB-INF/plugin bind mount hides the one
# baked into the image), so after the upgrade those jobs fail - the Default Crawler
# first - and Fess logs "Settings use the script engine groovy, which is not
# registered" at startup.
#
# This script, run once against the upgraded 15.9 server:
#   * scheduled jobs with script type groovy (or none): sets the type to
#     javascript and rewrites the two constructs the 15.8 bundled jobs need
#     changed - the Groovy long literal (1000L -> 1000, Thumbnail Purger) and the
#     org.opensearch package that 15.9 renamed (Index Exporter). The result is
#     exactly the job script Fess 15.9 ships.
#   * data configs with script_type groovy (or none): sets script_type=javascript.
#     The handler script written by register_github.sh is valid JavaScript as is.
#
# Scripts you customized in Groovy beyond that are switched too; every change is
# printed, so review them (or run with --dry-run first).
#
# Connection/auth use fessctl's own environment variables:
#   FESS_ENDPOINT      Fess base URL          (default: http://localhost:8080)
#   FESS_ACCESS_TOKEN  admin-api access token (required)
#   FESS_VERSION       Fess version           (default: FESS_VERSION in .env; 15.9 or later)
#
# Requirements: fessctl (https://github.com/codelibs/fessctl), python3.
set -euo pipefail

usage() {
  cat <<'EOF'
migrate-to-javascript.sh — switch 15.8-era Groovy jobs and data configs to JavaScript on Fess 15.9.

Usage:
  FESS_ACCESS_TOKEN=<token> ./bin/migrate-to-javascript.sh [--dry-run]

Options:
  -n, --dry-run   Print what would change; do not update anything
  -h, --help      Show this help and exit
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry_run=1; shift;;
    -h|--help)    usage; exit 0;;
    *)            usage >&2; die "unknown argument: $1";;
  esac
done

command -v fessctl >/dev/null 2>&1 || die "fessctl not found. Install with: pipx install fessctl (or: uv tool install fessctl). See https://github.com/codelibs/fessctl"
command -v python3 >/dev/null 2>&1 || die "python3 not found."
[ -n "${FESS_ACCESS_TOKEN:-}" ] || die "FESS_ACCESS_TOKEN is not set (an admin-api access token)."
: "${FESS_ENDPOINT:=http://localhost:8080}"; export FESS_ENDPOINT
# Same FESS_VERSION handling as register_github.sh: default to the .env pin and
# drop an image-tag suffix, since fessctl accepts only <x.y.z>.
base_dir=$(cd "$(dirname "$0")/.." && pwd)
[ -n "${FESS_VERSION:-}" ] || FESS_VERSION=$(sed -n 's/^FESS_VERSION=//p' "${base_dir}/.env" 2>/dev/null | tail -1)
FESS_VERSION="${FESS_VERSION%%-*}"
case "$FESS_VERSION" in
  [0-9]*.[0-9]*) export FESS_VERSION ;;
  *) die "fessctl needs a numeric FESS_VERSION (e.g. 15.9.0), not '${FESS_VERSION}'." ;;
esac
# Fess 15.8 and earlier have no JavaScript engine: switching there breaks every job.
[ "$(printf '%s\n' 15.9 "$FESS_VERSION" | sort -V | head -1)" = "15.9" ] \
  || die "run this against Fess 15.9 or later (FESS_VERSION=${FESS_VERSION}); 15.8 has no JavaScript engine."

DRY_RUN="${dry_run}" python3 - <<'PYEOF'
import json, os, re, subprocess, sys

dry_run = os.environ["DRY_RUN"] == "1"

def fessctl(*args):
    proc = subprocess.run(["fessctl", *args, "-o", "json"], capture_output=True, text=True)
    try:
        response = json.loads(proc.stdout).get("response", {})
    except ValueError:
        response = {}
    if proc.returncode != 0 or response.get("status") != 0:
        message = response.get("message") or proc.stderr.strip() or proc.stdout.strip()
        sys.exit("Error: fessctl %s failed: %s" % (" ".join(args[:2]), message))
    return response

def list_all(resource):
    settings, page = [], 1
    while True:
        response = fessctl(resource, "list", "--page", str(page), "--size", "100")
        batch = response.get("settings", [])
        settings += batch
        if not batch or len(settings) >= int(response.get("total", 0)):
            return settings
        page += 1

def is_groovy(script_type):
    return (script_type or "").strip().lower() in ("", "groovy")

def to_javascript(script):
    # Groovy long literal: JavaScript numbers take no suffix.
    script = re.sub(r"(?<![\w.])(\d+)[lL]\b", r"\1", script)
    # Fess 15.9 dropped the OpenSearch jar for its own fork of the same classes.
    return re.sub(r"\borg\.opensearch\.", "org.codelibs.fesen.opensearch.", script)

changed = 0

for job in list_all("scheduler"):
    if not is_groovy(job.get("script_type")):
        continue
    old, new = job.get("script_data") or "", to_javascript(job.get("script_data") or "")
    print("scheduled job %s (%s): %s -> javascript" % (job["id"], job.get("name"), job.get("script_type") or "(unset)"))
    if new != old:
        print("    script: %s\n        -> %s" % (old, new))
    if not dry_run:
        fessctl("scheduler", "update", job["id"], "--script-type", "javascript", "--script-data", new)
    changed += 1

for config in list_all("dataconfig"):
    params = config.get("handler_parameter") or ""
    lines = params.splitlines()
    types = [l.split("=", 1)[1] for l in lines if l.split("=", 1)[0].strip() == "script_type" and "=" in l]
    if types and not is_groovy(types[-1]):
        continue
    kept = [l for l in lines if not (l.split("=", 1)[0].strip() == "script_type" and "=" in l)]
    new_params = "\n".join(kept + ["script_type=javascript"])
    print("data config %s (%s): script_type %s -> javascript" % (config["id"], config.get("name"), types[-1] if types else "(unset)"))
    if not dry_run:
        fessctl("dataconfig", "update", config["id"], "--handler-parameter", new_params)
    changed += 1

if changed == 0:
    print("Nothing to migrate: no scheduled job or data config uses Groovy.")
elif dry_run:
    print("%d setting(s) would be switched to JavaScript (dry run; nothing changed)." % changed)
else:
    print("Switched %d setting(s) to JavaScript; they apply from the next run." % changed)
    print("Fess checks script engines only at startup, so its groovy warning stays in fess.log until fess01 restarts.")
PYEOF
