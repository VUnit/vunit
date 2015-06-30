-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;

entity logging_example is
end entity logging_example;

architecture test of logging_example is
  shared variable temperature_logger : logger_t;
  signal enable_sensor_clusters : boolean := false;
  procedure core_dump(
    line_num : natural := 0;
    file_name : string := "") is
  begin
    debug(temperature_logger, "Sensor core dump", line_num => line_num, file_name => file_name);
    debug(temperature_logger, "Internal state = sensor_error", line_num => line_num, file_name => file_name);
    debug(temperature_logger, "Error register = 0x0010", line_num => line_num, file_name => file_name);
  end procedure core_dump;
begin
  sensor_cluster1: process is
  begin
    wait until enable_sensor_clusters;
    info("Sensor 1 = x", sensor_cluster1'path_name & "sensor1");
    info("Sensor 2 = y", sensor_cluster1'path_name & "sensor2");
    wait;
  end process sensor_cluster1;

  sensor_cluster2: process is
  begin
    wait until enable_sensor_clusters;
    info("Sensor 3 = v", sensor_cluster2'path_name & "sensor3");
    info("Sensor 4 = w", sensor_cluster2'path_name & "sensor4");
    wait;
  end process sensor_cluster2;

  example_process: process is
    alias status is info_low2[string, string, natural, string];
    variable display_filter1, display_filter2 : log_filter_t;
  begin  -- process example_process
    log ("This is the most basic type of log call. Just a write to stdout.");

    log("Debug type of logs can be given with different levels of detail.");
    info("Highest level of debug message (least details) is an info message.");
    debug("Debug messages are on the middle level.");
    verbose("Verbose debug messages contain the most details (lowest level).");
    info("The output for different levels contains nothing special to indicate that level. This can be changed...");
    info("All log calls are made to a logger. There is one default logger which we used so far but custom loggers can also be created as is shown later.");
    info("All loggers have two output handlers. One for display output and one for file output.");
    info("Each handler has an associated formatter that decides the output format. So far we've used the raw formatter that output messages as given in the log call. We can change that to the level formatter which will display the log level");
    logger_init(display_format => level);
    info("The level (info) shown.");
    info("There are also levels for indicating the severity of error type of log messages.");
    failure("Error with highest level of severity. Application is likely to crash. This will stop your simulation. Hopefully your simulator allows you to continue to single-step through the example.");
    error("Error but it may be possible to continue running.");
    warning("Least severe type of error. The application can handle this.");
    info("The six basic levels are also interleaved with a number of other levels. The names of these has the following format to indicate their relative severity/detail (x is one of the previously defined levels)" & LF &
         "  - x_high2" & LF &
         "  - x_high1" & LF &
         "  - x" & LF &
         "  - x_low1" & LF &
         "  - x_low2");
    info("These levels can be used to create additional custom levels. For example, if a status level is needed in between info and debug one can rename the info_low2 level to ""status"" and create an status alias for that procedure call.");
    rename_level(info_low2, "status");
    status("Here is the new status message.");

    info("The previous failure message stopped the simulation because the stop level is set to failure. This can be changed to some other level.");
    logger_init(display_format => level, stop_level => failure_high1);
    failure("This failure should not stop the simulation.");

    info("Log calls can be given a source ID to better indicate where it comes from. To see this information we need another formatter, e.g. the verbose formatter.");
    logger_init(display_format => verbose);
    warning("Over-temperature (73 degrees C)!", "Temperature sensor");
    info("Source ID can also be given as an hierarchical reference into the structure of the design by setting it to a path.", example_process'path_name & "some_source");
    logger_init(display_format => level);
    info("Verbose outputs contain the simulator time, the level, the source ID if specified, file and line if compiled with the VUnit location preprocessor and the message.");
    info("A default source ID is often given to a custom logger used for a specific purpose.");
    logger_init(temperature_logger, default_src => example_process'path_name & "temperature_sensor", display_format => verbose);
    warning(temperature_logger, "Over-temperature (73 degrees C)!");
    debug(temperature_logger, "Normal temperature (52 degrees C).");
    info("Custom subprograms can also be located (see how it's done in compile.py)");
    core_dump;

    info("Logs can also be made to file which has its own formatter.");
    logger_init(temperature_logger, default_src => example_process'path_name & "temperature_sensor", display_format => level, file_name => "temp_log.csv", file_format => verbose_csv);
    info(temperature_logger, "This will end up as log entries with different formats on the display and in temp_log.csv. The CSV format makes the file suitable for analysis in a spreadsheet tool.");

    info("Filters (more than one) can be attached to handlers to control what logs that are passed to the output. An exampel is to reduce he amount of information on the screen while keeping everything in the file.");
    stop_level(temperature_logger, (verbose, debug), display_handler, display_filter1);
    warning(temperature_logger, "Over-temperature (73 degrees C)!");
    debug(temperature_logger, "Normal temperature (52 degrees C).");
    info("At this point you should see one temperature entry on the display but two in the temp_log.csv file");
    info("It's also possible to filter on source ID");
    pass_source("passed source", display_handler, display_filter2);
    info("This is a message that should be stopped", "stopped source");
    info("This second message should pass", "passed source");
    info("Filters can be removed", "passed source");
    remove_filter(display_filter2);
    info("Now any call to the default logger will pass");

    info("It's also possible to filter a complete hierarchy");
    stop_source(sensor_cluster1'path_name, display_handler, display_filter2);
    logger_init(display_format => verbose, file_format => verbose_csv, file_name => "default_log.csv");
    enable_sensor_clusters <= true;
    wait for 1 ns;
    logger_init(display_format => level);
    info("Only logs from sensor_cluster2 should be displayed");

    wait;
  end process example_process;

end architecture test;
