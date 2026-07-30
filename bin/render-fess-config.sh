#!/usr/bin/env bash
#
# Render data/fess/opt/fess/fess_config.properties from the upstream base
# (pinned by FESS_VERSION in .env) plus the codesearch overlay and an optional
# local override.
#
# Why a full generated file: the official Fess image puts the default
# fess_config.properties on the classpath under /etc/fess and prepends
# /opt/fess (FESS_OVERRIDE_CONF_PATH) ahead of it. A file at
# /opt/fess/fess_config.properties therefore *shadows the whole base file*
# (classpath "first match wins" — not a per-key merge). So we cannot ship a
# minimal override; we must emit a complete file for the pinned version.
#
# Strategy: fetch the upstream base for FESS_VERSION (cached per version),
# strip every key that the overlay/local redefine (handling backslash
# continuations such as the multi-line index.filetype), then append the
# overlay (and local). Only the codesearch delta is maintained in git; the
# base auto-tracks the pinned Fess version on upgrade.
set -euo pipefail

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- version: single source of truth is .env ---
# shellcheck disable=SC1091
[ -f "${base_dir}/.env" ] && . "${base_dir}/.env"
: "${FESS_VERSION:?FESS_VERSION must be set (in .env)}"

overlay="${base_dir}/conf/fess_config.overlay.properties"
local_overlay="${base_dir}/conf/fess_config.local.properties"
out_dir="${base_dir}/data/fess/opt/fess"
out="${out_dir}/fess_config.properties"

# --- map the image tag in FESS_VERSION to the git ref that holds its base config ---
# FESS_VERSION is a ghcr.io/codelibs/fess tag, and the published tags are
# "<x.y.z>", "<x.y.z>-noble", "<x.y.z>-al2023", "snapshot" and "snapshot-<os>".
# Only the plain "<x.y.z>" form matches a git tag ("fess-<x.y.z>"), so the OS
# suffix has to be dropped and the snapshot tags mapped to the development
# branch. Getting this wrong 404s and used to leave NO generated config behind,
# silently reverting Fess to its stock defaults (empty
# query.additional.facet.fields => every codesearch search returns 0 hits).
# Override with FESS_CONFIG_BASE_REF for a tag this mapping does not cover.
if [ -n "${FESS_CONFIG_BASE_REF:-}" ]; then
  base_ref="${FESS_CONFIG_BASE_REF}"
else
  # Normalize the image tag to a release: strip the OS variant suffix, and treat
  # every snapshot flavour (snapshot, snapshot-noble, 15.8.0-SNAPSHOT, ...) alike.
  fess_release="${FESS_VERSION}"
  case "${fess_release}" in
    snapshot | snapshot-* | *-SNAPSHOT | *-snapshot) fess_release="snapshot" ;;
    *-*) fess_release="${fess_release%%-*}" ;;
  esac
  case "${fess_release}" in
    snapshot) base_ref="master" ;;
    [0-9]*.[0-9]*.[0-9]*) base_ref="fess-${fess_release}" ;;
    *)
      echo "ERROR: cannot derive the fess_config.properties base ref from FESS_VERSION=${FESS_VERSION}." >&2
      echo "       Pin an explicit release in .env (e.g. FESS_VERSION=15.7.0) - a floating tag" >&2
      echo "       such as 'latest' has no matching source ref - or set FESS_CONFIG_BASE_REF" >&2
      echo "       to the codelibs/fess ref that image was built from." >&2
      exit 1
      ;;
  esac
fi

cache="${out_dir}/.fess_config.base-${base_ref//\//_}.properties"
url="https://raw.githubusercontent.com/codelibs/fess/${base_ref}/src/main/resources/fess_config.properties"

[ -f "${overlay}" ] || { echo "ERROR: overlay not found: ${overlay}" >&2; exit 1; }
mkdir -p "${out_dir}"

