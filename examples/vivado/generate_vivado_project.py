# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from vivado_util import run_vivado
from os.path import join, dirname, exists, normpath
from shutil import rmtree


def main():
    root = normpath(dirname(__file__))
    project_name = "myproject"
    if exists(join(root, project_name)):
        rmtree(join(root, project_name))

    run_vivado(join(root, "tcl", "generate_project.tcl"), root, "myproject")

if __name__ == "__main__":
    main()
