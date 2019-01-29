// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

`define WATCHDOG(runtime) \
   initial begin \
      __runner__.watchdog((runtime) / 1ns); \
   end

`define TEST_SUITE_FROM_PARAMETER(parameter_name) \
   parameter string parameter_name = ""; \
   import vunit_pkg::*; \
   initial \
     if (__runner__.setup(parameter_name)) \
      while (__runner__.loop)

`define TEST_SUITE `TEST_SUITE_FROM_PARAMETER(runner_cfg)
`define NESTED_TEST_SUITE `TEST_SUITE_FROM_PARAMETER(nested_runner_cfg)

`define TEST_CASE(test_name) if (__runner__.run(test_name))

`define TEST_SUITE_SETUP if (__runner__.is_test_suite_setup())
`define TEST_SUITE_CLEANUP if (__runner__.is_test_suite_cleanup())

`define TEST_CASE_SETUP if (__runner__.is_test_case_setup())
`define TEST_CASE_CLEANUP if (__runner__.is_test_case_cleanup())
`define CREATE_MSG(full_msg,func_name,got,expected,msg=__none) \
	string __none__; \
	string got_str; \
	string expected_str; \
	string full_msg; \
	int index; \
	got_str = "";\
	expected_str ="";\
	$swrite(got_str, got); \
	$swrite(expected_str, expected); \
	for (int i=0; i<got_str.len(); i++) begin \
		if (got_str[i] != " ") begin \
			got_str = got_str.substr(i, got_str.len()-1); \
			break; \
		end \
	end \
	for (int i=0; i<expected_str.len(); i++) begin \
		if (expected_str[i] != " ") begin \
			expected_str = expected_str.substr(i, expected_str.len()-1); \
			break; \
		end \
	end \
	full_msg = {func_name, " failed! Got ",`"got`", "=",  got_str, " expected ", expected_str, ". ", msg}; 
`define CHECK_EQUAL(got,expected,msg=__none__) \
        assert ((got) === (expected)) else \
          begin \
			 `CREATE_MSG(full_msg, "CHECK_EQUAL", got, expected, msg); \
             $error(full_msg); \
          end
`define CHECK_NOT_EQUAL(got,expected,msg=__none__) \
        assert ((got) !== (expected)) else \
          begin \
             `CREATE_MSG(full_msg, "CHECK_NOT_EQUAL", got, expected, msg); \
             $error(full_msg); \
          end
`define CHECK_GREATER(got,expected,msg=__none__) \
        assert ((got) > (expected)) else \
          begin \
             `CREATE_MSG(full_msg, "CHECK_GREATER", got, expected, msg); \
             $error(full_msg); \
          end
`define CHECK_LESS(got,expected,msg=__none__) \
        assert ((got) < (expected)) else \
          begin \
             `CREATE_MSG(full_msg, "CHECK_LESS", got, expected, msg); \
             $error(full_msg); \
          end
`define CHECK_EQUAL_VARIANCE(got,expected,variance,msg=__none__) \
        assert (((got) < ((expected) + (variance))) && ((got) > ((expected) - (variance)))) else \
          begin \
             string __none__; \
             string got_str; \
             string expected_str; \
			 string variance_str; \
             string full_msg; \
             int index; \
             got_str = "";\
			 variance_str = "";\
             expected_str ="";\
             $swrite(got_str, got); \
			 $swrite(variance_str, variance); \
             $swrite(expected_str, expected); \
               for (int i=0; i<got_str.len(); i++) begin \
                  if (got_str[i] != " ") begin \
                     got_str = got_str.substr(i, got_str.len()-1); \
                     break; \
                  end \
               end \
			   for (int i=0; i<variance_str.len(); i++) begin \
                  if (variance_str[i] != " ") begin \
                     variance_str = variance_str.substr(i, variance_str.len()-1); \
                     break; \
                  end \
               end \
               for (int i=0; i<expected_str.len(); i++) begin \
                  if (expected_str[i] != " ") begin \
                     expected_str = expected_str.substr(i, expected_str.len()-1); \
                     break; \
                  end \
               end \
             full_msg = {"CHECK_EQUAL_VARIANCE failed! Got ",`"got`", "=",  got_str, " expected ", expected_str, ", +-", variance_str, ". ", msg}; \
             $error(full_msg); \
          end