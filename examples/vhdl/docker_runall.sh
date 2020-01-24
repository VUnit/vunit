#!/bin/sh

cd $(dirname "$0")

docker run --rm -t \
  -v /$(pwd)/../..://work \
  -w //work/examples/vhdl \
  -e PYTHONPATH=//work \
  ghdl/vunit:llvm-master sh -c ' \
    VUNIT_SIMULATOR=ghdl; \
    for f in `find ./ -name run.py`; do \
      if [ -d "vunit_out" ]; then rm -rf vunit_out; fi; \
      python3 $f; \
    done \
  '
