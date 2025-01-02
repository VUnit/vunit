# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Module for generating VHDL com codecs.
"""

from string import Template
from vunit.ostools import read_file, write_file
from vunit.com.codec_vhdl_package import CodecVHDLPackage


def generate_codecs(
    input_package_design_unit,
    codec_package_name,  # pylint: disable=too-many-arguments
    used_packages,
    output_file,
):
    """This function generates codecs for the types in the input package and compile the result into
    codec_package_name. used_packages is a list specifying what to include into the result package
    other than the input package. A used package on the format 'lib.pkg' will result in a library and
    a use statement. A used package on the format 'pkg' is assumed to be located in work. output_file
    is where the resulting codec package is written."""

    # The design unit doesn't contain the package so it must be found first in the source file. This file
    # may contain other packages
    code = read_file(input_package_design_unit.source_file.name)
    package = CodecVHDLPackage.find_named_package(code, input_package_design_unit.name)
    if package is None:
        raise KeyError(input_package_design_unit.name)

    # Get all function declarations and definitions derived from the package type definitions
    declarations, definitions = package.generate_codecs_and_support_functions()

    # Create extra use clauses
    use_clauses = ""
    libraries = []
    for used_package in used_packages if used_packages is not None else []:
        if "." in used_package:
            if used_package.split(".")[0] not in libraries:
                libraries.append(used_package.split(".")[0])
            use_clauses += f"use {used_package!s}.all;\n"
        else:
            use_clauses += f"use work.{used_package!s}.all;\n"
    if libraries:
        use_clauses = "library " + ";\nlibrary ".join(libraries) + ";\n" + use_clauses

    # Assemble everything and write to output file
    codec_package_template = Template(
        """\
library vunit_lib;
use vunit_lib.string_ops.all;
context vunit_lib.com_context;
use vunit_lib.queue_pkg.all;
use vunit_lib.queue_2008p_pkg.all;

use std.textio.all;

use work.$package_name.all;

$use_clauses
package $codec_package_name is
$declarations
end package $codec_package_name;

package body $codec_package_name is
$definitions
end package body $codec_package_name;

"""
    )

    codec_package = codec_package_template.substitute(
        declarations=declarations,
        definitions=definitions,
        package_name=package.identifier,
        codec_package_name=codec_package_name,
        use_clauses=use_clauses,
    )

    write_file(output_file, codec_package)
