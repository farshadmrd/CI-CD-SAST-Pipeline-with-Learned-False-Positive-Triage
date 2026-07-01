FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# CodeQL builds C/C++ by watching a real compile, so the same autotools +
# build-essential toolchain the other agents use must be present to run
# libtiff's ./configure && make (parity with Infer and cppcheck).
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        autoconf \
        automake \
        libtool \
        pkg-config \
        git \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# The CodeQL *bundle* ships the CLI together with the pre-compiled standard
# query packs, so no `codeql pack download` (and thus no network) is needed at
# scan time. Pin a release for reproducibility instead of 'latest/download'.
ARG CODEQL_VERSION=2.20.3
RUN curl -fsSL "https://github.com/github/codeql-action/releases/download/codeql-bundle-v${CODEQL_VERSION}/codeql-bundle-linux64.tar.gz" \
        | tar -C /opt -xz \
    && ln -s /opt/codeql/codeql /usr/local/bin/codeql

# Fail the build here if the binary cannot run on this base, not later in CI.
RUN codeql version

WORKDIR /work
