.. _logging_library:

Logging Library User Guide
==========================

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

 .. raw:: html
    :file: log_call.html

will use the default logger while

 .. raw:: html
    :file: log_call_with_logger.html

will use the custom ``my_logger``. A custom logger is created
by declaring a constant or a variable of type ``logger_t``.

 .. raw:: html
    :file: logger_declaration.html

``get_logger`` will internally create an identity for the name
provided in the call (see :ref:`identity package <id_user_guide>`)
which means that the concept of name hierarchy is inherited by
loggers. In this case a logger will also be created for ``system0``
if it didn't already exist.

A logger can also be created directly from an identity.

 .. raw:: html
    :file: logger_from_id.html

Log Handlers
------------

Log messages made to a logger are handled by a one or more log handlers
linked to that logger. By default, all loggers are linked to a handler for
the display output (stdout) but handlers can also be added for file output.
Every log entry to a logger is passed to the log handlers of the logger.
Each handler may have different output format and log level settings.
The format is used to control the layout and amount of information being displayed.

Log Levels
----------

Every log entry you make has a log level which is defined by dedicated
procedure calls for each log level. The standard log levels and their
associated procedure calls are:

 .. raw:: html
    :file: standard_log_levels.html

There are also conditional log procedures for warning, error and failure:

 .. raw:: html
    :file: conditional_log.html

It's also possible to create custom log levels. For example

 .. raw:: html
    :file: custom_log_level.html

The last optional parameters define the foreground, background and style of the output color.
Valid values are defined in ansi_pkg.

To make a log entry with the custom level use any of the ``log`` procedures:

 .. raw:: html
    :file: log_call_with_custom_level.html

Formatting
----------
The default display format is ``verbose`` but he format can be
changed to any of ``raw``, ``level``, and ``csv``.

 .. raw:: html
    :file: set_format.html

which will result in the following output:

 .. raw:: html
    :file: set_format_log.html

The default ``verbose`` format which adds more details to the
output looks like this:

 .. raw:: html
    :file: verbose_format_log.html

The verbose output will always contain the simulator time, the log
level, the logger, and the message.

The ``raw`` formatter just emits the log message and nothing else. The
``csv`` formatter emits all information in the log entry as a comma
separated list for convenient parsing.

To enhance readability, the simulation time format can be specified by the ``log_time_unit``
and ``n_log_time_decimals`` parameters to the ``set_format`` procedure. ``log_time_unit``
controls the unit used for the simulation time and the default value is ``native_time_unit``
which corresponds to the simulator's resolution. Setting it to ``auto_time_unit`` will select
the unit based on the simulator time, following these rules:

* If simulation time is greater than or equal to 1 second: unit = ``sec``
* If simulation time is less than 1 second: unit is chosen from ``fs``, ``ps``, ``ns``, ``us``,
  and ``ms`` so that the numerical value falls within the range [1, 1000). For example,
  ``123456 ps`` will be displayed as (``n_log_time_decimals`` = 3):

 .. raw:: html
    :file: log_time_unit_log.html

``log_time_unit`` can also be set explicitly to ``fs``, ``ps``, ``ns``, ``us``, ``ms``, or ``sec``
as long as the value is greater than or equal to the simulator's resolution. No other time values are allowed.

``n_log_time_decimals`` specifies the number of decimal places in the output. Setting it to
``full_time_resolution`` will output the full resolution of the simulator. For instance, if the resolution is ``ps``
and ``log_time_unit`` is set to ``us``, ``123456 ps`` will be displayed as:

 .. raw:: html
    :file: full_time_resolution_log.html

If ``n_log_time_decimals`` is set to a non-negative number, the output is formatted to that number of decimals:

* If the simulator resolution is higher than the specified decimals, the value is **truncated**.
* If the number of decimals exceeds the resolution, the value is zero-padded.

For example, ``123456 ps`` with ``auto_time_unit`` and 2 decimals is displayed as:

 .. raw:: html
    :file: fix_decimals_log.html

Stopping simulation
-------------------
By default the simulation will come to a stop if a single log with
level ``error`` or ``failure`` is made. In VUnit a simulation stop
before ``test_runner_cleanup`` is considered a failure.

Simulation stop is controlled via a stop count mechanism. The stop count mechanism works in the following way:

- Stop count may be either set or not set for a specific logger and log level.
- When a log is made to a logger it is checked if there is a stop count set.

  - If set it is decremented and reaching zero means simulation stops.
  - If not set the decrementation is recursively propagated to the parent logger.
