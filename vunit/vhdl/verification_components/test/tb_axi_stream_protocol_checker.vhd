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
use work.runner_pkg.all;

entity tb_axi_stream_protocol_checker is
  generic(
    runner_cfg  : string;
    data_length : natural := 8;
    max_waits   : natural := 16);
end entity;

architecture a of tb_axi_stream_protocol_checker is
  signal aclk     : std_logic                                  := '0';
  signal areset_n : std_logic                                  := '1';
  signal tvalid   : std_logic                                  := '0';
  signal tready   : std_logic                                  := '0';
  signal tdata    : std_logic_vector(data_length - 1 downto 0) := (others => '0');
  signal tlast    : std_logic                                  := '1';

  constant logger           : logger_t                      := get_logger("protocol_checker");
  constant protocol_checker : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(
    data_length => tdata'length, logger => logger, actor => new_actor("protocol_checker"), max_waits => max_waits
  );
  constant meta_values      : std_logic_vector(1 to 5)      := "-XWZU";
  constant valid_values     : std_logic_vector(1 to 4)      := "01LH";

begin

  main : process
    variable rule_logger : logger_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test passing check of that tdata remains stable when tvalid is asserted and tready is low") then
      wait until rising_edge(aclk);
      tdata  <= (others => '1');
      tready <= '1';
      wait until rising_edge(aclk);
      tdata  <= (others => '0');
      wait until rising_edge(aclk);
      tdata  <= (others => '1');
      tready <= '0';
      wait until rising_edge(aclk);
      tdata  <= (others => '0');
      wait until rising_edge(aclk);

      tvalid <= '1';
      tdata  <= (others => '1');
      wait until rising_edge(aclk);
      tdata  <= (others => 'H');
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tvalid <= '0';
    elsif run("Test failing check of that tdata remains stable when tvalid is asserted and tready is low") then
      rule_logger := get_logger(get_name(logger) & ":rule 1");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      tdata  <= (others => '1');
      wait until rising_edge(aclk);
      tdata  <= (others => '0');
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_only_log(
        rule_logger,
        "Stability check failed for tdata while waiting for tready - Got 1111_1111 (255) " & "at 2nd active and enabled clock edge. Expected 0000_0000 (0).",
        error);

      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      tdata  <= (others => '1');
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_only_log(
        rule_logger,
        "Stability check failed for tdata while waiting for tready - Got 1111_1111 (255) " & "at 2nd active and enabled clock edge. Expected 0000_0000 (0).",
        error);

      tvalid <= '1';
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      wait until rising_edge(aclk);
      tdata  <= (others => '0');
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_log(
        rule_logger,
        "Stability check passed for tdata while waiting for tready - Got 1111_1111 (255) " & "for 2 active and enabled clock edges.",
        pass);
      check_only_log(
        rule_logger,
        "Stability check failed for tdata while waiting for tready - Got 0000_0000 (0) " & "at 2nd active and enabled clock edge. Expected 1111_1111 (255).",
        error);

      unmock(rule_logger);
    elsif run("Test passing check of that tlast remains stable when tvalid is asserted and tready is low") then
      wait until rising_edge(aclk);
      tlast  <= '1';
      tready <= '1';
      wait until rising_edge(aclk);
      tlast  <= '0';
      wait until rising_edge(aclk);
      tlast  <= '1';
      tready <= '0';
      wait until rising_edge(aclk);
      tlast  <= '0';
      wait until rising_edge(aclk);

      tvalid <= '1';
      tlast  <= '1';
      wait until rising_edge(aclk);
      tlast  <= 'H';
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tvalid <= '0';
    elsif run("Test failing check of that tlast remains stable when tvalid is asserted and tready is low") then
      rule_logger := get_logger(get_name(logger) & ":rule 2");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      tlast  <= '0';
      wait until rising_edge(aclk);
      tlast  <= '1';
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_only_log(
        rule_logger,
        "Stability check failed for tlast while waiting for tready - Got 0 " & "at 2nd active and enabled clock edge. Expected 1.",
        error);

      wait until rising_edge(aclk);
      tvalid <= '1';
      tlast  <= '0';
      wait until rising_edge(aclk);
      tlast  <= '1';
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_only_log(
        rule_logger,
        "Stability check failed for tlast while waiting for tready - Got 1 " & "at 2nd active and enabled clock edge. Expected 0.",
        error);

      tvalid <= '1';
      tlast  <= '0';
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      wait until rising_edge(aclk);
      tlast  <= '1';
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_log(
        rule_logger,
        "Stability check passed for tlast while waiting for tready - Got 0 " & "for 2 active and enabled clock edges.",
        pass);
      check_only_log(
        rule_logger,
        "Stability check failed for tlast while waiting for tready - Got 1 " & "at 2nd active and enabled clock edge. Expected 0.",
        error);

      unmock(rule_logger);
    elsif run("Test passing check of that tvalid remains asserted until tready is high") then
      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      tvalid <= 'H';
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tvalid <= '0';
      tready <= '0';
      wait until rising_edge(aclk);

      tvalid <= '1';
      tready <= 'H';
      wait until rising_edge(aclk);
      tvalid <= '0';
      tready <= '0';
    elsif run("Test failing check of that tvalid remains asserted until tready is high") then
      rule_logger := get_logger(get_name(logger) & ":rule 3");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      tvalid <= '0';
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_log(
        rule_logger,
        "Stability check failed for tvalid while waiting for tready - Got 0 " & "at 2nd active and enabled clock edge. Expected 1.",
        error);
      check_only_log(
        rule_logger,
        "Stability check failed for tvalid while waiting for tready - Got 0 " & "at 3rd active and enabled clock edge. Expected 1.",
        error);

      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      tvalid <= 'L';
      tready <= 'H';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_only_log(
        rule_logger,
        "Stability check failed for tvalid while waiting for tready - Got L " & "at 2nd active and enabled clock edge. Expected 1.",
        error);

      unmock(rule_logger);
    elsif run("Test passing check of that tready comes within max_waits after valid") then
      wait until rising_edge(aclk);
      tvalid <= '1';
      for i in 1 to max_waits loop
        wait until rising_edge(aclk);
      end loop;
      tready <= '1';
      wait until rising_edge(aclk);
      tvalid <= '0';
      tready <= '0';
    elsif run("Test failing check of that tready comes within max_waits after valid") then
      rule_logger := get_logger(get_name(logger) & ":rule 4");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= 'H';
      for i in 1 to max_waits + 1 loop
        wait until rising_edge(aclk);
      end loop;
      tready <= 'H';
      wait until rising_edge(aclk);
      tvalid <= '0';
      tready <= '0';

      check_only_log(
        rule_logger,
        "Check failed for performance - tready active " & to_string(max_waits + 1) & " clock cycles after tvalid. Expected <= " & to_string(max_waits) & " clock cycles.",
        warning);

      unmock(rule_logger);
    elsif run("Test passing check of that tdata must not be unknown when tvalid is high") then
      wait until rising_edge(aclk);
      for i in meta_values'range loop
        tdata <= (others => meta_values(i));
        wait until rising_edge(aclk);
      end loop;

      tvalid <= '1';
      tready <= '1';
      for i in valid_values'range loop
        tdata <= (others => valid_values(i));
        wait until rising_edge(aclk);
      end loop;

    elsif run("Test failing check of that tdata must not be unknown when tvalid is high") then
      rule_logger := get_logger(get_name(logger) & ":rule 5");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      tready <= '1';
      for i in meta_values'range loop
        tdata <= (others => meta_values(i));
        wait until rising_edge(aclk);
        wait for 1 ns;
        check_only_log(
          rule_logger,
          "Not unknown check failed for tdata when tvalid is high - Got " & to_nibble_string(std_logic_vector'(tdata'range => meta_values(i))) & ".",
          error);
      end loop;

      unmock(rule_logger);
    elsif run("Test passing check of that tlast must not be unknown when tvalid is high") then
      wait until rising_edge(aclk);
      for i in meta_values'range loop
        tlast <= meta_values(i);
        wait until rising_edge(aclk);
      end loop;

      tvalid <= '1';
      tready <= '1';
      for i in valid_values'range loop
        tlast <= valid_values(i);
        wait until rising_edge(aclk);
      end loop;

    elsif run("Test failing check of that tlast must not be unknown when tvalid is high") then
      rule_logger := get_logger(get_name(logger) & ":rule 6");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      tready <= '1';
      for i in meta_values'range loop
        tlast <= meta_values(i);
        wait until rising_edge(aclk);
        wait for 1 ns;
        check_only_log(
          rule_logger,
          "Not unknown check failed for tlast when tvalid is high - Got " & to_string(meta_values(i)) & ".",
          error);
      end loop;

      unmock(rule_logger);

    elsif run("Test passing check of that tvalid must not be unknown unless in reset") then
      wait until rising_edge(aclk);
      areset_n <= '0';
      tready   <= '1';
      for i in meta_values'range loop
        tvalid <= meta_values(i);
        wait until rising_edge(aclk);
      end loop;
      areset_n <= '1';
      tready   <= '1';
      for i in valid_values'range loop
        tvalid <= valid_values(i);
        wait until rising_edge(aclk);
      end loop;

    elsif run("Test failing check of that tvalid must not be unknown unless in reset") then
      rule_logger := get_logger(get_name(logger) & ":rule 7");
      mock(rule_logger);

      for i in meta_values'range loop
        tvalid <= meta_values(i);
        wait until rising_edge(aclk);
        wait for 1 ns;
        check_only_log(
          rule_logger,
          "Not unknown check failed for tvalid when not in reset - Got " & to_string(meta_values(i)) & ".",
          error);
      end loop;

      unmock(rule_logger);

    elsif run("Test passing check of that tready must not be unknown unless in reset") then
      wait until rising_edge(aclk);
      areset_n <= '0';
      tvalid   <= '1';
      for i in meta_values'range loop
        tready <= meta_values(i);
        wait until rising_edge(aclk);
      end loop;
      areset_n <= '1';
      tvalid   <= '1';
      for i in valid_values'range loop
        tready <= valid_values(i);
        wait until rising_edge(aclk);
      end loop;

    elsif run("Test failing check of that tready must not be unknown unless in reset") then
      rule_logger := get_logger(get_name(logger) & ":rule 8");
      mock(rule_logger);

      for i in meta_values'range loop
        tready <= meta_values(i);
        wait until rising_edge(aclk);
        wait for 1 ns;
        check_only_log(
          rule_logger,
          "Not unknown check failed for tready when not in reset - Got " & to_string(meta_values(i)) & ".",
          error);
      end loop;

      unmock(rule_logger);

    elsif run("Test passing check of that all packets are complete when the simulation ends") then
      wait until rising_edge(aclk);
      tvalid <= '1';
      tlast  <= '0';
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tvalid <= '0';
      wait until rising_edge(aclk);
      tvalid <= '1';
      tlast  <= '1';
      tready <= '1';
      wait until rising_edge(aclk);

    elsif run("Test failing check of that all packets are complete when the simulation ends") then
      rule_logger := get_logger(get_name(logger) & ":rule 9");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      tlast  <= '0';
      tready <= '1';
      wait until rising_edge(aclk);
      tlast  <= '0';
      wait until rising_edge(aclk);

      set_phase(runner_state, test_runner_cleanup);
      notify(runner);
      entry_gate(runner);

      check_only_log(rule_logger, "Check failed for packet completion.", error);

      unmock(rule_logger);

    end if;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 ms);

  axi_stream_protocol_checker_inst : entity work.axi_stream_protocol_checker
    generic map(
      protocol_checker => protocol_checker
    )
    port map(
      aclk     => aclk,
      areset_n => areset_n,
      tvalid   => tvalid,
      tready   => tready,
      tdata    => tdata,
      tlast    => tlast
    );

  aclk <= not aclk after 5 ns;
end architecture;
