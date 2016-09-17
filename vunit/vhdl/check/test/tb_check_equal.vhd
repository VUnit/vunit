-- This test suite verifies the check_equal checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
use vunit_lib.log_types_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;
use work.test_count.all;

entity tb_check_equal is
  generic (
    runner_cfg : string);
end entity tb_check_equal;

architecture test_fixture of tb_check_equal is
begin
  check_equal_runner : process
    variable stat : checker_stat_t;
    variable check_equal_checker : checker_t;
    variable pass : boolean;
  begin
    checker_init(check_equal_checker);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should handle comparison of vectors longer than 32 bits") then
        get_checker_stat(stat);
        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        verify_passed_checks(stat, 4);

        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");
        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");

        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");
        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");
      elsif run("Test when integer check fails on comparison with short vector") then
        check_equal(unsigned'(X"A5"), natural'(256));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 256 (1_0000_0000).");
        check_equal(natural'(256), unsigned'(X"A5"));
        verify_log_call(inc_count, "Equality check failed! Got 256 (1_0000_0000). Expected 1010_0101 (165).");
        check_equal(unsigned'(X"A5"), natural'(2147483647));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 2147483647 (111_1111_1111_1111_1111_1111_1111_1111).");

        check_equal(signed'(X"A5"), integer'(-256));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected -256 (1_0000_0000).");
        check_equal(integer'(-256), signed'(X"A5"));
        verify_log_call(inc_count, "Equality check failed! Got -256 (1_0000_0000). Expected 1010_0101 (-91).");
        check_equal(signed'(X"05"), integer'(256));
        verify_log_call(inc_count, "Equality check failed! Got 0000_0101 (5). Expected 256 (01_0000_0000).");
        check_equal(signed'(X"A5"), integer'(-2147483648));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected -2147483648 (1000_0000_0000_0000_0000_0000_0000_0000).");
      elsif run("Test should pass on unsigned equal unsigned") then
        get_checker_stat(stat);
        check_equal(unsigned'(X"A5"), unsigned'(X"A5"));
        check_equal(pass, unsigned'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(unsigned'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(to_unsigned(natural'left,31), to_unsigned(natural'left,31));
        check_equal(to_unsigned(natural'right,31), to_unsigned(natural'right,31));
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, unsigned'(X"A5"), unsigned'(X"A5"));
        check_equal(check_equal_checker, pass, unsigned'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on unsigned not equal unsigned") then
        check_equal(unsigned'(X"A5"), unsigned'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(unsigned'(X"A5"), unsigned'(X"5A"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90). Extra info.");
        check_equal(pass, unsigned'(X"A5"), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        pass := check_equal(unsigned'(X"A5"), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");

        check_equal(check_equal_checker, unsigned'(X"A5"), unsigned'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(check_equal_checker, pass, unsigned'(X"A5"), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
      elsif run("Test should pass on unsigned equal natural") then
        get_checker_stat(stat);
        check_equal(unsigned'(X"A5"), natural'(165));
        check_equal(pass, unsigned'(X"A5"), natural'(165));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(unsigned'(X"A5"), natural'(165));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(to_unsigned(natural'left,31), natural'left);
        check_equal(to_unsigned(natural'right,31), natural'right);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, unsigned'(X"A5"), natural'(165));
        check_equal(check_equal_checker, pass, unsigned'(X"A5"), natural'(165));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on unsigned not equal natural") then
        check_equal(unsigned'(X"A5"), natural'(90));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 90 (0101_1010).");
        check_equal(unsigned'(X"A5"), natural'(90), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 90 (0101_1010). Extra info.");
        check_equal(pass, unsigned'(X"A5"), natural'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 90 (0101_1010).");
        pass := check_equal(unsigned'(X"A5"), natural'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 90 (0101_1010).");

        check_equal(check_equal_checker, unsigned'(X"A5"), natural'(90));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 90 (0101_1010).");
        check_equal(check_equal_checker, pass, unsigned'(X"A5"), natural'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 90 (0101_1010).");
      elsif run("Test should pass on natural equal unsigned") then
        get_checker_stat(stat);
        check_equal(natural'(165), unsigned'(X"A5"));
        check_equal(pass, natural'(165), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(natural'(165), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(natural'left, to_unsigned(natural'left,31));
        check_equal(natural'right, to_unsigned(natural'right,31));
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, natural'(165), unsigned'(X"A5"));
        check_equal(check_equal_checker, pass, natural'(165), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on natural not equal unsigned") then
        check_equal(natural'(165), unsigned'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 165 (1010_0101). Expected 0101_1010 (90).");
        check_equal(natural'(165), unsigned'(X"5A"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 165 (1010_0101). Expected 0101_1010 (90). Extra info.");
        check_equal(pass, natural'(165), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 165 (1010_0101). Expected 0101_1010 (90).");
        pass := check_equal(natural'(165), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 165 (1010_0101). Expected 0101_1010 (90).");

        check_equal(check_equal_checker, natural'(165), unsigned'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 165 (1010_0101). Expected 0101_1010 (90).");
        check_equal(check_equal_checker, pass, natural'(165), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 165 (1010_0101). Expected 0101_1010 (90).");
      elsif run("Test should pass on unsigned equal std_logic_vector") then
        get_checker_stat(stat);
        check_equal(unsigned'(X"A5"), std_logic_vector'(X"A5"));
        check_equal(pass, unsigned'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(unsigned'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(to_unsigned(natural'left,31), std_logic_vector(to_unsigned(natural'left,31)));
        check_equal(to_unsigned(natural'right,31), std_logic_vector(to_unsigned(natural'right,31)));
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, unsigned'(X"A5"), std_logic_vector'(X"A5"));
        check_equal(check_equal_checker, pass, unsigned'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on unsigned not equal std_logic_vector") then
        check_equal(unsigned'(X"A5"), std_logic_vector'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(unsigned'(X"A5"), std_logic_vector'(X"5A"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90). Extra info.");
        check_equal(pass, unsigned'(X"A5"), std_logic_vector'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        pass := check_equal(unsigned'(X"A5"), std_logic_vector'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");

        check_equal(check_equal_checker, unsigned'(X"A5"), std_logic_vector'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(check_equal_checker, pass, unsigned'(X"A5"), std_logic_vector'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
      elsif run("Test should pass on std_logic_vector equal unsigned") then
        get_checker_stat(stat);
        check_equal(std_logic_vector'(X"A5"), unsigned'(X"A5"));
        check_equal(pass, std_logic_vector'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(std_logic_vector'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(std_logic_vector(to_unsigned(natural'left,31)), to_unsigned(natural'left,31));
        check_equal(std_logic_vector(to_unsigned(natural'right,31)), to_unsigned(natural'right,31));
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, std_logic_vector'(X"A5"), unsigned'(X"A5"));
        check_equal(check_equal_checker, pass, std_logic_vector'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on std_logic_vector not equal unsigned") then
        check_equal(std_logic_vector'(X"A5"), unsigned'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(std_logic_vector'(X"A5"), unsigned'(X"5A"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90). Extra info.");
        check_equal(pass, std_logic_vector'(X"A5"), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        pass := check_equal(std_logic_vector'(X"A5"), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");

        check_equal(check_equal_checker, std_logic_vector'(X"A5"), unsigned'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(check_equal_checker, pass, std_logic_vector'(X"A5"), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
      elsif run("Test should pass on std_logic_vector equal std_logic_vector") then
        get_checker_stat(stat);
        check_equal(std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        check_equal(pass, std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(std_logic_vector(to_unsigned(natural'left,31)), std_logic_vector(to_unsigned(natural'left,31)));
        check_equal(std_logic_vector(to_unsigned(natural'right,31)), std_logic_vector(to_unsigned(natural'right,31)));
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        check_equal(check_equal_checker, pass, std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on std_logic_vector not equal std_logic_vector") then
        check_equal(std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(std_logic_vector'(X"A5"), std_logic_vector'(X"5A"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90). Extra info.");
        check_equal(pass, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        pass := check_equal(std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");

        check_equal(check_equal_checker, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_equal(check_equal_checker, pass, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 0101_1010 (90).");
      elsif run("Test should pass on signed equal signed") then
        get_checker_stat(stat);
        check_equal(signed'(X"A5"), signed'(X"A5"));
        check_equal(pass, signed'(X"A5"), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(signed'(X"A5"), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(to_signed(integer'left,32), to_signed(integer'left,32));
        check_equal(to_signed(integer'right,32), to_signed(integer'right,32));
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, signed'(X"A5"), signed'(X"A5"));
        check_equal(check_equal_checker, pass, signed'(X"A5"), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on signed not equal signed") then
        check_equal(signed'(X"A5"), signed'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 0101_1010 (90).");
        check_equal(signed'(X"A5"), signed'(X"5A"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 0101_1010 (90). Extra info.");
        check_equal(pass, signed'(X"A5"), signed'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 0101_1010 (90).");
        pass := check_equal(signed'(X"A5"), signed'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 0101_1010 (90).");

        check_equal(check_equal_checker, signed'(X"A5"), signed'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 0101_1010 (90).");
        check_equal(check_equal_checker, pass, signed'(X"A5"), signed'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 0101_1010 (90).");
      elsif run("Test should pass on signed equal integer") then
        get_checker_stat(stat);
        check_equal(signed'(X"A5"), integer'(-91));
        check_equal(pass, signed'(X"A5"), integer'(-91));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(signed'(X"A5"), integer'(-91));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(to_signed(integer'left,32), integer'left);
        check_equal(to_signed(integer'right,32), integer'right);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, signed'(X"A5"), integer'(-91));
        check_equal(check_equal_checker, pass, signed'(X"A5"), integer'(-91));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on signed not equal integer") then
        check_equal(signed'(X"A5"), integer'(90));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 90 (0101_1010).");
        check_equal(signed'(X"A5"), integer'(90), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 90 (0101_1010). Extra info.");
        check_equal(pass, signed'(X"A5"), integer'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 90 (0101_1010).");
        pass := check_equal(signed'(X"A5"), integer'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 90 (0101_1010).");

        check_equal(check_equal_checker, signed'(X"A5"), integer'(90));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 90 (0101_1010).");
        check_equal(check_equal_checker, pass, signed'(X"A5"), integer'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected 90 (0101_1010).");
      elsif run("Test should pass on integer equal signed") then
        get_checker_stat(stat);
        check_equal(integer'(-91), signed'(X"A5"));
        check_equal(pass, integer'(-91), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(integer'(-91), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(integer'left, to_signed(integer'left,32));
        check_equal(integer'right, to_signed(integer'right,32));
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, integer'(-91), signed'(X"A5"));
        check_equal(check_equal_checker, pass, integer'(-91), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on integer not equal signed") then
        check_equal(integer'(-91), signed'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got -91 (1010_0101). Expected 0101_1010 (90).");
        check_equal(integer'(-91), signed'(X"5A"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got -91 (1010_0101). Expected 0101_1010 (90). Extra info.");
        check_equal(pass, integer'(-91), signed'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got -91 (1010_0101). Expected 0101_1010 (90).");
        pass := check_equal(integer'(-91), signed'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got -91 (1010_0101). Expected 0101_1010 (90).");

        check_equal(check_equal_checker, integer'(-91), signed'(X"5A"));
        verify_log_call(inc_count, "Equality check failed! Got -91 (1010_0101). Expected 0101_1010 (90).");
        check_equal(check_equal_checker, pass, integer'(-91), signed'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got -91 (1010_0101). Expected 0101_1010 (90).");
      elsif run("Test should pass on integer equal integer") then
        get_checker_stat(stat);
        check_equal(integer'(-91), integer'(-91));
        check_equal(pass, integer'(-91), integer'(-91));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(integer'(-91), integer'(-91));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(integer'left, integer'left);
        check_equal(integer'right, integer'right);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, integer'(-91), integer'(-91));
        check_equal(check_equal_checker, pass, integer'(-91), integer'(-91));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on integer not equal integer") then
        check_equal(integer'(-91), integer'(90));
        verify_log_call(inc_count, "Equality check failed! Got -91. Expected 90.");
        check_equal(integer'(-91), integer'(90), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got -91. Expected 90. Extra info.");
        check_equal(pass, integer'(-91), integer'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got -91. Expected 90.");
        pass := check_equal(integer'(-91), integer'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got -91. Expected 90.");

        check_equal(check_equal_checker, integer'(-91), integer'(90));
        verify_log_call(inc_count, "Equality check failed! Got -91. Expected 90.");
        check_equal(check_equal_checker, pass, integer'(-91), integer'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got -91. Expected 90.");
      elsif run("Test should pass on std_logic equal std_logic") then
        get_checker_stat(stat);
        check_equal('1', '1');
        check_equal(pass, '1', '1');
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal('1', '1');
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal('0', '0');
        check_equal('1', '1');
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, '1', '1');
        check_equal(check_equal_checker, pass, '1', '1');
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on std_logic not equal std_logic") then
        check_equal('1', '0');
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected 0.");
        check_equal('1', '0', "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected 0. Extra info.");
        check_equal(pass, '1', '0');
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected 0.");
        pass := check_equal('1', '0');
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected 0.");

        check_equal(check_equal_checker, '1', '0');
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected 0.");
        check_equal(check_equal_checker, pass, '1', '0');
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected 0.");
      elsif run("Test should pass on std_logic equal boolean") then
        get_checker_stat(stat);
        check_equal('1', true);
        check_equal(pass, '1', true);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal('1', true);
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal('0', false);
        check_equal('1', true);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, '1', true);
        check_equal(check_equal_checker, pass, '1', true);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on std_logic not equal boolean") then
        check_equal('1', false);
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected false.");
        check_equal('1', false, "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected false. Extra info.");
        check_equal(pass, '1', false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected false.");
        pass := check_equal('1', false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected false.");

        check_equal(check_equal_checker, '1', false);
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected false.");
        check_equal(check_equal_checker, pass, '1', false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 1. Expected false.");
      elsif run("Test should pass on boolean equal std_logic") then
        get_checker_stat(stat);
        check_equal(true, '1');
        check_equal(pass, true, '1');
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(true, '1');
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(false, '0');
        check_equal(true, '1');
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, true, '1');
        check_equal(check_equal_checker, pass, true, '1');
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on boolean not equal std_logic") then
        check_equal(true, '0');
        verify_log_call(inc_count, "Equality check failed! Got true. Expected 0.");
        check_equal(true, '0', "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected 0. Extra info.");
        check_equal(pass, true, '0');
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected 0.");
        pass := check_equal(true, '0');
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected 0.");

        check_equal(check_equal_checker, true, '0');
        verify_log_call(inc_count, "Equality check failed! Got true. Expected 0.");
        check_equal(check_equal_checker, pass, true, '0');
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected 0.");
      elsif run("Test should pass on boolean equal boolean") then
        get_checker_stat(stat);
        check_equal(true, true);
        check_equal(pass, true, true);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(true, true);
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(false, false);
        check_equal(true, true);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, true, true);
        check_equal(check_equal_checker, pass, true, true);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on boolean not equal boolean") then
        check_equal(true, false);
        verify_log_call(inc_count, "Equality check failed! Got true. Expected false.");
        check_equal(true, false, "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected false. Extra info.");
        check_equal(pass, true, false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected false.");
        pass := check_equal(true, false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected false.");

        check_equal(check_equal_checker, true, false);
        verify_log_call(inc_count, "Equality check failed! Got true. Expected false.");
        check_equal(check_equal_checker, pass, true, false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got true. Expected false.");
      elsif run("Test should pass on natural equal natural") then
        get_checker_stat(stat);
        check_equal(natural'(165), natural'(165));
        check_equal(pass, natural'(165), natural'(165));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(natural'(165), natural'(165));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(natural'left, natural'left);
        check_equal(natural'right, natural'right);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, natural'(165), natural'(165));
        check_equal(check_equal_checker, pass, natural'(165), natural'(165));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on natural not equal natural") then
        check_equal(natural'(165), natural'(90));
        verify_log_call(inc_count, "Equality check failed! Got 165. Expected 90.");
        check_equal(natural'(165), natural'(90), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got 165. Expected 90. Extra info.");
        check_equal(pass, natural'(165), natural'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 165. Expected 90.");
        pass := check_equal(natural'(165), natural'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 165. Expected 90.");

        check_equal(check_equal_checker, natural'(165), natural'(90));
        verify_log_call(inc_count, "Equality check failed! Got 165. Expected 90.");
        check_equal(check_equal_checker, pass, natural'(165), natural'(90));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got 165. Expected 90.");

      -------------------------------------------------------------------------
      -- Manually added test cases
      -------------------------------------------------------------------------

      elsif run("Test should pass on time equal time") then
        get_checker_stat(stat);
        check_equal(-91 ns, -91 ns);
        check_equal(pass, -91 ns, -91 ns);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(-91 ns, -91 ns);
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(time'left, time'left);
        check_equal(time'right, time'right);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, -91 ns, -91 ns);
        check_equal(check_equal_checker, pass, -91 ns, -91 ns);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on time not equal time") then
        check_equal(-91 ns, 90 ns);
        verify_time_log_call(inc_count, -91 ns, 90 ns);
        check_equal(-91 ns, 90 ns);
        verify_time_log_call(inc_count, -91 ns, 90 ns);
        check_equal(pass, -91 ns, 90 ns);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_time_log_call(inc_count, -91 ns, 90 ns);
        pass := check_equal(-91 ns, 90 ns);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_time_log_call(inc_count, -91 ns, 90 ns);

        check_equal(check_equal_checker, -91 ns, 90 ns);
        verify_time_log_call(inc_count, -91 ns, 90 ns);
        check_equal(check_equal_checker, pass, -91 ns, 90 ns);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_time_log_call(inc_count, -91 ns, 90 ns);

      elsif run("Test should pass on string equal string") then
        get_checker_stat(stat);
        check_equal(string'("test"), string'("test"));
        check_equal(pass, string'("test"), string'("test"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal(string'("test"), string'("test"));
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal(string'(""), string'(""));
        verify_passed_checks(stat, 4);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, string'("test"), string'("test"));
        check_equal(check_equal_checker, pass, string'("test"), string'("test"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on string not equal string") then
        check_equal(string'("test"), string'("tests"));
        verify_log_call(inc_count, "Equality check failed! Got test. Expected tests.");
        check_equal(string'("test"), string'("tests"), "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got test. Expected tests. Extra info.");
        check_equal(pass, string'("test"), string'("tests"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got test. Expected tests.");
        pass := check_equal(string'("test"), string'("tests"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got test. Expected tests.");

        check_equal(check_equal_checker, string'("test"), string'("tests"));
        verify_log_call(inc_count, "Equality check failed! Got test. Expected tests.");
        check_equal(check_equal_checker, pass, string'("test"), string'("tests"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got test. Expected tests.");
      end if;
    end loop;

    reset_checker_stat;
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
