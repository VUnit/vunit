:tags: VUnit
:author: lasplund
:excerpt: 2

Enable Your Simulator to Handle Complex Top-Level Generics
==========================================================
A powerful feature in VUnit is the ability to run testbenches and test cases with different configurations
(not to be confused with VHDL configurations). The typical use case is to run tests with different generics
but you can also run with different simulator settings and register Python functions to be run before and
after the test. The latter can be used to create stimuli and verify test outputs using the power of Python or
some other external program like Matlab.

Over time VUnit users tend to get more advanced in the use of generics which inevitably leads to more complex data
types. Rather than passing many generics of scalar types they want to create composite types like records and
arrays. Unfortunately, many simulators have restrictions on what type of generics you can pass to the top-level
testbench entity. Typically you're limited to a small subset of the standard composite types like ``string`` and
``std_logic_vector`` and can't use custom composite types. This is a limitation when trying to write clean and
efficient code but something that can be worked around using VUnit. The trick is to encode your composite data
type into something that the simulator _can_ handle and then decode back to the original type within the VHDL
testbench. ``string`` is something most (all?) simulators can handle and what I will use in these examples.

Let's say that you want pass an ``integer_vector`` generic called ``image_resolution`` to your testbench. Such a
vector can be represented with a list in Python which can be encoded into a comma-separated string.

.. code-block:: python

    image_resolution = [640, 480]
    encoded_image_resolution = ", ".join(map(str, image_resolution))

The Python ``map`` function applies the provided ``str`` function to all elements of the ``image_resolution`` list
to convert the integers to strings. The resulting string elements are then joined together to create a
comma-separated string ``"640, 480"``.

Assuming my testbench entity is named ``tb_composite_generics``, is compiled into library ``tb_lib``, and has a
test case (badly) named ``Test 1``, I can create a configuration for that test case with these lines in my
Python run script.

.. code-block:: python

    image_resolution = [640, 480]
    encoded_image_resolution = ", ".join(map(str, image_resolution))

    testbench = tb_lib.entity("tb_composite_generics")
    test_1 = testbench.test("Test 1")

    generics = dict(encoded_image_resolution=encoded_image_resolution)
    test_1.add_config(name='VGA', generics=generics)


Generics are represented with a Python dictionary (list of key=value pairs) where the key is the name of the
generic, in this case ``encoded_image_resolution`` which is assigned our variable with the same name. We name
our configuration to ``VGA`` and when listing our test cases we will see our test case and its only configuration.

.. code-block:: console

    > python run.py -l
    tb_lib.tb_composite_generics.VGA.Test 1
    Listed 1 tests

The beginning of our example testbench at this point looks like this

