#!/bin/sh

# Stop in case of error
set -e

docker build \
  --build-arg IMAGE="python:3-slim-bookworm" \
  --build-arg LLVM_VER=14 \
  --build-arg GNAT_VER=12 \
  --target vunit \
  -t "vunit/dev/${TAG}" \
  - <<-EOF
$(curl -fsSL https://raw.githubusercontent.com/ghdl/docker/master/run_debian.dockerfile)

FROM ghdl/pkg:bookworm-$PKG AS ghdl

FROM $TAG AS vunit
COPY --from=ghdl /usr/ /usr/
RUN pip install -U tox colorama coverage --progress-bar off
EOF
