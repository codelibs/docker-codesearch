#!/bin/bash
#
# Prepare the bind-mounted data/ tree: plugins, the codesearch static theme,
# system.properties and the generated fess_config.properties.
#
# Every step is fatal. A partially completed setup produces a Fess that boots
# fine on stock defaults and then silently returns 0 hits for every search
# (the codesearch fields are neither mapped nor allowed as facets), so a
# half-finished run must never look like a successful one.
set -euo pipefail

base_dir=$(cd "$(dirname "$0")";cd ..;pwd)
# fess-script-groovy is no longer downloaded: the Groovy script engine is
# bundled in Fess core since 15.0.
# Override a version with e.g. FESS_DS_GIT_VERSION=15.8.0 (these are not
# derived from FESS_VERSION: snapshot images have no matching release plugin).
fess_plugins="
fess-ds-git:${FESS_DS_GIT_VERSION:-15.7.0}
"

# fess-themes branch to fetch the codesearch static theme from (default: main).
# Override with FESS_THEMES_BRANCH=<branch> to test theme changes from another branch.
fess_themes_branch="${FESS_THEMES_BRANCH:-main}"

# The theme is re-fetched on every run so it tracks the branch above. Set
# FESS_THEMES_SKIP_FETCH=1 to keep the copy already in data/fess/themes
# (offline runs, or a locally patched theme).
fess_themes_skip_fetch="${FESS_THEMES_SKIP_FETCH:-0}"

if [ "$(uname -s)" = "Linux" ] ; then
  echo "Changing an owner for directories..."
  sudo chown -R "$(id -u)" "${base_dir}/data"
fi

echo "Creating directories..."
mkdir -p "${base_dir}/data/https-portal/ssl_certs"
mkdir -p "${base_dir}/data/fess/home/fess"
mkdir -p "${base_dir}/data/fess/opt/fess"
mkdir -p "${base_dir}/data/fess/var/lib/fess"
mkdir -p "${base_dir}/data/fess/var/log/fess"
mkdir -p "${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin"
mkdir -p "${base_dir}/data/fess/usr/share/fess/app/WEB-INF/classes/fess_indices/_codesearch"
mkdir -p "${base_dir}/data/opensearch/usr/share/opensearch/data"
mkdir -p "${base_dir}/data/opensearch/usr/share/opensearch/config/dictionary"

plugin_dir=${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin
# Stale jars are pruned only after every download succeeded, so a failed run
# leaves the previously working plugins in place.
kept_plugins=""

for fess_plugin in ${fess_plugins} ; do
  plugin_name=$(echo "$fess_plugin" | sed -e "s/:.*//")
  plugin_version=$(echo "$fess_plugin" | sed -e "s/.*://")
  plugin_jar=${plugin_name}-${plugin_version}.jar
  plugin_file=${plugin_dir}/${plugin_jar}
  plugin_url=https://repo1.maven.org/maven2/org/codelibs/fess/${plugin_name}/${plugin_version}/${plugin_jar}
  echo "Downloading ${plugin_name} version ${plugin_version}..."
  # -f, or a 404 page gets written out as a .jar that Fess then fails to load.
  if ! curl -fsSL "${plugin_url}" -o "${plugin_file}.tmp"; then
    rm -f "${plugin_file}.tmp"
    echo "ERROR: could not download ${plugin_name} ${plugin_version} from" >&2
    echo "       ${plugin_url}" >&2
    echo "       Check the version (see FESS_DS_GIT_VERSION in this script)." >&2
    exit 1
  fi
  if ! unzip -tq "${plugin_file}.tmp" > /dev/null 2>&1; then
    rm -f "${plugin_file}.tmp"
    echo "ERROR: ${plugin_url} did not return a jar archive." >&2
    exit 1
  fi
  mv "${plugin_file}.tmp" "${plugin_file}"
  kept_plugins="${kept_plugins} ${plugin_jar}"
done

for existing in "${plugin_dir}"/fess-*.jar ; do
  [ -e "${existing}" ] || continue
  case " ${kept_plugins} " in
    *" $(basename "${existing}") "*) ;;
    *) echo "Removing stale plugin $(basename "${existing}")..." ; rm -f "${existing}" ;;
  esac
done

# Fetch the codesearch static theme from the fess-themes repo.
if [ "${fess_themes_skip_fetch}" = "1" ] && [ -d "${base_dir}/data/fess/themes/codesearch" ]; then
  echo "Keeping the existing codesearch theme (FESS_THEMES_SKIP_FETCH=1)."
else
  echo "Fetching codesearch theme from fess-themes (branch: ${fess_themes_branch})..."
  tmp_themes=$(mktemp -d)
  trap 'rm -rf "${tmp_themes}"' EXIT
  git clone --depth 1 --branch "${fess_themes_branch}" https://github.com/codelibs/fess-themes.git "${tmp_themes}"
  bash "${tmp_themes}/scripts/package.sh" codesearch
  # Replace rather than unzip over the old copy, so files dropped from the
  # theme do not linger and get served.
  rm -rf "${base_dir}/data/fess/themes/codesearch"
  mkdir -p "${base_dir}/data/fess/themes/codesearch"
  unzip -q "${tmp_themes}"/dist/codesearch-*.zip -d "${base_dir}/data/fess/themes/codesearch"
  rm -rf "${tmp_themes}"
  trap - EXIT
fi

if [ ! -f "${base_dir}/data/fess/opt/fess/system.properties" ]; then
  cp "${base_dir}/data/fess/opt/fess/system.properties.template" "${base_dir}/data/fess/opt/fess/system.properties"
fi

echo "Generating fess_config.properties (base + codesearch overlay)..."
bash "${base_dir}/bin/render-fess-config.sh"

if [ "$(uname -s)" = "Linux" ] ; then
  echo "Changing an owner for directories..."
  sudo chown -R root "${base_dir}/data/https-portal/ssl_certs"
  sudo chown -R 1001 "${base_dir}/data/fess/home/fess"
  sudo chown -R 1001 "${base_dir}/data/fess/opt/fess"
  sudo chown -R 1001 "${base_dir}/data/fess/var/lib/fess"
  sudo chown -R 1001 "${base_dir}/data/fess/var/log/fess"
  sudo chown -R 1001 "${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin"
  sudo chown -R 1001 "${base_dir}/data/fess/usr/share/fess/app/WEB-INF/classes/fess_indices/_codesearch"
  sudo chown -R 1001 "${base_dir}/data/fess/themes"
  sudo chown -R 1000 "${base_dir}/data/opensearch/usr/share/opensearch/data"
  sudo chown -R 1000 "${base_dir}/data/opensearch/usr/share/opensearch/config/dictionary"
fi

echo "Setup complete. Start the stack, then run bin/verify.sh to confirm the"
echo "config and the index mapping actually took effect."
