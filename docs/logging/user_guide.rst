.. _logging_library:

Logging Library
===============

Introduction
------------

The VUnit log package (``log``) is used internally by VUnit for various
logging purposes but it can also be used standalone for general purpose
logging. It provides many of the features that you find in SW logging
frameworks. For example

-  Logging of simple text messages
-  Standard and user defined log levels to filter messages
-  Custom hierarchical grouping to filter messages
-  Configurable formatting of message output
-  Automatic file and line number tagging of output messages
-  File and stdout output channels with independent formatting and
   filtering settings
-  Support for multiple logs with their own output files and their own
   settings
-  Logging of non-string objects

Architecture
------------

To understand ``log`` it's important to understand its architecture.
Whenever you do a log entry that entry is handled by a logger. There is
a default logger that is used when none is specified but you can also
create multiple custom loggers. For example

.. code-block:: vhdl

    log("Hello world");

will use the default logger while

.. code-block:: vhdl

    log(my_logger, "Hello world");

will use the custom ``my_logger``.

Each logger has two output handlers, one for handling display (stdout)
output and one for handling file output. Every log entry you do is
passed to both these handlers. For each handler there is one formatter
and zero or more filters. The formatter is used to control the format of
the output while the filters control if a log entry is passed to the
output or not.

Basic Log
---------

The most basic log you can do is a simple text message using the default
logger.

.. code-block:: vhdl

    log("Hello world");

The default settings of the default logger is such that this will be
output on stdout (no file output) just as you wrote it (raw formatter).

Log Level
---------

Every log entry you make has a log level which is ``info`` for the log
call procedure unless you specify anything using the ``log_level``
parameter. There are also dedicated procedure calls for each log level.
The standard log levels and their associated procedure calls are

.. code-block:: vhdl

    failure("Highest level of *error* message (most severe).");
    error("Normal severity error message.");
    warning("Error message with lowest severity.");
    info("Highest level of *debug* message (least details) is an info message.");
    debug("Debug messages are on the middle level.");
    verbose("Verbose debug messages contain the most details (lowest level).");

The six standard levels are also interleaved with a number of other
levels. The names of these has the following format to indicate their
relative severity/detail (x is one of the standard levels)

-  x\_high2 (e.g. debug\_high2)
-  x\_high1
-  x
-  x\_low1
-  x\_low2

These extra levels can be used to create additional custom levels. For
example, if a status level is needed in between info and debug you can
rename the info\_low2 level to *status* and then create a status alias
for the info\_low2 procedure call.

.. code-block:: vhdl

    alias status is info_low2[string, string, natural, string];
    ...
    rename_level(info_low2, "status");
    status("Here is the new status message.");

Stop Level
----------

By default the simulation will stop if the log level is ``failure`` or
more severe. This can be changed to any of the other levels by changing
the stop level configuration.

.. code-block:: vhdl

    logger_init(stop_level => error);

Formatters
----------

With the default raw formatter you won't see the log level in the output
message produced. To do that you have to change the formatter to
something else. Here I'm changing the formatter for the default logger
display handler

.. code-block:: vhdl

    logger_init(display_format => level);
    info("Hello world");

which will result in the following output.

.. code-block:: console

    INFO: Hello world

There is also a ``verbose`` formatter which adds more details to the
output.

.. code-block:: console

    1000 ps: INFO: Hello World

The verbose output will always contain the simulator time, the log
level, and the message. More information about log is shown if
available, see the grouping and location chapters.

There is also a ``verbose_csv`` formatter, typically used for file
output, that provides the same information comma-separated. The default
separator is a comma but you can change that with the ``separator``
parameter of ``logger_init``. The CSV format enables you to use the
power of your spreadsheet tool to handle (large) log files.

Finally, there's a formatter called ``off`` and it's used to prevent all
output from a handler.

File Name
---------

The path to the file targeted with the file handler is also controlled
with ``logger_init``. Typically you would have something like this.

.. code-block:: vhdl

    logger_init(display_format => verbose, file_format => verbose_csv, file_name = "path/to/my/logs/my_log.csv");

The default file name is ``log.csv`` in the current directory and the
default file format is ``off``. By default an existing file will be
replaced when calling ``logger_init`` but you can change that by setting
the input parameter ``append`` true.

Grouping
--------

