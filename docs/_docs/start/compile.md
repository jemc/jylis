---
title: Compiling from Source
permalink: /docs/compile/
---

# Compiling from Source

## Get Pony

Jylis is written in the [Pony programming language](https://www.ponylang.org/), so you'll need to install a working Pony compiler [using a method appropriate to your platform](https://github.com/ponylang/ponyc/blob/master/README.md#installation). It's generally best to use the latest "bleeding edge" master branch of the Pony compiler, or at least the latest stable release.

## Get Stable

Jylis uses a dependency manager for Pony called [Stable](https://github.com/ponylang/pony-stable) to fetch and manage Pony libraries, so you'll also need to [install](https://github.com/ponylang/pony-stable#installation) it as well.

## Clone & Build

Once you've got access to `ponyc` and `stable` in your development environment, you're ready to clone the Jylis source code to your machine and compile it.

```bash
git clone https://github.com/jemc/jylis
cd jylis
stable fetch
make
```

After doing so, you should be the proud new owner of a compiled Jylis binary, sitting at `bin/jylis` in the project directory.

## Run Tests

If you want to work on hacking some changes into Jylis, you'll want to be able to run the test suite. You can do so by running `make test` in the project directory where you cloned the source code. Note that you'll need to have run `stable fetch` first to fetch any missing or outdated libraries.
