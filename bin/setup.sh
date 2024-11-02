#!/bin/bash

base_dir=$(cd $(dirname $0);cd ..;pwd)
fess_plugins="
fess-script-groovy:14.17.0
fess-ds-git:14.17.0
fess-theme-codesearch:14.17.0
"

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
mkdir -p ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/view/codesearch
mkdir -p ${base_dir}/data/fess/usr/share/fess/app/css/codesearch
mkdir -p ${base_dir}/data/fess/usr/share/fess/app/images/codesearch
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
  if [[ ${plugin_name} = "fess-theme-codesearch" ]] ; then
    rm -rf ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/view/codesearch
    unzip ${plugin_file} "view/*" -d ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/view
    mv ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/view/view ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/view/codesearch
    rm -rf ${base_dir}/data/fess/usr/share/fess/app/css/codesearch
    unzip ${plugin_file} "css/*" -d ${base_dir}/data/fess/usr/share/fess/app/css
    mv ${base_dir}/data/fess/usr/share/fess/app/css/css ${base_dir}/data/fess/usr/share/fess/app/css/codesearch
    rm -rf ${base_dir}/data/fess/usr/share/fess/app/images/codesearch
    unzip ${plugin_file} "images/*" -d ${base_dir}/data/fess/usr/share/fess/app/images
    mv ${base_dir}/data/fess/usr/share/fess/app/images/images ${base_dir}/data/fess/usr/share/fess/app/images/codesearch
  fi
done

if [ $(uname -s) = "Linux" ] ; then
  echo "Changing an owner for directories..."
  sudo chown -R root ${base_dir}/data/https-portal/ssl_certs
  sudo chown -R 1001 ${base_dir}/data/fess/home/fess
  sudo chown -R 1001 ${base_dir}/data/fess/opt/fess
  sudo chown -R 1001 ${base_dir}/data/fess/var/lib/fess
  sudo chown -R 1001 ${base_dir}/data/fess/var/log/fess
  sudo chown -R 1001 ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/plugin
  sudo chown -R 1001 ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/classes/fess_indices/_codesearch
  sudo chown -R 1001 ${base_dir}/data/fess/usr/share/fess/app/WEB-INF/view/codesearch
  sudo chown -R 1001 ${base_dir}/data/fess/usr/share/fess/app/css/codesearch
  sudo chown -R 1001 ${base_dir}/data/fess/usr/share/fess/app/images/codesearch
  sudo chown -R 1000 ${base_dir}/data/opensearch/usr/share/opensearch/data
  sudo chown -R 1000 ${base_dir}/data/opensearch/usr/share/opensearch/config/dictionary
fi
