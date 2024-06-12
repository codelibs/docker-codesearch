# Code Search on Fess

[Fess](https://fess.codelibs.org/) is an Enterprise Search Server. This Docker environment provides a Source Code Search Server using Fess.

## Public Site

* [codesearch.codelibs.org](https://codesearch.codelibs.org/)

## Getting Started

### Setup

First, clone the repository and navigate into the directory:

```bash
$ git clone https://github.com/codelibs/docker-codesearch.git
$ cd docker-codesearch
$ bash ./bin/setup.sh
```

### Start the Server

To start the server, use Docker Compose:

```bash
docker compose -f compose.yaml up -d
```

Once the server is running, access it at [http://localhost:8080/](http://localhost:8080/).

### Create an Access Token

To use the Admin API for Fess, create an access token with the `{role}admin-api` permission on the Admin Access Token page ([http://localhost:8080/admin/accesstoken/](http://localhost:8080/admin/accesstoken/)).

For more details, see the [Admin Access Token Guide](https://fess.codelibs.org/14.14/admin/accesstoken-guide.html).

### Create DataStore Configuration for GitHub

You can create DataStore and Scheduler settings on Fess using the `bin/register_github.sh` script:

```bash
register_github.sh ACCESS_TOKEN FESS_URL REPO_DOMAIN REPO_ORG REPO_NAME

Example:
$ bash ./bin/register_github.sh ...token... http://localhost:8080 github.com codelibs fess
```

Check the created settings on the DataConfig page ([http://localhost:8080/admin/dataconfig/](http://localhost:8080/admin/dataconfig/)).

### Start the Crawler

To start the crawler, run `Default Crawler` or `Data Crawler - ...` on the Admin Scheduler page ([http://localhost:8080/admin/scheduler/](http://localhost:8080/admin/scheduler/)).

### Search

You can view search results at [http://localhost:8080/](http://localhost:8080/).

### Stop the Server

To stop the server, use the following command:

```bash
docker compose -f compose.yaml down
```

