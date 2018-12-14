.. _python_interface:

Python Interface
================
The Python interface of VUnit is exposed through the :class:`VUnit
<vunit.ui.VUnit>` class that can be imported directly from the
:mod:`vunit <vunit.ui>` module.

.. automodule:: vunit.ui


.. _attributes:

Attributes
----------
The user may set custom attributes on test cases via comments. The
attributes can for example be used to achieve requirements
trace-ability. The attributes are exported in the :ref:`JSON Export
<json_export>`. All user defined attributes must start with a dot
(``.``) as non-dot attributes are reserved for built-in attributes.

Example
<<<<<<<
.. code-block:: vhdl
   :caption: VHDL Example

   if run("Test 1") then
       -- vunit: .requirement-117
   end if;


.. code-block:: verilog
   :caption: SystemVerilog Example

   `TEST_SUITE begin
       `TEST_CASE("Test 1") begin
           // vunit: .requirement-117
        end
    end

.. code-block:: json
   :caption: JSON Export has attributes attached to each test. The
             attributes all have null value to be forward compatible
             in a future where user attributes can have values.

    {
       "attributes": {
            ".requirement-117": null
       }
    }


.. _pre_and_post_hooks:

Pre and post simulation hooks
-----------------------------
There are two hooks to run user defined Python code.

:pre_config: A ``pre_config`` is called before simulation of the test
             case. The function may accept an ``output_path`` string
             which is the filesystem path to the directory where test
             outputs are stored. The function must return ``True`` or
             the test will fail immediately.

             The use case is to automatically create input data files
             that is read by the test case during simulation. The test
             bench can access the test case unique ``output_path`` via
             a :ref:`special generic/parameter <special_generics>`.

:post_check: A ``post_check`` is called after a passing simulation of
             the test case. The function may accept an ``output_path``
             string which is the filesystem path to the directory
             where test outputs are stored. The function may accept an
             ``output`` string which full standard output from the
             test containing the simulator transcript. The function
             must return ``True`` or the test will fail.

             The use case is to automatically check output data files
             that is written by the test case during simulation. The test
             bench can access the test case unique ``output_path`` via
             a :ref:`special generic/parameter <special_generics>`.

             .. note::
                The ``post_check`` function is only called after a
                passing test and skipped in case of failure.


Example
<<<<<<<
    .. code-block:: python

       class DataChecker:
           """
           Provides input data to test bench and checks its output data
           """
           def __init__(self, data):
               self.input_data = data

           def pre_config(self, output_path):
               write_data(self.input_data, join(output_path, "input.csv"))
               return True

           def post_check(self, output_path):
               expected = compute_expected(self.input_data)
               got = read_data(join(output_path, "output.csv"))
               return check_equal(got, expected)

       # Just change the original test
       checker = DataChecker(data=create_random_data(seed=11))
       my_test.set_pre_config(checker.pre_config)
       my_test.set_post_check(checker.post_check)

       # .. or create many configurations of the test
       for seed in range(10, 20):
           checker = DataChecker(data=create_random_data(seed))
           my_test.add_config(name="seed%i" % seed,
                              pre_config=checker.pre_config,
                              post_check=checker.post_check)


.. automodule:: vunit.vunit_cli