- It is possible to disable stopping simulation by setting an infinite stop count.
- By default only the root logger has a stop count set.

  - Root logger has stop count set to 1 for ``error`` and ``failure``.
  - Root logger has stop disabled for all other log levels.

Example:
<<<<<<<<

 .. raw:: html
    :file: stopping_simulation.html

Print Procedure
---------------

``print`` is a procedure that unconditionally outputs its message to stdout or file without any formatting.

.. raw:: html
    :file: print.html

It's also possible to print to an open file object.

.. raw:: html
    :file: print_to_open_file.html

This procedure can be used to optimize performance by printing many messages before flushing or closing the file.

Log visibility
--------------

Log visibility to a log handler can be configured for specific log levels of a logger.

 .. raw:: html
    :file: log_visibility.html

Mocking
-------
When writing libraries and verification components it is very
important to verify that they produce failures as intended. Using the
VUnit logging system it is very easy to test that the expected
failures are produced by mocking a logger object and checking the
expected calls to it.

 .. raw:: html
    :file: mocking.html

The ``check_only_log`` procedure checks that one and only one log
message was produced.  There is also the ``check_log`` procedure which
checks and consumes one log message from the list of recorded log calls to
check a sequence of log messages.

The ``mock`` procedures ensure that all future calls to the logger
are recorded and not sent to a log handler or cause simulation
abort. The ``unmock`` procedure restores the logger to its normal
state.  The ``unmock`` call also checks that all recorded log messages
have been checked by a corresponding ``check_log`` or
``check_only_log`` procedure.

It is possible to mock several loggers or log levels simultaneously.
All mocked log messages are written to the same global mock queue.
The number of log messages in this queue is returned by the
``mock_queue_length`` function.

The mock queue length can be used in a test bench to wait for a log to
occur before issuing the ``check_log`` procedure.

 .. raw:: html
    :file: mock_queue_length.html

Disabled logs
-------------
In addition to visibility settings a log level from a specific logger
can be disabled. The use case for disabling a log is to ignore an
irrelevant or unwanted log message. Disabling prevents simulation
stop and all visibility to log handlers. A disabled log is still
counted to get statistics on disabled log messages.

 .. raw:: html
    :file: disabled_log.html

.. _logging_library:LogLocation:

Log Location
------------

For simulators supporting VHDL-2019 VUnit adds file name
and line number location information to all log entries. Currently
only Riviera-PRO and Active-HDL supports VHDL-2019 and they restrict the feature
to **debug compiled files**. You can compile all files or just the ones
using logging. For example,

 .. raw:: html
    :file: set_debug_option.html

For earlier VHDL standards there is an optional location preprocessor that can
be used to serve the same purpose. The preprocessor is enabled from
the ``run.py`` file like this:

 .. raw:: html
    :file: location_preprocessing.html

Regardless of method the location information is appended to the end of the log entry:

 .. raw:: html
    :file: log_location_log.html

If you've placed your log call(s) in a convenience procedure you may
want the location of the calls to that procedure to be in the
output and not the location of the log call in the definition of the
convenience procedure. For VHDL-2019 you can use the ``path_offset``
parameter to specify a number of steps earlier in the call stack. For
example:

 .. raw:: html
    :file: convenience_procedure.html

When ``path_offset`` is set to 1 the location of the caller to
``my_convenience_procedure`` will be used in the log output.

With earlier VHDL standards you can add the ``line_num`` and
``file_name`` parameters to the **end** of the parameter list for the
convenience procedure:

 .. raw:: html
    :file: another_convenience_procedure.html

Then let the location preprocessor know about the added procedure:

 .. raw:: html
    :file: additional_subprograms.html

External Logging Framework Integration
--------------------------------------

VUnit provides a package ``common_log_pkg`` providing a single procedure ``write_to_log`` that is used to
output the string produced by a log entry. The implementation of this procedure can be changed to redirect VUnit log
messages to a third party logging framework, thereby aligning the logging styles in a testbench with code using several
logging frameworks. The feature is enabled by passing a reference to the file implementing the package body:

 .. raw:: html
    :file: use_external_log.html

The procedure interface is designed to be generic and suitable for third party logging frameworks as well. If provided,
third party log messages can also be redirected to VUnit logging:

.. literalinclude:: ../../vunit/vhdl/logging/src/common_log_pkg.vhd
   :language: vhdl
   :lines: 7-69


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
   :lines: 7-89


Example
-------
A runnable example using logging can be found in :vunit_example:`Logging Example <vhdl/logging/>`.
