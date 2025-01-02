// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com


`include "vunit_defines.svh"

module tb_with_parameter_config;

   parameter string output_path = "";
   parameter string set_parameter = "default";
   parameter string config_parameter = "default";
   parameter string lib_parameter = "default";
   parameter string libs_parameter = "default";

   `TEST_SUITE begin
      `CHECK_EQUAL(lib_parameter, "set-for-lib");
      `CHECK_EQUAL(libs_parameter, "set-for-libs");
      `TEST_CASE("Test 0") begin
         `CHECK_EQUAL(set_parameter, "set-for-module");
         `CHECK_EQUAL(config_parameter, "default");
      end
      `TEST_CASE("Test 1") begin
         `CHECK_EQUAL(set_parameter, "set-for-module");
         `CHECK_EQUAL(config_parameter, "set-from-config");
      end
      `TEST_CASE("Test 2") begin
         `CHECK_EQUAL(set_parameter, "set-for-test");
         `CHECK_EQUAL(config_parameter, "default");
      end
      `TEST_CASE("Test 3") begin
         `CHECK_EQUAL(set_parameter, "set-for-test");
         `CHECK_EQUAL(config_parameter, "set-from-config");
      end
      `TEST_CASE("Test 4") begin
         int fd;
         `CHECK_EQUAL(set_parameter, "set-from-config");
         `CHECK_EQUAL(config_parameter, "set-from-config");
         fd = $fopen({output_path, "post_check.txt"});
         $fwrite(fd, "Test 4 was here");
         $fclose(fd);
      end
   end;
endmodule
