-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.queue_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.dict_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_bit.all;
use ieee.math_complex.all;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use std.textio.all;

entity tb_com_msg_building is
  generic (
    runner_cfg : string);
end entity tb_com_msg_building;

architecture test_fixture of tb_com_msg_building is
begin
  test_runner : process
    variable actor     : actor_t;
    variable msg, msg2, msg2_copy : msg_t;
    variable queue, queue_copy : queue_t;
    variable bv : bit_vector(0 to 5);
    variable sulv : std_ulogic_vector(0 to 5);
    variable boolv : boolean_vector(0 to 1);
    variable integer_vector_ptr, integer_vector_ptr_copy : integer_vector_ptr_t;
    variable integer_array, integer_array_copy : integer_array_t;
    variable dict : dict_t;

    constant my_msg_type : msg_type_t := new_msg_type("my msg type");
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that a message can be created") then
        msg := new_msg;
        check_equal(msg.id, no_message_id);
        check(msg.status = ok);
        check(msg.sender = null_actor);
        check(msg.receiver = null_actor);
        check_equal(msg.request_id, no_message_id);
        check_equal(length(msg.data), 0);

        actor := new_actor("sender");
        msg2  := new_msg(sender => actor);
        check_equal(msg2.id, no_message_id);
        check(msg2.status = ok);
        check(msg2.sender = actor);
        check(msg2.receiver = null_actor);
        check_equal(msg2.request_id, no_message_id);
        check_equal(length(msg2.data), 0);
      elsif run("Test that a message can be deleted") then
        actor := new_actor("sender");

        msg            := new_msg(sender => actor);
        msg.id         := 1;
        msg.status     := null_message_error;
        msg.receiver   := actor;
        msg.request_id := 1;
        push(msg.data, 1);

        delete(msg);

        check_equal(msg.id, no_message_id);
        check(msg.status = null_message_error);
        check(msg.sender = null_actor);
        check(msg.receiver = null_actor);
        check_equal(msg.request_id, no_message_id);
        check(msg.data = null_queue);
      elsif run("Test push and pop integer") then
        msg := new_msg;
        push_integer(msg, 11);
        push_integer(msg, 22);
        check_equal(pop_integer(msg), 11, "data");
        check_equal(pop_integer(msg), 22, "data");
      elsif run("Test push and pop character") then
        msg := new_msg;
        push_character(msg, '1');
        push_character(msg, '2');
        assert pop_character(msg) = '1';
        assert pop_character(msg) = '2';
      elsif run("Test push and pop queue") then
        msg   := new_msg;
        queue := new_queue;
        push(queue, 22);
        queue_copy := queue;
        push_queue_ref(msg, queue);
        assert queue = null_queue report "Ownership was transfered";
        assert pop_queue_ref(msg) = queue_copy report "Queue should come back";
      elsif run("Test push and pop string") then
        msg := new_msg;
        push_string(msg, "hello world");
        push_string(msg, "two");
        assert pop_string(msg) = "hello world";
        assert pop_string(msg) = "two";
      elsif run("Test push and pop bit") then
        msg := new_msg;
        push_bit(msg, '0');
        push_bit(msg, '1');
        check(pop_bit(msg) = '0');
        check(pop_bit(msg) = '1');
      elsif run("Test push and pop std_ulogic") then
        msg := new_msg;
        push_std_ulogic(msg, 'U');
        push_std_ulogic(msg, 'X');
        assert pop_std_ulogic(msg) = 'U';
        assert pop_std_ulogic(msg) = 'X';
      elsif run("Test push and pop severity_level") then
        msg := new_msg;
        push_severity_level(msg, note);
        push_severity_level(msg, error);
        check(pop_severity_level(msg) = note);
        check(pop_severity_level(msg) = error);
      elsif run("Test push and pop file_open_status") then
        msg := new_msg;
        push_file_open_status(msg, open_ok);
        push_file_open_status(msg, mode_error);
        check(pop_file_open_status(msg) = open_ok);
        check(pop_file_open_status(msg) = mode_error);
      elsif run("Test push and pop file_open_kind") then
        msg := new_msg;
        push_file_open_kind(msg, read_mode);
        push_file_open_kind(msg, append_mode);
        check(pop_file_open_kind(msg) = read_mode);
        check(pop_file_open_kind(msg) = append_mode);
      elsif run("Test push and pop bit_vector") then
        msg := new_msg;
        push_bit_vector(msg, "1");
        push_bit_vector(msg, "010101");
        bv(0 to 0) := pop_bit_vector(msg);
        check(bv(0) = '1');
        bv := pop_bit_vector(msg) ;
        check(bv = "010101");
      elsif run("Test push and pop std_ulogic_vector") then
        msg := new_msg;
        push_std_ulogic_vector(msg, "1");
        push_std_ulogic_vector(msg, "010101");
        sulv(0 to 0) := pop_std_ulogic_vector(msg);
        check(sulv(0) = '1');
        sulv := pop_std_ulogic_vector(msg);
        check(sulv = "010101");
      elsif run("Test push and pop complex") then
        msg := new_msg;
        push_complex(msg, (1.0, 2.2));
        push_complex(msg, (-1.0, -2.2));
        check(pop_complex(msg) = (1.0, 2.2));
        check(pop_complex(msg) = (-1.0, -2.2));
      elsif run("Test push and pop complex_polar") then
        msg := new_msg;
        push_complex_polar(msg, (1.0, 0.707));
        push_complex_polar(msg, (3.14, -0.707));
        check(pop_complex_polar(msg) = (1.0, 0.707));
        check(pop_complex_polar(msg) = (3.14, -0.707));
      elsif run("Test push and pop ieee.numeric_bit.unsigned") then
        msg := new_msg;
        push_numeric_bit_unsigned(msg, "1");
        push_numeric_bit_unsigned(msg, "010101");
        check(pop_numeric_bit_unsigned(msg) = "1");
        check(pop_numeric_bit_unsigned(msg) = "010101");
      elsif run("Test push and pop ieee.numeric_bit.signed") then
        msg := new_msg;
        push_numeric_bit_signed(msg, "1");
        push_numeric_bit_signed(msg, "010101");
        check(pop_numeric_bit_signed(msg) = "1");
        check(pop_numeric_bit_signed(msg) = "010101");
      elsif run("Test push and pop ieee.numeric_std.unsigned") then
        msg := new_msg;
        push_numeric_std_unsigned(msg, "1");
        push_numeric_std_unsigned(msg, "010101");
        check(pop_numeric_std_unsigned(msg) = "1");
        check(pop_numeric_std_unsigned(msg) = "010101");
      elsif run("Test push and pop ieee.numeric_std.signed") then
        msg := new_msg;
        push_numeric_std_signed(msg, "1");
        push_numeric_std_signed(msg, "010101");
        check(pop_numeric_std_signed(msg) = "1");
        check(pop_numeric_std_signed(msg) = "010101");
      elsif run("Test push and pop signed and unsigned") then
        msg := new_msg;
        push_std_ulogic_vector(msg, std_ulogic_vector(ieee.numeric_std.to_unsigned(11, 16)));
        push_std_ulogic_vector(msg, std_ulogic_vector(ieee.numeric_std.to_signed(-1, 8)));
        assert ieee.numeric_std.unsigned(pop_std_ulogic_vector(msg)) = ieee.numeric_std.to_unsigned(11, 16);
        assert ieee.numeric_std.signed(pop_std_ulogic_vector(msg)) = ieee.numeric_std.to_signed(-1, 8);
      elsif run("Test push and pop real") then
        msg := new_msg;
        push_real(msg, 1.0);
        push_real(msg, -1.0);
        assert pop_real(msg) = 1.0;
        assert pop_real(msg) = -1.0;
      elsif run("Test push and pop time") then
        msg := new_msg;
        push_time(msg, 1 fs);
        push_time(msg, 1 ps);
        assert pop_time(msg) = 1 fs;
        assert pop_time(msg) = 1 ps;
      elsif run("Test push and pop boolean_vector") then
        msg := new_msg;
        push_boolean_vector(msg, (1 => true));
        push_boolean_vector(msg, (false, true));
        boolv(0 to 0) := pop_boolean_vector(msg);
        check(boolv(0) = true);
        boolv := pop_boolean_vector(msg);
        check(boolv = (false, true));
      elsif run("Test push and pop integer_vector") then
        msg := new_msg;
        push_integer_vector(msg, (1        => 17));
        push_integer_vector(msg, (-21, 42));
        check(pop_integer_vector(msg) = (1 => 17));
        check(pop_integer_vector(msg) = (-21, 42));
      elsif run("Test push and pop real_vector") then
        msg := new_msg;
        push_real_vector(msg, (1        => 17.17));
        push_real_vector(msg, (-21.21, 42.42));
        check(pop_real_vector(msg) = (1 => 17.17));
        check(pop_real_vector(msg) = (-21.21, 42.42));
      elsif run("Test push and pop time_vector") then
        msg := new_msg;
        push_time_vector(msg, (1        => 17.17 ms));
        push_time_vector(msg, (-21.21 min, 42.42 us));
        check(pop_time_vector(msg) = (1 => 17.17 ms));
        check(pop_time_vector(msg) = (-21.21 min, 42.42 us));
      elsif run("Test push and pop ufixed") then
        msg := new_msg;
        push_ufixed(msg, to_ufixed(17.17, 6, -9));
        push_ufixed(msg, to_ufixed(42.42, 6, -9));
        check(pop_ufixed(msg) = to_ufixed(17.17, 6, -9));
        check(pop_ufixed(msg) = to_ufixed(42.42, 6, -9));
      elsif run("Test push and pop sfixed") then
        msg := new_msg;
        push_sfixed(msg, to_sfixed(17.17, 6, -9));
        push_sfixed(msg, to_sfixed(-21.21, 6, -9));
        check(pop_sfixed(msg) = to_sfixed(17.17, 6, -9));
        check(pop_sfixed(msg) = to_sfixed(-21.21, 6, -9));
      elsif run("Test push and pop float") then
        msg := new_msg;
        push_float(msg, to_float(17.17));
        push_float(msg, to_float(-21.21));
        check(pop_float(msg) = to_float(17.17));
        check(pop_float(msg) = to_float(-21.21));
      elsif run("Test push and pop of msg_type") then
        msg := new_msg;
        push_msg_type(msg, my_msg_type);
        check(pop_msg_type(msg) = my_msg_type);
      elsif run("Test push and pop of integer_vector_ptr_t") then
        msg := new_msg;
        integer_vector_ptr := new_integer_vector_ptr;
        integer_vector_ptr_copy := integer_vector_ptr;
        push_integer_vector_ptr_ref(msg, integer_vector_ptr);
        assert integer_vector_ptr = null_ptr report "Ownership was transfered";
        check(pop_integer_vector_ptr_ref(msg) = integer_vector_ptr_copy);
      elsif run("Test push and pop of integer_array_t") then
        msg := new_msg;
        integer_array := new_3d(1, 2, 3, 4);
        integer_array_copy := integer_array;
        push_integer_array_t_ref(msg, integer_array);
        check(integer_array = null_integer_array);
        check(pop_integer_array_t_ref(msg) = integer_array_copy);
      elsif run("Test push and pop of dict_t") then
        msg := new_msg;
        dict := new_dict;
        set_integer(dict, "key", 17);
        push_dict_t_ref(msg, dict);
        check(dict = null_dict);
        check_equal(get_integer(pop_dict_t_ref(msg), "key"), 17);
      elsif run("Test push and pop of msg_t") then
        msg := new_msg;
        msg2 := new_msg;
        msg2_copy := msg2;
        push(msg, msg2);
        assert msg2 = null_msg report "Ownership was transfered";
        check(pop(msg) = msg2_copy);
      elsif run("Test setting and getting msg_type") then
        msg := new_msg;
        check(message_type(msg) = null_msg_type);
        msg := new_msg(my_msg_type);
        check(message_type(msg) = my_msg_type);
        delete(msg);
        check(message_type(msg) = null_msg_type);
      elsif run("Test message for being empty") then
        msg := new_msg;
        check(is_empty(msg));
        push_integer(msg, 11);
        check_false(is_empty(msg));
        check_equal(pop_integer(msg), 11);
        check(is_empty(msg));
        push_integer(msg, 11);
        delete(msg);
        check(is_empty(msg));
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end test_fixture;
