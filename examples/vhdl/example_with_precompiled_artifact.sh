#!/bin/sh

# This shell script examplifies use of the --precompiled flag

test_file=tb_axis_loop-tb
if [ ! -f "$test_file" ]; then
  make compile move clean
fi
make simulate
test_output=$(find -iname output.txt)
if [ -n "$test_output" ]; then
  echo "Simulated with precompiled artifact."
  exit 0
else
  echo "Simulation with precompiled artifact failed."
  exit 1
fi
