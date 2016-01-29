import sys

for file_name in sys.argv[1:]:
    print(file_name)
    with open(file_name, "r") as fptr:
        text = fptr.read()

    text = text.replace("context vunit_lib.vunit_context;",
"""\
use vunit_lib.lang.all;
use vunit_lib.textio.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;"""
)

    text = text.replace("context vunit_lib.com_context;",
"""\
use vunit_lib.com_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.com_codec_pkg.all;
use vunit_lib.com_string_pkg.all;
use vunit_lib.com_debug_codec_builder_pkg.all;
use vunit_lib.com_std_codec_builder_pkg.all;
""")

    with open(file_name, "w") as fptr:
        fptr.write(text)
