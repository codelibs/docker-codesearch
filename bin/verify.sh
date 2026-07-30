#!/usr/bin/env bash
#
# Verify that the codesearch configuration actually took effect at runtime.
#
# Why this exists: a codesearch deployment can boot perfectly and still return
# 0 hits for every query, with nothing but a WARN in fess.log. Two independent
# things have to be true, and neither is visible on the search page:
#
#   1. The generated /opt/fess/fess_config.properties must be in effect. It
#      carries query.additional.facet.fields; the codesearch theme facets on
#      repository/organization/filename unconditionally, and Fess validates
#      facet fields against that allowlist only - never against the index
#      mapping. One unlisted field aborts the whole search.
#   2. The live index must actually have the codesearch fields mapped. That
#      comes from search_engine.type=codesearch, which is read only when the
#      index is CREATED. If the first boot ran on stock defaults, fixing the
#      config later does not repair the index - Fess applies a mapping only to
#      an index that has none yet.
#
# Works against any supported Fess (15.7.0 and later): the checks read the
# effective config and the live mapping, and the API probe compares a faceted
# search against an unfaceted one rather than relying on the HTTP status, since
# older Fess reports a rejected facet field as an empty result set (HTTP 200)
# instead of an error.
#
# Usage:
#   bash ./bin/verify.sh
#
# Environment:
#   FESS_ENDPOINT       default http://localhost:8080
#   SEARCH_ENGINE_URL   default http://localhost:9200
#   FESS_CONTAINER      default fess01 (set empty to skip the container check)
#   VERIFY_QUERY        default "test" - the query used for the API probe
set -uo pipefail

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fess_endpoint="${FESS_ENDPOINT:-http://localhost:8080}"
search_engine_url="${SEARCH_ENGINE_URL:-http://localhost:9200}"
fess_container="${FESS_CONTAINER-fess01}"
verify_query="${VERIFY_QUERY:-test}"

generated="${base_dir}/data/fess/opt/fess/fess_config.properties"
tracked_doc_json="${base_dir}/data/fess/usr/share/fess/app/WEB-INF/classes/fess_indices/_codesearch/fess/doc.json"

# Facet fields the codesearch theme requests on every search
# (themes/codesearch/assets/search.js). filetype is allowed by Fess by default;
# the other three are not.
facet_fields="organization repository filename"
# Codesearch document fields that must exist in the index mapping
# (data/fess/.../fess_indices/_codesearch/fess/doc.json).
code_fields="domain organization repository path repository_url owner homepage"

failed=0
index_broken=0

if [ -t 1 ]; then
  c_ok=$'\033[0;32m'; c_bad=$'\033[0;31m'; c_warn=$'\033[0;33m'; c_off=$'\033[0m'
else
  c_ok=""; c_bad=""; c_warn=""; c_off=""
fi
pass() { printf '  %sOK%s    %s\n' "${c_ok}" "${c_off}" "$1"; }
fail() { printf '  %sFAIL%s  %s\n' "${c_bad}" "${c_off}" "$1"; failed=$((failed + 1)); }
skip() { printf '  %sSKIP%s  %s\n' "${c_warn}" "${c_off}" "$1"; }
warn() { printf '  %sWARN%s  %s\n' "${c_warn}" "${c_off}" "$1"; }

# Reads a JSON value with python3; callers must have checked have_python first.
have_python=0
command -v python3 > /dev/null 2>&1 && have_python=1

echo "== generated fess_config.properties =="
if [ ! -s "${generated}" ]; then
  fail "${generated} is missing. Run 'bash ./bin/setup.sh'."
  echo
  echo "Without it Fess falls back to the stock config in the image"
  echo "(/etc/fess/fess_config.properties): no codesearch index schema and an"
  echo "empty facet allowlist, so every search returns 0 hits."
  exit 1
fi
pass "$(basename "${generated}") exists"

if grep -q '^search_engine\.type=codesearch' "${generated}"; then
  pass "search_engine.type=codesearch"
else
  fail "search_engine.type=codesearch is missing (the _codesearch index schema would not be used)"
