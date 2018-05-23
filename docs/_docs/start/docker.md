---
title: Running in Docker
permalink: /docs/start/docker/
---

# Running in Docker

A [docker](https://www.docker.com/) image of Jylis is available on Docker Hub at [jemc/jylis](https://hub.docker.com/r/jemc/jylis/).

Start by pulling the latest image:

```bash
docker pull jemc/jylis
```

Now start a Jylis container:

```bash
docker run -p 6379:6379 jemc/jylis
```

The container is now ready to accept connections on port `6379`. Pressing `Ctrl + C` will shut down the container. Adding the `-d` flag before the image name will start the container in the background.

## docker-compose

This section demonstrates a minimal [docker-compose](https://docs.docker.com/compose/) file that will start Jylis and use a Redis CLI to connect to the database. Create a new directory and copy the following code to `docker-compose.yml`:

```yaml
version: "3"
services:
  db:
    image: jemc/jylis
    ports:
      - 6379:6379

  cli:
    image: redis:alpine
    restart: "no"
    command: redis-cli -h db
    links:
      - db
```

Start Jylis in the background:

```bash
docker-compose up -d
```

Run the Redis CLI:

```bash
docker-compose run cli
```

Jylis is exposed to the system on port `6379` if you would like to connect additional applications to the database.
