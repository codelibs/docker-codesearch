# Code Search on Fess

Fess is Enterprise Search Server.
This docker environment provides Source Code Search Server on Fess.

## Public Site

* [codesearch.codelibs.org](https://codesearch.codelibs.org/)

## Getting Started

### Setup

```
$ git clone -b 13.4.1.0 https://github.com/codelibs/docker-codesearch.git
$ cd docker-codesearch
$ bash ./bin/setup.sh
```

### Start Server

```
docker-compose up -d
```

and then access `http://localhost:8080/`.

### Create Access Token

To use Admin API for Fess, you need to create an access token with `{role}admin-api` permission at Admin Access Token page(`http://localhost:8080/admin/accesstoken/`).
For more details, see [Admin Access Token](https://fess.codelibs.org/13.4/admin/accesstoken-guide.html).

### Install DataStore Git Plugin

To crawl a git repository, you need to install fess-ds-git plugin in Admin Plugin page(`http://localhost:8080/admin/plugin/`).

### Create DataStore coniguration for GitHub

Using `bin/register_github.sh`, you can create DataStore and Scheduler settings on Fess.

```
register_github.sh ACCESS_TOKEN FESS_URL REPO_DOMAIN REPO_ORG REPO_NAME

Example:
$ bash ./bin/register_github.sh ...token... http://localhost:8080 github.com codelibs fess
```

You can check if settings are created in `http://localhost:8080/admin/dataconfig/`.

### Start Crawler

To start the crawler, run `Default Crawler` or `Data Crawler - ...` in Admin Scheduler page(`http://localhost:8080/admin/scheduler/`).

### Search

You can check search results on `http://localhost:8080/`.

### Stop Server

```
docker-compose down
```

## For Production

* Replace `codesearch.codelibs.org` with your domain in docker-compose.yml.
* If you want to use SSL, modify a value of STAGE in docker-compose.yml.
