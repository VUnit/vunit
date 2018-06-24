-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.axi_stream_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;

entity tb_axi_stream is
  generic(runner_cfg : string);
end entity;

architecture a of tb_axi_stream is
  signal aclk   : std_logic := '0';
  signal areset_n   : std_logic := '1';
  signal tvalid : std_logic;
  signal tready : std_logic;
  signal tdata  : std_logic_vector(7 downto 0);
  signal tlast  : std_logic;

  constant monitor : axi_stream_monitor_t := new_axi_stream_monitor(
    data_length => tdata'length, logger => get_logger("monitor"), actor => new_actor("monitor")
  );

  constant protocol_checker : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(
    data_length => tdata'length,
    logger => get_logger("protocol_checker"),
    actor => new_actor("protocol_checker"),
    max_waits => 8
  );

  constant master_axi_stream : axi_stream_master_t := new_axi_stream_master_with_monitor(
    data_length => tdata'length, logger => get_logger("master"), actor => new_actor("master")
  );
  constant master_stream     : stream_master_t     := as_stream(master_axi_stream);

  constant slave_axi_stream : axi_stream_slave_t := new_axi_stream_slave_with_monitor(
    data_length => tdata'length, logger => get_logger("slave"), actor => new_actor("slave")
  );
  constant slave_stream     : stream_slave_t     := as_stream(slave_axi_stream);



  constant n_monitors : natural := 3;

begin

  main : process
    constant subscriber             : actor_t := new_actor("main");
    variable data                   : std_logic_vector(tdata'range);
    variable last                   : boolean;
    variable reference_queue        : queue_t := new_queue;
    variable reference              : stream_reference_t;
    variable msg                    : msg_t;
    variable msg_type               : msg_type_t;
    variable axi_stream_transaction : axi_stream_transaction_t(tdata(tdata'range));

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

    if run("test single push and pop") then
      push_stream(net, master_stream, x"77", true);
      pop_stream(net, slave_stream, data, last);
      check_equal(data, std_logic_vector'(x"77"), result("for pop stream data"));
      check_true(last, result("for pop stream last"));

      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"77"),
          result("for axi_stream_transaction.tdata")
        );
        check_true(axi_stream_transaction.tlast, result("for axi_stream_transaction.tlast"));
      end loop;

    elsif run("test single push and pop with tlast") then
      push_stream(net, master_stream, x"88", true);
      pop_stream(net, slave_stream, data, last);
      check_equal(data, std_logic_vector'(x"88"), result("for pop stream data"));
      check_true(last, result("for pop stream last"));

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
      pop_stream(net, slave_stream, data, last);
      check_equal(data, std_logic_vector'(x"99"), result("for pop stream data"));
      check_true(last, result("for pop stream last"));

      for i in 1 to n_monitors loop
        get_axi_stream_transaction(axi_stream_transaction);
        check_equal(
          axi_stream_transaction.tdata,
          std_logic_vector'(x"99"),
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
    end if;
    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 10 ms);

  axi_stream_master_inst : entity work.axi_stream_master
    generic map(
      master => master_axi_stream)
    port map(
      aclk   => aclk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata,
      tlast  => tlast);

  axi_stream_slave_inst : entity work.axi_stream_slave
    generic map(
      slave => slave_axi_stream)
    port map(
      aclk   => aclk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata,
      tlast  => tlast);

  axi_stream_monitor_inst : entity work.axi_stream_monitor
    generic map(
      monitor => monitor
    )
    port map(
      aclk   => aclk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata,
      tlast  => tlast
    );

  axi_stream_protocol_checker_inst: entity work.axi_stream_protocol_checker
    generic map (
      protocol_checker => protocol_checker)
    port map (
      aclk     => aclk,
      areset_n => areset_n,
      tvalid   => tvalid,
      tready   => tready,
      tdata    => tdata,
      tlast    => tlast);

  aclk <= not aclk after 5 ns;
end architecture;
