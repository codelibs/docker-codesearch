#!/bin/bash

base_dir=$(cd $(dirname $0);cd ..;pwd)
# fess-script-groovy is no longer downloaded: the Groovy script engine is
# bundled in Fess core since 15.0.
fess_plugins="
fess-ds-git:15.7.0
"

# fess-themes branch to fetch the codesearch static theme from.
# Override with FESS_THEMES_BRANCH=... while the theme is unmerged (PR #23,
# branch feat/codesearch-theme). Defaults to main once it is merged.
fess_themes_branch="${FESS_THEMES_BRANCH:-main}"

if [ $(uname -s) = "Linux" ] ; then
  echo "Changing an owner for directories..."
  sudo chown -R $(id -u)  ${base_dir}/data
fi

echo "Creating directories..."
mkdir -p ${base_dir}/data/https-portal/ssl_certs
mkdir -p ${base_dir}/data/fess/home/fess
mkdir -p ${base_dir}/data/fess/opt/fess
mkdir -p ${base_dir}/data/fess/var/lib/fess
mkdir -p ${base_dir}/data/fess/var/log/fess
mkdir -p ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin
mkdir -p ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/classes/fess_indices/_codesearch
mkdir -p ${base_dir}/data/opensearch/usr/share/opensearch/data
mkdir -p ${base_dir}/data/opensearch/usr/share/opensearch/config/dictionary

rm -f ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin/fess-*.jar

for fess_plugin in ${fess_plugins} ; do
  plugin_name=$(echo $fess_plugin | sed -e "s/:.*//")
  plugin_version=$(echo $fess_plugin | sed -e "s/.*://")
  plugin_file=${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin/${plugin_name}-${plugin_version}.jar
  echo "Downloading ${plugin_name} version ${plugin_version}..."
  curl -s -o ${plugin_file} \
    https://repo1.maven.org/maven2/org/codelibs/fess/${plugin_name}/${plugin_version}/${plugin_name}-${plugin_version}.jar
done

# Fetch codesearch static theme from fess-themes repo.
# NOTE: clones the ${fess_themes_branch} branch (default: main). While the theme
# is still under review, set FESS_THEMES_BRANCH=feat/codesearch-theme (PR #23).
if [ ! -d ${base_dir}/data/fess/themes/codesearch ]; then
  echo "Fetching codesearch theme from fess-themes (branch: ${fess_themes_branch})..."
  mkdir -p ${base_dir}/data/fess/themes/codesearch
  tmp_themes=$(mktemp -d)
  git clone --depth 1 --branch "${fess_themes_branch}" https://github.com/codelibs/fess-themes.git ${tmp_themes}
  bash ${tmp_themes}/scripts/package.sh codesearch
  unzip ${tmp_themes}/dist/codesearch-*.zip -d ${base_dir}/data/fess/themes/codesearch
  rm -rf ${tmp_themes}
fi

if [ ! -f ${base_dir}/data/fess/opt/fess/system.properties ]; then
  cp ${base_dir}/data/fess/opt/fess/system.properties.template ${base_dir}/data/fess/opt/fess/system.properties
fi

echo "Generating fess_config.properties (base + codesearch overlay)..."
bash ${base_dir}/bin/render-fess-config.sh

if [ $(uname -s) = "Linux" ] ; then
  echo "Changing an owner for directories..."
  sudo chown -R root ${base_dir}/data/https-portal/ssl_certs
  sudo chown -R 1001 ${base_dir}/data/fess/home/fess
  sudo chown -R 1001 ${base_dir}/data/fess/opt/fess
  sudo chown -R 1001 ${base_dir}/data/fess/var/lib/fess
  sudo chown -R 1001 ${base_dir}/data/fess/var/log/fess
  sudo chown -R 1001 ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin
  sudo chown -R 1001 ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/classes/fess_indices/_codesearch
  sudo chown -R 1001 ${base_dir}/data/fess/themes
  sudo chown -R 1000 ${base_dir}/data/opensearch/usr/share/opensearch/data
  sudo chown -R 1000 ${base_dir}/data/opensearch/usr/share/opensearch/config/dictionary
fi
