#!/bin/bash

ACCESS_TOKEN=$1
FESS_URL=$2
REPO_DOMAIN=$3
REPO_ORG=$4
REPO_NAME=$5

curl -sk -H "Authorization:$ACCESS_TOKEN" -XPUT "$FESS_URL/api/admin/dataconfig/setting" -d '
{
  "version_no": -1,
  "updated_by": "admin",
  "updated_time": 0,
  "name": "'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'",
  "handler_name": "GitDataStore",
  "handler_parameter": "uri=https://'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'.git\nbase_url=https://'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'/blob/master/\nextractors=text/.*:textExtractor,application/xml:textExtractor,application/javascript:textExtractor,\ndelete_old_docs=false\nrepository_path=/home/fess/workspace/'$REPO_NAME'",
  "handler_script": "url=url\nhost=\"'$REPO_DOMAIN'\"\nsite=\"'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'/\" + path\ntitle=name\ncontent=container.getComponent(\"documentHelper\").appendLineNumber(\"L\", content)\ncache=\"\"\ndigest=author.toExternalString()\nanchor=\ncontent_length=contentLength\nlast_modified=timestamp\ntimestamp=timestamp\nmimetype=mimetype\ndomain=\"'$REPO_DOMAIN'\"\norganization=\"'$REPO_ORG'\"\nrepository=\"'$REPO_NAME'\"\npath=path\nrepository_url=\"https://'$REPO_DOMAIN'/'$REPO_ORG'/'$REPO_NAME'\"",
  "boost": 1,
  "available": "true",
  "permissions": "{role}guest",
  "virtual_hosts": "codesearch",
  "sort_order": 0,
  "created_by": "admin",
  "created_time": 0
}
'
