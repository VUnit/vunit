-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

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
    id_length   : natural := 4;
    dest_length : natural := 4;
    user_length : natural := 8;
    max_waits   : natural := 16);
end entity;

architecture a of tb_axi_stream_protocol_checker is
  signal aclk     : std_logic := '0';
  signal areset_n : std_logic := '1';
  signal tvalid   : std_logic := '0';
  signal tready   : std_logic := '0';
  signal tdata    : std_logic_vector(data_length - 1 downto 0) := (others => '0');
  signal tlast    : std_logic := '1';
  signal tdest    : std_logic_vector(dest_length - 1 downto 0) := (others => '0');
  signal tid      : std_logic_vector(id_length - 1 downto 0) := (others => '0');
  signal tstrb    : std_logic_vector(data_length/8 - 1 downto 0) := (others => '0');
  signal tkeep    : std_logic_vector(data_length/8 - 1 downto 0) := (others => '0');
  signal tuser    : std_logic_vector(user_length - 1 downto 0) := (others => '0');

  constant logger           : logger_t                      := get_logger("protocol_checker");
  constant protocol_checker : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(
    data_length => tdata'length, id_length => tid'length, dest_length => tdest'length, user_length => tuser'length,
    logger => logger, actor => new_actor("protocol_checker"), max_waits => max_waits, allow_x_in_non_data_bytes => true
  );
  constant meta_values      : std_logic_vector(1 to 5)      := "-XWZU";
  constant valid_values     : std_logic_vector(1 to 4)      := "01LH";

