#!/bin/bash

ACCESS_TOKEN=$1
FESS_URL=$2
REPO_DOMAIN=$3
REPO_ORG=$4
REPO_NAME=$5
OWNER=$6
HOMEPAGE=$7
TIMEOUT=900

TMP_FILE=/tmp/register_github.$$

curl -sk -H "Authorization:$ACCESS_TOKEN" -XPUT "$FESS_URL/api/admin/dataconfig/setting" -d '
{
  "version_no": -1,
  "updated_by": "admin",
  "updated_time": 0,
  "name": "'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'",
  "handler_name": "GitDataStore",
  "handler_parameter": "uri=https://'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'.git\nbase_url=https://'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'/blob/master/\nextractors=text/.*:textExtractor,application/xml:textExtractor,application/javascript:textExtractor,application/json:textExtractor,application/x-sh:textExtractor,application/x-bat:textExtractor,audio/.*:filenameExtractor,chemical/.*:filenameExtractor,image/.*:filenameExtractor,model/.*:filenameExtractor,video/.*:filenameExtractor,\ndelete_old_docs=false\nrepository_path=/home/fess/workspace/'$REPO_NAME'",
  "handler_script": "url=url\nhost=\"'$REPO_DOMAIN'\"\nsite=\"'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'/\" + path\ntitle=name\ncontent=container.getComponent(\"documentHelper\").appendLineNumber(\"L\", content)\ncache=\"\"\ndigest=author.toExternalString()\nanchor=\ncontent_length=contentLength\nlast_modified=timestamp\ntimestamp=timestamp\nfilename=name\nmimetype=mimetype\ndomain=\"'$REPO_DOMAIN'\"\norganization=\"'$REPO_ORG'\"\nrepository=\"'$REPO_NAME'\"\npath=path\nrepository_url=\"https://'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'\"\nfiletype=container.getComponent(\"fileTypeHelper\").get(mimetype)\nowner=\"'$OWNER'\"\nhomepage=\"'$HOMEPAGE'\"",
  "boost": 1,
  "available": "true",
  "permissions": "{role}guest",
  "virtual_hosts": "codesearch",
  "sort_order": 0,
  "created_by": "admin",
  "created_time": 0
}
' > $TMP_FILE
CONFIG_ID=`cat $TMP_FILE | jq -r '.response.id'`

curl -sk -H "Authorization:$ACCESS_TOKEN" -XPUT "$FESS_URL/api/admin/scheduler/setting" -d '
{
  "version_no": -1,
  "name": "Data Crawler - '$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'",
  "target": "all",
  "cron_expression": "'$(($RANDOM % 60))' '$(($RANDOM % 24))' * * '$(($RANDOM % 6))'",
  "script_type": "groovy",
  "script_data": "return container.getComponent(\"crawlJob\").logLevel(\"info\").sessionId(\"'$CONFIG_ID'\").webConfigIds([] as String[]).fileConfigIds([] as String[]).dataConfigIds([\"'$CONFIG_ID'\"] as String[]).jobExecutor(executor).timeout('$TIMEOUT').execute();",
  "crawler": "true",
  "job_logging": "true",
  "available": "true",
  "sort_order": 0
}
' > $TMP_FILE
JOB_ID=`cat $TMP_FILE | jq -r '.response.id'`

rm $TMP_FILE

echo "$CONFIG_ID $JOB_ID"
