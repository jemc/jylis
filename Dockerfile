FROM alpine:3.7

# Install Pony dependencies and other build tools.
ENV LLVM_VERSION=3.9
RUN apk add --update \
        alpine-sdk clang-dev linux-headers libexecinfo-dev binutils-gold \
        libressl-dev pcre2-dev coreutils llvm${LLVM_VERSION}-dev

# Install Pony compiler and Pony runtime.
ENV PONYC_GIT_URL https://github.com/ponylang/ponyc
RUN git clone --depth 1 ${PONYC_GIT_URL} /tmp/ponyc && \
    cd /tmp/ponyc && \
    env CC=clang make default_pic=true install && \
    rm -rf /tmp/ponyc

# Install Pony dependency manager (stable).
# TODO: use master branch when this branch has been merged
ENV STABLE_GIT_URL https://github.com/ponylang/pony-stable
RUN git clone --depth 1 ${STABLE_GIT_URL} /tmp/pony-stable && \
    cd /tmp/pony-stable && \
    make config=release install && \
    rm -rf /tmp/pony-stable

# Build the application as a static binary.
# TODO: use --runtimebc (available only when clang version matches LLVM version)
ENV CC=clang
RUN mkdir /src
WORKDIR /src
COPY Makefile bundle.json /src/
COPY jylis /src/jylis
RUN stable fetch && stable env ponyc --static -o release jylis

# Transfer the static binary to a new empty image.
FROM scratch
COPY --from=0 /src/release/jylis .
ENTRYPOINT ["./jylis"]
