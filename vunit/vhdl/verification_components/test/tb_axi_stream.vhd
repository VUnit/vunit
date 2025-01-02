-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.axi_stream_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.sync_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_stream is
  generic(
    runner_cfg    : string;
    g_data_length : positive := 8;
    g_id_length   : natural := 8;
    g_dest_length : natural := 8;
    g_user_length : natural := 8;
    g_stall_percentage_master : natural range 0 to 100 := 0;
    g_stall_percentage_slave  : natural range 0 to 100 := 0
  );
end entity;

architecture a of tb_axi_stream is

  constant min_stall_cycles : natural := 5;
  constant max_stall_cycles : natural := 15;
  constant master_stall_config : stall_config_t := new_stall_config(stall_probability => real(g_stall_percentage_master)/100.0, min_stall_cycles => min_stall_cycles, max_stall_cycles => max_stall_cycles);
  constant slave_stall_config  : stall_config_t := new_stall_config(stall_probability => real(g_stall_percentage_slave)/100.0 , min_stall_cycles => min_stall_cycles, max_stall_cycles => max_stall_cycles);

  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master(
    data_length => g_data_length, id_length => g_id_length, dest_length => g_dest_length, user_length => g_user_length,
    stall_config => master_stall_config, logger => get_logger("master"), actor => new_actor("master"),
    monitor => default_axi_stream_monitor, protocol_checker => default_axi_stream_protocol_checker
  );
  constant master_stream : stream_master_t := as_stream(master_axi_stream);
  constant master_sync   : sync_handle_t   := as_sync(master_axi_stream);

  constant slave_axi_stream : axi_stream_slave_t := new_axi_stream_slave(
    data_length => g_data_length, id_length => g_id_length, dest_length => g_dest_length, user_length => g_user_length,
    stall_config => slave_stall_config, logger => get_logger("slave"), actor => new_actor("slave"),
    monitor => default_axi_stream_monitor, protocol_checker => default_axi_stream_protocol_checker
  );
  constant slave_stream : stream_slave_t := as_stream(slave_axi_stream);
  constant slave_sync   : sync_handle_t  := as_sync(slave_axi_stream);

  constant monitor : axi_stream_monitor_t := new_axi_stream_monitor(
    data_length => g_data_length, id_length => g_id_length, dest_length => g_dest_length, user_length => g_user_length,
    logger => get_logger("monitor"), actor => new_actor("monitor"),
    protocol_checker => default_axi_stream_protocol_checker
  );

  constant protocol_checker : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(
    data_length => g_data_length, id_length => g_id_length, dest_length => g_dest_length, user_length => g_user_length,
    logger      => get_logger("protocol_checker"),
    max_waits   => 8
  );

  constant n_monitors : natural := 3;

  signal aclk : std_logic := '0';
  signal areset_n : std_logic := '1';
  signal tvalid : std_logic;
  signal tready : std_logic;
  signal tdata : std_logic_vector(data_length(slave_axi_stream)-1 downto 0);
  signal tlast : std_logic;
  signal tkeep, tkeep_from_master : std_logic_vector(data_length(slave_axi_stream)/8-1 downto 0);
  signal tstrb, tstrb_from_master : std_logic_vector(data_length(slave_axi_stream)/8-1 downto 0);
  signal tid : std_logic_vector(id_length(slave_axi_stream)-1 downto 0);
  signal tdest : std_logic_vector(dest_length(slave_axi_stream)-1 downto 0);
  signal tuser : std_logic_vector(user_length(slave_axi_stream)-1 downto 0);

  signal not_valid      : std_logic;
  signal not_valid_data : std_logic;
  signal not_valid_keep : std_logic;
  signal not_valid_strb : std_logic;
  signal not_valid_id   : std_logic;
  signal not_valid_dest : std_logic;
  signal not_valid_user : std_logic;

  signal connected_tkeep : boolean := true;
  signal connected_tstrb : boolean := true;
  -----------------------------------------------------------------------------
  -- signals used for the statistics for stall evaluation
  type axis_stall_stats_fields_t is record
    length, min, max, events : natural;
    prev, start      : std_logic;
  end record;

  type axis_stall_stats_t is record
    valid : axis_stall_stats_fields_t;
    ready : axis_stall_stats_fields_t;
  end record;

  signal axis_stall_stats : axis_stall_stats_t := (
    valid => (0, 1000, 0, 0, '0', '0'),
    ready => (0, 1000, 0, 0, '0', '0')
    );

