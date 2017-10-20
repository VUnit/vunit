.. _logging_library:

Logging Library
===============

Introduction
------------

The VUnit logging library is used internally by VUnit for various
logging purposes but it can also be used standalone for general purpose
logging. It provides many of the features that you find in SW logging
frameworks. For example

-  Logging of simple text messages with different pre-defined log levels
-  Can create hierarchical loggers which can be individually configured
-  Can be mocked to be able to unit-test failures from verification libraries
-  Configurable formatting of message output
-  Automatic file and line number tagging of output messages
-  File and stdout output channels with independent formatting and
   filtering settings

Architecture
------------

A log entry is made to a logger. You can think of a logger as a named
channel. There is a default logger that is used when none is specified
but you can also create multiple custom loggers. For example

.. code-block:: vhdl

    info("Hello world");

will use the default logger while

.. code-block:: vhdl

    info(my_logger, "Hello world");

will use the custom ``my_logger``.

Log messages are then handled by a log handler. By default there are
two output handlers, one for handling display (stdout) output and one
for handling output to a file. Every log entry you do is passed to
both these handlers. Each handler may have a different output format
and log level setting. The format is used to control they layout and
amount of information being displayed. The log level is used to filter
log messages. Individual loggers can also be filered.

Log Level
---------

Every log entry you make has a log level which is defined by dedicated
procedure calls for each log level. The standard log levels and their
associated procedure calls are:

.. code-block:: vhdl

    -- Visible to display by default
    failure("Most severe error that by default causes simulation error");
    error("Error message that by default casues simulation error.");
    warning("A warning.");

    -- Visible to file by default
    info("Informative message for very useful public information");
    debug("Debug message for seldom useful or internal information");

    -- Not visible by default
    verbose("Verbose messages only used for tracing program flow");

Every log level is associated with a numeric value. failure = 90, error = 75,
warning = 60, info = 45, debug = 30, and verbose = 15. Other values between
0 and 99 are free for custom defined levels. For example

.. code-block:: vhdl

    license_info := new_log_level("license", 50, fg => red, bg => yellow, style => bright);

The numeric value can also be defined relative to other levels

.. code-block:: vhdl

    license_info := new_log_level("license", info + 5, fg => red, bg => yellow, style => bright);


The last optional parameters define the foreground, background and style of the output color.
Valid values are defined in ansi_pkg.

To make a log entry with the custom level use any of the `log` procedures:

.. code-block:: vhdl

    log("Mozilla Public License, v. 2.0.", license_info);
    log(my_logger, "Mozilla Public License, v. 2.0.", license_info);


Stop Level
----------

By default the simulation will stop if the log level is ``failure`` or
more severe. This can be changed to any of the other levels by changing
the stop level configuration.

.. code-block:: vhdl

    -- Set stop level for all loggers
    set_stop_level(error);

    -- Set stop level for specific logger and all children
    set_stop_level(get_logger("my_library:my_component"), warning)


Formatting
----------
The default display format is ``verbose`` and the default file format
is ``csv`` to enable simple log file parsing. The format can be
changed to any of ``raw``, ``level``, ``verbose`` and ``csv``.

.. code-block:: vhdl

    set_format(display_handler, level);
    info("Hello world");

which will result in the following output.

.. code-block:: console

    INFO: Hello world

There default ``verbose`` format which adds more details to the
output looks like this:

.. code-block:: console

         1000 ps - default -    INFO - Hello world

The verbose output will always contain the simulator time, the log
level, the logger, and the message.

The ``raw`` formatter just emits the log message and nothing else. The
``csv`` formatter emits all information in the log entry as a comma
separated list for convenient parsing. By the default the VUnit test
runner configures the file handler to create a ``csv`` formatted
``log.csv`` file in the test case output path.

Print Procedure
---------------

``print`` is a procedure that unconditionally outputs its message to stdout or file without any formatting.

.. code-block:: vhdl

    print("Message to stdout");
    print("Append this message to an existing file or create a new file if it doesn't exist", "path/to/file");
    print("Create new file with this message", "path/to/file", write_mode);

It's also possible to print to an open file object.

.. code-block:: vhdl

    print("Message to file object", my_file_object);

This procedure can be used to optimize performance by printing many messages before flushing or closing the file.


Logging hierarchy
-----------------

Custom hierarchical loggers can be created to provide more information and control of what is being logged.

.. code-block:: vhdl

    constant temp_logger : logger_t := get_logger("temperature_sensor");
    warning(temp_logger, "Over-temperature (73 degrees C)!");

