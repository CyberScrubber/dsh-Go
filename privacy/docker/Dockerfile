# syntax=docker/dockerfile:1
# Build-only image: Linux x86_64 Flutter/Android SDK/NDK + the repo's runtime
# dependencies. No emulator is used at build time.
#
# Build from the repo root, with the small `tooling/` context:
#   docker build --platform linux/amd64 \
#     -f privacy/docker/Dockerfile -t dshgo-build tooling
#
# Run with the repo mounted at /src:
#   docker run --rm --platform linux/amd64 \
#     -v "$PWD":/src -w /src \
#     -v dshgo-gradle:/root/.gradle \
#     -v dshgo-pub:/root/.pub-cache \
#     dshgo-build \
#     'source /opt/dshgo/env.sh && (cd app && flutter pub get) && \
#      bash runtime/build-runtime.sh arm64-v8a && \
#      privacy/build.sh -f arm64 --build-name 1.2.1'
FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl file git gpgv python3 unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV DEV_ROOT=/opt/dshgo
COPY setup-toolchain.sh /opt/dshgo/setup-toolchain.sh
# Installs JDK 17, Flutter 3.47.7, Android SDK/NDK and writes /opt/dshgo/env.sh.
# It also installs an emulator + system image; build-only use can ignore them.
RUN bash /opt/dshgo/setup-toolchain.sh

WORKDIR /src
ENTRYPOINT ["/bin/bash", "-lc"]
