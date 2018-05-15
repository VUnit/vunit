from os.path import join, dirname
from vunit import VUnit

import sys
import os
import subprocess

proj = VUnit.from_argv()
lib = proj.add_library("lib")
lib.add_source_files(join(dirname(__file__), "*.vhd"))


class StreamingIOTest(object):
    def __init__(self):
        self._input_gen = None
        self._output_val = None

    def pre_config(self, output_path):
        assert self._input_gen is None
        assert self._output_val is None

        input_file_name = join(output_path, "input")
        output_file_name = join(output_path, "output")

        os.mkfifo(input_file_name)
        os.mkfifo(output_file_name)

        self._input_gen = subprocess.Popen([sys.executable, join(dirname(__file__), "gen.py"),
                                            input_file_name])
        self._output_gen = subprocess.Popen([sys.executable, join(dirname(__file__), "val.py"),
                                             output_file_name])

        return True

    def post_check(self, output_path):
        assert self._input_gen is not None
        assert self._output_gen is not None

        assert self._input_gen.wait() == 0, "Input gen failed"
        assert self._output_gen.wait() == 0, "Output gen failed"

        return True

streamio = StreamingIOTest()
lib.test_bench("tb_example").set_pre_config(streamio.pre_config)
lib.test_bench("tb_example").set_post_check(streamio.post_check)

proj.main()
