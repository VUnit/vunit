# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

# Make vunit python module importable
from os.path import join, dirname, basename
import sys
path_to_vunit = join(dirname(__file__), '..', '..')
sys.path.append(path_to_vunit)
#  -------

from vunit import VUnit
from vunit.csv_logs import CsvLogs

def post_merge_csv():
    def merge_csv(output_path):
        CsvLogs(join(output_path, "*.csv")).write(join(output_path,"merged_logs.csv"))
        return True
    return merge_csv

src_path = join(dirname(__file__), "src")

ui = VUnit.from_argv()
ui.enable_location_preprocessing(additional_subprograms=["check_received_bytes"])

uart_lib = ui.add_library("uart_lib")
uart_lib.add_source_files(join(src_path, "*.vhd"))

tb_uart_lib = ui.add_library("tb_uart_lib")
tb_uart_lib.add_source_files(join(src_path, "test", "*.vhd"))
tb_uart_rx = tb_uart_lib.entity("tb_uart_rx")
tb_uart_tx = tb_uart_lib.entity("tb_uart_tx")
tb_uart_rx.add_config(name="merge_csv", generics = dict(), post_check=post_merge_csv())
tb_uart_tx.add_config(name="merge_csv", generics = dict(), post_check=post_merge_csv())

ui.main()
