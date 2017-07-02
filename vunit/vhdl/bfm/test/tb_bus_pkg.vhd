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

use work.message_pkg.all;
use work.queue_pkg.all;
use work.bus_pkg.all;
use work.memory_pkg.all;
use work.fail_pkg.all;

entity tb_bus_pkg is
  generic (runner_cfg : string);
end entity;

architecture a of tb_bus_pkg is
  constant memory : memory_t := new_memory;
  constant bus_handle : bus_t := new_bus(data_length => 32, address_length => 32);
begin
  main : process
    variable alloc : alloc_t;
    variable read_data : std_logic_vector(bus_handle.data_length-1 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);
    if run("test write_bus") then
      alloc := allocate(memory, 4, permissions => write_only);
      set_expected_word(memory, base_address(alloc), x"00112233");
      write_bus(event, bus_handle, x"00000000", x"00112233");

    elsif run("test read_bus") then
      alloc := allocate(memory, 4, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      read_bus(event, bus_handle, x"00000000", read_data);
      check_equal(read_data, std_logic_vector'(x"00112233"));

    elsif run("test check_bus") then
      alloc := allocate(memory, 4, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112233"));
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"), mask => std_logic_vector'(x"ffffff00"));

      disable_failure(bus_handle.fail_log);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"));
      check_equal(pop_failure(bus_handle.fail_log), "check_bus(x""00000000"") - Got x""00112233"" expected x""00112244""");
      check_no_failures(bus_handle.fail_log);

      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"), msg => "msg");
      check_equal(pop_failure(bus_handle.fail_log), "msg - Got x""00112233"" expected x""00112244""");
      check_no_failures(bus_handle.fail_log);

      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"), mask => std_logic_vector'(x"00ffffff"));
      check_equal(pop_failure(bus_handle.fail_log), "check_bus(x""00000000"") - Got x""00112233"" expected x""00112244"" using mask x""00FFFFFF""");
      check_no_failures(bus_handle.fail_log);

    elsif run("test check_bus support reduced data length") then
      alloc := allocate(memory, 4, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"112233"));

      write_word(memory, base_address(alloc), x"77112233", ignore_permissions => True);
      disable_failure(bus_handle.fail_log);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"112233"));
      check_equal(pop_failure(bus_handle.fail_log), "check_bus(x""00000000"") - Got x""77112233"" expected x""00112233""");
      check_no_failures(bus_handle.fail_log);
    end if;
    test_runner_cleanup(runner);
  end process;

  memory_model : process
    variable msg : msg_t;
    variable reply : reply_t;
    variable bus_access_type : bus_access_type_t;

    variable addr  : std_logic_vector(bus_handle.address_length-1 downto 0);
    variable data  : std_logic_vector(bus_handle.data_length-1 downto 0);
  begin
    loop
      recv(event, bus_handle.inbox, msg, reply);

      bus_access_type := bus_access_type_t'val(integer'(pop(msg.data)));
      addr := pop_std_ulogic_vector(msg.data);

      case bus_access_type is
        when read_access =>
          assert reply /= null_reply;
          data := read_word(memory, to_integer(unsigned(addr)), bytes_per_word => data'length/8);
          push_std_ulogic_vector(reply.data, data);
          send_reply(event, reply);

        when write_access =>
          assert reply = null_reply;
          data := pop_std_ulogic_vector(msg.data);
          write_word(memory,
                     to_integer(unsigned(addr)),
                     data);
      end case;
    end loop;
  end process;

end architecture;
