#!/usr/bin/env sh

docker run --rm -t \
  -v $(pwd):/src \
  -w /src \
  -e PYTHONPATH=/src \
  ghcr.io/vunit/dev/llvm \
  "$@"
