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

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_read_slave is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_read_slave is
  signal clk    : std_logic := '0';

  constant data_size : integer := 16;

  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal arid    : std_logic_vector(3 downto 0);
  signal araddr  : std_logic_vector(31 downto 0);
  signal arlen   : axi4_len_t;
  signal arsize  : axi4_size_t;
  signal arburst : axi_burst_t;

  signal rvalid : std_logic;
  signal rready : std_logic := '0';
  signal rid : std_logic_vector(arid'range);
  signal rdata : std_logic_vector(8*data_size-1 downto 0);
  signal rresp : axi_resp_t;
  signal rlast : std_logic;

  signal error_queue : queue_t;

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

    procedure write_addr(id : std_logic_vector;
                         addr : natural;
                         len : natural;
                         log_size : natural;
                         burst : axi_burst_t) is
    begin
        arvalid <= '1';
        arid <= id;
        araddr <= std_logic_vector(to_unsigned(addr, araddr'length));
        arlen <= std_logic_vector(to_unsigned(len-1, arlen'length));
        arsize <= std_logic_vector(to_unsigned(log_size, arsize'length));
        arburst <= burst;

        wait until (arvalid and arready) = '1' and rising_edge(clk);
        arvalid <= '0';
    end procedure;

    procedure read_data(id : std_logic_vector; address : natural; size : natural; resp : axi_resp_t; last : boolean) is
      variable idx : integer;
    begin
      rready <= '1';
      wait until (rvalid and rready) = '1' and rising_edge(clk);
      rready <= '0';
      for i in 0 to size-1 loop
        idx := (address + i) mod data_size; -- Align data bus
        check_equal(rdata(8*idx+7 downto 8*idx), read_byte(memory, address+i));
      end loop;
      check_equal(rid, id, "rid");
      check_equal(rresp, resp, "rresp");
      check_equal(rlast, last, "rlast");
    end procedure;

    variable data : integer_vector_ptr_t;
    variable size, log_size : natural;
    variable id : std_logic_vector(arid'range);
    variable len : natural;
    variable burst : axi_burst_t;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("Test random read") then
      for test_idx in 0 to 32-1 loop

        id := rnd.RandSlv(arid'length);
        case rnd.RandInt(1) is
          when 0 =>
            burst := axi_burst_fixed;
            len := 1;
          when 1 =>
            burst := axi_burst_incr;
            len := rnd.RandInt(1, 2**arlen'length);
          when others =>
            assert false;
        end case;

        log_size := rnd.RandInt(0, 3);
        size := 2**log_size;
        random_integer_vector(rnd, size * len, 0, 255, data);

        alloc := allocate(memory, 8 * len);
        for i in 0 to length(data)-1 loop
          write_byte(memory, base_address(alloc)+i, get(data, i));
        end loop;

        write_addr(id, base_address(alloc), len, log_size, burst);

        for i in 0 to len-1 loop
          read_data(id, base_address(alloc)+size*i, size, axi_resp_ok, i=len-1);
        end loop;
      end loop;

    elsif run("Test error on unsupported wrap burst") then
      error_queue <= allocate;
      alloc := allocate(memory, 8);
      write_addr(x"2", base_address(alloc), 2, 0, axi_burst_wrap);
      wait until length(error_queue) > 0 and rising_edge(clk);
      check_equal(pop_string(error_queue), "Wrapping burst type not supported");
      check_equal(length(error_queue), 0, "no more errors");
    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 1 ms);

  dut : entity work.axi_read_slave
    generic map (
      memory => memory)
    port map (
      aclk    => clk,

      arvalid => arvalid,
      arready => arready,
      arid    => arid,
      araddr  => araddr,
      arlen   => arlen,
      arsize  => arsize,
      arburst => arburst,

      rvalid  => rvalid,
      rready  => rready,
      rid     => rid,
      rdata   => rdata,
      rresp   => rresp,
      rlast   => rlast,

      error_queue => error_queue);

  clk <= not clk after 5 ns;
end architecture;
