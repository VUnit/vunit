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

use work.axi_pkg.all;
use work.memory_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.queue_pkg.all;
use work.message_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_write_slave is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_write_slave is
  signal clk    : std_logic := '0';
  constant data_size : integer := 16;

  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal awid    : std_logic_vector(3 downto 0);
  signal awaddr  : std_logic_vector(31 downto 0);
  signal awlen   : axi4_len_t;
  signal awsize  : axi4_size_t;
  signal awburst : axi_burst_type_t;

  signal wvalid  : std_logic;
  signal wready  : std_logic := '0';
  signal wid     : std_logic_vector(awid'range);
  signal wdata   : std_logic_vector(8*data_size-1 downto 0);
  signal wstrb   : std_logic_vector(data_size downto 0);
  signal wlast   : std_logic;

  signal bvalid  : std_logic := '0';
  signal bready  : std_logic;
  signal bid     : std_logic_vector(awid'range);
  signal bresp   : axi_resp_t;

  signal error_queue : queue_t;

  constant inbox : inbox_t := new_inbox;
  constant memory : memory_t := new_memory;

begin
  main : process
    variable alloc : alloc_t;
    variable rnd : RandomPType;

    -- @TODO move to common utility library
    procedure random_integer_vector(variable rnd : inout RandomPType;
                                    length : integer;
                                    min_value : integer;
                                    max_value : integer;
                                    variable ptr : inout integer_vector_ptr_t) is
    begin
      if ptr = null_ptr then
        ptr := allocate(length);
      else
        reallocate(ptr, length);
      end if;

      for i in 0 to length-1 loop
        set(ptr, i, rnd.RandInt(min_value, max_value));
      end loop;
    end procedure;

    procedure read_response(id : std_logic_vector;
                            resp : axi_resp_t := axi_resp_ok) is
    begin
      bready <= '1';
      wait until (bvalid and bready) = '1' and rising_edge(clk);
      check_equal(bresp, resp, "bresp");
      check_equal(bid, id, "bid");
      bready <= '0';
    end procedure;

    procedure write_addr(id : std_logic_vector;
                         addr : natural;
                         len : natural;
                         log_size : natural;
                         burst : axi_burst_type_t) is
    begin
        awvalid <= '1';
        awid <= id;
        awaddr <= std_logic_vector(to_unsigned(addr, awaddr'length));
        awlen <= std_logic_vector(to_unsigned(len-1, awlen'length));
        awsize <= std_logic_vector(to_unsigned(log_size, awsize'length));
        awburst <= burst;

        wait until (awvalid and awready) = '1' and rising_edge(clk);
        awvalid <= '0';
    end procedure;

    variable data : integer_vector_ptr_t;
    variable strb : integer_vector_ptr_t;
    variable size, log_size : natural;
    variable id : std_logic_vector(awid'range);
    variable len : natural;
    variable burst : axi_burst_type_t;
    variable idx : integer;

    variable num_ops : integer;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("Test random writes") then
      num_ops := 0;
      for test_idx in 0 to 32-1 loop

        id := rnd.RandSlv(awid'length);
        case rnd.RandInt(1) is
          when 0 =>
            burst := axi_burst_type_fixed;
            len := 1;
          when 1 =>
            burst := axi_burst_type_incr;
            len := rnd.RandInt(1, 2**awlen'length);
          when others =>
            assert false;
        end case;

        log_size := rnd.RandInt(0, 3);
        size := 2**log_size;
        random_integer_vector(rnd, size * len, 0, 255, data);
        random_integer_vector(rnd, length(data), 0, 1, strb);

        alloc := allocate(memory, 8 * len, alignment => 4096);
        for i in 0 to length(data)-1 loop
          if get(strb, i) = 1 then
            set_reference(memory, base_address(alloc)+i, get(data, i));
            num_ops := num_ops + 1;
          else
            set_permissions(memory, base_address(alloc)+i, no_access);
          end if;
        end loop;

        write_addr(id, base_address(alloc), len, log_size, burst);

        wid <= id;

        for j in 0 to len-1 loop
          for i in 0 to size-1 loop
            idx := (base_address(alloc) + j*size + i) mod data_size;
            wdata(8*idx+7 downto 8*idx) <= std_logic_vector(to_unsigned(get(data, j*size + i), 8));
            wstrb(idx downto idx) <= std_logic_vector(to_unsigned(get(strb, j*size + i), 1));
          end loop;

          if j = len-1 then
            wlast <= '1';
          else
            wlast <= '0';
          end if;

          wvalid <= '1';
          wait until (wvalid and wready) = '1' and rising_edge(clk);
          wvalid <= '0';
          wstrb <= (others => '0');
          wdata <= (others => '0');
        end loop;

        read_response(id, axi_resp_ok);

        check_all_was_written(alloc);
      end loop;

      assert num_ops > 5000;

    elsif run("Test error on missing tlast fixed") then
      error_queue <= allocate;

      alloc := allocate(memory, 8);
      write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_fixed);
      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';
      wait until length(error_queue) > 0 and rising_edge(clk);
      check_equal(pop_string(error_queue), "Expected wlast='1' on last beat of burst with length 1 starting at address 0");
      check_equal(length(error_queue), 0, "no more errors");
      read_response(x"2", axi_resp_ok);

    elsif run("Test error on missing tlast incr") then
      error_queue <= allocate;

      alloc := allocate(memory, 8);
      write_addr(x"2", base_address(alloc), 2, 0, axi_burst_type_incr);

      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';
      wait until wvalid = '0' and rising_edge(clk);

      check_equal(length(error_queue), 0, "no errors yet");

      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';
      wait until length(error_queue) > 0 and rising_edge(clk);

      check_equal(pop_string(error_queue), "Expected wlast='1' on last beat of burst with length 2 starting at address 0");
      check_equal(length(error_queue), 0, "no more errors");
      read_response(x"2", axi_resp_ok);

    elsif run("Test error on unsupported wrap burst") then
      error_queue <= allocate;
      alloc := allocate(memory, 8);
      write_addr(x"2", base_address(alloc), 2, 0, axi_burst_type_wrap);
      wait until length(error_queue) > 0 and rising_edge(clk);
      check_equal(pop_string(error_queue), "Wrapping burst type not supported");
      check_equal(length(error_queue), 0, "no more errors");

    elsif run("Test error 4KB boundary crossing") then
      alloc := allocate(memory, 4096+32, alignment => 4096);
      error_queue <= allocate;
      write_addr(x"2", base_address(alloc)+4000, 256, 0, axi_burst_type_incr);
      wait until length(error_queue) > 0 and rising_edge(clk);
      check_equal(pop_string(error_queue), "Crossing 4KB boundary");
      check_equal(length(error_queue), 0, "no more errors");
    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 1 ms);

  dut : entity work.axi_write_slave
    generic map (
      inbox => inbox,
      memory => memory)
    port map (
      aclk    => clk,
      awvalid => awvalid,
      awready => awready,
      awid    => awid,
      awaddr  => awaddr,
      awlen   => awlen,
      awsize  => awsize,
      awburst => awburst,
      wvalid  => wvalid,
      wready  => wready,
      wid     => wid,
      wdata   => wdata,
      wstrb   => wstrb,
      wlast   => wlast,
      bvalid  => bvalid,
      bready  => bready,
      bid     => bid,
      bresp   => bresp,
      error_queue => error_queue);

  clk <= not clk after 5 ns;
end architecture;
