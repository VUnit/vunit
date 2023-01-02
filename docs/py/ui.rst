.. _python_interface:

Python Interface
================
The Python interface of VUnit is exposed through the :class:`VUnit
class <vunit.ui.VUnit>` that can be imported directly. See the
:ref:`User Guide <user_guide>` for a quick introduction. The
following list provides detailed references of the Python API and
about how to set compilation and simulation options.

.. toctree::

   vunit
   opts

.. _configurations:

Configurations
--------------
In VUnit Python API the name ``configuration`` is used to denote the
user controllable configuration of one test run such as
generic/parameter settings, simulation options as well as the
pre_config and post_check :ref:`callback functions <pre_and_post_hooks>`.
User :ref:`attributes <attributes>` can also be added as a part of a
configuration.

Configurations can either be unique for each test case or must be
common for the entire test bench depending on the situation.  For test
benches without test such as `tb_example` in the User Guide the
configuration is common for the entire test bench. For test benches
containing tests such as `tb_example_many` the configuration is done
for each test case. If the ``run_all_in_same_sim`` attribute has been used,
configuration is performed at the test bench level even if there are
individual tests within since they must run in the same simulation.

In a VUnit all test benches and test cases are created with an unnamed default
configuration which is modified by different methods such as ``set_generic`` etc.
In addition to the unnamed default configuration multiple named configurations
can be derived from it by using the ``add_config`` method. The default
configuration is only run if there are no named configurations.

.. _attributes:

Attributes
----------
The user may set custom attributes on test cases via comments or via the
``set_attribute`` method. The attributes can for example be used to achieve
requirements trace-ability. The attributes are exported in the
:ref:`JSON Export <json_export>`. All user defined attributes must start
with a dot (``.``) as non-dot attributes are reserved for built-in
attributes.

Attributes set via the python interface will effectively overwrite the value
of a user attribute set via code comments.

Attribute example
<<<<<<<<<<<<<<<<<
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


.. code-block:: python
   :caption: Python Example

   my_test.set_attribute(".requirement-117", None)


.. code-block:: json
   :caption: JSON Export has attributes attached to each test. The
             attributes added via comments all have null value to be
             forward compatible in a future where user attributes can
             have values. Attributes set via python can have basic type
             values.

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
             case. The function accepts an optional string argument
             ``output_path``, which is the filesystem path to the
             directory where test outputs are stored, and an optional
             string argument ``simulator_output_path`` which is the path
             to the simulator working directory.

             .. note::
               ``simulator_output_path`` is shared by all test runs. The
               user must take care that test runs do not read or write the
               same files asynchronously. It is therefore recommended to use
               ``output_path`` in favor of ``simulator_output_path``.

             A ``pre_config`` must return ``True`` or the test will fail
             immediately.

             The use case for ``pre_config`` is to automatically create
             input data files that are read by the test case during
             simulation. The test bench can access the test case unique
             ``output_path`` via a special generic or a using the
             ``output_path`` function. See the
             :doc:`run library user guide <../run/user_guide>`.

             The use case for ``simulator_output_path`` is to support
             code expecting input files to be located in the
             simulator working directory.

:post_check: A ``post_check`` is called after a passing simulation of
             the test case. The function accepts an optional string argument
             ``output_path``, which is the filesystem path to the
             directory where test outputs are stored, and an optional
             string argument ``output``  which is the full standard output from the
             test containing the simulator transcript.

             The function must return ``True`` or the test will fail.

             The use case is to automatically check output data files
             that are written by the test case during simulation. The
             test bench can access the test case unique
             ``output_path`` via a special generic or a using the
             ``output_path`` function. See the
             :doc:`run library user guide <../run/user_guide>`.

             .. note::
                The ``post_check`` function is only called after a
                passing test and skipped in case of failure.


Hook example
<<<<<<<<<<<<
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
