-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
use work.memory_pkg.all;
use work.avalon_pkg.all;
use work.bus_master_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_avalon_master is
  generic (
    runner_cfg : string;
    encoded_tb_cfg : string
  );
end entity;

architecture a of tb_avalon_master is

  type tb_cfg_t is record
    data_width : positive;
    addr_width : positive;
    burst_width : positive;
    write_prob : real;
    read_prob : real;
    waitrequest_prob : real;
    readdatavalid_prob : real;
    transfers : positive;
    rndburst_max : positive;
  end record tb_cfg_t;

  impure function decode(encoded_tb_cfg : string) return tb_cfg_t is
  begin
    return (data_width => 32,
            addr_width => 32,
            burst_width => 8,
            rndburst_max => 3,
            write_prob => real'value(get(encoded_tb_cfg, "write_prob")),
            read_prob => real'value(get(encoded_tb_cfg, "read_prob")),
            waitrequest_prob => real'value(get(encoded_tb_cfg, "waitrequest_prob")),
            readdatavalid_prob => real'value(get(encoded_tb_cfg, "readdatavalid_prob")),
            transfers => positive'value(get(encoded_tb_cfg, "transfers"))
    );
  end function decode;

  constant tb_cfg : tb_cfg_t := decode(encoded_tb_cfg);

  signal clk    : std_logic := '0';
  signal address    : std_logic_vector(tb_cfg.addr_width-1 downto 0);
  signal writedata  : std_logic_vector(tb_cfg.data_width-1 downto 0);
  signal readdata  : std_logic_vector(tb_cfg.data_width-1 downto 0);
  signal byteenable   : std_logic_vector(tb_cfg.data_width/8 -1 downto 0);
  signal burstcount : std_logic_vector(tb_cfg.burst_width -1 downto 0);
  signal write   : std_logic := '0';
  signal read   : std_logic := '0';
  signal readdatavalid : std_logic := '0';
  signal waitrequest    : std_logic := '0';

  constant master_logger : logger_t := get_logger("master");
  constant tb_logger : logger_t := get_logger("tb");
  constant master_actor : actor_t := new_actor("Avalon-MM Master");
  constant bus_handle : bus_master_t := new_bus(data_length => tb_cfg.data_width,
      address_length => tb_cfg.addr_width, logger => master_logger,
      actor => master_actor);

  constant memory : memory_t := new_memory;
  constant buf : buffer_t := allocate(memory, tb_cfg.transfers * byteenable'length);
  constant avalon_slave : avalon_slave_t := new_avalon_slave(
    memory => memory,
    readdatavalid_high_probability => tb_cfg.readdatavalid_prob,
    waitrequest_high_probability => tb_cfg.waitrequest_prob,
    name => "Avalon-MM Slave"
  );

  procedure gen_rndburst(
    variable rnd : inout RandomPType;
    variable rndburst : inout positive;
    variable transfers : inout natural
  ) is
  begin
    rndburst := rnd.RandInt(1, tb_cfg.rndburst_max);
    if transfers >= rndburst then
      transfers := transfers - rndburst;
    else
      rndburst := transfers;
      transfers := 0;
    end if;
  end procedure;

begin

  main_stim : process
    variable tmp : std_logic_vector(writedata'range);
    variable value : std_logic_vector(writedata'range) := (others => '1');
    variable burst_rd_ref : bus_reference_t;
    variable bus_rd_ref1 : bus_reference_t;
    variable bus_rd_ref2 : bus_reference_t;
    type bus_reference_arr_t is array (0 to tb_cfg.transfers-1) of bus_reference_t;
    variable rd_ref : bus_reference_arr_t;
    constant data_queue : queue_t := new_queue;
    constant rd_ref_queue : queue_t := new_queue;
    variable rnd : RandomPType;
    variable transfers : natural;
    variable rndburst : positive;
    variable i : natural;
    variable addr : natural range 0 to tb_cfg.transfers*byteenable'length;
  begin
    rnd.InitSeed(rnd'instance_name);
    test_runner_setup(runner, runner_cfg);
    set_format(display_handler, verbose, true);
    show(tb_logger, display_handler, trace);
    show(default_logger, display_handler, trace);
    show(master_logger, display_handler, trace);
    show(com_logger, display_handler, trace);

    wait until rising_edge(clk);

    if run("wr single rd single") then
      info(tb_logger, "Writing...");
      write_bus(net, bus_handle, 0, value);
      wait until rising_edge(clk);
      wait for 100 ns;
      info(tb_logger, "Reading...");
      read_bus(net, bus_handle, 0, tmp);
      check_equal(tmp, value, "read data");

    elsif run("wr block rd block") then
      info(tb_logger, "Writing...");
      for i in 0 to tb_cfg.transfers -1 loop
        write_bus(net, bus_handle, i*(byteenable'length),
            std_logic_vector(to_unsigned(i, writedata'length)));
      end loop;

      info(tb_logger, "Reading...");
      for i in 0 to tb_cfg.transfers-1 loop
        read_bus(net, bus_handle, i*(byteenable'length), rd_ref(i));
      end loop;

      info(tb_logger, "Get reads by references...");
      for i in 0 to tb_cfg.transfers-1 loop
        await_read_bus_reply(net, rd_ref(i), tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, readdata'length)), "read data");
      end loop;

    elsif run("wr rd interleaved") then
      info(tb_logger, "Writing and reading...");
      for i in 0 to tb_cfg.transfers -1 loop
        write_bus(net, bus_handle, i*(byteenable'length),
            std_logic_vector(to_unsigned(i, writedata'length)));
        read_bus(net, bus_handle, i*(byteenable'length), rd_ref(i));
      end loop;

      info(tb_logger, "Get reads by references...");
      for i in 0 to tb_cfg.transfers-1 loop
        await_read_bus_reply(net, rd_ref(i), tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, readdata'length)), "read data");
      end loop;


    elsif run("burst wr and burst rd non-blocking") then
      info(tb_logger, "Writing...");
      for i in 0 to tb_cfg.transfers -1 loop
        push(data_queue, std_logic_vector(to_unsigned(i, writedata'length)));
      end loop;
      burst_write_bus(net, bus_handle, 0, tb_cfg.transfers, data_queue);
      check_true(is_empty(data_queue), "wr queue not flushed by master");

      info(tb_logger, "Reading...");
      burst_read_bus(net, bus_handle, 0, tb_cfg.transfers, burst_rd_ref);
      info(tb_logger, "Get reads by references...");
      await_burst_read_bus_reply(net, bus_handle, data_queue, burst_rd_ref);

      info(tb_logger, "Compare...");
      for i in 0 to tb_cfg.transfers-1 loop
        tmp := pop(data_queue);
        check_equal(tmp, std_logic_vector(to_unsigned(i, readdata'length)), "read data");
      end loop;
      check_true(is_empty(data_queue), "rd queue not flushed by master");


    elsif run("burst wr and burst rd blocking") then
      info(tb_logger, "Writing...");
      for i in 0 to tb_cfg.transfers -1 loop
        push(data_queue, std_logic_vector(to_unsigned(i, writedata'length)));
      end loop;
      burst_write_bus(net, bus_handle, 0, tb_cfg.transfers, data_queue);
      check_true(is_empty(data_queue), "wr queue not flushed by master");

      info(tb_logger, "Reading...");
      burst_read_bus(net, bus_handle, 0, tb_cfg.transfers, data_queue);

      info(tb_logger, "Compare...");
      for i in 0 to tb_cfg.transfers-1 loop
        tmp := pop(data_queue);
        check_equal(tmp, std_logic_vector(to_unsigned(i, readdata'length)), "read data");
      end loop;
      check_true(is_empty(data_queue), "rd queue not flushed by master");


    elsif run("random burstcount") then
      for i in 0 to tb_cfg.transfers -1 loop
        push(data_queue, std_logic_vector(to_unsigned(i, writedata'length)));
      end loop;

      info(tb_logger, "Writing...");
      transfers := tb_cfg.transfers;
      addr := 0;
      while transfers > 0 loop
        gen_rndburst(rnd, rndburst, transfers);
        burst_write_bus(net, bus_handle, addr, rndburst, data_queue);
        addr := addr + rndburst * byteenable'length;
      end loop;
      check_true(is_empty(data_queue), "wr queue not flushed by master");

      info(tb_logger, "Reading...");
      transfers := tb_cfg.transfers;
      addr := 0;
      while transfers > 0 loop
        gen_rndburst(rnd, rndburst, transfers);
        burst_read_bus(net, bus_handle, addr, rndburst, burst_rd_ref);
        push(rd_ref_queue, burst_rd_ref);
        addr := addr + rndburst * byteenable'length;
      end loop;

      info(tb_logger, "Get reads by references and compre...");
      while not is_empty(rd_ref_queue) loop
        burst_rd_ref := pop(rd_ref_queue);
        await_burst_read_bus_reply(net, bus_handle, data_queue, burst_rd_ref);
        while not is_empty(data_queue) loop
          tmp := pop(data_queue);
          check_equal(tmp, std_logic_vector(to_unsigned(i, readdata'length)), "read data");
          i := i + 1;
        end loop;
      end loop;

    elsif run("wait until idle") then
      wait_until_idle(net, bus_handle);
      write_bus(net, bus_handle, 0, value);
      value := std_logic_vector(to_unsigned(456, value'length));
      write_bus(net, bus_handle, 0, value);
      read_bus(net, bus_handle, 4, bus_rd_ref1);
      read_bus(net, bus_handle, 0, bus_rd_ref2);
      wait_until_idle(net, bus_handle);
      await_read_bus_reply(net, bus_rd_ref1, tmp);
      await_read_bus_reply(net, bus_rd_ref2, tmp);
      check_equal(tmp, value, "invalid data");
      wait_until_idle(net, bus_handle);
      write_bus(net, bus_handle, 0, value);
      wait_until_idle(net, bus_handle);

      -- Wait till idle during bursts
      for i in 1 to tb_cfg.transfers loop
        push(data_queue, std_logic_vector(to_unsigned(i, writedata'length)));
      end loop;
      burst_write_bus(net, bus_handle, 0, tb_cfg.transfers, data_queue);
      wait_until_idle(net, bus_handle);
      wait until rising_edge(clk);
      check_equal(write, '0', "unexpected write after wail till idle");

      burst_read_bus(net, bus_handle, 0, tb_cfg.transfers, data_queue);
      wait_until_idle(net, bus_handle);
      wait until rising_edge(clk);
      check_equal(readdatavalid, '0', "unexpected readdatavalid after wail till idle");

      burst_read_bus(net, bus_handle, 0, tb_cfg.transfers, burst_rd_ref);
      wait_until_idle(net, bus_handle);
      wait until rising_edge(clk);
      check_equal(readdatavalid, '0', "unexpected readdatavalid after wail till idle");
      await_burst_read_bus_reply(net, bus_handle, data_queue, burst_rd_ref);
      wait_until_idle(net, bus_handle);

    end if;

    info(tb_logger, "Done, quit...");
    wait for 50 ns;
    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);

  dut : entity work.avalon_master
    generic map (
      bus_handle => bus_handle,
      write_high_probability => tb_cfg.write_prob,
      read_high_probability => tb_cfg.read_prob
    )
    port map (
      clk   => clk,
      address => address,
      byteenable => byteenable,
      burstcount => burstcount,
      write => write,
      writedata => writedata,
      read => read,
      readdata => readdata,
      readdatavalid => readdatavalid,
      waitrequest => waitrequest
    );

  slave : entity work.avalon_slave
    generic map (
      avalon_slave => avalon_slave
    )
    port map (
      clk   => clk,
      address => address,
      byteenable => byteenable,
      burstcount => burstcount,
      write => write,
      writedata => writedata,
      read => read,
      readdata => readdata,
      readdatavalid => readdatavalid,
      waitrequest => waitrequest
    );

  clk <= not clk after 5 ns;

end architecture;
