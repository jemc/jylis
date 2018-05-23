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