begin

  main : process
    constant subscriber             : actor_t := new_actor("main");

    variable data      : std_logic_vector(tdata'range);
    variable last_bool : boolean;
    variable last      : std_logic;
    variable keep      : std_logic_vector(tkeep'range);
    variable strb      : std_logic_vector(tstrb'range);
    variable id        : std_logic_vector(tid'range);
    variable dest      : std_logic_vector(tdest'range);
    variable user      : std_logic_vector(tuser'range);

    variable axi_stream_transaction : axi_stream_transaction_t(
      tdata(tdata'range),
      tkeep(tkeep'range),
      tstrb(tstrb'range),
      tid(tid'range),
      tdest(tdest'range),
      tuser(tuser'range)
    );
    variable reference_queue : queue_t := new_queue;
    variable reference : stream_reference_t;
    variable msg                    : msg_t;
    variable msg_type               : msg_type_t;
    variable timestamp              : time := 0 ns;

    variable mocklogger : logger_t;
    variable rnd : RandomPtype;

    procedure get_axi_stream_transaction(variable axi_stream_transaction : out axi_stream_transaction_t) is
    begin
      receive(net, subscriber, msg);
      msg_type := message_type(msg);
      handle_axi_stream_transaction(msg_type, msg, axi_stream_transaction);
      check(is_already_handled(msg_type));
    end;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed("A seed");
    subscribe(subscriber, find("monitor"));
    subscribe(subscriber, find("master"));
    subscribe(subscriber, find("slave"));
    show(get_logger("monitor"), display_handler, debug);
    show(get_logger("master"), display_handler, debug);
    show(get_logger("slave"), display_handler, debug);

    wait for 20 ns;

    if run("test single push and pop") then
      push_stream(net, master_stream, x"77", true);
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"77"), result("for pop stream data"));
      check_true(last_bool, result("for pop stream last"));

      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"77"),
          result("for axi_stream_transaction.tdata")
        );
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
      end loop;
    elsif run("test reset") then
      wait until rising_edge(aclk);
      areset_n <= '0';
      wait until rising_edge(aclk);
      check_equal(tvalid, '0', result("for valid low check while in reset"));
      areset_n <= '1';
      wait until rising_edge(aclk);

    elsif run("test single push and pop with tlast") then
      push_stream(net, master_stream, x"88", true);
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"88"), result("for pop stream data"));
      check_true(last_bool, result("for pop stream last"));

      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"88"),
          result("for axi_stream_transaction.tdata")
        );
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
      end loop;

    elsif run("test single axi push and pop") then
      push_axi_stream(net, master_axi_stream, x"99", tlast => '1');
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"99"), result("pop stream data"));
      check_equal(last_bool, true, result("pop stream last"));

    elsif run("test single push and axi pop") then
      push_stream(net, master_stream, x"AA", last => true);
      pop_axi_stream(net, slave_axi_stream, data, last);
      check_equal(data, std_logic_vector'(x"AA"), result("pop stream data"));
      check_equal(last, '1', result("pop stream last"));

    elsif run("test single axi push and axi pop") then
      push_axi_stream(net, master_axi_stream, x"99", tlast => '1', tkeep => "1", tstrb => "1", tid => x"11", tdest => x"22", tuser => x"33" );
      pop_axi_stream(net, slave_axi_stream, data, last, keep, strb, id, dest, user);
      check_equal(data, std_logic_vector'(x"99"), result("pop axi stream data"));
      check_equal(last, std_logic'('1'), result("pop stream last"));
      check_equal(keep, std_logic_vector'("1"), result("pop stream keep"));
      check_equal(strb, std_logic_vector'("1"), result("pop stream strb"));
      check_equal(id, std_logic_vector'(x"11"), result("pop stream id"));
      check_equal(dest, std_logic_vector'(x"22"), result("pop stream dest"));
      check_equal(user, std_logic_vector'(x"33"), result("pop stream user"));

      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(axi_stream_transaction.tdata, std_logic_vector'(x"99"), result("for axi_stream_transaction.tdata"));
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
        check_equal(axi_stream_transaction.tkeep, std_logic_vector'("1"), result("pop stream keep"));
        check_equal(axi_stream_transaction.tstrb, std_logic_vector'("1"), result("pop stream strb"));
        check_equal(axi_stream_transaction.tid, std_logic_vector'(x"11"), result("pop stream id"));
        check_equal(axi_stream_transaction.tdest, std_logic_vector'(x"22"), result("pop stream dest"));
        check_equal(axi_stream_transaction.tuser, std_logic_vector'(x"33"), result("pop stream user"));
      end loop;

    elsif run("test disconnecting tstrb and tkeep") then
      for iter in 1 to 2 loop
        connected_tstrb <= false;
        connected_tkeep <= iter = 1;
        if iter = 1 then
          push_axi_stream(net, master_axi_stream, x"99", tlast => '1', tkeep => "1", tid => x"11", tdest => x"22", tuser => x"33" );
        else
          push_axi_stream(net, master_axi_stream, x"99", tlast => '1', tid => x"11", tdest => x"22", tuser => x"33" );
        end if;
        pop_axi_stream(net, slave_axi_stream, data, last, keep, strb, id, dest, user);
        check_equal(data, std_logic_vector'(x"99"), result("pop axi stream data"));
        check_equal(last, std_logic'('1'), result("pop stream last"));
        check_equal(keep, std_logic_vector'("1"), result("pop stream keep"));
        check_equal(strb, std_logic_vector'("1"), result("pop stream strb"));
        check_equal(id, std_logic_vector'(x"11"), result("pop stream id"));
        check_equal(dest, std_logic_vector'(x"22"), result("pop stream dest"));
        check_equal(user, std_logic_vector'(x"33"), result("pop stream user"));

        for i in 1 to n_monitors loop
          get_axi_stream_transaction(axi_stream_transaction);
          check_equal(axi_stream_transaction.tdata, std_logic_vector'(x"99"), result("for axi_stream_transaction.tdata"));
          check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
          check_equal(axi_stream_transaction.tkeep, std_logic_vector'("1"), result("pop stream keep"));
          check_equal(axi_stream_transaction.tstrb, std_logic_vector'("1"), result("pop stream strb"));
          check_equal(axi_stream_transaction.tid, std_logic_vector'(x"11"), result("pop stream id"));
          check_equal(axi_stream_transaction.tdest, std_logic_vector'(x"22"), result("pop stream dest"));
          check_equal(axi_stream_transaction.tuser, std_logic_vector'(x"33"), result("pop stream user"));
        end loop;
      end loop;

    elsif run("test single stalled push and pop") then
      wait until rising_edge(aclk);
      wait_for_time(net, master_sync, 30 ns);
      timestamp := now;
      push_stream(net, master_stream, x"77", true);
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"77"), result("for pop stream data"));
      check_true(last_bool, result("for pop stream last"));
      check_equal(now - 10 ns, timestamp + 50 ns, result("for push wait time"));  -- two extra cycles inserted by alignment
      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"77"),
          result("for axi_stream_transaction.tdata")
        );
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
      end loop;

    elsif run("test single push and stalled pop") then
      wait until rising_edge(aclk);
      wait_for_time(net, slave_sync, 30 ns);
      timestamp := now;
      push_stream(net, master_stream, x"77", true);
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"77"), result("for pop stream data"));
      check_true(last_bool, result("for pop stream last"));
      check_equal(now - 10 ns, timestamp + 50 ns, result("for push wait time"));

      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"77"),
          result("for axi_stream_transaction.tdata")
        );
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
      end loop;

    elsif run("test single push and stalled pop with non-multiple of clock period") then
      wait until rising_edge(aclk);
      wait_for_time(net, slave_sync, 29 ns);
      timestamp := now;
      push_stream(net, master_stream, x"77", true);
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"77"), result("for pop stream data"));
      check_true(last_bool, result("for pop stream last"));
      check_equal(now - 10 ns, timestamp + 40 ns, result("for push wait time"));

      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"77"),
          result("for axi_stream_transaction.tdata")
        );
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
      end loop;

    elsif run("test single stalled push and pop with non-multiple of clock period") then
      wait until rising_edge(aclk);
      wait_for_time(net, master_sync, 29 ns);
      timestamp := now;
      push_stream(net, master_stream, x"77", true);
      pop_stream(net, slave_stream, data, last_bool);
      check_equal(data, std_logic_vector'(x"77"), result("for pop stream data"));
      check_true(last_bool, result("for pop stream last"));
      check_equal(now - 10 ns, timestamp + 40 ns, result("for push wait time"));  -- Aligned to clock edge again
      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"77"),
          result("for axi_stream_transaction.tdata")
        );
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
      end loop;

    elsif run("test pop before push") then
      for i in 0 to 7 loop
        pop_stream(net, slave_stream, reference);
        push(reference_queue, reference);
      end loop;

      for i in 0 to 7 loop
        push_stream(net, master_stream, std_logic_vector(to_unsigned(i + 1, data'length)), true);
      end loop;

      wait_until_idle(net, master_sync); -- wait until all transfers are done before checking them
      wait_until_idle(net, slave_sync);

      for i in 0 to 7 loop
        reference := pop(reference_queue);
        await_pop_stream_reply(net, reference, data);
        check_equal(data, to_unsigned(i + 1, data'length), result("for await pop stream data"));

        for j in 1 to n_monitors loop
          get_axi_stream_transaction(axi_stream_transaction);
          check_equal(
            axi_stream_transaction.tdata,
            to_unsigned(i + 1, data'length),
            result("for axi_stream_transaction.tdata")
          );
        end loop;
      end loop;

    elsif run("test passing check") then
      data := rnd.RandSlv(data'length);
      keep := (others => '1');
      strb := (others => '1');
      if id'length > 0 then
        id := x"23";
      end if;
      if dest'length > 0 then
        dest := x"34";
      end if;
      if user'length > 0 then
        user := x"45";
      end if;
      push_axi_stream(net, master_axi_stream, data, tlast => '1', tkeep => keep, tstrb => strb, tid => id, tdest => dest, tuser => user);
      check_axi_stream(net, slave_axi_stream, data, tlast => '1', tkeep => keep, tstrb => strb, tid => id, tdest => dest, tuser => user,
                       msg => "checking axi stream");

    elsif run("test passing reduced check") then
      data := rnd.RandSlv(data'length);
      keep := (others => '1');
      strb := (others => '1');
      if id'length > 0 then
        id := x"23";
      end if;
      if dest'length > 0 then
        dest := x"34";
      end if;
      if user'length > 0 then
        user := x"45";
      end if;
      push_axi_stream(net, master_axi_stream, data, tlast => '1', tkeep => keep, tstrb => strb, tid => id, tdest => dest, tuser => user);
      check_axi_stream(net, slave_axi_stream, data, tlast => '1', msg => "reduced checking axi stream");

    elsif run("test passing with no tkeep") then
      for blocking in boolean range false to true loop
        data := x"1234";
        keep := "10";
        strb := "10";
        id := x"23";
        dest := x"34";
        user := x"45";
        push_axi_stream(net, master_axi_stream, data, tlast => '1', tkeep => keep, tstrb => strb, tid => id, tdest => dest, tuser => user);
        check_axi_stream(net, slave_axi_stream, data xor x"00ff", tlast => '1', tkeep => keep, tstrb => strb, tid => id, tdest => dest,
                         tuser => user, msg => "checking axi stream", blocking => blocking);
      end loop;
      wait_until_idle(net, as_sync(slave_axi_stream));

    elsif run("test failing check") then
      data := (others => '1');
      keep := (others => '1');
      strb := (others => '1');
      if id'length > 0 then
        id := x"22";
      end if;
      if dest'length > 0 then
        dest := x"33";
      end if;
      if user'length > 0 then
        user := x"44";
      end if;
      push_axi_stream(net, master_axi_stream, data, tlast => '1', tkeep => keep, tstrb => strb, tid => id, tdest => dest, tuser => user);
      -- Delay mocking the logger to prevent 'invalid checks' from failing the checks below
      wait until rising_edge (aclk) and tvalid = '1';

      mocklogger := get_logger("check");
      mock(mocklogger);

      if id'length > 0 then
        id := x"23";
      end if;
      if dest'length > 0 then
        dest := x"34";
      end if;
      if user'length > 0 then
        user := x"45";
      end if;
      check_axi_stream(net, slave_axi_stream, not data, tlast => '0', tkeep => not keep, tstrb => not strb, tid => id, tdest => dest,
                       tuser => user, msg => "checking axi stream");

      check_log(mocklogger, "TDATA mismatch, checking axi stream - Got " &
                to_nibble_string(data) & " (" & to_string(to_integer(data)) & "). Expected " &
                to_nibble_string(not data) & " (" & to_string(to_integer(not data)) & ").", error);
      check_log(mocklogger, "TKEEP mismatch, checking axi stream - Got " &
                to_nibble_string(keep) & " (" & to_string(to_integer(keep)) & "). Expected " &
                to_nibble_string(not keep) & " (" & to_string(to_integer(not keep)) & ").", error);
      check_log(mocklogger, "TSTRB mismatch, checking axi stream - Got " &
                to_nibble_string(strb) & " (" & to_string(to_integer(strb)) & "). Expected " &
                to_nibble_string(not strb) & " (" & to_string(to_integer(not strb)) & ").", error);
      check_log(mocklogger, "TLAST mismatch, checking axi stream - Got 1. Expected 0.", error);
      if id'length > 0 then
        check_log(mocklogger, "TID mismatch, checking axi stream - Got 0010_0010 (34). Expected 0010_0011 (35).", error);
      end if;
      if dest'length > 0 then
        check_log(mocklogger, "TDEST mismatch, checking axi stream - Got 0011_0011 (51). Expected 0011_0100 (52).", error);
      end if;
      if user'length > 0 then
        check_log(mocklogger, "TUSER mismatch, checking axi stream - Got 0100_0100 (68). Expected 0100_0101 (69).", error);
      end if;

      unmock(mocklogger);

    elsif run("test back-to-back passing check") then
      keep := (others => '1');
      strb := (others => '1');
      wait until rising_edge(aclk);
      timestamp := now;

      last := '0';
      for i in 3 to 14 loop
        if i = 14 then
          last := '1';
        end if;
        push_axi_stream(net, master_axi_stream,
                        tdata => to_slv(i, tdata),
                        tlast => last,
                        tkeep => keep,
                        tstrb => strb,
                        tid => std_logic_vector(to_unsigned(42, id'length)),
                        tdest => std_logic_vector(to_unsigned(i+1, dest'length)),
                        tuser => std_logic_vector(to_unsigned(i*2, user'length)));
      end loop;

      last := '0';
      for i in 3 to 14 loop
        if i = 14 then
          last := '1';
        end if;
        check_axi_stream(net, slave_axi_stream,
                         expected => to_slv(i, tdata),
                         tlast => last,
                         tkeep => keep,
                         tstrb => strb,
                         tid => std_logic_vector(to_unsigned(42, id'length)),
                         tdest => std_logic_vector(to_unsigned(i+1, dest'length)),
                         tuser => std_logic_vector(to_unsigned(i*2, user'length)),
                         msg  => "check non-blocking",
                         blocking  => false);
      end loop;

      check_equal(now, timestamp, result(" setting up transaction stalled"));

      wait_until_idle(net, as_sync(slave_axi_stream));
      check_equal(now, timestamp + (12+1)*10 ns, " transaction time incorrect");

    elsif run("test back-to-back passing reduced check") then
      keep := (others => '1');
      strb := (others => '1');
      wait until rising_edge(aclk);
      timestamp := now;

      last := '0';
      for i in 3 to 14 loop
        if i = 14 then
          last := '1';
        end if;
        push_axi_stream(net, master_axi_stream,
                        tdata => to_slv(i, tdata),
                        tlast => last,
                        tkeep => keep,
                        tstrb => strb,
                        tid => std_logic_vector(to_unsigned(42, id'length)),
                        tdest => std_logic_vector(to_unsigned(i+1, dest'length)),
                        tuser => std_logic_vector(to_unsigned(i*2, user'length)));
      end loop;

      last := '0';
      for i in 3 to 14 loop
        if i = 14 then
          last := '1';
        end if;
        check_axi_stream(net, slave_axi_stream,
                         expected => to_slv(i, tdata),
                         tlast => last,
                         msg  => "check non-blocking",
                         blocking  => false);
      end loop;

      check_equal(now, timestamp, result(" setting up transaction stalled"));

      wait_until_idle(net, as_sync(slave_axi_stream));
      check_equal(now, timestamp + (12+1)*10 ns, " transaction time incorrect");

    elsif run("test back-to-back failing check") then
      data := (others => '1');
      keep := (others => '1');
      strb := (others => '1');
      wait until rising_edge(aclk);
      timestamp := now;

      push_axi_stream(net, master_axi_stream,
                      tdata => data,
                      tlast => '1',
                      tkeep => keep,
                      tstrb => strb,
                      tid => std_logic_vector(to_unsigned(42, id'length)),
                      tdest => std_logic_vector(to_unsigned(4, dest'length)),
                      tuser => std_logic_vector(to_unsigned(7, user'length)));

      check_axi_stream(net, slave_axi_stream,
                       expected => not data,
                       tlast => '0',
                       tkeep => not keep,
                       tstrb => not strb,
                       tid => std_logic_vector(to_unsigned(44, id'length)),
                       tdest => std_logic_vector(to_unsigned(5, dest'length)),
                       tuser => std_logic_vector(to_unsigned(8, g_user_length)),
                       msg => "check non-blocking",
                       blocking  => false);

      check_equal(now, timestamp, result(" setting up transaction stalled"));

      wait until rising_edge(aclk);
      wait for 1 ps;
      mocklogger := get_logger("check");
      mock(mocklogger);

      wait until rising_edge(aclk) and tvalid = '1';
      wait for 1 ps;

      check_log(mocklogger, "TDATA mismatch, check non-blocking - Got " &
                to_nibble_string(data) & " (" & to_string(to_integer(data)) & "). Expected " &
                to_nibble_string(not data) & " (" & to_string(to_integer(not data)) & ").", error);
      check_log(mocklogger, "TKEEP mismatch, check non-blocking - Got " &
                to_nibble_string(keep) & " (" & to_string(to_integer(keep)) & "). Expected " &
                to_nibble_string(not keep) & " (" & to_string(to_integer(not keep)) & ").", error);
      check_log(mocklogger, "TSTRB mismatch, check non-blocking - Got " &
                to_nibble_string(keep) & " (" & to_string(to_integer(keep)) & "). Expected " &
                to_nibble_string(not keep) & " (" & to_string(to_integer(not keep)) & ").", error);
      check_log(mocklogger, "TLAST mismatch, check non-blocking - Got 1. Expected 0.", error);
      if id'length > 0 then
        check_log(mocklogger, "TID mismatch, check non-blocking - Got 0010_1010 (42). Expected 0010_1100 (44).", error);
      end if;
      if dest'length > 0 then
        check_log(mocklogger, "TDEST mismatch, check non-blocking - Got 0000_0100 (4). Expected 0000_0101 (5).", error);
      end if;
      if user'length > 0 then
        check_log(mocklogger, "TUSER mismatch, check non-blocking - Got 0000_0111 (7). Expected 0000_1000 (8).", error);
      end if;

      unmock(mocklogger);

      check_equal(now, timestamp + 20 ns + 1 ps, " transaction time incorrect");

    elsif run("test random stall on master") or run("test random pop stall on slave") then
      wait until rising_edge(aclk);
      for i in 0 to 100 loop
        pop_stream(net, slave_stream, reference);
        push(reference_queue, reference);
      end loop;
      for i in 0 to 100 loop
        push_stream(net, master_stream, std_logic_vector(to_unsigned(i + 1, data'length)), true);
      end loop;

      wait_until_idle(net, master_sync);  -- wait until all transfers are done before checking them
      wait_until_idle(net, slave_sync);

      for i in 0 to 100 loop
        reference := pop(reference_queue);
        await_pop_stream_reply(net, reference, data);
        check_equal(data, to_unsigned(i + 1, data'length), result("for await pop stream data"));
      end loop;
      info("There have been " & to_string(axis_stall_stats.valid.events) & " tvalid stall events");
      info("Min stall length was " & to_string(axis_stall_stats.valid.min));
      info("Max stall length was " & to_string(axis_stall_stats.valid.max));
      if running_test_case = "test random stall on master" then
        check((axis_stall_stats.valid.events < (g_stall_percentage_master+10)) and (axis_stall_stats.valid.events > (g_stall_percentage_master-10)), "Checking that the tvalid stall probability lies within reasonable boundaries");
        check((axis_stall_stats.valid.min >= min_stall_cycles) and (axis_stall_stats.valid.max <= max_stall_cycles), "Checking that the minimal and maximal stall lenghts are in expected boundaries");
        check_equal(axis_stall_stats.ready.events, 0, "Checking that there are zero tready stall events");
      else
        check((axis_stall_stats.ready.events < (g_stall_percentage_slave+10)) and (axis_stall_stats.ready.events > (g_stall_percentage_slave-10)), "Checking that the tready stall probability lies within reasonable boundaries");
        check((axis_stall_stats.ready.min >= min_stall_cycles) and (axis_stall_stats.ready.max <= max_stall_cycles), "Checking that the minimal and maximal stall lenghts are in expected boundaries");
        check_equal(axis_stall_stats.valid.events, 0, "Checking that there are zero tvalid stall events");
      end if;

    elsif run("test random check stall on slave") then
      wait until rising_edge(aclk);
      for i in 0 to 100 loop
        check_axi_stream(net, slave_axi_stream, std_logic_vector(to_unsigned(i + 1, data'length)), blocking => false);
      end loop;
      for i in 0 to 100 loop
        push_stream(net, master_stream, std_logic_vector(to_unsigned(i + 1, data'length)), true);
      end loop;

      wait_until_idle(net, master_sync);  -- wait until all transfers are done before checking them
      wait_until_idle(net, slave_sync);

      info("There have been " & to_string(axis_stall_stats.valid.events) & " tvalid stall events");
      info("Min stall length was " & to_string(axis_stall_stats.valid.min));
      info("Max stall length was " & to_string(axis_stall_stats.valid.max));
      check((axis_stall_stats.ready.events < (g_stall_percentage_slave+10)) and (axis_stall_stats.ready.events > (g_stall_percentage_slave-10)), "Checking that the tready stall probability lies within reasonable boundaries");
      check((axis_stall_stats.ready.min >= min_stall_cycles) and (axis_stall_stats.ready.max <= max_stall_cycles), "Checking that the minimal and maximal stall lenghts are in expected boundaries");
      check_equal(axis_stall_stats.valid.events, 0, "Checking that there are zero tvalid stall events");

    end if;
    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 10 ms);

  axi_stream_master_inst : entity work.axi_stream_master
    generic map(
      master => master_axi_stream)
    port map(
      aclk     => aclk,
      areset_n => areset_n,
      tvalid   => tvalid,
      tready   => tready,
      tdata    => tdata,
      tlast    => tlast,
      tkeep    => tkeep_from_master,
      tstrb    => tstrb_from_master,
      tid      => tid,
      tuser    => tuser,
      tdest    => tdest);

  tkeep <= tkeep_from_master when connected_tkeep else (others => '1');
  tstrb <= tstrb_from_master when connected_tstrb else (others => 'U');

 not_valid <= not tvalid;

 not_valid_data <= '1' when is_x(tdata) else '0';
 check_true(aclk, not_valid, not_valid_data, "Invalid data not X");
 not_valid_keep <= '1' when is_x(tkeep_from_master) else '0';
 check_true(aclk, not_valid, not_valid_keep, "Invalid keep not X");
 not_valid_strb <= '1' when is_x(tstrb_from_master) else '0';
 check_true(aclk, not_valid, not_valid_strb, "Invalid strb not X");
 GEN_CHECK_INVALID_ID: if g_id_length > 0 generate
   not_valid_id   <= '1' when is_x(tid) else '0';
   check_true(aclk, not_valid, not_valid_id,   "Invalid id not X");
 end generate;
 GEN_CHECK_INVALID_DEST: if g_dest_length > 0 generate
   not_valid_dest <= '1' when is_x(tdest) else '0';
   check_true(aclk, not_valid, not_valid_dest, "Invalid dest not X");
 end generate;
 GEN_CHECK_INVALID_USER: if g_user_length > 0 generate
   not_valid_user <= '1' when tuser = std_logic_vector'("00000000") else '0';
   check_true(aclk, not_valid, not_valid_user, "Invalid user not 0");
 end generate;

  axi_stream_slave_inst : entity work.axi_stream_slave
    generic map(
      slave => slave_axi_stream)
    port map(
      aclk     => aclk,
      areset_n => areset_n,
      tvalid   => tvalid,
      tready   => tready,
      tdata    => tdata,
      tlast    => tlast,
      tkeep    => tkeep,
      tstrb    => tstrb,
      tid      => tid,
      tuser    => tuser,
      tdest    => tdest);

  axi_stream_monitor_inst : entity work.axi_stream_monitor
    generic map(
      monitor => monitor
    )
    port map(
      aclk   => aclk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata,
      tlast  => tlast,
      tkeep  => tkeep,
      tstrb  => tstrb,
      tid    => tid,
      tdest  => tdest,
      tuser  => tuser
    );

  axi_stream_protocol_checker_inst : entity work.axi_stream_protocol_checker
    generic map(
      protocol_checker => protocol_checker)
    port map(
      aclk     => aclk,
      areset_n => areset_n,
      tvalid   => tvalid,
      tready   => tready,
      tdata    => tdata,
      tlast    => tlast,
      tkeep    => tkeep,
      tstrb    => tstrb,
      tid      => tid,
      tdest    => tdest,
      tuser    => tuser
    );

  statistics : process(aclk)
  begin
    if rising_edge(aclk) then
      axis_stall_stats.valid.prev <= tvalid;
      axis_stall_stats.ready.prev <= tready;
      -------------------------------------------------------------------------
      -- TVALID and TREADY stall events counters
      if tvalid and (not tready) and axis_stall_stats.ready.prev then
        axis_stall_stats.ready.events <= axis_stall_stats.ready.events + 1;
      end if;
      if (not tvalid) and tready and axis_stall_stats.valid.prev then
        axis_stall_stats.valid.events <= axis_stall_stats.valid.events + 1;
      end if;

      -------------------------------------------------------------------------
      -- TVALID Minmal and Maximal Stall lengths
      if tvalid then
        axis_stall_stats.valid.start <= '1';
      end if;

      if (not tvalid) and axis_stall_stats.valid.start then
        axis_stall_stats.valid.length <= axis_stall_stats.valid.length + 1;
      end if;
      if tvalid and axis_stall_stats.valid.start and (not axis_stall_stats.valid.prev) then
        axis_stall_stats.valid.length <= 0;
        axis_stall_stats.valid.min <= minimum(axis_stall_stats.valid.length, axis_stall_stats.valid.min);
        axis_stall_stats.valid.max <= maximum(axis_stall_stats.valid.length, axis_stall_stats.valid.max);
      end if;
      -------------------------------------------------------------------------
      -- TREADY Minmal and Maximal Stall lengths
      if tready then
        axis_stall_stats.ready.start <= '1';
      end if;

      if (not tready) and axis_stall_stats.ready.start then
        axis_stall_stats.ready.length <= axis_stall_stats.ready.length + 1;
      end if;
      if tready and axis_stall_stats.ready.start and (not axis_stall_stats.ready.prev) then
        axis_stall_stats.ready.length <= 0;
        axis_stall_stats.ready.min <= minimum(axis_stall_stats.ready.length, axis_stall_stats.ready.min);
        axis_stall_stats.ready.max <= maximum(axis_stall_stats.ready.length, axis_stall_stats.ready.max);
      end if;

    end if;
  end process;

  aclk <= not aclk after 5 ns;
end architecture;
