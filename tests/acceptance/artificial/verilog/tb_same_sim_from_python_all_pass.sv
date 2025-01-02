// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

module tb_same_sim_from_python_all_pass;

   parameter string output_path = "";

   integer counter = 1;

   `TEST_SUITE begin

      `TEST_CASE("Test 1") begin
         $info("Test 1");
         `CHECK_EQUAL(counter, 1);
         counter = counter + 1;
      end

      `TEST_CASE("Test 2") begin
         $info("Test 2");
         `CHECK_EQUAL(counter, 2);
         counter = counter + 1;
      end

      `TEST_CASE("Test 3") begin
         int fd;
         $info("Test 3");
         `CHECK_EQUAL(counter, 3);
         counter = counter + 1;
         fd = $fopen({output_path, "post_check.txt"});
         $fwrite(fd, "Test 3 was here");
         $fclose(fd);
      end
   end;

   `WATCHDOG(1ns);
endmodule
