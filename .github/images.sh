#!/bin/sh

# Stop in case of error
set -e

docker build \
  --build-arg IMAGE="python:3-slim-buster" \
  --build-arg LLVM_VER=7 \
  --build-arg GNAT_VER=8 \
  --target vunit \
  -t "vunit/dev:${TAG}" \
  - <<-EOF
$(curl -fsSL https://raw.githubusercontent.com/ghdl/docker/master/run_debian.dockerfile)

FROM $TAG AS vunit
COPY --from=ghdl/pkg:buster-$PKG / /
RUN pip install -U tox colorama coverage --progress-bar off
EOF
