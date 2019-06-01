-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.axi_stream_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.sync_pkg.all;

entity tb_axi_stream is
  generic(runner_cfg : string);
end entity;

architecture a of tb_axi_stream is
  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master(
    data_length => 8, id_length => 8, dest_length => 8, user_length => 8,
    logger      => get_logger("master"), actor => new_actor("master"),
    monitor     => default_axi_stream_monitor, protocol_checker => default_axi_stream_protocol_checker
  );
  constant master_stream : stream_master_t := as_stream(master_axi_stream);
  constant master_sync   : sync_handle_t   := as_sync(master_axi_stream);

  constant slave_axi_stream : axi_stream_slave_t := new_axi_stream_slave(
    data_length => 8, id_length => 8, dest_length => 8, user_length => 8,
    logger      => get_logger("slave"), actor => new_actor("slave"),
    monitor     => default_axi_stream_monitor, protocol_checker => default_axi_stream_protocol_checker
  );
  constant slave_stream : stream_slave_t := as_stream(slave_axi_stream);
  constant slave_sync   : sync_handle_t  := as_sync(slave_axi_stream);

  constant monitor : axi_stream_monitor_t := new_axi_stream_monitor(
    data_length => 8, id_length => 8, dest_length => 8, user_length => 8,
    logger => get_logger("monitor"), actor => new_actor("monitor"),
    protocol_checker => default_axi_stream_protocol_checker
  );

  constant protocol_checker : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(
    data_length => 8, id_length => 8, dest_length => 8, user_length => 8,
    logger      => get_logger("protocol_checker"),
    max_waits   => 8
  );

  constant n_monitors : natural := 3;

  signal aclk     : std_logic := '0';
  signal areset_n : std_logic := '1';
  signal tvalid   : std_logic;
  signal tready   : std_logic;
  signal tdata    : std_logic_vector(data_length(slave_axi_stream)-1 downto 0);
  signal tlast    : std_logic;
  signal tkeep    : std_logic_vector(data_length(slave_axi_stream)/8-1 downto 0);
  signal tstrb    : std_logic_vector(data_length(slave_axi_stream)/8-1 downto 0);
  signal tid      : std_logic_vector(id_length(slave_axi_stream)-1 downto 0);
  signal tdest    : std_logic_vector(dest_length(slave_axi_stream)-1 downto 0);
  signal tuser    : std_logic_vector(user_length(slave_axi_stream)-1 downto 0);

  signal not_valid      : std_logic;
  signal not_valid_data : std_logic;
  signal not_valid_keep : std_logic;
  signal not_valid_strb : std_logic;
  signal not_valid_id   : std_logic;
  signal not_valid_dest : std_logic;
  signal not_valid_user : std_logic;
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

    procedure get_axi_stream_transaction(variable axi_stream_transaction : out axi_stream_transaction_t) is
    begin
      receive(net, subscriber, msg);
      msg_type := message_type(msg);
      handle_axi_stream_transaction(msg_type, msg, axi_stream_transaction);
      check(is_already_handled(msg_type));
    end;

  begin
    test_runner_setup(runner, runner_cfg);
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
      push_axi_stream(net, master_axi_stream, x"12", tlast => '1', tkeep => "1", tstrb => "1", tid => x"23", tdest => x"34", tuser => x"45");
      check_axi_stream(net, slave_axi_stream, x"12", '1', "1", "1", x"23", x"34", x"45", "checking axi stream");

    elsif run("test passing reduced check") then
      push_axi_stream(net, master_axi_stream, x"12", tlast => '1', tkeep => "1", tstrb => "1", tid => x"23", tdest => x"34", tuser => x"45");
      check_axi_stream(net, slave_axi_stream, x"12", '1', msg => "reduced checking axi stream");

    elsif run("test failing check") then

      push_axi_stream(net, master_axi_stream, x"11", tlast => '0', tkeep => "0", tstrb => "0", tid => x"22", tdest => x"33", tuser => x"44");
      -- Delay mocking the logger to prevent 'invalid checks' from failing the checks below
      wait until rising_edge (aclk) and tvalid = '1';

      mocklogger := get_logger("check");
      mock(mocklogger);

      check_axi_stream(net, slave_axi_stream, x"12", '1', "1", "1", x"23", x"34", x"45", "checking axi stream");
      check_log(mocklogger, "TDATA mismatch, checking axi stream - Got 0001_0001 (17). Expected 0001_0010 (18).", error);
      check_log(mocklogger, "TLAST mismatch, checking axi stream - Got 0. Expected 1.", error);
      check_log(mocklogger, "TKEEP mismatch, checking axi stream - Got 0 (0). Expected 1 (1).", error);
      check_log(mocklogger, "TSTRB mismatch, checking axi stream - Got 0 (0). Expected 1 (1).", error);
      check_log(mocklogger, "TID mismatch, checking axi stream - Got 0010_0010 (34). Expected 0010_0011 (35).", error);
      check_log(mocklogger, "TDEST mismatch, checking axi stream - Got 0011_0011 (51). Expected 0011_0100 (52).", error);
      check_log(mocklogger, "TUSER mismatch, checking axi stream - Got 0100_0100 (68). Expected 0100_0101 (69).", error);

      unmock(mocklogger);

    elsif run("test back-to-back passing check") then
      wait until rising_edge(aclk);
      timestamp := now;

      last := '0';
      for i in 3 to 14 loop
        if i = 14 then
          last := '1';
        end if;
        push_axi_stream(net, master_axi_stream,
                        tdata => std_logic_vector(to_unsigned(i, 8)),
                        tlast => last,
                        tkeep => "1",
                        tstrb => "1",
                        tid => std_logic_vector(to_unsigned(42, 8)),
                        tdest => std_logic_vector(to_unsigned(i+1, 8)),
                        tuser => std_logic_vector(to_unsigned(i*2, 8)));
      end loop;

      last := '0';
      for i in 3 to 14 loop
        if i = 14 then
          last := '1';
        end if;
        check_axi_stream(net, slave_axi_stream,
                         expected => std_logic_vector(to_unsigned(i, 8)),
                         tlast => last,
                         tkeep => "1",
                         tstrb => "1",
                         tid => std_logic_vector(to_unsigned(42, 8)),
                         tdest => std_logic_vector(to_unsigned(i+1, 8)),
                         tuser => std_logic_vector(to_unsigned(i*2, 8)),
                         msg  => "check blocking",
                         blocking  => false);
      end loop;

      check_equal(now, timestamp, result(" setting up transaction stalled"));

      wait_until_idle(net, as_sync(slave_axi_stream));
      check_equal(now, timestamp + (12+1)*10 ns, " transaction time incorrect");

    elsif run("test back-to-back failing check") then
      wait until rising_edge(aclk);
      timestamp := now;

      push_axi_stream(net, master_axi_stream,
                      tdata => std_logic_vector(to_unsigned(3, 8)),
                      tlast => '1',
                      tkeep => "0",
                      tstrb => "0",
                      tid => std_logic_vector(to_unsigned(42, 8)),
                      tdest => std_logic_vector(to_unsigned(4, 8)),
                      tuser => std_logic_vector(to_unsigned(7, 8)));

      check_axi_stream(net, slave_axi_stream,
                       expected => std_logic_vector(to_unsigned(6, 8)),
                       tlast => '0',
                       tkeep => "1",
                       tstrb => "1",
                       tid => std_logic_vector(to_unsigned(44, 8)),
                       tdest => std_logic_vector(to_unsigned(5, 8)),
                       tuser => std_logic_vector(to_unsigned(8, 8)),
                       msg => "check non-blocking",
                       blocking  => false);

      check_equal(now, timestamp, result(" setting up transaction stalled"));

      wait until rising_edge(aclk);
      mocklogger := get_logger("check");
      mock(mocklogger);

      wait until rising_edge(aclk) and tvalid = '1';

      check_log(mocklogger, "TDATA mismatch, check non-blocking - Got 0000_0011 (3). Expected 0000_0110 (6).", error);
      check_log(mocklogger, "TLAST mismatch, check non-blocking - Got 1. Expected 0.", error);
      check_log(mocklogger, "TKEEP mismatch, check non-blocking - Got 0 (0). Expected 1 (1).", error);
      check_log(mocklogger, "TSTRB mismatch, check non-blocking - Got 0 (0). Expected 1 (1).", error);
      check_log(mocklogger, "TID mismatch, check non-blocking - Got 0010_1010 (42). Expected 0010_1100 (44).", error);
      check_log(mocklogger, "TDEST mismatch, check non-blocking - Got 0000_0100 (4). Expected 0000_0101 (5).", error);
      check_log(mocklogger, "TUSER mismatch, check non-blocking - Got 0000_0111 (7). Expected 0000_1000 (8).", error);

      unmock(mocklogger);

      check_equal(now, timestamp + 20 ns, " transaction time incorrect");

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
      tkeep    => tkeep,
      tstrb    => tstrb,
      tid      => tid,
      tuser    => tuser,
      tdest    => tdest);

 not_valid <= not tvalid;

 not_valid_data <= '1' when tdata = std_logic_vector'("XXXXXXXX") else '0';
 check_true(aclk, not_valid, not_valid_data, "Invalid data not X");
 not_valid_keep <= '1' when tkeep = std_logic_vector'("X") else '0';
 check_true(aclk, not_valid, not_valid_keep, "Invalid keep not X");
 not_valid_strb <= '1' when tstrb = std_logic_vector'("X") else '0';
 check_true(aclk, not_valid, not_valid_strb, "Invalid strb not X");
 not_valid_id   <= '1' when tid   = std_logic_vector'("XXXXXXXX") else '0';
 check_true(aclk, not_valid, not_valid_id,   "Invalid id not X");
 not_valid_dest <= '1' when tdest = std_logic_vector'("XXXXXXXX") else '0';
 check_true(aclk, not_valid, not_valid_dest, "Invalid dest not X");
 not_valid_user <= '1' when tuser = std_logic_vector'("00000000") else '0';
 check_true(aclk, not_valid, not_valid_user, "Invalid user not 0");

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

  aclk <= not aclk after 5 ns;
end architecture;
