#!/bin/sh

cd $(dirname $0)

if [ -d "vunit_out" ]; then rm -rf vunit_out; fi

docker run --rm -t \
  -v /$(pwd)://work \
  -w //work \
  ghdl/ext:vunit-master sh -c ' \
    VUNIT_SIMULATOR=ghdl; \
    for f in $(find ./ -name 'run.py'); do python3 $f; done \
  '
