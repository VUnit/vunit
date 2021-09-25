# This make file examplifies the use of the --precompiled flag

TARGET = tb_axis_loop-tb
RUN_PY = array_axis_vcs/run.py
VUNIT = python3 $(RUN_PY)
VUNIT_FLAGS  = --minimal --elaborate
VUNIT_OUT_DIR = ./vunit_out
MOVE = find -iname $(TARGET) -exec cp -u {} $(PWD) \; ; \

DOCKER_CMD = docker run --rm -t \
  -v /$(PWD)/../..:/work \
  -w /work/examples/vhdl \
  -e PYTHONPATH=/work \
	ghdl/vunit:llvm-master sh -c

.PHONY: clean

all: clean make compile move clean simulate

compile:
	$(DOCKER_CMD) '$(VUNIT) $(VUNIT_FLAGS)'

move:
	$(MOVE)

simulate:
	$(DOCKER_CMD) '$(VUNIT) --precompiled $(TARGET)'

make:
ifeq ($(strip $(TARGET)),)
	@echo "run file not set. Use TARGET=<value> to set it."
	@exit 1
endif

clean:
	$(DOCKER_CMD) 'rm -rf $(VUNIT_OUT_DIR)'
