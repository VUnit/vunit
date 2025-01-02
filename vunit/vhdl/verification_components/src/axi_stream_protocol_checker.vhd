-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use std.textio.all;

use work.axi_stream_pkg.all;
use work.check_pkg.all;
use work.checker_pkg.all;
use work.event_common_pkg.is_active;
use work.integer_array_pkg.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.run_pkg.all;
use work.run_types_pkg.all;

entity axi_stream_protocol_checker is
  generic (
    protocol_checker : axi_stream_protocol_checker_t);
  port (
    aclk     : in std_logic;
    areset_n : in std_logic := '1';
    tvalid   : in std_logic;
    tready   : in std_logic := '1';
    tdata    : in std_logic_vector(data_length(protocol_checker) - 1 downto 0);
    tlast    : in std_logic                                                    := '1';
    tkeep    : in std_logic_vector(data_length(protocol_checker)/8-1 downto 0) := (others => '1');
    tstrb    : in std_logic_vector(data_length(protocol_checker)/8-1 downto 0) := (others => 'U');
    tid      : in std_logic_vector(id_length(protocol_checker)-1 downto 0)     := (others => '0');
    tdest    : in std_logic_vector(dest_length(protocol_checker)-1 downto 0)   := (others => '0');
    tuser    : in std_logic_vector(user_length(protocol_checker)-1 downto 0)   := (others => '0')
    );
end entity;

