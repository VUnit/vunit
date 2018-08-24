-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use std.textio.all;

context work.vunit_context;
context work.com_context;
use work.axi_stream_pkg.all;

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
    tkeep    : in std_logic_vector(data_length(protocol_checker)/8-1 downto 0) := (others => '0');
    tstrb    : in std_logic_vector(data_length(protocol_checker)/8-1 downto 0) := (others => '0');
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

  signal enable_rule1_check, enable_rule2_check, handshake_is_not_x : std_logic;
  signal enable_rule11_check : std_logic;
begin
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
  end process;

  -- AXI4STREAM_ERRM_TDATA_X A value of X on TDATA is not permitted when TVALID
  -- is HIGH
  check_not_unknown(rule5_checker, aclk, tvalid, tdata, result("for tdata when tvalid is high"));

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
      lock_entry(runner, test_runner_cleanup);
      wait_until(runner, test_runner_cleanup);

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

      unlock_entry(runner, test_runner_cleanup);
      wait;
    end process;
  end block;

  -- AXI4STREAM_ERRM_TUSER_X A value of X on TUSER is not permitted when not in reset
  -- is HIGH
  check_not_unknown(rule10_checker, aclk, areset_n, tdata, result("for tuser when areset_n is high"));

  -- AXI4STREAM_ERRM_TUSER_STABLE TUSER payload signals must remain constant while TVALID is asserted,
  -- and TREADY is de-asserted
  enable_rule11_check <= '1' when (handshake_is_not_x = '1') and not is_x(tuser) else '0';
  check_stable(
    rule11_checker, aclk, enable_rule11_check, tvalid, tready, tuser,
    result("for tuser while waiting for tready"));

  -- AXI4STREAM_ERRM_TUSER_TIEOFF TUSER must be stable while USER_WIDTH has been set to zero
  -- cannot be checked, vector has negative range
end architecture;
