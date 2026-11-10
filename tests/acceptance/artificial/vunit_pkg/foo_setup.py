# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Setup function of the foo package.

The module is placed outside of the foo package such that the package __init__.py file,
which must not be executed when adding the package, is not imported.
"""


def setup(context):
    """Record that the setup function was called with the expected context."""
    (context.output_path / "foo_setup_called.txt").write_text(
        f"library={context.library.name}\n"
        f"package_root={context.package_root}\n"
        f"run_script_path={context.run_script_path}\n"
        f"simulator_name={context.simulator_name}\n",
        encoding="utf-8",
    )
