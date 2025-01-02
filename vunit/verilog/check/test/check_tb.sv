// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

`timescale 10ns / 10ns
`include "vunit_defines.svh"
`define __ERROR_FUNC(err_msg) $sformat(test_output, "%s", err_msg);
`define MAX_TESTS 512
`define TEST_VARIANCE 5

module check_tb;

   class test_data;
      bit            [15:0]    data_bit;
      int            data_int;
      byte         data_byte;
      shortint      data_shortint;
      time         data_time;
      function void make_random;
         data_bit = $random();
         data_int = int'($random());
         data_byte = byte'($random());
         data_shortint = shortint'($random());
         data_time = time'($random());
      endfunction
   endclass
   test_data tc_data1;
   test_data tc_data2;
   integer tc_greater, tc_less;
   string test_output;
   string test_expected;
   string err_msg;
   function bit check_string_empty(string str);
      if (str.len() == 0)
         return 1;
      else
         return 0;
   endfunction
   function void check_macro_output(string actual, string expected);
      assert ( actual.compare(expected) == 0) else
         begin
            $sformat(err_msg, "CHECK_EQUAL_ERROR: Failure message not as expected.\n RECV: |%f|\n  EXP: |%f|\n", actual, expected);
            $error(err_msg);
         end;
   endfunction;
   `TEST_SUITE begin
      `TEST_SUITE_SETUP begin
         string str;
         tc_data1 = new();
         tc_data2 = new();
         tc_data1.make_random();
         tc_greater = tc_data1.data_int+1;
         tc_less = tc_data1.data_int-1;
         test_output = "";
      end
      `TEST_CASE("Check Macros Are Visible") begin
         // Since $error is overriden by a macro, we need to explicitly check
         // test output. The test_output string is only empty if the test passes.
         `CHECK_EQUAL(tc_data1.data_int, tc_data1.data_int);
         assert(check_string_empty(test_output) == 1);
         `CHECK_NOT_EQUAL(tc_data1.data_int, tc_greater);
         assert(check_string_empty(test_output) == 1);
         `CHECK_GREATER(tc_greater, tc_data1.data_int);
         assert(check_string_empty(test_output) == 1);
         `CHECK_LESS(tc_less, tc_data1.data_int);
         assert(check_string_empty(test_output) == 1);
         `CHECK_EQUAL_VARIANCE(tc_less, tc_data1.data_int, 2);
         assert(check_string_empty(test_output) == 1);
         `CHECK_EQUAL_VARIANCE(tc_greater, tc_data1.data_int, 2);
         assert(check_string_empty(test_output) == 1);
      end
      `TEST_CASE("CREATE_MSG output w message") begin
         `CREATE_MSG(full_msg, "CHECK_EQUAL", tc_data1.data_int, tc_greater, "=", "This test should fail.");
         $sformat(test_expected, "CHECK_EQUAL failed! Got tc_data1.data_int=%0d expected =%0d. This test should fail.", tc_data1.data_int, tc_greater);
         check_macro_output(full_msg, test_expected);
      end
      `TEST_CASE("CREATE_MSG output wo message") begin
         `CREATE_MSG(full_msg, "CHECK_EQUAL", tc_data1.data_int, tc_greater, "=");
         $sformat(test_expected, "CHECK_EQUAL failed! Got tc_data1.data_int=%0d expected =%0d. ", tc_data1.data_int, tc_greater);
         check_macro_output(full_msg, test_expected);
      end
      `TEST_CASE("Test that there are no extra spaces") begin
         `CREATE_MSG(full_msg, "CHECK_EQUAL", 17, 21, "", "This test should fail.");
         $sformat(test_expected, "CHECK_EQUAL failed! Got 17=17 expected 21. This test should fail.");
         check_macro_output(full_msg, test_expected);
      end
      `TEST_CASE("CHECK_EQUAL_VARIANCE failure message integer") begin
         // Check printouts for correct error messages
         integer rand_int1, rand_int2;
         rand_int1 = $random();
         rand_int2 = rand_int1 + 15;
         `CHECK_EQUAL_VARIANCE(rand_int1, rand_int2, 5, "This test should fail.");
         $sformat(test_expected, "CHECK_EQUAL_VARIANCE failed! Got rand_int1=%0d expected %0d +-%0d. This test should fail.", rand_int1, rand_int2, 5);
         check_macro_output(test_output, test_expected);
         test_output = "";
         `CHECK_EQUAL_VARIANCE(rand_int1, rand_int2, 5);
         $sformat(test_expected, "CHECK_EQUAL_VARIANCE failed! Got rand_int1=%0d expected %0d +-%0d. ", rand_int1, rand_int2, 5);
         check_macro_output(test_output, test_expected);
         test_output = "";
      end
      `TEST_CASE("CHECK_EQUAL Int Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_EQUAL(tc_data1.data_int, tc_data2.data_int);
            if (tc_data1.data_int == tc_data2.data_int) begin
               $display("Test data is equal, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_EQUAL failed! Got tc_data1.data_int=%0d expected %0d. ", tc_data1.data_int, tc_data2.data_int);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
      `TEST_CASE("CHECK_NOT_EQUAL Int Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            `CHECK_NOT_EQUAL(tc_data1.data_int, tc_data1.data_int);
            $sformat(test_expected, "CHECK_NOT_EQUAL failed! Got tc_data1.data_int=%0d expected !=%0d. ", tc_data1.data_int, tc_data1.data_int);
            check_macro_output(test_output, test_expected);
            test_output = "";
         end
      end
      `TEST_CASE("CHECK_GREATER Int Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_GREATER(tc_data1.data_int, tc_data2.data_int);
            if (tc_data1.data_int > tc_data2.data_int) begin
               $display("Test data is greater, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_GREATER failed! Got tc_data1.data_int=%0d expected >%0d. ", tc_data1.data_int, tc_data2.data_int);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
      `TEST_CASE("CHECK_LESS Int Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_LESS(tc_data1.data_int, tc_data2.data_int);
            if (tc_data1.data_int < tc_data2.data_int) begin
               $display("Test data is less, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_LESS failed! Got tc_data1.data_int=%0d expected <%0d. ", tc_data1.data_int, tc_data2.data_int);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
      `TEST_CASE("CHECK_EQUAL_VARIANCE Int Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_EQUAL_VARIANCE(tc_data1.data_int, tc_data2.data_int, `TEST_VARIANCE);
            if ((tc_data1.data_int > tc_data2.data_int - `TEST_VARIANCE) && (tc_data1.data_int < tc_data2.data_int + `TEST_VARIANCE)) begin
               $display("Test data is equal, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_EQUAL_VARIANCE failed! Got tc_data1.data_int=%0d expected %0d +-%0d. ", tc_data1.data_int, tc_data2.data_int, `TEST_VARIANCE);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
      `TEST_CASE("CHECK_EQUAL Time Random Tests") begin
         for (time x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_EQUAL(tc_data1.data_time, tc_data2.data_time);
            if (tc_data1.data_time == tc_data2.data_time) begin
               $display("Test data is equal, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_EQUAL failed! Got tc_data1.data_time=%0d expected %0d. ", tc_data1.data_time, tc_data2.data_time);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
      `TEST_CASE("CHECK_NOT_EQUAL Time Random Tests") begin
         for (time x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_NOT_EQUAL(tc_data1.data_time, tc_data1.data_time);
            $sformat(test_expected, "CHECK_NOT_EQUAL failed! Got tc_data1.data_time=%0d expected !=%0d. ", tc_data1.data_time, tc_data1.data_time);
            check_macro_output(test_output, test_expected);
            test_output = "";
         end
      end
      `TEST_CASE("CHECK_GREATER Time Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_GREATER(tc_data1.data_time, tc_data2.data_time);
            if (tc_data1.data_time > tc_data2.data_time) begin
               $display("Test data is greater, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_GREATER failed! Got tc_data1.data_time=%0d expected >%0d. ", tc_data1.data_time, tc_data2.data_time);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
      `TEST_CASE("CHECK_LESS Time Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_LESS(tc_data1.data_time, tc_data2.data_time);
            if (tc_data1.data_time < tc_data2.data_time) begin
               $display("Test data is lesser, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_LESS failed! Got tc_data1.data_time=%0d expected <%0d. ", tc_data1.data_time, tc_data2.data_time);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
      `TEST_CASE("CHECK_EQUAL_VARIANCE Time Random Tests") begin
         for (int x = 0; x < `MAX_TESTS; x++) begin
            tc_data1.make_random();
            tc_data2.make_random();
            `CHECK_EQUAL_VARIANCE(tc_data1.data_time, tc_data2.data_time, `TEST_VARIANCE);
            if ((tc_data1.data_time > tc_data2.data_time - `TEST_VARIANCE) && (tc_data1.data_time < tc_data2.data_time + `TEST_VARIANCE)) begin
               $display("Test data is equal, checking output");
               assert(check_string_empty(test_output) == 1);
            end
            else begin
               $sformat(test_expected, "CHECK_EQUAL_VARIANCE failed! Got tc_data1.data_time=%0d expected %0d +-%0d. ", tc_data1.data_time, tc_data2.data_time, `TEST_VARIANCE);
               check_macro_output(test_output, test_expected);
               test_output = "";
            end
         end
      end
   end
endmodule
