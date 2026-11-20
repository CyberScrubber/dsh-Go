#!/usr/bin/env bash
# Build a privacy APK: every dart entrypoint gets DSH_PRIVACY=1.
#
#   privacy/build.sh -f arm64 --build-name 1.0.18
#
# Do not pass your own `--`; this wrapper adds the define after the normal
# build-apk.sh options.
set -euo pipefail
ROOT=$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
exec "$ROOT/tooling/build-apk.sh" "$@" -- --dart-define=DSH_PRIVACY=1
