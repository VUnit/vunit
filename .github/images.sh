#!/bin/sh
set -eu

: "${TAG:?TAG must be set}"
: "${PKG:?PKG must be set}"

# Download separately so a failed download stops the script.
DOCKERFILE=$(curl -fsSL \
  https://raw.githubusercontent.com/ghdl/docker/master/run_debian.dockerfile)

docker build \
  --progress=plain \
  --build-arg IMAGE="python:3.13-slim-bookworm" \
  --build-arg LLVM_VER=14 \
  --build-arg GNAT_VER=12 \
  --target vunit \
  -t "vunit/dev/${TAG}" \
  - <<EOF
${DOCKERFILE}

FROM ${TAG} AS vunit

COPY --from=ghdl/pkg:bookworm-${PKG} / /usr/local/

RUN ghdl --version
RUN pip install -U tox colorama coverage --progress-bar off
EOF