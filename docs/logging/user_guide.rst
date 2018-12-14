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
   visibility settings

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
and log level setting. The format is used to control the layout and
amount of information being displayed.

Log Levels
----------

Every log entry you make has a log level which is defined by dedicated
procedure calls for each log level. The standard log levels and their
associated procedure calls are:

.. code-block:: vhdl

    -- Visible to display by default
    failure("Fatal error, there is most likely no point in going further");
    error("An error but we could still keep running for a while");
    warning("A warning");
    info("Informative message for very useful public information");

    -- Not visible by default
    pass("Message from a passing check");
    debug("Debug message for seldom useful or internal information");
    trace("Trace messages only used for tracing program flow");

There are also conditional log procedures for warning, error and failure:

.. code-block:: vhdl

    warning_if(True, "A warning happened");
    warning_if(False, "A warning did not happen");

    -- There are also variants for error and failure as well as with
    -- non-default logger argument.

It's also possible to create custom log levels. For example

.. code-block:: vhdl

    license_info := new_log_level("license", fg => red, bg => yellow, style => bright);


The last optional parameters define the foreground, background and style of the output color.
Valid values are defined in ansi_pkg.

To make a log entry with the custom level use any of the `log` procedures:

.. code-block:: vhdl

    log("Mozilla Public License, v. 2.0.", license_info);
    log(my_logger, "Mozilla Public License, v. 2.0.", license_info);

Stopping simulation
-------------------
By default the simulation will come to a stop if a single log with
level ``error`` or ``failure`` is made. In VUnit a simulation stop
before ``test_runner_cleanup`` is considered a failure.

Simulation stop is controlled via a stop count mechanism. The stop count mechanism works in the following way:

- Stop count may be ether set or not set for a specific logger and log level.
- When a log is made to a logger it is checked if there is a stop count set.

  - If set it is decremented and reaching zero means simulation stops.
  - If not set the decrementation is recursively propagated to the parent logger.
- It is possible to disable stopping simulation by setting an infinite stop count.
- By default only the root logger has a stop count set.

  - Root logger has stop count set to 1 for ``error`` and ``failure``.
  - Root logger has stop disabled for all other log levels.

Example:
<<<<<<<<
.. code-block:: vhdl

    -- Allow 10 errors from my_logger and its children
    set_stop_count(my_logger, error, 10);

    -- Disable stop on errors from my_logger and its children
    disable_stop(my_logger, error);

    -- Short hand for stopping on error and failure but not warning globally
    set_stop_level(error);

    -- Short hand for stopping on warning, error and failure for specific logger
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
separated list for convenient parsing.

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


Log visibility
--------------

Log visibility to a log handler can be configured for specific log levels of a logger.

.. code-block:: vhdl

    -- Disable all logging to the display.
    hide_all(display_handler);

    -- Show debug log level of system0 logger to the display
    show(get_logger("system0"), display_handler, debug);

    -- Show all logging from the uart module in system0 to the display
    show_all(get_logger("system0:uart"), display_handler);

    -- Hide all debug output to display handler
    hide(display_handler, debug);


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
    mock(logger, failure);
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

It is possible to mock several logger or log levels simultaneously.
All mocked log messages are written to the same global mock queue.
The number of log messages in this queue is returned by the
``mock_queue_length`` function.

The mock queue length can be used in a test bench to wait for a log to
occur before issuing the ``check_log`` procedure.


.. code-block:: vhdl

    mock(logger, failure);
    trigger_error(clk);
    wait until mock_queue_length > 0 and rising_edge(clk);
    check_only_log(logger, "Error was triggered", failure);
    unmock(logger);


Disabled logs
-------------
In addition to visibility settings a log level from a specific logger
can be disabled. The use case for disabling a log is to ignore an
irrelevant or unwanted log message. Disabling prevents simulation
stop and all visibility to log handlers. A disabled log is still
counted to get statistics on disabled log messages.


.. code-block:: vhdl

    -- Irrelevant warning
    disable(get_logger("memory_ip:timing_check"), warning);


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
<<<<<<<<<<
Contains ``logger_t`` datatype and logger local procedures.

.. literalinclude:: ../../vunit/vhdl/logging/src/logger_pkg.vhd
   :language: vhdl
   :lines: 7-


log_handler_pkg
<<<<<<<<<<<<<<<
Contains ``log_handler_t`` datatype and log handler local configuration
procedures.

.. literalinclude:: ../../vunit/vhdl/logging/src/log_handler_pkg.vhd
   :language: vhdl
   :lines: 7-


Example
-------
A runnable example using logging can be found in :vunit_example:`Logging Example <vhdl/logging/>`.
