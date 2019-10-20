#!/bin/bash

USERID=`whoami`
BRANCH=`git branch | grep ^\* | awk '{ print $2 }'`
TMP_PROP_FILE=/tmp/system.properties.$$

sudo chown -R $USERID ./data/fess/opt/fess/system.properties
sudo chown -R $USERID ./data/fess/usr/share/fess/app/WEB-INF/view/codesearch
sudo chown -R $USERID ./data/fess/usr/share/fess/app/css/codesearch
sudo chown -R $USERID ./data/fess/usr/share/fess/app/images/codesearch
cp ./data/fess/opt/fess/system.properties $TMP_PROP_FILE
git checkout -- ./data/fess/opt/fess/system.properties
git checkout -- ./data/fess/usr/share/fess/app/WEB-INF/view/codesearch
git checkout -- ./data/fess/usr/share/fess/app/css/codesearch
git checkout -- ./data/fess/usr/share/fess/app/images/codesearch

git pull origin $BRANCH

cp $TMP_PROP_FILE ./data/fess/opt/fess/system.properties
sudo chown -R 1001 ./data/fess/opt/fess/system.properties
sudo chown -R 1001 ./data/fess/usr/share/fess/app/WEB-INF/view/codesearch
sudo chown -R 1001 ./data/fess/usr/share/fess/app/css/codesearch
sudo chown -R 1001 ./data/fess/usr/share/fess/app/images/codesearch

rm $TMP_PROP_FILE
