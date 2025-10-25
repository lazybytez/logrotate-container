# Logrotate Container

[![gh-commit-badge][gh-commit-badge]][gh-commit]
[![gh-contributors-badge][gh-contributors-badge]][gh-contributors]
[![gh-stars-badge][gh-stars-badge]][gh-stars]
[![gh-downloads-badge][gh-downloads-badge]][gh-downloads-badge]

## Description

A small side-car container that discovers log files and rotates them using the standard logrotate utility. It is intended to be attached to workloads that write logs to disk and need automated rotation/retention.

This fork modernizes the project and bringt up to date containers.

## Overview

This container:

-   Generates a logrotate configuration based on environment variables.
-   Runs logrotate on a schedule (interval or cron schedule).
-   Supports compression, size thresholds, custom olddir, statusfile and scripts to run before/after rotation.

## Usage

Rotate Docker container logs (daily, keep 5 rotations):

```sh
docker run -d \
  -v /var/lib/docker/containers:/var/lib/docker/containers \
  -v /var/log/docker:/var/log/docker \
  -e "LOGS_DIRECTORIES=/var/lib/docker/containers /var/log/docker" \
ghcr.io/lazybytez/logrotate-container
```

Rotate hourly:

```sh
docker run -d \
  -v /var/lib/docker/containers:/var/lib/docker/containers \
  -v /var/log/docker:/var/log/docker \
  -e "LOGS_DIRECTORIES=/var/lib/docker/containers /var/log/docker" \
  -e "LOGROTATE_INTERVAL=hourly" \
ghcr.io/lazybytez/logrotate-container
```

Docker Compose example:

```yaml
services:
    logrotate:
        image: ghcr.io/lazybytez/logrotate-container:latest
        environment:
            LOGS_DIRECTORIES: /config/log/app/
            LOGROTATE_INTERVAL: daily
            LOGROTATE_SIZE: 1G
        volumes:
            - app_data:/config
```

## Environment variables

-   `LOGS_DIRECTORIES` (required) - space separated directories to scan, e.g. "/var/log /var/lib/docker/containers"
-   `LOG_FILE_ENDINGS` - space separated file extensions (default: "log")
-   `LOGROTATE_INTERVAL` - hourly|daily|weekly|monthly|yearly (affects logrotate rules)
-   `LOGROTATE_CRONSCHEDULE` - cron expression for the schedule; default is suitable for interval
-   `LOGROTATE_COPIES` - number of rotated copies to keep (default 5)
-   `LOGROTATE_SIZE` - trigger rotate when file exceeds size (e.g. 100k, 10M)
-   `LOGROTATE_COMPRESSION` - set to "compress" to enable compression
-   `LOGROTATE_DELAYCOMPRESS` - "false" to disable default delaycompress (when compression enabled)
-   `LOGROTATE_MODE` - e.g. "create 0644" to change rotate mode (default: copytruncate)
-   `LOGROTATE_OLDDIR` - directory to move old logs into
-   `LOGROTATE_STATUSFILE` - path to logrotate status file
-   `LOGROTATE_PARAMETERS` - raw flags passed to logrotate (e.g. "vdf")
-   `LOGROTATE_PREROTATE_COMMAND` / `LOGROTATE_POSTROTATE_COMMAND` - scripts/commands to run
-   `LOGROTATE_AUTOUPDATE` - regenerate logrotate configuration on each cron execution

## Examples & notes

-   To capture Docker JSON logs: set LOGS_DIRECTORIES to /var/lib/docker/containers and mount that path into the container.
-   To keep rotated logs in a separate volume: mount a host dir and set LOGROTATE_OLDDIR to that mount point.
-   If compression is enabled but you want the newest rotated file compressed immediately: set LOGROTATE_DELAYCOMPRESS=false.

## Limitations

-   Containers in read-only mode are not supported (this image generates a logrotate configuration on startup).

## Troubleshooting

-   Check the cron log (if you configured LOG_FILE) and the logrotate logfile (LOGROTATE_LOGFILE).
-   Ensure mounted paths are accessible by the container user.
-   Use LOGROTATE_PARAMETERS=v or vf to troubleshoot behavior without making changes.
-   Ensure the container is not running in read-only mode.

## Contributing

If you want to take part in contribution, like fixing issues and contributing directly to the code base, please visit
the [How to Contribute][gh-contribute] document.

## Useful links

-   [Contributing][gh-contribute]
-   [Code of conduct][gh-codeofconduct]
-   [Issues][gh-issues]
-   [Pull requests][gh-pulls]
-   [Logrotate manpage](http://www.linuxcommand.org/man_pages/logrotate8.html)
-   [Docker](https://www.docker.com/)

<!-- Variables -->

[gh-commit-badge]: https://img.shields.io/github/last-commit/lazybytez/logrotate-container?style=for-the-badge&colorA=302D41&colorB=cba6f7
[gh-commit]: https://github.com/lazybytez/logrotate-container/commits/main
[gh-contributors-badge]: https://img.shields.io/github/contributors/lazybytez/logrotate-container?style=for-the-badge&colorA=302D41&colorB=89dceb
[gh-contributors]: https://github.com/lazybytez/logrotate-container/graphs/contributors
[gh-stars-badge]: https://img.shields.io/github/stars/lazybytez?style=for-the-badge&colorA=302D41&colorB=f9e2af
[gh-downloads-badge]: https://img.shields.io/github/downloads/lazybytez/logrotate-container/total?style=for-the-badge&colorA=302D41&colorB=cba6f7
[gh-stars]: https://github.com/lazybytez/logrotate-container/stargazers
[gh-contribute]: https://github.com/lazybytez/.github/blob/main/docs/CONTRIBUTING.md
[gh-codeofconduct]: https://github.com/lazybytez/.github/blob/main/docs/CODE_OF_CONDUCT.md
[gh-issues]: https://github.com/lazybytez/logrotate-container/issues
[gh-pulls]: https://github.com/lazybytez/logrotate-container/pulls4
[gh-team]: https://github.com/lazybytez
