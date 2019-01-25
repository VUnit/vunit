// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

`timescale 10ns / 10ns
`include "vunit_defines.svh"

module check_tb;

	class test_data;
		randc	logic	[15:0] 	data_logic;
		randc	integer			data_integer;
		randc	byte			data_byte;
		randc	shortint		data_shortint;
		randc	longint			data_longint;
		randc	time			data_time;
		//randc	real			data_real;
	endclass;
	
	test_data case_data1;
	integer case_greater, case_less;

	`TEST_SUITE begin
		`TEST_SUITE_SETUP begin
			case_data1 = new();
		end
		
		`TEST_CASE("Check Macros Are Visible") begin
				if(!case_data1.randomize()) 
					$display("Randomization failed"); 
				case_greater = case_data1.data_integer+1;
				case_less = case_data1.data_integer-1;
				`CHECK_EQUAL(case_data1.data_integer, case_data1.data_integer);
				`CHECK_NOT_EQUAL(case_data1.data_integer, case_greater);
				`CHECK_GREATER(case_greater, case_data1.data_integer);
				`CHECK_LESS(case_less, case_data1.data_integer);
				`CHECK_EQUAL_VARIANCE(case_less, case_data1.data_integer, 2);
				`CHECK_EQUAL_VARIANCE(case_greater, case_data1.data_integer, 2);
			
		end
	end

endmodule 