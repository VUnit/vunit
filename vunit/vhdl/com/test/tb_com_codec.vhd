-- Test suite for com codec package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library tb_com_lib;
use tb_com_lib.custom_codec_pkg.all;
use tb_com_lib.custom_types_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.float_pkg.all;

use std.textio.all;

entity tb_com_codec is
  generic (
    runner_cfg : string);
end entity tb_com_codec;

architecture test_fixture of tb_com_codec is
begin
  test_runner : process
    constant f64    : float64 := (others => '0');
    constant special_chars       : string(1 to 3) := "),(";
    constant comma               : character      := ',';
    constant lp                  : character      := '(';
    constant rp                  : character      := ')';
    variable null_array4_t       : array4_t(10 to 8);
    variable null_array5_t       : array5_t(1 to 0, 1 to 0);
    variable null_array5_2_t     : array5_t(0 to 1, 1 to 0);
    variable null_array5_3_t     : array5_t(1 to 0, 0 to 1);
    variable null_array6_t       : array6_t(apple downto banana);
--    variable null_array7_t       : array7_t(1 to 2, apple downto banana);
    variable t1  : time;
    variable my_record4          : record4_t;
    variable my_record5          : record5_t;
    variable my_record6          : record6_t;
    variable my_record7          : record7_t;
    variable e1, e2, e3          : line;

    variable a1 : array1_t;
    variable a2 : array2_t;
    variable a3 : array3_t;
    variable a4 : array4_t(1 to 5);
    variable a4_null : array4_t(1 to 0);
    variable a5_null : array5_t(1 to 0, 1 to 0);
    variable a5_null2 : array5_t(0 to 1, 1 to 0);
    variable a5_null3 : array5_t(1 to 0, 0 to 1);
    variable a5 : array5_t(1 to 5, 1 to 3);
    variable a6_null : array6_t(apple downto orange);
    variable a6 : array6_t(apple to orange);