architecture a of axi_stream_protocol_checker is
  constant rule1_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 1");
  constant rule2_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 2");
  constant rule3_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 3");
  constant rule4_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 4");
  constant rule5_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 5");
  constant rule6_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 6");
  constant rule7_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 7");
  constant rule8_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 8");
  constant rule9_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 9");
  constant rule10_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 10");
  constant rule11_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 11");
  constant rule12_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 12");
  constant rule13_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 13");
  constant rule14_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 14");
  constant rule15_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 15");
  constant rule16_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 16");
  constant rule17_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 17");
  constant rule18_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 18");
  constant rule19_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 19");
  constant rule20_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 20");
  constant rule21_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 21");
  constant rule22_checker : checker_t := new_checker(get_name(protocol_checker.p_logger) & ":rule 22");

  signal handshake_is_not_x : std_logic;
  signal enable_rule1_check : std_logic;
  signal enable_rule2_check : std_logic;
  signal enable_rule11_check : std_logic;
  signal enable_rule12_check : std_logic;
  signal enable_rule13_check : std_logic;
  signal enable_rule14_check : std_logic;
  signal enable_rule15_check : std_logic;
  signal rule20_check_value : std_logic;

  signal areset_n_d  : std_logic := '0';
  signal areset_rose : std_logic;
  signal not_tvalid  : std_logic;

  signal tdata_normalized : std_logic_vector(tdata'range);
  signal tstrb_resolved : std_logic_vector(tstrb'range);

  function normalize_tdata(data, strb, keep : std_logic_vector) return std_logic_vector is
    variable ret : std_logic_vector(data'range);
  begin
    ret := data;
    for i in keep'range loop
      if keep(i) = '0' or strb(i) = '0' then
        ret(i*8+7 downto i*8) := (others => '0');
      end if;
    end loop;
    return ret;
  end function;
begin
  tstrb_resolved <= tkeep when is_u(tstrb) else tstrb;
  handshake_is_not_x <= '1' when not is_x(tvalid) and not is_x(tready) else '0';

  -- AXI4STREAM_ERRM_TDATA_STABLE TDATA remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule1_check <= '1' when (handshake_is_not_x = '1') and not is_x(tdata) else '0';
  check_stable(
    rule1_checker, aclk, enable_rule1_check, tvalid, tready, tdata,
    result("for tdata while waiting for tready"));

  -- AXI4STREAM_ERRM_TLAST_STABLE TLAST remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule2_check <= '1' when (handshake_is_not_x = '1') and not is_x(tlast) else '0';
  check_stable(
    rule2_checker, aclk, enable_rule2_check, tvalid, tready, tlast,
    result("for tlast while waiting for tready"));

  -- AXI4STREAM_ERRM_TVALID_STABLE When TVALID is asserted, then it must remain
  -- asserted until TREADY is HIGH
  check_stable(
    rule3_checker, aclk, handshake_is_not_x, tvalid, tready, tvalid,
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
    check(rule4_checker,
          n_clock_cycles <= protocol_checker.p_max_waits,
          result("for performance - tready active " & to_string(n_clock_cycles) &
          " clock cycles after tvalid. Expected <= " & to_string(protocol_checker.p_max_waits) & " clock cycles."),
          level => warning);
    n_clock_cycles := 0;
  end process;

  -- AXI4STREAM_ERRM_TDATA_X A value of X on TDATA is not permitted when TVALID
  -- is HIGH
  tdata_normalized <= normalize_tdata(tdata, tstrb_resolved, tkeep) when protocol_checker.p_allow_x_in_non_data_bytes else tdata;
  check_not_unknown(rule5_checker, aclk, tvalid, tdata_normalized, result("for tdata when tvalid is high"));

  -- AXI4STREAM_ERRM_TLAST_X A value of X on TLAST is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule6_checker, aclk, tvalid, tlast, result("for tlast when tvalid is high"));

  -- AXI4STREAM_ERRM_TVALID_X A value of X on TVALID is not permitted when not
  -- in reset
  check_not_unknown(rule7_checker, aclk, areset_n, tvalid, result("for tvalid when not in reset"));

  -- AXI4STREAM_ERRS_TREADY_X A value of X on TREADY is not permitted when not
  -- in reset
  check_not_unknown(rule8_checker, aclk, areset_n, tready, result("for tready when not in reset"));

  -- AXI4STREAM_ERRM_STREAM_ALL_DONE_EOS At the end of simulation, all streams have had
  -- their corresponding TLAST transfer
  check_complete_packets : block is
    constant active_streams : integer_array_t := new_1d(length => 2 ** tid'length);
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
      wait until is_active(runner_phase) and is_within_gates_of(test_runner_cleanup);

      if tid'length = 0 then
        check(rule9_checker, get(active_streams, 0) = 0, result("for packet completion."));
      else
        for i in 0 to 2 * tid'length - 1 loop
          if get(active_streams, i) /= 0 then
            if incomplete_streams = null then
              write(incomplete_streams, to_string(i));
            else
              write(incomplete_streams, ", " & to_string(i));
            end if;
          end if;
        end loop;

        if incomplete_streams /= null then
          check_failed(rule9_checker, result("for packet completion for the following streams: " &
            incomplete_streams.all & "."));
        else
          check_passed(rule9_checker, result("for packet completion."));
        end if;
      end if;

      wait;
    end process;
  end block;

  -- AXI4STREAM_ERRM_TUSER_X A value of X on TUSER is not permitted when not in reset
  -- is HIGH
  check_not_unknown(rule10_checker, aclk, areset_n, tuser, result("for tuser when areset_n is high"));

  -- AXI4STREAM_ERRM_TUSER_STABLE TUSER payload signals must remain constant while TVALID is asserted,
  -- and TREADY is de-asserted
  enable_rule11_check <= '1' when (handshake_is_not_x = '1') and not is_x(tuser) else '0';
  check_stable(
    rule11_checker, aclk, enable_rule11_check, tvalid, tready, tuser,
    result("for tuser while waiting for tready"));

  -- AXI4STREAM_ERRM_TID_STABLE TID remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule12_check <= '1' when (handshake_is_not_x = '1') and not is_x(tid) else '0';
  check_stable(
    rule12_checker, aclk, enable_rule12_check, tvalid, tready, tid,
    result("for tid while waiting for tready"));

  -- AXI4STREAM_ERRM_TDEST_STABLE TDEST remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule13_check <= '1' when (handshake_is_not_x = '1') and not is_x(tdest) else '0';
  check_stable(
    rule13_checker, aclk, enable_rule13_check, tvalid, tready, tdest,
    result("for tdest while waiting for tready"));

  -- AXI4STREAM_ERRM_TSTRB_STABLE TSTRB remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule14_check <= '1' when (handshake_is_not_x = '1') and not is_x(tstrb_resolved) else '0';
  check_stable(
    rule14_checker, aclk, enable_rule14_check, tvalid, tready, tstrb_resolved,
    result("for tstrb while waiting for tready"));

  -- AXI4STREAM_ERRM_TKEEP_STABLE TKEEP remains stable when TVALID is asserted,
  -- and TREADY is LOW
  enable_rule15_check <= '1' when (handshake_is_not_x = '1') and not is_x(tkeep) else '0';
  check_stable(
    rule15_checker, aclk, enable_rule15_check, tvalid, tready, tkeep,
    result("for tkeep while waiting for tready"));

  -- AXI4STREAM_ERRM_TID_X A value of X on TID is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule16_checker, aclk, tvalid, tid, result("for tid when tvalid is high"));

  -- AXI4STREAM_ERRM_TDEST_X A value of X on TDEST is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule17_checker, aclk, tvalid, tdest, result("for tdest when tvalid is high"));

  -- AXI4STREAM_ERRM_TSTRB_X A value of X on TSTRB is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule18_checker, aclk, tvalid, tstrb_resolved, result("for tstrb when tvalid is high"));

  -- AXI4STREAM_ERRM_TKEEP_X A value of X on TKEEP is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule19_checker, aclk, tvalid, tkeep, result("for tkeep when tvalid is high"));

  -- AXI4STREAM_ERRM_TKEEP_TSTRB If TKEEP is de-asserted, then TSTRB must also be de-asserted
  -- eschmidscs: Binding this to tvalid. ARM does not include that, but makes more sense this way?
  rule20_check_value <= not(or(((not tkeep) and tstrb_resolved)));
  check_true(rule20_checker, aclk, tvalid, rule20_check_value, result("for tstrb de-asserted when tkeep de-asserted"));

  -- AXI4STREAM_AUXM_TID_TDTEST_WIDTH  The value of ID_WIDTH + DEST_WIDTH must not exceed 24
  -- eschmidscs: Must wait a short while to allow testing of the rule.
  process
  begin
    wait for 1 ps;
    check_true(rule21_checker, tid'length + tdest'length <= 24, result("for tid width and tdest width together must be less than 25"));
    wait;
  end process;

  -- AXI4STREAM_ERRM_TVALID_RESET TVALID is LOW for the first cycle after ARESETn goes HIGH
  process (aclk) is
  begin
    if rising_edge(aclk) then
      areset_n_d <= areset_n;
    end if;
  end process;
  areset_rose <= areset_n and not areset_n_d;
  not_tvalid   <= not tvalid;
  check_implication(rule22_checker, aclk, areset_n, areset_rose, not_tvalid, result("for tvalid de-asserted after reset release"));

  -- for * being DATA, KEEP, STRB, ID, DEST or USER
  -- AXI4STREAM_ERRM_T*_TIEOFF T* must be stable while *_WIDTH has been set to zero
  -- cannot be checked, vector has negative range
end architecture;
