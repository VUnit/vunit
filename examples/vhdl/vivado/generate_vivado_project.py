# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from shutil import rmtree
from vunit.vivado import run_vivado


def main():
    root = Path(__file__).parent.resolve()
    project_name = "myproject"
    if (root / project_name).exists():
        rmtree(root / project_name)
    run_vivado(root / "tcl" / "generate_project.tcl", tcl_args=[root, "myproject"])


if __name__ == "__main__":
    main()
