--
--  File Name:         AlertLog_Demo_Global.vhd
--  Design Unit Name:  AlertLog_Demo_Global
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
--    Demo showing use of the global counter in AlertLogPkg
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
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.log_types_pkg.all;
-- Cannot include entire log_pkg since
-- its log would interfere with
-- log in OSVVM
use vunit_lib.log_pkg.info;
use vunit_lib.log_pkg.debug;
use vunit_lib.log_pkg.info_high1;
use vunit_lib.log_pkg.info_high2;
use vunit_lib.log_pkg.logger_init;
use vunit_lib.log_pkg.stop_level;
use vunit_lib.log_pkg.remove_filter;
use vunit_lib.log_pkg.rename_level;
use vunit_lib.check_pkg.all;
use vunit_lib.path.all;

library osvvm;
use osvvm.OsvvmGlobalPkg.all;
use osvvm.TranscriptPkg.all;
use osvvm.AlertLogPkg.all;

use work.common_pkg.all;

--use work.TextUtilPkg.all ;

entity tb_AlertLog_Demo_Global_With_Comments is
  generic (
    runner_cfg : string := runner_cfg_default);
end tb_AlertLog_Demo_Global_With_Comments;
architecture hierarchy of tb_AlertLog_Demo_Global_With_Comments is
  signal Clk : std_logic := '0';

  -- VUnit:
  -- Creating some custom log levels from the provided "no-name"
  -- levels.
  alias final is info_high1[string, string, natural, string];
  alias clock is info_high2[string, string, natural, string];