fi

for f in ${facet_fields}; do
  if grep -qE "^query\.additional\.facet\.fields=.*\b${f}\b" "${generated}"; then
    pass "query.additional.facet.fields allows '${f}'"
  else
    fail "query.additional.facet.fields does not allow '${f}' - searches will return 0 hits"
  fi
done

echo
echo "== running container =="
if [ -z "${fess_container}" ]; then
  skip "container check disabled (FESS_CONTAINER is empty)"
elif ! command -v docker > /dev/null 2>&1; then
  skip "docker not found; cannot check what ${fess_container} has mounted"
elif ! docker inspect "${fess_container}" > /dev/null 2>&1; then
  skip "container '${fess_container}' does not exist (not started yet?)"
elif docker exec "${fess_container}" test -s /opt/fess/fess_config.properties 2>/dev/null; then
  pass "${fess_container} sees /opt/fess/fess_config.properties"
  if docker exec "${fess_container}" grep -q '^search_engine\.type=codesearch' /opt/fess/fess_config.properties 2>/dev/null; then
    pass "${fess_container}'s copy has search_engine.type=codesearch"
  else
    fail "${fess_container}'s copy differs from the generated file - restart the container"
  fi
else
  fail "${fess_container} does not see /opt/fess/fess_config.properties (bind mount or restart missing)"
fi

echo
echo "== live index mapping (${search_engine_url}) =="
mapping="$(curl -fsS "${search_engine_url}/fess.update/_mapping" 2>/dev/null)"
if [ -z "${mapping}" ]; then
  skip "could not read the mapping from ${search_engine_url} (engine down, or set SEARCH_ENGINE_URL)"
elif [ "${have_python}" -eq 0 ]; then
  skip "python3 not found; cannot parse the mapping"
else
  missing="$(printf '%s' "${mapping}" | python3 -c '
import json, sys
want = sys.argv[1].split()
doc = json.load(sys.stdin)
props = set()
for index in doc.values():
    props |= set(index.get("mappings", {}).get("properties", {}))
print(" ".join(f for f in want if f not in props))
' "${code_fields}")"
  if [ -z "${missing}" ]; then
    pass "all codesearch fields are mapped (${code_fields})"
  else
    fail "the live index is missing these mapped fields: ${missing}"
    index_broken=1
  fi
fi

echo
echo "== search API probe (${fess_endpoint}) =="
probe_common="${fess_endpoint}/api/v2/search?q=$(printf '%s' "${verify_query}" | sed -e 's/ /%20/g')"
probe_faceted="${probe_common}"
for f in ${facet_fields} filetype; do
  probe_faceted="${probe_faceted}&facet.field=${f}"
done
status="$(curl -sS -o /dev/null -w '%{http_code}' "${probe_faceted}" 2>/dev/null)"
case "${status}" in
  400)
    # Only a Fess that reports the rejection answers 400 here.
    fail "the theme's facet request is rejected (HTTP 400) - a facet field is not allowed"
    ;;
  404)
    skip "no /api/v2/search on this Fess (HTTP 404); config and mapping checks above still apply"
    ;;
  000 | "")
    skip "could not reach ${fess_endpoint} (set FESS_ENDPOINT)"
    ;;
  200)
    # A Fess without that fix answers 200 with zero documents, so the status
    # alone proves nothing. Compare with the same query minus the facets: only
    # a rejected facet field makes the faceted count collapse to 0.
    if [ "${have_python}" -eq 0 ]; then
      skip "python3 not found; cannot compare record counts (HTTP 200 alone does not prove the facets worked)"
    else
      count_of() {
        curl -fsS "$1" 2>/dev/null | python3 -c '
import json, sys
try:
    print(int(json.load(sys.stdin).get("record_count", -1)))
except Exception:
    print(-1)
' 2>/dev/null || echo -1
      }
      plain_count="$(count_of "${probe_common}")"
      facet_count="$(count_of "${probe_faceted}")"
      if [ "${plain_count}" = "-1" ] || [ "${facet_count}" = "-1" ]; then
        skip "could not read record_count from the response"
      elif [ "${plain_count}" -eq 0 ]; then
        skip "no documents match '${verify_query}'; cannot probe (crawl first, or set VERIFY_QUERY)"
      elif [ "${facet_count}" -eq 0 ]; then
        fail "'${verify_query}' returns ${plain_count} hits without facets but 0 with the theme's facets - a facet field is rejected"
      else
        pass "the theme's facet request returns hits (${facet_count} for '${verify_query}')"
      fi
    fi
    ;;
  *)
    fail "unexpected HTTP ${status} from ${probe_faceted}"
    ;;