Log calls can be given a source ID such that it can be associated to a
group of logs like logs coming from the same module or logs of a
specific type.

.. code-block:: vhdl

    warning("Over-temperature (73 degrees C)!", "Temperature sensor");

results in something like this with the ``verbose`` formatter.

.. code-block:: console

    1000 ps: WARNING in Temperature sensor: Over-temperature (73 degrees C)!

It's also possible to give a logger a default source ID with the
``logger_init`` call.

.. code-block:: vhdl

    logger_init(default_src => "Test runner");

Log Location
------------

You can have the file name and the line number of a log entry if the
testbench is compiled with the location preprocessor provided with
VUnit. It's enabled like this in your VUnit run script

.. code-block:: python

    ui = VUnit.from_argv()
    ui.enable_location_preprocessing()

and will change the output to something like this.

.. code-block:: console

    1000 ps: WARNING in Temperature sensor (logging_example.vhd:79): Over-temperature (73 degrees C)!

If you've placed your log call(s) in a convenience procedure you most
likely want the location of the calls to that procedure to be in the
output and not the location of the log call in the definition of the
convenience procedure. You can do that by adding the ``line_num`` and
``file_name`` parameters to the **end** of the parameter list for that
convenience procedure

.. code-block:: vhdl

    procedure my_convenience_procedure(
      <my parameters>
      line_num : natural := 0;
      file_name : string := "") is
    begin
      <some code>
      info("Some message", line_num => line_num, file_name => file_name);
      <some code>
    end procedure my_convenience_procedure;

and then let the location preprocessor know about the added procedure

.. code-block:: python

    ui = VUnit.from_argv()
    ui.enable_location_preprocessing(additional_subprograms=['my_convenience_procedure'])

Filters
-------

One or more filters can be attached to the display and file handlers to
control what logs that are passed to the output. Filters are either pass
filters that pass logs of the specified type or stop filters which pass
anything but the specified type. The type to pass or stop is based on
either the log level or the log source ID

Log Level Filters
~~~~~~~~~~~~~~~~~

The two procedures below show how you can create pass and stop filters
on one or more log levels.

.. code-block:: vhdl

    stop_level((debug, verbose), display_handler, my_display_filter);
    pass_level(error, file_handler, my_file_filter);

The last procedure parameter is of type ``log_filter_t`` and returns the
created filter which is used as reference if you want to remove the
filter.

.. code-block:: vhdl

    remove_filter(my_display_filter);

You can also apply the same filter to both handlers.

.. code-block:: vhdl

    stop_level((debug, verbose), (display_handler, file_handler), my_filter);

Log Source Filters
~~~~~~~~~~~~~~~~~~

Pass and stop filters that act on the log source can also be created.
For example

.. code-block:: vhdl

    stop_source("UART receiver", display_handler, uart_rx_stop_filter);
    pass_source("status message", file_handler, status_msg_pass_filter);

It's also possible to filter hierarchies of sources. If the sources of a
number of logs have the same prefix and the prefix starts with a point
or a colon then you can create a filter that apply to all of them. The
typical use case is something like this.

.. code-block:: vhdl

    info("Some message", my_module'path_name & "monitor1");
    info("Another message", my_module'path_name & "monitor2");

The following filter will stop both of them.

.. code-block:: vhdl

    stop_source(my_module'path_name, display_handler, my_module_stop_filter);

Combined Log Level and Log Source Filters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Log level(s) and log source can be combined in a single filter. For
example, this filter will stop debug logs from the UART source.

.. code-block:: vhdl

    stop_source_level("UART", debug, display_handler, stop_uart_debug_msg_filter);

Logging Non-String Objects
--------------------------

Any type of data object can be logged as long as you can express it as a
string. For example, you can log an integer by using the associated
``to_string`` function. The VUnit ``com`` package also has functionality
for generating ``to_string`` functions for your custom data types which
makes them easy to log as well. For more information see the ``com``
:doc:`user guide <../com/user_guide>`.

Custom Loggers
--------------

Previous chapters have used the built-in default logger for the examples
but you can also create your own loggers. You do that by declaring a
(shared) variable of type ``logger_t``.

.. code-block:: vhdl

    shared variable my_logger : logger_t;

and then you use that variable as the first parameter in the procedure
calls presented in the previous chapters, for example.

.. code-block:: vhdl

    log(my_logger, "Hello world");