begin

  main : process
    variable rule_logger : logger_t;

    procedure pass_stable_test (signal d : out std_logic_vector) is
      constant zeros : std_logic_vector(d'range) := (others => '0');
      constant ones : std_logic_vector(d'range) := (others => '1');
      constant highs: std_logic_vector(d'range) := (others => 'H');
    begin
      wait until rising_edge(aclk);
      d <= ones;
      tready <= '1';
      wait until rising_edge(aclk);
      d <= zeros;
      wait until rising_edge(aclk);
      d  <= ones;
      tready <= '0';
      wait until rising_edge(aclk);
      d  <= zeros;
      wait until rising_edge(aclk);

      tvalid <= '1';
      d  <= ones;
      wait until rising_edge(aclk);
      d  <= highs;
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tvalid <= '0';
    end;

    procedure fail_stable_test (
      signal d : out std_logic_vector;
      constant rname : string; constant sname : string;
      constant szero : string; constant sone : string;
      constant vzero : std_logic := '0'; constant vone : std_logic := '1'
    ) is
      constant zeros : std_logic_vector(d'range) := (others => vzero);
      constant ones : std_logic_vector(d'range) := (others => vone);
      variable rule_logger : logger_t;
    begin
      rule_logger := get_logger(get_name(logger) & rname);
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      d  <= ones;
      wait until rising_edge(aclk);
      d  <= zeros;
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_only_log(
        rule_logger,
        "Stability check failed for " & sname & " while waiting for tready - Got " & sone & " at 2nd active and enabled clock edge. Expected " & szero & ".",
        error);

      wait until rising_edge(aclk);
      tvalid <= '1';
      wait until rising_edge(aclk);
      d  <= ones;
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_only_log(
        rule_logger,
        "Stability check failed for " & sname & " while waiting for tready - Got " & sone & " at 2nd active and enabled clock edge. Expected " & szero & ".",
        error);

      tvalid <= '1';
      wait until rising_edge(aclk);
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      wait until rising_edge(aclk);
      d  <= zeros;
      tready <= '1';
      wait until rising_edge(aclk);
      tready <= '0';
      tvalid <= '0';
      wait until rising_edge(aclk);

      check_log(
        rule_logger,
        "Stability check passed for " & sname & " while waiting for tready - Got " & sone & " for 2 active and enabled clock edges.",
        pass);
      check_only_log(
        rule_logger,
        "Stability check failed for " & sname & " while waiting for tready - Got " & szero & " at 2nd active and enabled clock edge. Expected " & sone & ".",
        error);

      unmock(rule_logger);
    end;

    procedure pass_unknown_test(
      signal d : out std_logic_vector;
      signal e1, e2 : out std_logic) is
    begin
      wait until rising_edge(aclk);
      e1 <= '0';
      e2 <= '0';
      for i in meta_values'range loop
        d <= (d'range => meta_values(i));
        wait until rising_edge(aclk);
      end loop;
      e1 <= '1';
      e2 <= '1';
      for i in valid_values'range loop
        d <= (d'range => valid_values(i));
        wait until rising_edge(aclk);
      end loop;
    end;

    procedure pass_masked_unknown_test(
      signal d, k, s : out std_logic_vector;
      signal e1, e2 : out std_logic) is
      variable p : integer;
    begin
      wait until rising_edge(aclk);
      e1 <= '1';
      e2 <= '1';

      for i in valid_values'range loop
        for j in 0 to data_length/8*2-1 loop
          for l in meta_values'range loop
            k <= (k'range => '1');
            s <= (s'range => '1');
            if j < data_length/8 then
              k(j) <= '0';
              p := j;
            else
              p := j-data_length/8;
            end if;
            d <= (d'range => valid_values(i));
            s(p) <= '0';
            d(p*8+7 downto p*8) <= (others => meta_values(l));
            wait until rising_edge(aclk);
          end loop;
        end loop;
      end loop;
    end;

    procedure fail_unknown_test(
      signal d: out std_logic_vector;
      signal e1, e2: out std_logic;
      constant rname : string;
      constant sname : string;
      constant e1name : string;
      constant skip_meta_values : boolean_vector(meta_values'range) := (others => false)
    ) is
      variable rule_logger : logger_t;
    begin
      rule_logger := get_logger(get_name(logger) & rname);
      mock(rule_logger);

      -- need to disable these signals first, because there would be a log message for the first clock edge if enabled (happens with areset_n)
      e1 <= '0';
      e2 <= '0';
      wait until rising_edge(aclk);
      e1 <= '1';
      e2 <= '1';
      for i in meta_values'range loop
        next when skip_meta_values(i);
        d <= (d'range => meta_values(i));
        wait until rising_edge(aclk);
        wait for 1 ns;
        check_only_log(
          rule_logger,
          "Not unknown check failed for " & sname & " when " & e1name & " is high - Got " & to_nibble_string(std_logic_vector'(d'range => meta_values(i))) & ".",
          error);
      end loop;

      unmock(rule_logger);
    end;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test passing check of that tdata remains stable when tvalid is asserted and tready is low") then
      pass_stable_test(tdata);

    elsif run("Test failing check of that tdata remains stable when tvalid is asserted and tready is low") then
      fail_stable_test(tdata, ":rule 1", "tdata", "0000_0000 (0)", "1111_1111 (255)");

    elsif run("Test passing check of that tlast remains stable when tvalid is asserted and tready is low") then
      pass_stable_test(d(0) => tlast);

    elsif run("Test failing check of that tlast remains stable when tvalid is asserted and tready is low") then
      fail_stable_test(d(0) => tlast, rname => ":rule 2", sname => "tlast", szero => "1", sone => "0", vzero => '1', vone => '0');

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
      rule_logger := get_logger(get_name(logger) & ":rule 4");
      mock(rule_logger, warning);
      mock(rule_logger, error);

      for iteration in 1 to 2 loop
        wait until rising_edge(aclk);
        tvalid <= '1';
        for i in 1 to max_waits loop
          wait until rising_edge(aclk);
        end loop;
        tready <= '1';
        wait until rising_edge(aclk);
        tvalid <= '0';
        tready <= '0';
      end loop;

      check_no_log;
      unmock(rule_logger);

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
      pass_unknown_test(tdata, tvalid, tready);

    elsif run("Test passing check of that valid tdata bytes must not be unknown when tvalid is high") then
      pass_masked_unknown_test(tdata, tkeep, tstrb, tvalid, tready);

    elsif run("Test failing check of that tdata must not be unknown when tvalid is high") then
      tkeep <= (others => '1');
      tstrb <= (others => '1');
      fail_unknown_test(tdata, tvalid, tready, ":rule 5", "tdata", "tvalid");

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
      wait until rising_edge(aclk);
      wait for 1 ns;
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
      tvalid   <= '0';
      tready <= valid_values(1);
      wait until rising_edge(aclk);
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
      wait until rising_edge(aclk);
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
      entry_gate(runner);

      check_only_log(rule_logger, "Unconditional check failed for packet completion for the following streams: 0.", error);

      unmock(rule_logger);

    elsif run("Test passing check of that tuser must not be unknown unless in reset") then
      pass_unknown_test(tuser, areset_n, areset_n);

    elsif run("Test failing check of that tuser must not be unknown unless in reset") then
      fail_unknown_test(tuser, areset_n, areset_n, ":rule 10", "tuser", "areset_n");

    elsif run("Test passing check of that tuser remains stable when tvalid is asserted and tready is low") then
      pass_stable_test(tuser);

    elsif run("Test failing check of that tuser remains stable when tvalid is asserted and tready is low") then
      fail_stable_test(tuser, ":rule 11", "tuser", "0000_0000 (0)", "1111_1111 (255)");

    elsif run("Test passing check of that tid remains stable when tvalid is asserted and tready is low") then
      pass_stable_test(tid);

    elsif run("Test failing check of that tid remains stable when tvalid is asserted and tready is low") then
      fail_stable_test(tid, ":rule 12", "tid", "0000 (0)", "1111 (15)");

    elsif run("Test passing check of that tdest remains stable when tvalid is asserted and tready is low") then
      pass_stable_test(tdest);

    elsif run("Test failing check of that tdest remains stable when tvalid is asserted and tready is low") then
      fail_stable_test(tdest, ":rule 13", "tdest", "0000 (0)", "1111 (15)");

    elsif run("Test passing check of that tstrb remains stable when tvalid is asserted and tready is low") then
      tkeep <= (others => '1');
      pass_stable_test(tstrb);

    elsif run("Test failing check of that tstrb remains stable when tvalid is asserted and tready is low") then
      tkeep <= (others => '1');
      fail_stable_test(tstrb, ":rule 14", "tstrb", "0", "1");

    elsif run("Test passing check of that tkeep remains stable when tvalid is asserted and tready is low") then
      pass_stable_test(tkeep);

    elsif run("Test failing check of that tkeep remains stable when tvalid is asserted and tready is low") then
      fail_stable_test(tkeep, ":rule 15", "tkeep", "0", "1");

    elsif run("Test passing check of that tid must not be unknown when tvalid is high") then
      pass_unknown_test(tid, tvalid, tready);

    elsif run("Test failing check of that tid must not be unknown when tvalid is high") then
      fail_unknown_test(tid, tvalid, tready, ":rule 16", "tid", "tvalid");

    elsif run("Test passing check of that tdest must not be unknown when tvalid is high") then
      pass_unknown_test(tdest, tvalid, tready);

    elsif run("Test failing check of that tdest must not be unknown when tvalid is high") then
      fail_unknown_test(tdest, tvalid, tready, ":rule 17", "tdest", "tvalid");

    elsif run("Test passing check of that tstrb must not be unknown when tvalid is high") then
      tkeep <= (others => '1');
      pass_unknown_test(tstrb, tvalid, tready);

      -- U is reolved to the value of tkeep and should not fail
      tvalid <= '0';
      tready <= '0';
      wait until rising_edge(aclk);
      tvalid <= '1';
      tready <= '1';
      tstrb <= (others => 'U');
      wait until rising_edge(aclk);
      wait for 1 ns;
      check_no_log;

    elsif run("Test failing check of that tstrb must not be unknown when tvalid is high") then
      tkeep <= (others => '1');
      -- U is reolved to the value of tkeep and should not fail
      fail_unknown_test(tstrb, tvalid, tready, ":rule 18", "tstrb", "tvalid", skip_meta_values => (5 => true, others => false));

    elsif run("Test passing check of that tkeep must not be unknown when tvalid is high") then
      pass_unknown_test(tkeep, tvalid, tready);

    elsif run("Test failing check of that tkeep must not be unknown when tvalid is high") then
      fail_unknown_test(tkeep, tvalid, tready, ":rule 19", "tkeep", "tvalid");

    elsif run("Test passing check of that tstrb must be de-asserted when tkeep is de-asserted") then
      wait until rising_edge(aclk);
      tvalid <= '1';
      tready <= '1';
      for b in tstrb'range loop
        tkeep <= (others => '0');
        tkeep(b) <= '1';
        tstrb <= (others => '0');
        wait until rising_edge(aclk);
        tstrb(b) <= '1';
        wait until rising_edge(aclk);
      end loop;

    elsif run("Test failing check of that tstrb must be de-asserted when tkeep is de-asserted") then
      rule_logger := get_logger(get_name(logger) & ":rule 20");
      mock(rule_logger);

      wait until rising_edge(aclk);
      tvalid <= '1';
      tready <= '1';
      for b in tstrb'range loop
        tkeep <= (others => '1');
        tkeep(b) <= '0';
        tstrb <= (others => '0');
        wait until rising_edge(aclk);
        tstrb(b) <= '1';
        wait until rising_edge(aclk);
        wait for 1 ns;
        check_log(
          rule_logger,
          "True check passed for tstrb de-asserted when tkeep de-asserted",
          pass);
        check_only_log(
          rule_logger,
          "True check failed for tstrb de-asserted when tkeep de-asserted",
          error);
      end loop;

      unmock(rule_logger);

    elsif run("Test failing check of that the sum of tid width and tdest width must be less than 25") then
      rule_logger := get_logger(get_name(logger) & ":rule 21");
      mock(rule_logger);

      wait for 1 ns;
      check_only_log(
          rule_logger,
          "True check failed for tid width and tdest width together must be less than 25",
          error);

      unmock(rule_logger);

    elsif run("Test passing check of that tvalid must be low just after areset_n goes high") then
      areset_n <= '0';
      tvalid   <= '0';
      wait until rising_edge(aclk);
      areset_n <= '1';
      wait until rising_edge(aclk);
      tvalid   <= '1';
      wait until rising_edge(aclk);

    elsif run("Test failing check of that tvalid must be low just after areset_n goes high") then
      rule_logger := get_logger(get_name(logger) & ":rule 22");
      mock(rule_logger);

      areset_n <= '0';
      tvalid   <= '0';
      wait until rising_edge(aclk);
      areset_n <= '1';
      tvalid   <= '1';
      wait until rising_edge(aclk);
      wait for 1 ns;
      check_only_log(
          rule_logger,
          "Implication check failed for tvalid de-asserted after reset release",
          error);

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
      tlast    => tlast,
      tkeep    => tkeep,
      tstrb    => tstrb,
      tid      => tid,
      tdest    => tdest,
      tuser    => tuser
      );

  aclk <= not aclk after 5 ns;
end architecture;