results in something like this with the ``verbose`` formatter.

.. code-block:: console

    1000 ps - temperature_sensor -    INFO - Over-temperature (73 degrees C)!


Log filtering
-------------

Log filtering is controlled by applying filters to a logger or to a group of
loggers. A log must pass all filters to be propagated to the handler output.
Display and file handlers are configured individually.

You can set the log level to create a filter that will block all logs below that log level
or you can create a filter that will block an arbitrary set of log levels or you can combine
the two filters.

.. code-block:: vhdl

    -- Disable all logging to the display.
    disable_all(display_handler);

    -- Set the log level to block display handler logs below debug from all loggers within system0
    set_log_level(get_logger("system0"), display_handler, debug);

    -- Also block display handler warnings and debug messages from all loggers within system0
    set_block_filter(get_logger("system0"), display_handler, (warning, debug));

    -- Enable all logging from the uart module in system0
    enable_all(get_logger("system0:uart"), display_handler);


Custom Loggers
--------------

Previous chapters have used the built-in default logger for the
examples but you can also create your own loggers. You do that by
declaring a constant of type ``logger_t``.

.. code-block:: vhdl

    constant my_logger : logger_t := get_logger("system0:uart0");

and then you use that variable as the first parameter in the procedure
calls presented in the previous chapters, for example.

.. code-block:: vhdl

    info(my_logger, "Hello world");

Logger names are hierarchical which means setting the log level of
``system0`` will also set it for ``uart0``.


Mocking
-------
When writing libraries and verification components it is very
important to verify that they produce failures as intended. Using the
VUnit logging system it is very easy to test that the expected
failures are produced by mocking a logger object and checking the
expected calls to it.

.. code-block:: vhdl

    logger := get_logger("my_library");
    mock(logger);
    my_library.verify_something(args);
    check_only_log(logger, "Failed to verify something", failure);
    unmock(logger);


The ``check_only_log`` procedure checks that one and only one log
message was produced.  There is also the ``check_log`` procedure which
checks and consumes one log message from the list of recorded log calls to
check a sequence of log messages.

The ``mock`` procedures ensures that all future calls to the logger
are recorded and not sent to a any log handler or cause simulation
abort. The ``unmock`` procedure restores the logger to its normal
state.  The ``unmock`` call also checks that all recorded log messages
have been checked by a corresponding ``check_log`` or
``check_only_log`` procedure.

There is also the ``get_mock_log_count`` function which returs the
number of recorded log items that occurred for one or all log
levels. This can be used in a test bench to wait for a log to occur
before issuing the ``check_log`` procedure.


.. code-block:: vhdl

    mock(logger);
    trigger_error(clk);
    wait until get_mock_logger(logger, failure) > 0 and rising_edge(clk);
    check_only_log(logger, "Error was triggered", failure);
    unmock(logger);


Log Location Preprocessing
--------------------------

The optional VUnit location preprocessor can be used to add file name
and line number location information to all log calls. This
functionality is enabled from the ``run.py`` file like this:

.. code-block:: python

    ui = VUnit.from_argv()
    ui.enable_location_preprocessing()

and will change the output to something like this.

.. code-block:: console

    1000 ps - temperature_sensor -    INFO - Over-temperature (73 degrees C)! (logging_example.vhd:79)


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

Deprecated Interfaces
---------------------

To better support testbenches developed before VUnit 3.0 it's still possible to configure a logger using the
``logger_init`` procedure. The procedure uses best effort to map old behavior to contemporary functionality.

Public API
----------

logger_pkg
^^^^^^^^^^
Contains ``logger_t`` datatype and logger local procedures.

.. literalinclude:: ../../vunit/vhdl/logging/src/logger_pkg.vhd
   :language: vhdl
   :lines: 7-


log_handler_pkg
^^^^^^^^^^^^^^^
Contains ``log_handler_t`` datatype and log handler local configuration
procedures.

.. literalinclude:: ../../vunit/vhdl/logging/src/log_handler_pkg.vhd
   :language: vhdl
   :lines: 7-

log_deprecated_pkg
^^^^^^^^^^^^^^^
Contains deprecated interfaces

.. literalinclude:: ../../vunit/vhdl/logging/src/log_deprecated_pkg.vhd
   :language: vhdl
   :lines: 7-


Example
-------
A runnable example using logging can be found in :vunit_example:`Logging Example <vhdl/logging/>`.
