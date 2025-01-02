# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from os import getenv
import glob
from pathlib import Path
from vunit import VUnit, VUnitCLI, location_preprocessor
from math import log10, floor, ceil
from random import seed, randint, random


def main():
    vhdl_2019 = getenv("VUNIT_VHDL_STANDARD") == "2019"
    root = Path(__file__).parent

    cli = VUnitCLI()
    cli.parser.add_argument(
        "--performance-iterations",
        type=int,
        default=1,
        help="Number of iterations to run in performance tests",
    )
    cli.parser.add_argument(
        "--random-iterations",
        type=int,
        default=1,
        help="Number of randomized tests",
    )
    args = cli.parse_args()
    ui = VUnit.from_args(args=args)
    ui.add_vhdl_builtins()

    vunit_lib = ui.library("vunit_lib")
    files = glob.glob(str(root / "test" / "*.vhd"))
    files.remove(str(root / "test" / "tb_location.vhd"))
    vunit_lib.add_source_files(files)

    preprocessor = location_preprocessor.LocationPreprocessor()
    preprocessor.add_subprogram("print_pre_vhdl_2019_style")
    preprocessor.remove_subprogram("info")
    vunit_lib.add_source_files(root / "test" / "tb_location.vhd", preprocessors=[preprocessor])

    if vhdl_2019:
        testbenches = vunit_lib.get_source_files("*tb*")
        testbenches.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
        ui.set_sim_option("rivierapro.vsim_flags", ["-filter RUNTIME_0375"])

    vunit_lib.test_bench("tb_location").set_generic("vhdl_2019", vhdl_2019)

    tb = vunit_lib.test_bench("tb_sim_time_formatting")
    tb.set_generic("n_performance_iterations", args.performance_iterations)

    test_vectors = []
    native_unit_scaling = 0
    auto_unit_scaling = -1
    full_resolution = -1

    test_name = "Test native unit"
    test_vectors.append([test_name, f"no_decimals", 123456, native_unit_scaling, 0])

    test_name = "Test units of differents scales wrt the resolution_limit"
    for scaling in [1, 1000, 1000000, 1000000000]:
        test_vectors.append([test_name, f"scaling={scaling}", 123456, scaling, 0])

    test_name = "Test auto unit"
    test_vectors.append([test_name, "three_integer_digits", 456789, auto_unit_scaling, 0])
    test_vectors.append([test_name, "two_integer_digits", 56789, auto_unit_scaling, 0])
    test_vectors.append([test_name, "one_integer_digit", 6789, auto_unit_scaling, 0])

    test_name = "Test limiting number of decimals"
    for n_decimals in range(3):
        for scaling in [1, 1000, 1000000]:
            test_vectors.append([test_name, f"n_decimals={n_decimals}_scaling={scaling}", 456789, scaling, n_decimals])
        test_vectors.append(
            [test_name, f"n_decimals={n_decimals}_native_unit", 456789, native_unit_scaling, n_decimals]
        )
        test_vectors.append([test_name, f"n_decimals={n_decimals}_auto_unit", 456789, auto_unit_scaling, n_decimals])
    test_vectors.append([test_name, f"no significant digits among decimals", 456789, 1000000000, 3])
    test_vectors.append([test_name, f"some significant digits among decimals", 456789, 1000000000, 4])

    test_name = "Test full resolution"
    for scaling in [1, 1000, 1000000, 1000000000]:
        test_vectors.append([test_name, f"scaling={scaling}", 123456, scaling, full_resolution])
    test_vectors.append([test_name, f"native_unit", 123456, native_unit_scaling, full_resolution])
    test_vectors.append([test_name, f"auto_unit", 123456, auto_unit_scaling, full_resolution])

    test_name = "Test trailing zeros"
    for n_zeros in range(-1, -7, -1):
        test_time = round(123456, n_zeros)
        test_vectors.append([test_name, f"n_zeros={-n_zeros}", test_time, 1000, 3])

    test_name = "Test zero"
    test_vectors.append([test_name, "auto_with_all_decimals", 0, auto_unit_scaling, full_resolution])
    test_vectors.append([test_name, "scaling_with_fix_decimals", 0, 1000, 2])
    test_vectors.append([test_name, "scaling_with_no_decimals", 0, 1000, 0])

    def calculate_generics(test_time, scaling, n_decimals):
        auto_scaling = (
            1 if test_time == 0 else int(10 ** (floor(log10(test_time) / 3) * 3) if scaling == auto_unit_scaling else 1)
        )
        resolved_scaling = scaling if scaling > 0 else 1 if scaling == native_unit_scaling else auto_scaling

        test_time_str = str(test_time)
        n_decimals_to_use = int(log10(resolved_scaling))
        if n_decimals_to_use >= len(test_time_str):
            test_time_str = "0" * (n_decimals_to_use - len(test_time_str) + 1) + test_time_str

        if (n_decimals_to_use == 0) and (n_decimals <= 0):
            expected = test_time_str
        elif (n_decimals_to_use == 0) and (n_decimals > 0):
            expected = test_time_str + "." + "0" * n_decimals
        elif n_decimals == 0:
            expected = test_time_str[: len(test_time_str) - n_decimals_to_use]
        elif (n_decimals < 0) or (n_decimals == n_decimals_to_use):
            expected = (
                test_time_str[: len(test_time_str) - n_decimals_to_use]
                + "."
                + test_time_str[len(test_time_str) - n_decimals_to_use :]
            )
        elif n_decimals < n_decimals_to_use:
            expected = (
                test_time_str[: len(test_time_str) - n_decimals_to_use]
                + "."
                + test_time_str[
                    len(test_time_str) - n_decimals_to_use : len(test_time_str) - n_decimals_to_use + n_decimals
                ]
            )
        else:
            expected = (
                test_time_str[: len(test_time_str) - n_decimals_to_use]
                + "."
                + test_time_str[len(test_time_str) - n_decimals_to_use :]
                + "0" * (n_decimals - n_decimals_to_use)
            )

        return auto_scaling, expected

    for test_name, cfg_name, test_time, scaling, n_decimals in test_vectors:
        test = tb.test(test_name)
        auto_scaling, expected = calculate_generics(test_time, scaling, n_decimals)

        test.add_config(
            name=cfg_name,
            generics=dict(
                test_time=test_time,
                scaling=scaling,
                n_decimals=n_decimals,
                expected=expected,
                auto_scaling=auto_scaling,
            ),
        )

    test = tb.test("Test random")
    seed("A seed")
    cfg_names = set()
    iter = 0
    while iter < args.random_iterations:
        rnd = randint(0, 24)
        if rnd == 0:
            test_time = 0
        elif rnd == 1:
            test_time = 1
        elif rnd == 2:
            test_time = 2**31 - 1
        else:
            test_time = randint(1, 10 ** randint(1, 9))

        rnd = randint(0, 2)
        if rnd == 0:
            scaling = native_unit_scaling
        elif rnd == 1:
            scaling = auto_unit_scaling
        else:
            scaling = 10 ** (3 * randint(0, 3))

        n_decimals = full_resolution if randint(0, 1) == 0 else randint(0, 15)

        cfg_name = f"{test_time}_{scaling}_{n_decimals}"
        if cfg_name in cfg_names:
            continue

        cfg_names.add(cfg_name)
        iter += 1
        auto_scaling, expected = calculate_generics(test_time, scaling, n_decimals)
        test.add_config(
            name=cfg_name,
            generics=dict(
                test_time=test_time,
                scaling=scaling,
                n_decimals=n_decimals,
                expected=expected,
                auto_scaling=auto_scaling,
            ),
        )

    ui.main()


if __name__ == "__main__":
    main()
