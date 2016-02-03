--
--  File Name:         AlertLog_Demo_Hierarchy.vhd
--  Design Unit Name:  AlertLog_Demo_Hierarchy
--  Revision:          STANDARD VERSION,  2015.01
--
--  Copyright (c) 2015 by SynthWorks Design Inc.  All rights reserved.
--
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      email:  jim@synthworks.com
--
--  Description:
--    Demo showing use of hierarchy in AlertLogPkg
--    Both TB and CPU use sublevels of hierarchy
--    UART does not use sublevels of hierarchy
--    Usage of block statements emulates a separate entity/architecture
--
--  Developed for:
--              SynthWorks Design Inc.
--              Training Courses
--              11898 SW 128th Ave.
--              Tigard, Or  97223
--              http://www.SynthWorks.com
--
--
--  Revision History:
--    Date      Version    Description
--    01/2015   2015.01    Refining tests
--
--
--  Copyright (c) 2015 by SynthWorks Design Inc.  All rights reserved.
--
--  Verbatim copies of this source file may be used and
--  distributed without restriction.
--
--  This source file is free software; you can redistribute it
--  and/or modify it under the terms of the ARTISTIC License
--  as published by The Perl Foundation; either version 2.0 of
--  the License, or (at your option) any later version.
--
--  This source is distributed in the hope that it will be
--  useful, but WITHOUT ANY WARRANTY; without even the implied
--  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
--  PURPOSE. See the Artistic License for details.
--
--  You should have received a copy of the license with this source.
--  If not download it from,
--     http://www.perlfoundation.org/artistic_license_2_0
--

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use ieee.std_logic_textio.all;

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.OsvvmGlobalPkg.all;
use osvvm.TranscriptPkg.all;
use osvvm.AlertLogPkg.all;

use work.common_pkg.all;

-- use work.TextUtilPkg.all ;

entity tb_AlertLog_Demo_Hierarchy_With_Comments is
  generic (
    runner_cfg : string := runner_cfg_default);
end tb_AlertLog_Demo_Hierarchy_With_Comments;

architecture hierarchy of tb_AlertLog_Demo_Hierarchy_With_Comments is
  signal Clk : std_logic := '0';
  alias final is info_high1[string, string, natural, string];
  alias clock is info_high2[string, string, natural, string];
  shared variable tb_checker, cpu_checker, uart_checker : checker_t;