begin

  Clk <= not Clk after 10 ns;


  -- /////////////////////////////////////////////////////////////
  -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
  Testbench_1 : block
  begin

    TbP0 : process
      variable ClkNum : integer := 0;
    begin
      wait until Clk = '1';
      ClkNum := ClkNum + 1;
      print(LF & "Clock Number " & to_string(ClkNum));

      -- VUnit:
      -- The basic log call in Vunit is log(msg) but that collides with the log
      -- call in OSVVM. info(msg) is the same thing and that can be
      -- used instead. However, info will be used for other purposes in this example
      -- so I'm renaming one of the "no-name" levels and use that instead.
      rename_level(info_high2, "clock");
      clock(LF & "VUnit: Clock Number " & to_string(ClkNum));
    end process TbP0;

    ------------------------------------------------------------
    TbP1 : process
      variable filter1, filter2 : log_filter_t;
    begin
      test_runner_setup(runner, runner_cfg);
      checker_init(stop_level => failure, display_format => verbose, file_name => join(output_path(runner_cfg), "error.csv"));

      -- VUnit:
      -- Logging in VUnit use separate handlers for display (OUTPUT) and file.
      -- These can indually be set to be off or on with various text formatting.
      -- A log file is opened and closed with every log entry made so there is
      -- no need to explicitly open and close it. The default logger in VUnit
      -- (you can have any number of loggers with different settings) can be
      -- configured like this. The verbose format means that some extra information
      -- like simulation time is logged with every entry
      logger_init(display_format => verbose, file_format => verbose, file_name => join(output_path(runner_cfg), "Vunit_Demo_Global.txt"));

      -- Uncomment this line to use a log file rather than OUTPUT
      -- TranscriptOpen("./Demo_Global.txt") ;

      -- VUnit:
      -- VUnit doesn't have a "final" log level as OSVVM so it will be created
      rename_level(info_high1, "final");

      -- VUnit:
      -- VUnit supports that you stop on all errors, don't stop on errors, or
      -- stop on errors with a certain level of severity. Stopping after a
      -- number of errors has not been identified as an important feature since it's
      -- hard to set a good number. Whether or not it is useful to continue
      -- after 3 errors depends entirely on type of errors you have.

      -- SetAlertStopCount(error, 0);

      -- VUnit:
      -- Every logger has a default name, called the source, which is visible when a verbose format
      -- is used. The default name can be overridden when a log call is made
      logger_init(default_src => "AlertLog_Demo_Global", display_format => verbose, file_format => verbose, file_name => join(output_path(runner_cfg), "Vunit_Demo_Global.txt"));

      SetAlertLogName("AlertLog_Demo_Global");
      wait for 0 ns;              -- make sure all processes have elaborated

      -- VUnit:
      -- All VUnit logs are enabled by default unless the display/file_format
      -- has been set to off. Disabling info level that is still disabled in
      -- the OSVVM code at this point.
      stop_level(info, display_handler, filter1);

      SetLogEnable(DEBUG, true);  -- Enable DEBUG Messages for all levels of the hierarchy

      -- VUnit:
      -- Loggers can be configured to use a number of formats. None of those
      -- are justified. However, verbose_csv will create a CSV log which will
      -- be justified when opened in a spreadsheet tool. Custom formats are
      -- also fairly easy to add since all formatting functions are located in a
      -- separate file (log_formatting.vhd)

      -- Uncomment this line to justify alert and log reports
      -- SetAlertLogJustify ;

      while test_suite loop
        if run("Test failing alerts") then
          for i in 1 to 5 loop
            wait until Clk = '1';
            if i = 4 then
              -- VUnit:
              -- You can add a stop filter for one or several log levels independently on the
              -- display and file handlers. The typical use case is to remove
              -- all detals from the output and keep everything on file. If and
              -- when you hit an error you open the file and look into the details
              stop_level(debug, display_handler, filter2);

              SetLogEnable(DEBUG, false);
            end if;  -- DEBUG Mode OFF
            wait for 1 ns;

            -- VUnit:
            -- The generic log call kan take the level as an input but there
            -- are also convenience procedures for all levels
            check_failed("Tb.P1.E alert " & to_string(i) & " of 5");
            debug("Tb.P1.D log   " & to_string(i) & " of 5");

            Alert("Tb.P1.E alert " & to_string(i) & " of 5");  -- ERROR by default
            Log ("Tb.P1.D log   " & to_string(i) & " of 5", DEBUG);
          end loop;
          wait until Clk = '1';
          wait until Clk = '1';
          wait for 1 ns;

          -- VUnit:
          -- VUnit separates error statistics (get_checker_stat) from the presentation of the same
          -- to enable user to better control output formats. The statistics
          -- type returned from get_checker_stat has a defined to_string
          -- function so you can do info(to_string(get_checker_stat)) but you
          -- can also write your own to_string function. The contents of the
          -- returned statistics can be manipulated before presentation but
          -- hiding errors is dangerous and should be avoided. If you want to
          -- remove all errors from a test case it's also easier to insert a
          -- next statement in that if branch to skip to the next test case.

          -- Report Alerts with expected errors expressed as a negative ExternalErrors value
          ReportAlerts(Name => "AlertLog_Demo_Hierarchy with expected errors", ExternalErrors => -(failure => 0, error => 20, warning => 15));
        elsif run("Test passing alerts") then
          -- Vunit:
          -- check_false is the same thing as AlertIf
          check_false(false, "This should not fail");

          AlertIf(false, "This should not fail");
        end if;
      end loop;

      -- VUnit:
      -- The report is normally not printed. From a unit testing point of view it's
      -- more important to know what test cases that failed/passed (functions
      -- that work or don't) than how many failing/passing checks there were. However,
      -- the number of checks can be a quality metric. If you have 10
      -- passing test cases but only one check you're not testing sufficiently.
      final(to_string(get_checker_stat));

      ReportAlerts;
      TranscriptClose;

      test_runner_cleanup(runner, get_alert_statistics);
      wait;
    end process TbP1;

    ------------------------------------------------------------
    TbP2 : process
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 2 ns;
        -- VUnit equivalents
        check_failed("Tb.P2.E alert " & to_string(i) & " of 5");
        info("Tb.P2.I log   " & to_string(i) & " of 5");

        Alert("Tb.P2.E alert " & to_string(i) & " of 5", error);
        -- example of a log that is not enabled, so it does not print
        Log ("Tb.P2.I log   " & to_string(i) & " of 5", INFO);
      end loop;
      wait until Clk = '1';
      wait for 2 ns;
      -- Uncomment this line to and the simulation will stop here
      -- Alert("Tb.P2.F Message 1 of 1", FAILURE) ;
      wait;
    end process TbP2;

    ------------------------------------------------------------
    TbP3 : process
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 3 ns;

        -- VUnit equivalent
        check_failed("Tb.P3.W alert " & to_string(i) & " of 5", level => warning);

        Alert("Tb.P3.W alert " & to_string(i) & " of 5", warning);
      end loop;
      wait;
    end process TbP3;
  end block Testbench_1;


  -- /////////////////////////////////////////////////////////////
  -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
  Cpu_1 : block
  begin

    ------------------------------------------------------------
    CpuP1 : process
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 5 ns;
        -- VUnit equivalents
        check_failed("Cpu.P1.E Message " & to_string(i) & " of 5");
        debug("Cpu.P1.D log   " & to_string(i) & " of 5");
        final("Cpu.P1.F log   " & to_string(i) & " of 5");

        Alert("Cpu.P1.E Message " & to_string(i) & " of 5", error);
        Log ("Cpu.P1.D log   " & to_string(i) & " of 5", DEBUG);
        Log ("Cpu.P1.F log   " & to_string(i) & " of 5", osvvm.AlertLogPkg.FINAL);  -- enabled by Uart_1
      end loop;
      wait;
    end process CpuP1;

    ------------------------------------------------------------
    CpuP2 : process
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 6 ns;
        -- VUnit equivalents
        check_failed("Cpu.P2.W Message " & to_string(i) & " of 5", level => warning);
        info("Cpu.P2.I log   " & to_string(i) & " of 5");

        Alert("Cpu.P2.W Message " & to_string(i) & " of 5", warning);
        Log ("Cpu.P2.I log   " & to_string(i) & " of 5", INFO);
      end loop;
      wait;
    end process CpuP2;
  end block Cpu_1;


  -- /////////////////////////////////////////////////////////////
  -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
  Uart_1 : block
  begin
    -- VUnit:
    -- All VUnit logs are enabled by default unless the display/file_format
    -- has been set to off.

    -- Enable FINAL logs for every level
    -- Note it is expected that most control of alerts will occur only in the testbench block
    -- Note that this also turns on FINAL messages for CPU - see hierarchy for better control
    SetLogEnable(osvvm.AlertLogPkg.FINAL, true);          -- Runs once at initialization time

    ------------------------------------------------------------
    UartP1 : process
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 10 ns;
        -- VUnit equivalents
        check_failed("Uart.P1.E alert " & to_string(i) & " of 5");
        debug("UART.P1.D log   " & to_string(i) & " of 5");

        Alert("Uart.P1.E alert " & to_string(i) & " of 5");  -- ERROR by default
        Log ("UART.P1.D log   " & to_string(i) & " of 5", DEBUG);
      end loop;
      wait;
    end process UartP1;

    ------------------------------------------------------------
    UartP2 : process
    begin
      for i in 1 to 5 loop
        wait until Clk = '1';
        wait for 11 ns;
        -- VUnit equivalents
        check_failed("Uart.P2.W alert " & to_string(i) & " of 5", level => warning);
        info("UART.P2.I log   " & to_string(i) & " of 5");
        final("UART.P2.F log   " & to_string(i) & " of 5");

        Alert("Uart.P2.W alert " & to_string(i) & " of 5", warning);
        -- Info not enabled
        Log ("UART.P2.I log   " & to_string(i) & " of 5", INFO);
        Log ("UART.P2.F log   " & to_string(i) & " of 5", osvvm.AlertLogPkg.FINAL);
      end loop;
      wait;
    end process UartP2;
  end block Uart_1;

end hierarchy;
