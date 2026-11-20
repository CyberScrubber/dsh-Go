#!/usr/bin/env bash
# Build a privacy APK in a linux/amd64 Docker container.
#
#   privacy/docker/build.sh 1.2.1
#   FLAVOR=x64 privacy/docker/build.sh 1.2.1
#
# The first run builds the toolchain image (large: JDK + Flutter + Android
# SDK/NDK + emulator/system image); later runs reuse it and the Gradle/pub
# volumes.
set -euo pipefail
ROOT=$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VERSION=${1:?usage: privacy/docker/build.sh <version, e.g. 1.2.1>}
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
  echo "not a version name: $VERSION" >&2
  exit 2
}

FLAVOR=${FLAVOR:-arm64}
case "$FLAVOR" in
  arm64) ABI=arm64-v8a ;;
  x64) ABI=x86_64 ;;
  *) echo "FLAVOR must be arm64 or x64" >&2; exit 2 ;;
esac

docker build --platform linux/amd64 \
  -f "$ROOT/privacy/docker/Dockerfile" \
  -t dshgo-build \
  "$ROOT/tooling"

# The container writes into the bind-mounted repo. On macOS Docker Desktop
# that lands as the host user; on a Linux host it is root-owned.
docker run --rm --platform linux/amd64 \
  -v "$ROOT":/src -w /src \
  -v dshgo-gradle:/root/.gradle \
  -v dshgo-pub:/root/.pub-cache \
  dshgo-build \
  "source /opt/dshgo/env.sh && \
   (cd app && flutter pub get) && \
   bash runtime/build-runtime.sh $ABI && \
   privacy/build.sh -f $FLAVOR --build-name $VERSION"