--    variable a7_null : array7_t(1 to 2, apple downto banana);
--    variable a7 : array7_t(1 to 5, apple to melon);
    variable a8 : array8_t;
    variable a9 : array9_t;
    variable a10 : array10_t;

    variable enum1 : enum1_t;

    variable rec1 : record1_t;
    variable rec2 : record2_t;
    variable rec3 : record3_t;
    variable rec9 : record9_t;

    -- Temp variables to make test case pass Riviera-PRO 2016.10
    variable range_left, range_right : integer;

    variable msg, msg2 : msg_t;

    -- GHDL fails on "Test that custom record type can be encoded and decoded"
    -- unless we define the lp character position as a constant rather than using
    -- the expression inline.
    constant lp_pos : natural := character'pos(lp);

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that custom enumeration type can be encoded and decoded") then
        enum1 := decode(encode(red));
        check_relation(enum1 = red);
        enum1 := decode(encode(green));
        check_relation(enum1 = green);
        enum1 := decode(encode(blue));
        check_relation(enum1 = blue);
      elsif run("Test that custom enumeration type can be pushed and popped") then
        msg := new_msg;
        push_enum1_t(msg, red);
        check_relation(pop_enum1_t(msg) = red, result("for pop_enum1"));
      elsif run("Test that custom record type can be encoded and decoded") then
        rec1 := decode(encode_record1_t((lp_pos, -1, -2, -3)));
        check_relation(rec1 = (lp_pos, -1, -2, -3));

        rec2 := decode(encode_record2_t((command, 1, -1, -2, -3, '1')));
        check_relation(rec2 = (command, 1, -1, -2, -3, '1'));
        rec2 := decode(command(1, -1, -2, -3, '1'));
        check_relation(rec2 = (command, 1, -1, -2, -3, '1'));

        rec3 := decode(encode_record3_t((char => comma)));
        check_relation(rec3 = (char => comma));
        rec3 := decode(encode_record3_t((char => lp)));
        check_relation(rec3 = (char => lp));
        rec3 := decode(encode_record3_t((char => rp)));
        check_relation(rec3 = (char => rp));
      elsif run("Test that custom record type can be pushed and popped") then
        msg := new_msg;
        rec1 := (character'pos(lp), -1, -2, -3);
        push_record1_t(msg, rec1);
        check_relation(pop_record1_t(msg) = rec1, result("for pop_record1_t"));
      elsif run("Test that custom array can be encoded and decoded") then
        a1 := decode(encode_array1_t((0, 1, 2, 3, 4)));
        check_relation(a1 = (0, 1, 2, 3, 4));
        check_relation(a1'left = -2);
        check_relation(a1'right = 2);

        a2 := decode(encode_array2_t((0, 1, 2, 3, 4)));
        check_relation(a2 = (0, 1, 2, 3, 4));
        check_relation(a2'left = 2);
        check_relation(a2'right = -2);

        a3 := decode(encode_array3_t(((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14))));
        check_relation(a3 = ((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14)));
        check_relation(a3'left(1) = -2);
        check_relation(a3'right(1) = 2);
        check_relation(a3'left(2) = -1);
        check_relation(a3'right(2) = 1);

        a4_null := decode(encode(null_array4_t));
        check_relation(a4_null = null_array4_t);
        a4 := decode(encode_array4_t((0, 1, 2, 3, 4)));
        check_relation(a4 = (0, 1, 2, 3, 4));

        a5_null := decode(encode(null_array5_t));
        check_relation(a5_null = null_array5_t);
        a5_null2 := decode(encode(null_array5_2_t));
        check_relation(a5_null2 = null_array5_2_t);
        a5_null3 := decode(encode(null_array5_3_t));
        check_relation(a5_null3 = null_array5_3_t);
        a5 := decode(encode_array5_t(((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14))));
        check_relation(a5 = ((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14)));

        a6_null := decode(encode(null_array6_t));
        check_relation(a6_null = null_array6_t);
        a6 := decode(encode_array6_t((0, 1, 2, 3, 4)));
        check_relation(a6 = (0, 1, 2, 3, 4));

        -- This test has been removed since it fails under Active-HDL. @TODO
        -- Investigate futher if this can be reintroduced or separated into its
        -- own test that is selectively executed in the acceptance tests
        -- depending on simulator.
        --a7_null := decode(encode(null_array7_t));
        --check_relation(a7_null = null_array7_t);
        --a7 := decode(encode_array7_t(((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14))));
        --check_relation(a7 = ((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14)));

        a8 := decode(encode_array8_t(((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14))));
        check_relation(a8 = ((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14)));
        check_relation(a8'left(1) = -2);
        check_relation(a8'right(1) = 2);
        check_relation(a8'left(2) = -1);
        check_relation(a8'right(2) = 1);

        a9 := decode(encode_array9_t((0, 1, 2, 3, 4)));
        check_relation(a9 = (0, 1, 2, 3, 4));
        check_relation(a9'left = -2);
        check_relation(a9'right = 2);

        a10 := decode(encode_array10_t(((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14))));
        check_relation(a10 = ((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14)));
        check_relation(a10'left(1) = -2);
        check_relation(a10'right(1) = 2);
        check_relation(a10'left(2) = -1);
        check_relation(a10'right(2) = 1);
      elsif run("Test that custom array can be pushed and popped") then
        msg := new_msg;
        a1 := (0, 1, 2, 3, 4);
        push_array1_t(msg, a1);
        check_relation(pop_array1_t(msg) = a1, result("for pop_array1_t"));

        a3 := ((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14));
        push_array3_t(msg, a3);
        check_relation(pop_array3_t(msg) = a3, result("for pop_array3_t"));

        a4 := (0, 1, 2, 3, 4);
        push_array4_t(msg, a4);
        check_relation(pop_array4_t(msg) = a4, result("for pop_array4_t"));

        a5 := ((0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14));
        push_array5_t(msg, a5);
        check_relation(pop_array5_t(msg) = a5, result("for pop_array5_t"));

      elsif run("Test that all provided codecs can be used within a composite") then
        my_record4 := (17, 42.21, -365 ns, true, '0', 'U', error, open_ok, read_mode, 21);
        check_relation(my_record4 = decode(encode(my_record4)));

        my_record5 := ('f', "abc", (true, false, false), ('1', '0', '0'), (17, 21, 42), (-3.14, 2.71, 1000.1000),
                       (-13 ns, 14 ps, 3 ms), "1UX", (1.12, -0.25), 'g');
        check_relation(my_record5 = decode(encode(my_record5)));

        my_record6 := ((112.3, 0.48), "100", "011", "1XU", "LHW", "1U0X1", "01LZ1", to_float(234.56, f64),
                       (12.3, -0.48));
        check_relation(my_record6 = record6_t'(decode(encode(my_record6))));

        my_record7 := (my_record4, my_record5, my_record6);
        check_relation(my_record7 = record7_t'(decode(encode(my_record7))));
      elsif run("Test that the values of different enumeration types used for msg_type record elements get different encodings") then
        write(e1, encode(record2_msg_type_t'(command)));
        write(e2, encode(record8_msg_type_t'(read)));
        write(e3, encode(record8_msg_type_t'(write)));
        check_relation(e1.all /= e2.all);
        check_relation(e1.all /= e3.all);
        check_relation(e2.all /= e3.all);
        deallocate(e1);
        deallocate(e2);
        deallocate(e3);
      elsif run("Test that records with different msg_type enumeration types can classified with a single get_msg_type function") then
        write(e1, encode(record2_msg_type_t'(command)));
        write(e2, encode(record8_msg_type_t'(read)));
        write(e3, encode(record8_msg_type_t'(write)));
        check(get_record2_msg_type_t(e1.all) = command);
        check(get_record8_msg_type_t(e2.all) = read);
        check(get_record8_msg_type_t(e3.all) = write);
        check(get_msg_type(e1.all) = command);
        check(get_msg_type(e2.all) = read);
        check(get_msg_type(e3.all) = write);
        deallocate(e1);
        deallocate(e2);
        deallocate(e3);
      elsif run("Test that records containing arrays can be encoded and decoded") then
        rec9 := decode(encode(record9_t'(foo, x"a5", "foo", ((1, 2, 3, 4, 5, 6), (4, 3, 2, 1, 0, -1)))));
        check_relation(rec9 = (foo, x"a5", "foo", ((1, 2, 3, 4, 5, 6), (4, 3, 2, 1, 0, -1))));
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);
end test_fixture;
