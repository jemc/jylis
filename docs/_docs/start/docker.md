---
title: Running in Docker
permalink: /docs/start/docker/
---

# Running in Docker

To try Jylis in Docker, use the [`jemc/jylis`](https://hub.docker.com/r/jemc/jylis/) image published to Dockerhub:

```
$ docker run -p 6379:6379 jemc/jylis
Unable to find image 'jemc/jylis:latest' locally
latest: Pulling from jemc/jylis
4c25dfc6b921: Pull complete
Digest: sha256:31ab5e9a21430a950ab20467d9be9c96b5a8f1b6c88160b571a086ea5a1ec9a4
Status: Downloaded newer image for jemc/jylis:latest
                   ,           ,                 ,           ,
                .a8P8a.     .a8P8a.           .a8P8a.     .a8P8a.
                |8   8|     |8   `*8a.     .a8*'   8|     |8   8|
                '*8d8*;     '*8a.   `*8a.a8*'   .a8*'     '*8d8*'
       ,           ;a8P8a.     `*8a.   `*'   .a8*'           ;           .
    .a8P8a.        |8   `*8a.     `*8a.   .a8*'     ,     .a8P8a.     .a8P8a.
    |8   `*8a.     '*8a.   `*8a.     |8   8|     .a8P8a.  |8   8|  .a8*'   8|
    '*8a.   `*8a.     `*8a.   8|     |8   8|     |8   8|  |8   8|  |8   .a8*'
       '*8a.   `*8a.     |8   8|     |8   8|     |8   8|  |8   8|  |8   8|
          ;8>     8|     |8   8|     |8   8|     |8   8|  '*8d8*'  |8   8|
       .a8*'   .a8*'     |8   8|     |8   8|     |8   8|     `     |8   8|
    .a8*'   .a8*'     .a8*'   8|     |8   8|     |8   `*8a.     .a8*'   8|
    |8   .a8*'     .a8*'   .a8*'     |8   8|     |8      8|     |8   .a8*'
    '*8d8*'        |8   .a8*'     .a8*'   8|     |8   .a8*'     '*8d8*'
       `           '*8d8*'     .a8*'   .a8*'     '*8d8*'           `
                      `        |8   .a8*'           `
                               '*8d8*'
                                  `
advertises cluster address: 127.0.0.1:9999:sacred-ink-0a01fe046985
serves commands on port:    6379
(I) cluster listener ready
(I) server listener ready
```

You will then able to [interact with the Jylis server using a client](../connect)  on your Docker host's port 6379.