esac

echo
echo "== tracked codesearch index schema (advisory) =="
# The _codesearch schema is a hand-maintained fork of the upstream one, so it can
# drift as Fess evolves. Only the dangerous direction is reported: a core field
# upstream has that the fork lacks would simply be missing from the index.
schema_ref="$(sed -nE 's|^# base .*codelibs/fess@([^ ]+).*|\1|p' "${generated}" | head -1)"
if [ ! -s "${tracked_doc_json}" ]; then
  skip "$(basename "${tracked_doc_json}") not found"
elif [ -z "${schema_ref}" ]; then
  skip "cannot tell which Fess ref to compare against; re-run bin/setup.sh to refresh the header"
elif [ "${have_python}" -eq 0 ]; then
  skip "python3 not found; cannot compare the schema"
else
  upstream_doc_json="$(curl -fsS \
    "https://raw.githubusercontent.com/codelibs/fess/${schema_ref}/src/main/resources/fess_indices/fess/doc.json" 2>/dev/null)"
  if [ -z "${upstream_doc_json}" ]; then
    skip "could not fetch the upstream doc.json for '${schema_ref}'"
  else
    printf '%s' "${upstream_doc_json}" | python3 -c '
import collections, json, sys
local = json.load(open(sys.argv[1]))
upstream = json.load(sys.stdin)
missing = sorted(set(upstream.get("properties", {})) - set(local.get("properties", {})))
names = [next(iter(t)) for t in local.get("dynamic_templates", [])]
dups = sorted(k for k, c in collections.Counter(names).items() if c > 1)
print("MISSING " + " ".join(missing) if missing else "MISSING")
print("DUPS " + " ".join(dups) if dups else "DUPS")
' "${tracked_doc_json}" > /tmp/verify-schema.$$ 2>/dev/null
    schema_missing="$(sed -n 's/^MISSING *//p' /tmp/verify-schema.$$)"
    schema_dups="$(sed -n 's/^DUPS *//p' /tmp/verify-schema.$$)"
    rm -f /tmp/verify-schema.$$
    if [ -n "${schema_missing}" ]; then
      warn "fields present in codelibs/fess@${schema_ref} but absent from the codesearch schema: ${schema_missing}"
    else
      pass "the codesearch schema has every core field of codelibs/fess@${schema_ref}"
    fi
    if [ -n "${schema_dups}" ]; then
      warn "duplicate dynamic_templates names in the codesearch schema: ${schema_dups} (one of each pair is ignored)"
    fi
  fi
fi

echo
if [ "${failed}" -eq 0 ]; then
  echo "All checks passed. (WARNs above are advisory and do not affect search.)"
  exit 0
fi

echo "${failed} check(s) failed."
echo
echo "Remedies:"
echo "  * config not generated / stale:"
echo "      bash ./bin/setup.sh && docker compose -f compose.yaml up -d"
echo "    (setup.sh is fatal on any failure, so read its output if it stops early)"
if [ "${index_broken}" -eq 1 ]; then
  echo "  * index created without the codesearch fields:"
  echo "    Fixing the config is NOT enough - Fess only applies a mapping to an index"
  echo "    that has none yet. Rebuild the index from the current schema, then re-crawl:"
  echo "      1. open ${fess_endpoint}/admin/maintenance/ and run Reindex"
  echo "      2. fessctl scheduler start default_crawler"
fi
exit 1
