-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use std.textio.all;

context work.vunit_context;
context work.com_context;
use work.sync_pkg.all;
use work.vc_pkg.all;
use work.axi_stream_pkg.all;

entity axi_stream_protocol_checker is
  generic(
    protocol_checker : axi_stream_protocol_checker_t);
  port(
    aclk     : in std_logic;
    areset_n : in std_logic                                                        := '1';
    tvalid   : in std_logic;
    tready   : in std_logic                                                        := '1';
    tdata    : in std_logic_vector(data_length(protocol_checker) - 1 downto 0);
    tlast    : in std_logic                                                        := '1';
    tkeep    : in std_logic_vector(data_length(protocol_checker) / 8 - 1 downto 0) := (others => '0');
    tstrb    : in std_logic_vector(data_length(protocol_checker) / 8 - 1 downto 0) := (others => '0');
    tid      : in std_logic_vector(id_length(protocol_checker) - 1 downto 0)       := (others => '0');
    tdest    : in std_logic_vector(dest_length(protocol_checker) - 1 downto 0)     := (others => '0');
    tuser    : in std_logic_vector(user_length(protocol_checker) - 1 downto 0)     := (others => '0')
  );
end entity;

architecture a of axi_stream_protocol_checker is
  type checker_vec_t is array (positive range <>) of checker_t;

  impure function create_checkers(n_rules : positive) return checker_vec_t is
    variable checkers : checker_vec_t(1 to n_rules);
  begin
    for rule in 1 to n_rules loop
      checkers(rule) := new_checker(get_name(get_logger(protocol_checker.p_std_cfg)) & ":rule " & to_string(rule));
    end loop;

    return checkers;
  end;

  constant n_rules       : positive      := 23;
  constant rule_checkers : checker_vec_t := create_checkers(n_rules);

  constant active_streams : integer_array_t := new_1d(length => 2 ** tid'length);

  signal handshake_is_not_x  : std_logic;
  signal enable_rule1_check  : std_logic;
  signal enable_rule2_check  : std_logic;
  signal enable_rule11_check : std_logic;
  signal enable_rule12_check : std_logic;
  signal enable_rule13_check : std_logic;
  signal enable_rule14_check : std_logic;
  signal enable_rule15_check : std_logic;
  signal rule20_check_value  : std_logic;

  signal areset_n_d                  : std_logic := '1';
  signal areset                      : std_logic;
  signal areset_rose                 : std_logic;
  signal tvalid_low, tvalid_not_high : std_logic;
begin

  main : process
    variable request_msg : msg_t;
    variable msg_type    : msg_type_t;

    procedure wait_until_all_streams_have_completed is
      variable found_active_streams : boolean;
    begin
      loop
        found_active_streams := false;
        for i in 0 to length(active_streams) - 1 loop
          found_active_streams := get(active_streams, i) /= 0;
          exit when found_active_streams;
        end loop;

        if not found_active_streams then
          return;
        end if;

        wait until rising_edge(aclk);
      end loop;
    end;
  begin
    receive(net, get_actor(protocol_checker.p_std_cfg), request_msg);
    msg_type := message_type(request_msg);

    handle_wait_for_time(net, msg_type, request_msg);

    if msg_type = wait_until_idle_msg then
      wait_until_all_streams_have_completed;
      handle_wait_until_idle(net, msg_type, request_msg);
    else
      unexpected_msg_type(msg_type, protocol_checker.p_std_cfg);
    end if;
  end process;

  handshake_is_not_x <= '1' when not is_x(tvalid) and not is_x(tready) else '0';

  -- AXI4STREAM_ERRM_TDATA_STABLE TDATA remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule1_check <= '1' when (handshake_is_not_x = '1') and not is_x(tdata) else '0';
  check_stable(
    rule_checkers(1), aclk, enable_rule1_check, tvalid, tready, tdata,
    result("for tdata while waiting for tready"));

  -- AXI4STREAM_ERRM_TLAST_STABLE TLAST remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule2_check <= '1' when (handshake_is_not_x = '1') and not is_x(tlast) else '0';
  check_stable(
    rule_checkers(2), aclk, enable_rule2_check, tvalid, tready, tlast,
    result("for tlast while waiting for tready"));

  -- AXI4STREAM_ERRM_TVALID_STABLE When TVALID is asserted, then it must remain
  -- asserted until TREADY is HIGH
  check_stable(
    rule_checkers(3), aclk, handshake_is_not_x, tvalid, tready, tvalid,
    result("for tvalid while waiting for tready"));

  -- AXI4STREAM_RECS_TREADY_MAX_WAIT Recommended that TREADY is asserted within
  -- MAXWAITS cycles of TVALID being asserted
  process
    variable n_clock_cycles : natural;
  begin
    wait until rising_edge(aclk) and (to_x01(tvalid) = '1');
    while not tready loop
      wait until rising_edge(aclk);
      n_clock_cycles := n_clock_cycles + 1;
    end loop;
    check(rule_checkers(4),
          n_clock_cycles <= protocol_checker.p_max_waits,
          result("for performance - tready active " & to_string(n_clock_cycles) & " clock cycles after tvalid. Expected <= " & to_string(protocol_checker.p_max_waits) & " clock cycles."),
          level => warning);
    n_clock_cycles := 0;
  end process;

  -- AXI4STREAM_ERRM_TDATA_X A value of X on TDATA is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule_checkers(5), aclk, tvalid, tdata, result("for tdata when tvalid is high"));

  -- AXI4STREAM_ERRM_TLAST_X A value of X on TLAST is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule_checkers(6), aclk, tvalid, tlast, result("for tlast when tvalid is high"));

  -- AXI4STREAM_ERRM_TVALID_X A value of X on TVALID is not permitted when not
  -- in reset
  check_not_unknown(rule_checkers(7), aclk, areset_n, tvalid, result("for tvalid when not in reset"));

  -- AXI4STREAM_ERRS_TREADY_X A value of X on TREADY is not permitted when not
  -- in reset
  check_not_unknown(rule_checkers(8), aclk, areset_n, tready, result("for tready when not in reset"));

  -- AXI4STREAM_ERRM_STREAM_ALL_DONE_EOS At the end of simulation, all streams have had
  -- their corresponding TLAST transfer
  check_complete_packets : block is
  begin
    assert tid'length <= 8 report "tid must not be more than 8 bits (maximum recommendation)" severity failure;

    track_streams : process
      variable value : natural;
    begin
      wait until rising_edge(aclk) and (to_x01(tvalid) = '1');
      if tid'length = 0 then
        value := 1 when to_x01(tlast) = '0' else 0;
        set(active_streams, 0, value);
      elsif not is_x(tid) then
        value := 1 when to_x01(tlast) = '0' else 0;
        set(active_streams, to_integer(tid), value);
      end if;
    end process;

    check_that_streams_have_ended : process
      variable incomplete_streams : line;
    begin
      lock_entry(runner, test_runner_cleanup);
      wait_until(runner, test_runner_cleanup);

      if tid'length = 0 then
        check(rule_checkers(9), get(active_streams, 0) = 0, result("for packet completion."));
      else
        for i in 0 to 2 ** tid'length - 1 loop
          if get(active_streams, i) /= 0 then
            if incomplete_streams = null then
              write(incomplete_streams, to_string(i));
            else
              write(incomplete_streams, ", " & to_string(i));
            end if;
          end if;
        end loop;

        if incomplete_streams /= null then
          check_failed(rule_checkers(9), result("for packet completion for the following streams: " & incomplete_streams.all & "."));
        else
          check_passed(rule_checkers(9), result("for packet completion."));
        end if;
      end if;

      unlock_entry(runner, test_runner_cleanup);
      wait;
    end process;
  end block;

  -- AXI4STREAM_ERRM_TUSER_X A value of X on TUSER is not permitted when not in reset
  -- is HIGH
  check_not_unknown(rule_checkers(10), aclk, areset_n, tuser, result("for tuser when areset_n is high"));

  -- AXI4STREAM_ERRM_TUSER_STABLE TUSER payload signals must remain constant while TVALID is asserted,
  -- and TREADY is de-asserted
  enable_rule11_check <= '1' when (handshake_is_not_x = '1') and not is_x(tuser) else '0';
  check_stable(
    rule_checkers(11), aclk, enable_rule11_check, tvalid, tready, tuser,
    result("for tuser while waiting for tready"));

  -- AXI4STREAM_ERRM_TID_STABLE TID remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule12_check <= '1' when (handshake_is_not_x = '1') and not is_x(tid) else '0';
  check_stable(
    rule_checkers(12), aclk, enable_rule12_check, tvalid, tready, tid,
    result("for tid while waiting for tready"));

  -- AXI4STREAM_ERRM_TDEST_STABLE TDEST remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule13_check <= '1' when (handshake_is_not_x = '1') and not is_x(tdest) else '0';
  check_stable(
    rule_checkers(13), aclk, enable_rule13_check, tvalid, tready, tdest,
    result("for tdest while waiting for tready"));

  -- AXI4STREAM_ERRM_TSTRB_STABLE TSTRB remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule14_check <= '1' when (handshake_is_not_x = '1') and not is_x(tstrb) else '0';
  check_stable(
    rule_checkers(14), aclk, enable_rule14_check, tvalid, tready, tstrb,
    result("for tstrb while waiting for tready"));

  -- AXI4STREAM_ERRM_TKEEP_STABLE TKEEP remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule15_check <= '1' when (handshake_is_not_x = '1') and not is_x(tkeep) else '0';
  check_stable(
    rule_checkers(15), aclk, enable_rule15_check, tvalid, tready, tkeep,
    result("for tkeep while waiting for tready"));

  -- AXI4STREAM_ERRM_TID_X A value of X on TID is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule_checkers(16), aclk, tvalid, tid, result("for tid when tvalid is high"));

  -- AXI4STREAM_ERRM_TDEST_X A value of X on TDEST is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule_checkers(17), aclk, tvalid, tdest, result("for tdest when tvalid is high"));

  -- AXI4STREAM_ERRM_TSTRB_X A value of X on TSTRB is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule_checkers(18), aclk, tvalid, tstrb, result("for tstrb when tvalid is high"));

  -- AXI4STREAM_ERRM_TKEEP_X A value of X on TKEEP is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule_checkers(19), aclk, tvalid, tkeep, result("for tkeep when tvalid is high"));

  -- AXI4STREAM_ERRM_TKEEP_TSTRB If TKEEP is de-asserted, then TSTRB must also be de-asserted
  -- eschmidscs: Binding this to tvalid. ARM does not include that, but makes more sense this way?
  rule20_check_value <= not (or(((not tkeep) and tstrb)));
  check_true(rule_checkers(20), aclk, tvalid, rule20_check_value, result("for tstrb de-asserted when tkeep de-asserted"));

  -- AXI4STREAM_AUXM_TID_TDTEST_WIDTH  The value of ID_WIDTH + DEST_WIDTH must not exceed 24
  -- eschmidscs: Must wait a short while to allow testing of the rule.
  process
  begin
    wait for 1 ps;
    check_true(rule_checkers(21), tid'length + tdest'length <= 24, result("for tid width and tdest width together must be less than 25"));
    wait;
  end process;

  -- AXI4STREAM_ERRM_TVALID_RESET TVALID is LOW for the first cycle after ARESETn goes HIGH
  process(aclk) is
  begin
    if rising_edge(aclk) then
      areset_n_d <= areset_n;
    end if;
  end process;
  areset_rose <= to_x01(areset_n and not areset_n_d);
  tvalid_low  <= not tvalid;
  check_implication(rule_checkers(22), aclk, areset_n, areset_rose, tvalid_low, result("for tvalid de-asserted after reset release"));

  -- Check that tvalid stops being asserted asynchronously when areset_n is asserted
  areset          <= not areset_n;
  tvalid_not_high <= '1' when to_x01(tvalid) /= '1' else '0';
  check_implication(rule_checkers(23), aclk, areset, areset, tvalid_not_high, result("for tvalid de-asserted asynchronously when areset_n is asserted"));

  -- for * being DATA, KEEP, STRB, ID, DEST or USER
  -- AXI4STREAM_ERRM_T*_TIEOFF T* must be stable while *_WIDTH has been set to zero
  -- cannot be checked, vector has negative range
end architecture;
