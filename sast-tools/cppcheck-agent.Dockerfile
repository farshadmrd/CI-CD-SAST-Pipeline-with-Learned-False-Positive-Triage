FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# cppcheck: the analyzer. bear: captures compile_commands.json so cppcheck sees
# the same include paths and macros the real build uses (parity with Infer).
# autotools + build-essential exist only to run libtiff's ./configure && make.
RUN apt-get update && apt-get install -y --no-install-recommends \
        cppcheck \
        bear \
        build-essential \
        autoconf \
        automake \
        libtool \
        pkg-config \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN cppcheck --version
