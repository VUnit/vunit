// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

`timescale 10ns / 10ns
`include "vunit_defines.svh"

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

	`TEST_SUITE begin
		`TEST_SUITE_SETUP begin
			case_data1 = new();
			case_data1.make_random();
			case_greater = case_data1.data_int+1;
			case_less = case_data1.data_int-1;
		end
		`TEST_CASE("Check Macros Are Visible") begin
			// if(!case_data1.randomize())
			//	$error("Randomization failed");
			`CHECK_EQUAL(case_data1.data_int, case_data1.data_int);
			`CHECK_NOT_EQUAL(case_data1.data_int, case_greater);
			`CHECK_GREATER(case_greater, case_data1.data_int);
			`CHECK_LESS(case_less, case_data1.data_int);
			`CHECK_EQUAL_VARIANCE(case_less, case_data1.data_int, 2);
			`CHECK_EQUAL_VARIANCE(case_greater, case_data1.data_int, 2);
		end
		/* `TEST_CASE("CHECK_EQUAL failure message") begin
			`CHECK_EQUAL(case_data1.data_int, case_greater, "This test should fail.");
		end
		`TEST_CASE("CHECK_NOT_EQUAL failure message") begin
			`CHECK_NOT_EQUAL(case_data1.data_int, case_data1.data_int, "This test should fail.");
		end
		`TEST_CASE("CHECK_GREATER failure message") begin
			`CHECK_GREATER(case_data1.data_int, case_data1.data_int, "This test should fail.");
		end
		`TEST_CASE("CHECK_LESS failure message") begin
			`CHECK_LESS(case_data1.data_int, case_data1.data_int, "This test should fail.");
		end
		`TEST_CASE("CHECK_EQUAL_VARIANCE failure message") begin
			`CHECK_EQUAL_VARIANCE(case_data1.data_int, case_data1.data_int+5, 1, "This test should fail.");
		end */
	end
endmodule