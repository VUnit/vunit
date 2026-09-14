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

from dataclasses import dataclass, field
from os import environ
from typing import Callable, Dict, List, Optional

FlagsHook = Callable[..., List[str]]
EnvHook = Callable[..., Dict[str, str]]


@dataclass
class _Hooks:
    """The hooks registered for a simulator."""

    elab_flags: List[FlagsHook] = field(default_factory=list)
    run_flags: List[FlagsHook] = field(default_factory=list)
    run_env: List[EnvHook] = field(default_factory=list)


_HOOKS: Dict[str, _Hooks] = {}


def _check_callable(name: str, hook, simulator_name: str) -> None:
    """Check that a hook is callable."""
    if hook is not None and not callable(hook):
        raise ValueError(f"{name} hook for simulator {simulator_name} is not callable.")


def register_hooks(
    simulator_name: str,
    *,
    elab_flags: Optional[FlagsHook] = None,
    run_flags: Optional[FlagsHook] = None,
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
    :param run_env: A ``run_env(simulator_interface, env)`` function returning the environment
                    of the simulation of a test, given the environment it would otherwise have.
    """
    if not isinstance(simulator_name, str) or not simulator_name:
        raise ValueError("Simulator name must be a non-empty string.")

    _check_callable("elab_flags", elab_flags, simulator_name)
    _check_callable("run_flags", run_flags, simulator_name)
    _check_callable("run_env", run_env, simulator_name)

    hooks = _HOOKS.setdefault(simulator_name, _Hooks())

    if elab_flags is not None:
        hooks.elab_flags.append(elab_flags)

    if run_flags is not None:
        hooks.run_flags.append(run_flags)

    if run_env is not None:
        hooks.run_env.append(run_env)


def clear_hooks() -> None:
    """
    Remove all registered hooks.
    """
    _HOOKS.clear()


def _hooks(simulator_interface) -> _Hooks:
    """Return the hooks registered for the simulator of the interface."""
    return _HOOKS.get(simulator_interface.name, _Hooks())


def get_elab_flags(simulator_interface) -> List[str]:
    """
    Return the extra elaboration flags provided by the hooks of the simulator.
    """
    flags: List[str] = []
    for hook in _hooks(simulator_interface).elab_flags:
        flags += list(hook(simulator_interface))

    return flags


def get_run_flags(simulator_interface) -> List[str]:
    """
    Return the extra simulation flags provided by the hooks of the simulator.
    """
    flags: List[str] = []
    for hook in _hooks(simulator_interface).run_flags:
        flags += list(hook(simulator_interface))

    return flags


def get_run_env(simulator_interface, env: Optional[Dict[str, str]] = None) -> Optional[Dict[str, str]]:
    """
    Return the simulation environment transformed by the hooks of the simulator.

    The environment is returned unchanged if there are no hooks. None means that the simulation
    inherits the environment of VUnit, in which case a copy of that environment is given to the
    hooks.
    """
    hooks = _hooks(simulator_interface).run_env
    if not hooks:
        return env

    result = environ.copy() if env is None else env
    for hook in hooks:
        result = hook(simulator_interface, result)

    return result
