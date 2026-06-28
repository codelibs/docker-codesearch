#!/usr/bin/env bash
#
# register_github.sh — convenience wrapper around fessctl to register a Git
# repository as a codesearch data store (GitDataStore) and trigger a crawl.
#
# It wraps:
#   fessctl dataconfig create ...            (GitDataStore + codesearch field map)
#   fessctl scheduler start default_crawler  (crawls all data configs; no restart)
#
# Connection/auth use fessctl's own environment variables:
#   FESS_ENDPOINT      Fess base URL          (default: http://localhost:8080)
#   FESS_ACCESS_TOKEN  admin-api access token (required)
#   FESS_VERSION       Fess version           (default: 15.7.0)
#
# Requirements: fessctl (https://github.com/codelibs/fessctl), git, python3.
set -euo pipefail

usage() {
  cat <<'EOF'
register_github.sh — register a Git repository for code search and crawl it (via fessctl).

Usage:
  FESS_ACCESS_TOKEN=<token> ./bin/register_github.sh [options] <org> <repo>

Arguments:
  org                Repository owner / organization (e.g. codelibs)
  repo               Repository name (e.g. fess-suggest)

Options:
  -d, --domain HOST  Repository host (default: github.com)
  -b, --branch NAME  Default branch for source links (default: auto-detect)
      --owner NAME   "owner" metadata for the documents (optional)
      --homepage URL "homepage" metadata for the documents (optional)
      --no-crawl     Register the data store only; do not start the crawler
  -h, --help         Show this help and exit

Environment (consumed by fessctl):
  FESS_ENDPOINT      Fess base URL (default: http://localhost:8080)
  FESS_ACCESS_TOKEN  Admin-api access token (required)
  FESS_VERSION       Fess version (default: 15.7.0)

Examples:
  FESS_ACCESS_TOKEN=xxxx ./bin/register_github.sh codelibs fess-suggest
  FESS_ACCESS_TOKEN=xxxx ./bin/register_github.sh -b main --no-crawl myorg myrepo
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

# --- parse arguments ---
domain="github.com"
branch=""
owner=""
homepage=""
crawl=1
positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--domain)    domain="${2:?--domain needs a value}"; shift 2;;
    -b|--branch)    branch="${2:?--branch needs a value}"; shift 2;;
    --owner)        owner="${2:?--owner needs a value}"; shift 2;;
    --homepage)     homepage="${2:?--homepage needs a value}"; shift 2;;
    --no-crawl)     crawl=0; shift;;
    -h|--help)      usage; exit 0;;
    --)             shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done;;
    -*)             usage >&2; die "unknown option: $1";;
    *)              positional+=("$1"); shift;;
  esac
done

[ "${#positional[@]}" -eq 2 ] || { usage >&2; die "expected exactly <org> <repo>"; }
org="${positional[0]}"
repo="${positional[1]}"

# --- preflight checks ---
command -v fessctl >/dev/null 2>&1 || die "fessctl not found. Install with: pipx install fessctl (or: uv tool install fessctl). See https://github.com/codelibs/fessctl"
command -v git     >/dev/null 2>&1 || die "git not found."
command -v python3 >/dev/null 2>&1 || die "python3 not found."
[ -n "${FESS_ACCESS_TOKEN:-}" ] || die "FESS_ACCESS_TOKEN is not set (an admin-api access token)."
: "${FESS_ENDPOINT:=http://localhost:8080}"; export FESS_ENDPOINT
: "${FESS_VERSION:=15.7.0}";                 export FESS_VERSION

git_url="https://${domain}/${org}/${repo}.git"

# --- detect default branch if not specified ---
if [ -z "$branch" ]; then
  branch=$(git ls-remote --symref "$git_url" HEAD 2>/dev/null \
           | awk '/^ref:/ { sub(/refs\/heads\//, "", $2); print $2; exit }')
  [ -n "$branch" ] || die "could not detect the default branch of ${git_url}; pass --branch."
fi

name="${domain}/${org}/${repo}"
base_url="https://${domain}/${org}/${repo}/blob/${branch}/"

# --- skip if a data store with this name already exists (idempotent re-runs) ---
existing=$(fessctl dataconfig list -o json 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
name = sys.argv[1]
for s in d.get("response", {}).get("settings", []):
    if s.get("name") == name:
        print(s.get("id", ""))
        break
' "$name" || true)

handler_parameter="uri=${git_url}
base_url=${base_url}
extractors=text/.*:textExtractor,application/xml:textExtractor,application/javascript:textExtractor,application/json:textExtractor,application/x-sh:textExtractor,application/x-bat:textExtractor,audio/.*:filenameExtractor,chemical/.*:filenameExtractor,image/.*:filenameExtractor,model/.*:filenameExtractor,video/.*:filenameExtractor,
delete_old_docs=false
repository_path=/home/fess/workspace/${repo}"

handler_script="url=url
host=\"${domain}\"
site=\"${domain}/${org}/${repo}/\" + path
title=name
content=container.getComponent(\"documentHelper\").appendLineNumber(\"L\", content)
digest=author.toExternalString()
content_length=contentLength
last_modified=timestamp
timestamp=timestamp
filename=name
mimetype=mimetype
domain=\"${domain}\"
organization=\"${org}\"
repository=\"${repo}\"
path=path
repository_url=\"https://${domain}/${org}/${repo}\"
filetype=container.getComponent(\"fileTypeHelper\").get(mimetype)"
[ -n "$owner" ]    && handler_script="${handler_script}
owner=\"${owner}\""
[ -n "$homepage" ] && handler_script="${handler_script}
homepage=\"${homepage}\""

# --- create (or reuse) the data store config ---
if [ -n "$existing" ]; then
  echo "Data store already registered: ${name} (id=${existing}); skipping create."
else
  echo "Registering data store: ${name} (branch: ${branch})"
  fessctl dataconfig create \
    --name "$name" \
    --handler-name GitDataStore \
    --handler-parameter "$handler_parameter" \
    --handler-script "$handler_script" \
    --permission "{role}guest" \
    -o json \
  | python3 -c '
import sys, json
d = json.load(sys.stdin).get("response", {})
if d.get("status") != 0:
    sys.stderr.write("fessctl: " + str(d.get("message", "create failed")) + "\n")
    sys.exit(1)
print("Created data store id=" + str(d.get("id", "")))
' || die "failed to create the data store."
fi

# --- trigger the crawl (Default Crawler crawls all data configs) ---
if [ "$crawl" -eq 1 ]; then
  echo "Starting the Default Crawler..."
  fessctl scheduler start default_crawler -o json \
  | python3 -c '
import sys, json
d = json.load(sys.stdin).get("response", {})
if d.get("status") != 0:
    sys.stderr.write("fessctl: " + str(d.get("message", "start failed")) + "\n")
    sys.exit(1)
' || die "failed to start the crawler."
  echo "Crawl started. Progress: ${FESS_ENDPOINT}/admin/scheduler/ — results: ${FESS_ENDPOINT}/"
else
  echo "Registered only (--no-crawl). Start the crawl later with: fessctl scheduler start default_crawler"
fi