.. code-block:: vhdl

    library vunit_lib;
    context vunit_lib.vunit_context;

    entity tb_composite_generics is
      generic (
        encoded_image_resolution : string;
        runner_cfg : string);
    end tb_composite_generics;

    architecture tb of tb_composite_generics is
      impure function decode(encoded_integer_vector : string) return integer_vector is
        variable parts : lines_t := split(encoded_integer_vector, ", ");
        variable return_value : integer_vector(parts'range);
      begin
        for i in parts'range loop
          return_value(i) := integer'value(parts(i).all);
        end loop;

        return return_value;
      end;

      constant image_resolution : integer_vector := decode(encoded_image_resolution);
    begin

The decoded ``image_resolution`` constant is initialized by calling the ``decode`` function with the encoded
resolution. ``decode`` is based on VUnit's ``split`` function located in the ``string_ops`` package. It splits
a string into its parts based on a defined separator, in this case ``", "``, and returns a pointer to a vector
with ``line`` type elements. These ``line`` elements are converted back to integers which are inserted into
the returned ``integer_vector``. The overall solution is compact. Both the encoding and the decoding are single
lines of code once the reusable ``decode`` function has been placed in a support package.

Sometimes it's more convenient with record generics. Maybe you want your complete testbench configuration in a
single ``tb_cfg`` generic to avoid the hassle of re-routing generics through your design when new ones are added
or removed. Just add/remove elements in that record. Such a generic can be represented with a Python dictionary

.. code-block:: python

    tb_cfg = dict(image_width=640, image_height=480, dump_debug_data=False)
    encoded_tb_cfg = ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

The encoding joins a list of string elements into a comma-separated string like we did before but each element
in the list is a key:value pair taken from the ``tb_cfg`` dictionary. The resulting string is
``"image_width:640, image_height:480, dump_debug_data:True"``. This is the same key:value format used in the
``runner_cfg`` generic present in every VUnit testbench so we have built-in support for decoding such a string.

.. code-block:: vhdl

    type tb_cfg_t is record
      image_width     : positive;
      image_height    : positive;
      dump_debug_data : boolean;
    end record tb_cfg_t;

    impure function decode(encoded_tb_cfg : string) return tb_cfg_t is
    begin
      return (image_width => positive'value(get(encoded_tb_cfg, "image_width")),
              image_height => positive'value(get(encoded_tb_cfg, "image_height")),
              dump_debug_data => boolean'value(get(encoded_tb_cfg, "dump_debug_data")));
    end function decode;

    constant tb_cfg : tb_cfg_t := decode(encoded_tb_cfg);

The ``get`` function returns the value for the provided key as a string so it has to be converted before assigning
the target record.

Note that you can also use the ``tb_cfg`` to configure the structure of the test bench, not only parameter values
like image resolution. For example

.. code-block:: vhdl

    dump_debug_data: if tb_cfg.dump_debug_data generate
      process is
      begin
        for y in 0 to tb_cfg.image_height - 1 loop
          for x in 0 to tb_cfg.image_width - 1 loop
            wait until rising_edge(clk) and data_valid = '1';
            debug("Dumping tons of debug data");
          end loop;
        end loop;

        dumping_done <= true;
        wait;
      end process;
    end generate dump_debug_data;

Let's create two configurations this time. One configuration with a VGA image not dumping the extra debug data and
one configuration with a tiny image (for a fast simulation) and complete debug information.

.. code-block:: vhdl

    def encode(tb_cfg):
        return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

    vga_tb_cfg = dict(image_width=640, image_height=480, dump_debug_data=False)
    test_1.add_config(name='VGA', generics=dict(encoded_tb_cfg=encode(vga_tb_cfg)))

    tiny_tb_cfg = dict(image_width=4, image_height=3, dump_debug_data=True)
    test_1.add_config(name='tiny', generics=dict(encoded_tb_cfg=encode(tiny_tb_cfg)))

The result is

.. code-block:: console

    > python run.py -v
    Running test: tb_lib.tb_composite_generics.tiny.Test 1
    Running test: tb_lib.tb_composite_generics.VGA.Test 1
    Running 2 tests

    Starting tb_lib.tb_composite_generics.tiny.Test 1
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    DEBUG: Dumping tons of debug data
    simulation stopped @23ns with status 0
    pass (P=1 S=0 F=0 T=2) tb_lib.tb_composite_generics.tiny.Test 1 (0.3 seconds)

    Starting tb_lib.tb_composite_generics.VGA.Test 1
    simulation stopped @0ms with status 0
    pass (P=2 S=0 F=0 T=2) tb_lib.tb_composite_generics.VGA.Test 1 (0.3 seconds)

    ==== Summary ====================================================
    pass tb_lib.tb_composite_generics.tiny.Test 1 (0.3 seconds)
    pass tb_lib.tb_composite_generics.VGA.Test 1  (0.3 seconds)
    =================================================================
    pass 2 of 2
    =================================================================
    Total time was 0.5 seconds
    Elapsed time was 0.5 seconds
    =================================================================
    All passed!

That's all for this time. You can find the code for the final (dummy) testbench
`here <https://github.com/VUnit/vunit/blob/master/examples/vhdl/composite_generics/test/tb_composite_generics.vhd>`__.
