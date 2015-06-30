# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

ui = VUnit.from_argv()
ui.add_osvvm()

# Enable location preprocessor
# ----------------------------
#
# If you execute run.py with the verbose flag (python run.py -v) you will see
# that one test case (test_two_bytes_causes_overflow) generates a warning
#
# <some simulation time>: WARNING: Overflow
#
# In this case it's easy to locate where in the code this call was made.
# However, in a larger test, a test with many log and check calls, a test with
# less descriptive/unique messages, a test with non-static messages,
# or a test you're not very familiar with it may be harder to locate the source
# when all you have is the simulation time of the call.
#
# If you run this script which has enabled the location preprocessor you will
# see the following warning (remember the -v flag)
#
# <some simulation time>: WARNING in (tb_uart_rx.vhd:84): Overflow
#
# which immediately locates the call. The location preprocessor scans your files
# for log and check calls and adds the file name and line number as extra parameters
# to these calls. The modified source file is then saved in the vunit_out/preprocessed
# directory. It is the modified file that is compiled and the file that you would
# see in your simulator.
#
# Sometimes you write your own convenience subprograms for making special type
# of checks and log calls and then use that subprogram in various places in your
# code. Unless you do something special it will be the location of the standard
# log/check call made in that subprogram you'll see, not the location from which
# your subprogram was called. You can handle this problem by making sure that your
# subprogram has the file name and line number parameters recognized by VUnit and
# instruct the location preprocessor to scan for that subprogramas well.
#
# The src/test/tb_uart_tx.vhd file has one such convenience procedure:
#
# procedure check_received_bytes(bytes : integer_vector;
#                                line_num : natural := 0;
#                                file_name : string := "");
#
# Note the two last parameters and that the procedure name is passed to the location
# preprocessor below.
#
# Another use of the location preprocessor is that if you trigger a test run from your
# editor you can have the located output to appear visually in your source file, e.g.
# by using highlighting. The YouTube clips linked from the README.md file contains
# such an example.

ui.enable_location_preprocessing(additional_subprograms=["check_received_bytes"])

# Enable check preprocessor
# ----------------------------
#
# The check preprocessor looks for check_relation calls, generates an error message for the
# checked relation and then add that error message to the call. For example, if you have a call
#
# check_relation(number_of_received_bytes <= number_of_sent_bytes);
#
# and that relation fail you will have an error message looking something like this provided
# that the location preprocessor is enabled as well
#
# <some simulation time>: ERROR in (<file name>:<line number>): Relation number_of_received_bytes <=
# number_of_sent_bytes failed! Left is 18. Right is 17.
#
# check_relation can work with any VHDL relation, equalities included. For this reason it's worth
# pointing out the differences with the check_equal call:
#
# - check_relation may not work properly when the relation contains a call to an impure function.
#   The reason is that this function is called twice, once when the relation is evaluated and once
#   when the left and righthand values are calculated for the error messages. Use check_equal if it
#   supports the operand type or assign the result of the impure function call to a variable before the check
#   and then use the variable in the check_relation call
#
# - check_relation generates an error message. Calling
#
#   check_equal(number_of_received_bytes, number_of_sent_bytes)
#
#   without any error message would give this error message:
#
#   <time and location>: Equality check failed! Got 11. Expected 12.
#
#   i.e. there is no information on the relation itself unless you add a message of your own
#
#   check_equal(number_of_received_bytes, number_of_sent_bytes, "Number of sent and received bytes doesn't match.")
#
#   which would give
#
#   <time and location>: Equality check failed! Got 11. Expected 12. Number of sent and received
#   bytes doesn't match.
#
# - check_relation work with any operand type as long as the to_string function and the relational operator
#   are defined for that type. check_equal can compare operands of integer, natural, signed, unsigned,
#   std_logic_vector in relevant combinations (std_logic_vector is interpreted as unsigned). check_equal
#   can also compare std_logic and boolean in all combinations.
#
# - check_relation requires the preprocessor to be useful. It will still pass/fail correctly without but
#   the error message will just be "Check failed!"

ui.enable_check_preprocessing()

src_path = join(dirname(__file__), "src")

uart_lib = ui.add_library("uart_lib")
uart_lib.add_source_files(join(src_path, "*.vhd"))

tb_uart_lib = ui.add_library("tb_uart_lib")
tb_uart_lib.add_source_files(join(src_path, "test", "*.vhd"))

ui.main()
