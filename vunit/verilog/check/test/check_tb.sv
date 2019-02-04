// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

`timescale 10ns / 10ns
`include "vunit_defines.svh"
`define __ERROR_FUNC(err_msg) $sformat(test_output, "%s", err_msg);
`define MAX_TESTS 512

module check_tb;

	class test_data;
		bit				[15:0] 	data_bit;
		int				data_int;
		byte			data_byte;
		shortint		data_shortint;
		time			data_time;
		function void make_random;
			data_bit = $random();
			data_int = int'($random());
			data_byte = byte'($random());
			data_shortint = shortint'($random());
			data_time = time'($random());
		endfunction
	endclass
	test_data case_data1;
	integer case_greater, case_less;
	string test_output;
	string test_expected;
	string err_msg;
	
	function bit check_string_empty(string str);
		if (str.compare("") !== 1) 
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
			case_data1 = new();
			case_data1.make_random();
			case_greater = case_data1.data_int+1;
			case_less = case_data1.data_int-1;
			test_output = "";
		end
		`TEST_CASE("Check Macros Are Visible") begin
			// if(!case_data1.randomize())
			//	$error("Randomization failed");
			// Since $error is overriden by a macro, we need to explicitly check
			// test output. The test_output string is only empty if the test passes.
			`CHECK_EQUAL(case_data1.data_int, case_data1.data_int);
			assert(check_string_empty(test_output) == 1);
			`CHECK_NOT_EQUAL(case_data1.data_int, case_greater);
			assert(check_string_empty(test_output) == 1);
			`CHECK_GREATER(case_greater, case_data1.data_int);
			assert(check_string_empty(test_output) == 1);
			`CHECK_LESS(case_less, case_data1.data_int);
			assert(check_string_empty(test_output) == 1);
			`CHECK_EQUAL_VARIANCE(case_less, case_data1.data_int, 2);
			assert(check_string_empty(test_output) == 1);
			`CHECK_EQUAL_VARIANCE(case_greater, case_data1.data_int, 2);
			assert(check_string_empty(test_output) == 1);
		end
		`TEST_CASE("CHECK_EQUAL failure message") begin
			// Check printouts for correct error messages
			for (int x = 0; x < `MAX_TESTS; x++) begin
				case_data1.make_random();
				case_greater = case_data1.data_int+1;
				`CHECK_EQUAL(case_data1.data_int, case_greater, "This test should fail.");
				$sformat(test_expected, "CHECK_EQUAL failed! Got %d expected %d. This test should fail.", case_data1.data_int, case_greater);
				check_macro_output(test_output, test_expected);
				test_output = "";
				`CHECK_EQUAL(case_data1.data_int, case_greater);
				$sformat(test_expected, "CHECK_EQUAL failed! Got %d expected %d. ", case_data1.data_int, case_greater);
				check_macro_output(test_output, test_expected);
				test_output = "";
			end
		end
		`TEST_CASE("CHECK_NOT_EQUAL failure message") begin
			for (int x = 0; x < `MAX_TESTS; x++) begin
				case_data1.make_random();
				case_greater = case_data1.data_int+1;
				`CHECK_NOT_EQUAL(case_data1.data_int, case_data1.data_int, "This test should fail.");
				$sformat(test_expected, "CHECK_NOT_EQUAL failed! Got %d expected %d. This test should fail.", case_data1.data_int, case_data1.data_int);
				check_macro_output(test_output, test_expected);
				test_output = "";
				`CHECK_NOT_EQUAL(case_data1.data_int, case_data1.data_int);
				$sformat(test_expected, "CHECK_NOT_EQUAL failed! Got %d expected %d. ", case_data1.data_int, case_data1.data_int);
				check_macro_output(test_output, test_expected);
				test_output = "";
			end
		end
		`TEST_CASE("CHECK_GREATER failure message") begin
			for (int x = 0; x < `MAX_TESTS; x++) begin
				case_data1.make_random();
				`CHECK_GREATER(case_data1.data_int, case_data1.data_int, "This test should fail.");
				$sformat(test_expected, "CHECK_GREATER failed! Got %d expected %d. This test should fail.", case_data1.data_int, case_data1.data_int);
				check_macro_output(test_output, test_expected);
				test_output = "";
				`CHECK_GREATER(case_data1.data_int, case_data1.data_int);
				$sformat(test_expected, "CHECK_GREATER failed! Got %d expected %d. ", case_data1.data_int, case_data1.data_int);
				check_macro_output(test_output, test_expected);
				test_output = "";
			end
		end
		`TEST_CASE("CHECK_LESS failure message") begin
			for (int x = 0; x < `MAX_TESTS; x++) begin
				case_data1.make_random();
				`CHECK_LESS(case_data1.data_int, case_data1.data_int, "This test should fail.");
				$sformat(test_expected, "CHECK_LESS failed! Got %d expected %d. This test should fail.", case_data1.data_int, case_data1.data_int);
				check_macro_output(test_output, test_expected);
				test_output = "";
				`CHECK_LESS(case_data1.data_int, case_data1.data_int);
				$sformat(test_expected, "CHECK_LESS failed! Got %d expected %d. ", case_data1.data_int, case_data1.data_int);
				check_macro_output(test_output, test_expected);
				test_output = "";
			end
		end
		`TEST_CASE("CHECK_EQUAL_VARIANCE failure message") begin
			integer rand_int1, rand_int2;
			for (int x = 0; x < `MAX_TESTS; x++) begin
				rand_int1 = $random();
				rand_int2 = rand_int1 + 15;
				`CHECK_EQUAL_VARIANCE(rand_int1, rand_int2, 5, "This test should fail.");
				$sformat(test_expected, "CHECK_EQUAL_VARIANCE failed! Got %d expected %d +- %d. This test should fail.", rand_int1, rand_int2, 5);
				check_macro_output(test_output, test_expected);
				test_output = "";
				`CHECK_EQUAL_VARIANCE(rand_int1, rand_int2, 5);
				$sformat(test_expected, "CHECK_EQUAL_VARIANCE failed! Got %d expected %d +- %d. ", rand_int1, rand_int2, 5);
				check_macro_output(test_output, test_expected);
				test_output = "";
			end
		end 
	end
endmodule