# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
A persistent TCL shell to avoid startup overhead in TCL-based simulators
"""

import threading
import logging
from vunit.ostools import Process

LOGGER = logging.getLogger(__name__)


class PersistentTclShell(object):
    """
    A persistent TCL shell
    """

    def __init__(self, create_process):
        self._processes = {}
        self._lock = threading.Lock()
        self._create_process = create_process

    def _process(self):
        """
        Create the vsim process
        """
        ident = threading.current_thread().ident

        with self._lock:  # pylint: disable=not-context-manager
            try:
                process = self._processes[ident]
                if process.is_alive():
                    return process
            except KeyError:
                pass

            process = self._create_process(ident)
            self._processes[ident] = process

        process.writeline("puts #VUNIT_RETURN")
        try:
            consumer = SilentOutputConsumer()
            process.consume_output(consumer)
        except Process.NonZeroExitCode:
            # Print output if background vsim process startup failed
            LOGGER.error("Failed to start re-usable background process")
            LOGGER.error(consumer.output)
            raise
        return process

    def execute(self, cmd):
        """
        Execute a command to the persistent TCL shell
        """
        process = self._process()
        process.writeline(cmd)
        process.writeline("puts #VUNIT_RETURN")
        process.consume_output(output_consumer)

    def read_var(self, varname):
        """
        Read a variable from the persistent TCL shell
        """
        process = self._process()
        process.writeline(f"puts #VUNIT_READVAR=${varname!s}")
        consumer = ReadVarOutputConsumer()
        process.consume_output(consumer)
        return consumer.var

    def read_bool(self, varname):
        result = self.read_var(varname).lower()
        assert result in ("true", "false")
        return result == "true"

    def teardown(self):
        """
        Teardown all active processes before shutdown
        """
        with self._lock:  # pylint: disable=not-context-manager
            for proc in self._processes.values():
                if proc.is_alive():
                    proc.writeline("quit -force -code 0")

            for proc in self._processes.values():
                if proc.is_alive():
                    proc.wait()
            self._processes = {}

    def __del__(self):
        try:
            self.teardown()
        except KeyboardInterrupt:
            LOGGER.debug("PersistentTclShell.__del__: Ignoring KeyboardInterrupt")


def output_consumer(line):
    """
    Consume output until reaching #VUNIT_RETURN
    """
    if line.endswith("#VUNIT_RETURN"):
        return True

    print(line)
    return None


class SilentOutputConsumer(object):
    """
    Consume output until reaching #VUNIT_RETURN, silent
    """

    def __init__(self):
        self.output = ""

    def __call__(self, line):
        if line.endswith("#VUNIT_RETURN"):
            return True

        self.output += line + "\n"
        return None


class ReadVarOutputConsumer(object):
    """
    Consume output from modelsim and print with indentation
    """

    def __init__(self):
        self.var = None

    def __call__(self, line):
        self.var = line.split("#VUNIT_READVAR=")[-1].strip()
        return True