# --- fetch the base, cached per ref (offline-friendly afterwards) ---
# A tag is immutable, so its cache is authoritative. A branch is a moving
# target, so it is re-fetched every run; if that fetch fails we fall back to the
# cached copy, but say so - a stale base is a real (if minor) inaccuracy.
if [ ! -s "${cache}" ] || [ "${base_ref}" = "${base_ref#fess-}" ]; then
  echo "Fetching base fess_config.properties (FESS_VERSION=${FESS_VERSION}, ref=${base_ref})..."
  if curl -LfsS "${url}" -o "${cache}.tmp"; then
    mv "${cache}.tmp" "${cache}"
  else
    rm -f "${cache}.tmp"
    if [ -s "${cache}" ]; then
      echo "WARN: could not re-fetch ${url}" >&2
      echo "      Reusing the previously downloaded base for '${base_ref}', which may be stale." >&2
    else
      echo "ERROR: could not fetch the base fess_config.properties for FESS_VERSION=${FESS_VERSION}." >&2
      echo "       ${url}" >&2
      echo "       The ref '${base_ref}' does not exist, or the network is unavailable." >&2
      echo "       Set FESS_CONFIG_BASE_REF to a valid codelibs/fess ref and re-run." >&2
      exit 1
    fi
  fi
fi

# --- collect the top-level keys defined by the overlay(s) ---
collect_keys() {
  awk '
    cont { if ($0 ~ /\\$/) next; cont=0; next }
    /^[ \t]*#/ { next }
    /^[ \t]*!/ { next }
    /^[ \t]*$/ { next }
    {
      if ($0 ~ /^[ \t]*[^=:#! \t][^=:]*[=:]/) {
        k=$0; sub(/[ \t]*[=:].*/, "", k); gsub(/^[ \t]+/, "", k); print k
        if ($0 ~ /\\$/) cont=1
      }
    }
  ' "$@"
}

keys_file="$(mktemp)"
trap 'rm -f "${keys_file}"' EXIT
if [ -f "${local_overlay}" ]; then
  collect_keys "${overlay}" "${local_overlay}" | sort -u > "${keys_file}"
else
  collect_keys "${overlay}" | sort -u > "${keys_file}"
fi

# --- strip those logical properties (incl. continuations) from the base ---
strip_keys() {
  awk -v keysfile="${keys_file}" '
    BEGIN { while ((getline k < keysfile) > 0) if (k != "") drop[k]=1 }
    skip { if ($0 ~ /\\$/) next; skip=0; next }
    {
      if ($0 ~ /^[ \t]*[^=:#! \t][^=:]*[=:]/) {
        k=$0; sub(/[ \t]*[=:].*/, "", k); gsub(/^[ \t]+/, "", k)
        if (k in drop) { if ($0 ~ /\\$/) skip=1; next }
      }
      print
    }
  ' "${cache}"
}

{
  echo "# ============================================================"
  echo "# GENERATED by bin/render-fess-config.sh — DO NOT EDIT."
  echo "# base    : codelibs/fess@${base_ref} upstream fess_config.properties (FESS_VERSION=${FESS_VERSION})"
  echo "# overlay : conf/fess_config.overlay.properties (tracked delta)"
  echo "# local   : conf/fess_config.local.properties (optional, git-ignored)"
  echo "# Re-run bin/setup.sh (or this script) after changing .env or the overlay."
  echo "# ============================================================"
  strip_keys
  echo ""
  echo "# ---- codesearch overlay (conf/fess_config.overlay.properties) ----"
  cat "${overlay}"
  if [ -f "${local_overlay}" ]; then
    echo ""
    echo "# ---- local overrides (conf/fess_config.local.properties) ----"
    cat "${local_overlay}"
  fi
} > "${out}"

# --- sanity check ---
grep -q '^index\.filetype=' "${out}" || { echo "ERROR: index.filetype missing in generated file" >&2; exit 1; }
grep -q '^search_engine\.type=codesearch' "${out}" || { echo "ERROR: codesearch overrides missing in generated file" >&2; exit 1; }

# The theme requests facets on repository/organization/filename unconditionally, and Fess
# validates facet fields against this allowlist only. If they are missing, every search
# returns 0 hits with nothing but a WARN in fess.log, so fail here instead.
for facet_field in organization repository filename ; do
  grep -qE "^query\.additional\.facet\.fields=.*\b${facet_field}\b" "${out}" || {
    echo "ERROR: query.additional.facet.fields in the generated file does not allow '${facet_field}'." >&2
    echo "       The codesearch theme facets on it, so searches would return 0 hits." >&2
    exit 1
  }
done

echo "Generated ${out} (base codelibs/fess@${base_ref} + $(wc -l < "${keys_file}" | tr -d ' ') overridden keys)"
