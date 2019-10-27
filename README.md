# Code Search on Fess

## Public Site

* [codesearch.codelibs.org](https://codesearch.codelibs.org/)

## Getting Started

### Setup

```
bash ./bin/setup.sh
```

### Start Server

```
docker-compose up -d
```

### Stop Server

```
docker-compose down
```

## Configuration

### Create Access Token

To use Admin API for Fess, you need to create an access token with `{role}admin-api` permission at Admin Access Token page.
For more details, see [Admin Access Token](https://fess.codelibs.org/13.4/admin/accesstoken-guide.html).

### Create DataStore coniguration for GitHub

Using `bin/register_github.sh`, you can create DataStore and Scheduler settings on Fess.

```
register_github.sh ACCESS_TOKEN FESS_URL REPO_DOMAIN REPO_ORG REPO_NAME

Example:
$ bash ./bin/register_github.sh ...token... http://localhost:8080 github.com codelibs fess
```
