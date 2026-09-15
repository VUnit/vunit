# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Registry of simulator hooks.

A hook is a callable provided by a VUnit package to extend what a simulator interface does
for a test. The hooks are registered per simulator name and are called by the simulator
interfaces with the interface instance such that a hook can base its result on how the
simulator was configured.

The registry is cleared when a new VUnit object is created, that is the hooks registered for
a project do not leak into the next one.
"""

from os import environ
from typing import Callable, Dict, List, Optional, Tuple

FlagsHook = Callable[..., List[str]]
EnvHook = Callable[..., Dict[str, str]]

# The hooks registered for a simulator name and a kind of hook
_HOOKS: Dict[Tuple[str, str], List[Callable]] = {}


def register_hooks(
    simulator_name: str,
    *,
    elab_flags: Optional[FlagsHook] = None,
    run_flags: Optional[FlagsHook] = None,
    process_flags: Optional[FlagsHook] = None,
    run_env: Optional[EnvHook] = None,
) -> None:
    """
    Register hooks for a simulator.

    :param simulator_name: The name of the simulator the hooks apply to, for example "ghdl".
    :param elab_flags: A ``elab_flags(simulator_interface)`` function returning extra flags for
                       the elaboration of a test. Simulators without a separate elaboration step
                       do not call this hook.
    :param run_flags: A ``run_flags(simulator_interface)`` function returning extra flags for the
                      simulation of a test.
    :param process_flags: A ``process_flags(simulator_interface)`` function returning extra flags for
                          the simulator process VUnit starts. Only simulators driving the simulation
                          from a separate process, that is the vsim based ones, call this hook.
    :param run_env: A ``run_env(simulator_interface, env)`` function returning the environment
                    of the simulation of a test, given the environment it would otherwise have.
    """
    if not isinstance(simulator_name, str) or not simulator_name:
        raise ValueError("Simulator name must be a non-empty string.")

    new_hooks = {"elab_flags": elab_flags, "run_flags": run_flags, "process_flags": process_flags, "run_env": run_env}
    for kind, hook in new_hooks.items():
        if hook is not None and not callable(hook):
            raise ValueError(f"{kind} hook for simulator {simulator_name} is not callable.")

    for kind, hook in new_hooks.items():
        if hook is not None:
            _HOOKS.setdefault((simulator_name, kind), []).append(hook)


def clear_hooks() -> None:
    """
    Remove all registered hooks.
    """
    _HOOKS.clear()


def get_flags(simulator_interface, kind: str) -> List[str]:
    """
    Return the extra flags provided by the hooks of the simulator of a kind, that is
    "elab_flags", "run_flags" or "process_flags".
    """
    return [flag for hook in _HOOKS.get((simulator_interface.name, kind), []) for flag in hook(simulator_interface)]


def get_run_env(simulator_interface, env: Optional[Dict[str, str]] = None) -> Optional[Dict[str, str]]:
    """
    Return the simulation environment transformed by the hooks of the simulator.

    The environment is returned unchanged if there are no hooks. None means that the simulation
    inherits the environment of VUnit, in which case a copy of that environment is given to the
    hooks.
    """
    hooks = _HOOKS.get((simulator_interface.name, "run_env"), [])
    if not hooks:
        return env

    result = environ.copy() if env is None else env
    for hook in hooks:
        result = hook(simulator_interface, result)

    return result
