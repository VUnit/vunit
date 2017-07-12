-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;

use work.queue_pkg.all;
use work.bus_pkg.all;
use work.memory_pkg.all;
use work.logger_pkg.all;
use work.msg_types_pkg.all;

entity tb_bus_pkg is
  generic (runner_cfg : string);
end entity;

architecture a of tb_bus_pkg is
  constant memory : memory_t := new_memory;
  constant bus_handle : bus_t := new_bus(data_length => 32, address_length => 32);
begin
  main : process
    variable alloc : alloc_t;
    variable read_data : std_logic_vector(data_length(bus_handle)-1 downto 0);
    variable reference : bus_reference_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test write_bus") then
      alloc := allocate(memory, 12, permissions => write_only);
      set_expected_word(memory, base_address(alloc), x"00112233");
      set_expected_word(memory, base_address(alloc) + 4, x"00112233");
      set_expected_word(memory, base_address(alloc) + 8, x"00112233");
      write_bus(event, bus_handle, x"00000000", x"00112233");
      write_bus(event, bus_handle, x"4", x"00112233");
      write_bus(event, bus_handle, x"00000008", x"112233");

    elsif run("test write_bus with byte_enable") then
      alloc := allocate(memory, 12, permissions => write_only);
      set_permissions(memory, base_address(alloc), no_access);
      set_expected_byte(memory, base_address(alloc)+1, 16#33#);
      set_permissions(memory, base_address(alloc)+2, no_access);
      set_expected_byte(memory, base_address(alloc)+3, 16#11#);
      write_bus(event, bus_handle, base_address(alloc), x"11223344", byte_enable => "1010");

    elsif run("test read_bus") then
      alloc := allocate(memory, 8, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      write_word(memory, base_address(alloc) + 4, x"00112233", ignore_permissions => True);
      read_bus(event, bus_handle, x"00000000", read_data);
      check_equal(read_data, std_logic_vector'(x"00112233"));
      read_bus(event, bus_handle, x"4", reference);
      await_read_bus_reply(event, reference, read_data);
      check_equal(read_data, std_logic_vector'(x"00112233"));

    elsif run("test check_bus") then
      alloc := allocate(memory, 4, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112233"));
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"001122--"));

      mock(bus_logger);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"));
      check_only_log(bus_logger, "check_bus(x""00000000"") - Got x""00112233"" expected x""00112244""", failure);

      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"), msg => "msg");
      check_only_log(bus_logger, "msg - Got x""00112233"" expected x""00112244""", failure);

      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"--112244"));
      check_only_log(bus_logger, "check_bus(x""00000000"") - Got x""00112233"" expected x""XX112244""", failure);
      unmock(bus_logger);

    elsif run("test check_bus support reduced data length") then
      alloc := allocate(memory, 4, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"112233"));

      write_word(memory, base_address(alloc), x"77112233", ignore_permissions => True);
      mock(bus_logger);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"112233"));
      check_only_log(bus_logger, "check_bus(x""00000000"") - Got x""77112233"" expected x""00112233""", failure);
      unmock(bus_logger);
    end if;
    test_runner_cleanup(runner);
  end process;

  bus2memory_inst : entity work.bus2memory
    generic map (
      bus_handle => bus_handle,
      memory     => memory);
end architecture;