begin

  Clk <= not Clk after 10 ns;


  -- /////////////////////////////////////////////////////////////
  -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
  Testbench_1 : block
    constant TB_AlertLogID : AlertLogIDType := GetAlertLogID("Testbench_1");
  begin

    TbP0 : process
      variable ClkNum : integer := 0;
    begin
      wait until Clk = '1';
      rename_level(info_high2, "clock");
      clock(LF & "VUnit: Clock Number " & to_string(ClkNum));

      ClkNum := ClkNum + 1;
      print(LF & "Clock Number " & to_string(ClkNum));
    end process TbP0;

    ------------------------------------------------------------
    TbP1 : process
      constant TB_P1_ID : AlertLogIDType := GetAlertLogID("TB P1", TB_AlertLogID);
      variable TempID   : AlertLogIDType;
      variable cpu_debug_filter, global_debug_filter, tb_final_filter, cpu_final_filter,
               tb_info_filter, uart_info_filter : log_filter_t;
    begin
      test_runner_setup(runner, runner_cfg);
      -- VUnit:
      -- You have have custom checkers with individual names. Names starting
      -- with "." indicates a hierarchical name where every level of the
      -- hierarchy is separated with a "."
      checker_init(tb_checker, display_format => verbose, default_src => ".tb", file_name => join(output_path(runner_cfg), "error.csv"));

      -- Uncomment this line to use a log file rather than OUTPUT
      -- TranscriptOpen("./Demo_Hierarchy.txt") ;

      -- SetAlertStopCount(error, 0);

      SetAlertLogName("AlertLog_Demo_Hierarchy");
      wait for 0 ns;              -- make sure all processes have elaborated

      -- VUnit:
      -- All log levels are
      -- on by default so here I'm disabling the levels needed to get the same
      -- behaviour as the OSVVM example
      logger_init(display_format => verbose, file_name => join(output_path(runner_cfg), "log.csv"));
      stop_source_level(".cpu", debug, display_handler, cpu_debug_filter);
      stop_source_level(".tb", info, display_handler, tb_info_filter);
      stop_source_level(".uart", info, display_handler, uart_info_filter);
      rename_level(info_high1, "final");
      stop_source_level(".tb", info_high1, display_handler, tb_final_filter);
      stop_source_level(".cpu", info_high1, display_handler, cpu_final_filter);


      SetLogEnable(DEBUG, true);  -- Enable DEBUG Messages for all levels of the hierarchy
      TempID := GetAlertLogID("CPU_1");    -- Get The CPU AlertLogID
      SetLogEnable(TempID, DEBUG, false);  -- turn off DEBUG messages in CPU
      SetLogEnable(TempID, INFO, true);    -- turn on INFO messages in CPU

      -- Uncomment this line to justify alert and log reports
      -- SetAlertLogJustify ;

      while test_suite loop
        if run("Test failing alerts") then
          for i in 1 to 5 loop
            wait until Clk = '1';
            if i = 4 then
              stop_level(debug, display_handler, global_debug_filter);
              SetLogEnable(DEBUG, false);
            end if;  -- DEBUG Mode OFF
            wait for 1 ns;
            check_failed(tb_checker, "Tb.P1.E alert " & to_string(i) & " of 5");
            -- With a log you can set the name, indicating the hierarchy on a
            -- log call basis
            debug("Tb.P1.D log   " & to_string(i) & " of 5", ".tb.p1");

            -- Checks
            Alert(TB_P1_ID, "Tb.P1.E alert " & to_string(i) & " of 5");  -- ERROR by default
            Log (TB_P1_ID, "Tb.P1.D log   " & to_string(i) & " of 5", DEBUG);
          end loop;
          wait until Clk = '1';
          wait until Clk = '1';
          wait for 1 ns;
          -- Report Alerts with expected errors expressed as a negative ExternalErrors value
          ReportAlerts(Name => "AlertLog_Demo_Hierarchy with expected errors", ExternalErrors => -(failure => 0, error => 20, warning => 15));
        elsif run("Test passing alerts") then
          check_false(tb_checker, false, "This should not fail");
          AlertIf(false, "This should not fail");
        end if;
      end loop;

      -- Report Alerts without expected errors
      ReportAlerts;
      TranscriptClose;

      test_runner_cleanup(runner, get_alert_statistics);
      wait;
    end process TbP1;

    ------------------------------------------------------------
    TbP2 : process
      constant TB_P2_ID : AlertLogIDType := GetAlertLogID("TB P2", TB_AlertLogID);
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 2 ns;
        check_failed(tb_checker, "Tb.P2.E alert " & to_string(i) & " of 5");
        info("Tb.P2.I log   " & to_string(i) & " of 5", ".tb.p2");

        Alert(TB_P2_ID, "Tb.P2.E alert " & to_string(i) & " of 5", error);
        -- example of a log that is not enabled, so it does not print
        Log (TB_P2_ID, "Tb.P2.I log   " & to_string(i) & " of 5", INFO);
      end loop;
      wait until Clk = '1';
      wait for 2 ns;
      -- Uncomment this line to and the simulation will stop here
      -- check_failed("Tb.P2.F Message 1 of 1", level => failure);
      -- Alert(TB_P2_ID, "Tb.P2.F Message 1 of 1", FAILURE) ;
      wait;
    end process TbP2;

    ------------------------------------------------------------
    TbP3 : process
      constant TB_P3_ID : AlertLogIDType := GetAlertLogID("TB P3", TB_AlertLogID);
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 3 ns;
        check_failed(tb_checker, "Tb.P3.W alert " & to_string(i) & " of 5", level => warning);
        Alert(TB_P3_ID, "Tb.P3.W alert " & to_string(i) & " of 5", warning);
      end loop;
      wait;
    end process TbP3;
  end block Testbench_1;


  -- /////////////////////////////////////////////////////////////
  -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
  Cpu_1 : block
    constant CPU_AlertLogID : AlertLogIDType := GetAlertLogID("CPU_1");
  begin

    ------------------------------------------------------------
    CpuP1 : process
      constant CPU_P1_ID : AlertLogIDType := GetAlertLogID("CPU P1", CPU_AlertLogID);
    begin
      checker_init(cpu_checker, display_format => verbose, default_src => ".cpu", file_name => join(output_path(runner_cfg), "error.csv"));
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 5 ns;
        check_failed(cpu_checker, "Cpu.P1.E Message " & to_string(i) & " of 5");
        debug("Cpu.P1.D log   " & to_string(i) & " of 5", ".cpu.p1");
        final("Cpu.P1.F log   " & to_string(i) & " of 5", ".cpu.p1");

        Alert(CPU_P1_ID, "Cpu.P1.E Message " & to_string(i) & " of 5", error);
        Log (CPU_P1_ID, "Cpu.P1.D log   " & to_string(i) & " of 5", DEBUG);
        Log (CPU_P1_ID, "Cpu.P1.F log   " & to_string(i) & " of 5", osvvm.AlertLogPkg.FINAL);  -- disabled
      end loop;
      wait;
    end process CpuP1;

    ------------------------------------------------------------
    CpuP2 : process
      constant CPU_P2_ID : AlertLogIDType := GetAlertLogID("CPU P2", CPU_AlertLogID);
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 6 ns;
        check_failed(cpu_checker, "Cpu.P2.W Message " & to_string(i) & " of 5", level => warning);
        info("Cpu.P2.I log   " & to_string(i) & " of 5", ".cpu.p2");

        Alert(CPU_P2_ID, "Cpu.P2.W Message " & to_string(i) & " of 5", warning);
        Log (CPU_P2_ID, "Cpu.P2.I log   " & to_string(i) & " of 5", INFO);
      end loop;
      wait;
    end process CpuP2;
  end block Cpu_1;


  -- /////////////////////////////////////////////////////////////
  -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
  Uart_1 : block
    constant UART_AlertLogID : AlertLogIDType := GetAlertLogID("UART_1");
  begin
    -- Enable FINAL logs for every level
    -- Note it is expected that most control of alerts will occur only in the testbench block
    -- Note that this does not turn on FINAL messages for CPU - see global for settings that impact CPU
    SetLogEnable(UART_AlertLogID, osvvm.AlertLogPkg.FINAL, true);  -- Runs once at initialization time

    ------------------------------------------------------------
    UartP1 : process
    begin
      checker_init(uart_checker, display_format => verbose, default_src => ".uart", file_name => join(output_path(runner_cfg), "error.csv"));
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 10 ns;
        check_failed(uart_checker, "Uart.P1.E alert " & to_string(i) & " of 5");
        debug("UART.P1.D log   " & to_string(i) & " of 5", ".uart.p1");

        Alert(UART_AlertLogID, "Uart.P1.E alert " & to_string(i) & " of 5");  -- ERROR by default
        Log (UART_AlertLogID, "UART.P1.D log   " & to_string(i) & " of 5", DEBUG);
      end loop;
      wait;
    end process UartP1;

    ------------------------------------------------------------
    UartP2 : process
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 11 ns;
        check_failed(uart_checker, "Uart.P2.W alert " & to_string(i) & " of 5", level => warning);
        info("UART.P2.I log   " & to_string(i) & " of 5", ".uart.p2");
        final("UART.P2.F log   " & to_string(i) & " of 5", ".uart.p2");

        Alert(UART_AlertLogID, "Uart.P2.W alert " & to_string(i) & " of 5", warning);
        -- Info not enabled
        Log (UART_AlertLogID, "UART.P2.I log   " & to_string(i) & " of 5", INFO);
        Log (UART_AlertLogID, "UART.P2.F log   " & to_string(i) & " of 5", osvvm.AlertLogPkg.FINAL);
      end loop;
      wait;
    end process UartP2;
  end block Uart_1;

end hierarchy;
