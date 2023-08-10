:tags: VUnit, OSVVM, configurations
:author: lasplund
:excerpt: 1

Improved Support for VHDL Configurations and OSVVM
==================================================

For quite some time, several initiatives have been underway to improve the integration between VUnit and OSVVM. Examples
of these efforts are the `external logging framework integration feature
<https://vunit.github.io/logging/user_guide.html#external-logging-framework-integration>`__ and the OSVVM pull request
`#81 <https://github.com/OSVVM/OSVVM/pull/81>`__.

Another example is the introduction of support for top-level VHDL configurations which serves several purposes, for
example:

1.  Enabling the selection of the Device Under Test (DUT) to be used in a VUnit testbench.
2.  Direct support for running conventional OSVVM testbenches within the VUnit framework.

In this blog, we will primarily focus on top-level configurations but before delving into the specifics of these use cases, we will describe how VUnit addressed these issues in the past.

Selecting DUT Using Generics
----------------------------

Sometimes the VHDL DUT comes in different variants (architectures) and there is a need to verify all of these with the
same testbench. It could be an FPGA and an ASIC implementation or an RTL and a behavioral architecture. Before
supporting VHDL configurations, VUnit addressed this issue with a combination of generics and an if-generate statement
as showed in the example below. For the purpose of this blog, we have removed the complexities typically found in
real-world designs and chosen to focus on the fundamental principles. Thus, we will use a simple variable-width
flip-flop as the DUT for our demonstrations.

.. raw:: html
    :file: img/vhdl_configuration/selecting_dut_with_generics.html

This approach is straightforward: simply copy and paste the flip-flop instantiation, but modify the architecture to use
based on the ``dut_arch`` generic. While the approach is simple it also introduces code duplication which can be a bit
dangerous. In this case, since the copies are placed adjacent to each other, the risk of inadvertently changing one
without updating the other is somewhat mitigated.

If your DUT has numerous ports, you can consider leveraging the VHDL-2019 interface construct as a means to raise the
level of abstraction and reduce code duplication. This approach allows for a more concise representation of the design,
provided your simulator supports the latest VHDL standard.

.. NOTE::
    There is a proposed update to the VHDL standard related to this topic as it would fully remove the code duplication.
    `Issue #235 <https://gitlab.com/IEEE-P1076/VHDL-Issues/-/issues/235>`__ proposes that a string should be possible
    to use when specifying the architecture in an entity instantiation, i.e. ``"rtl"`` or ``"behavioral"`` rather than
    ``rtl`` or ``behavioral``. In our example we would simply have a single entity instantiation which architecture is
    specified with the ``dut_arch`` generic.

The various settings of the ``dut_arch`` generic are handled with a VUnit configuration in the Python run script.
Initially, the use of both VUnit and VHDL configuration concepts may appear confusing, but we will soon see that a VHDL
configuration is a special case of the broader VUnit configuration concept. In this example, we are also testing the DUT
with multiple ``width`` settings. Note how we can use the ``product`` function from ``itertools`` to iterate over all
combinations of ``dut_arch`` and ``width``. This is equivalent to two nested loops over these generics but scales better
as the number of generics to combine increases.

.. raw:: html
    :file: img/vhdl_configuration/create_vunit_configuration_for_selecting_dut.html

If we list all the tests, we will see that there are four for each test
case in the testbench, one for each combination of ``dut_arch`` and ``width``:

.. raw:: html
    :file: img/vhdl_configuration/tb_selecting_dut_with_generics_stdout.html

Selecting DUT Using VHDL Configurations
---------------------------------------

When using VHDL configurations we need three ingredients in our testbench

1. A component declaration for the DUT. In the example below it has been
   placed in the declarative part of the testbench architecture but it
   can also be placed in a separate package.
2. A component instantiation of the declared component. Note that the
   ``component`` keyword is optional and can be excluded.
3. A configuration declaration for each DUT architecture

.. raw:: html
    :file: img/vhdl_configuration/selecting_dut_with_vhdl_configuration.html

Instead of assigning a generic to select our architecture, we now specify which VHDL configuration our VUnit configuration should use:

.. raw:: html
    :file: img/vhdl_configuration/create_vunit_configuration_for_selecting_dut_with_a_vhdl_configuration.html

Incorporating VHDL configurations within VUnit configurations brings forth another advantage. From a VHDL point of view,
VHDL configurations are linked to entities, such as the testbench entity in our scenario. However, a VUnit configuration
can also be applied to specific test cases, opening up the possibility of using VHDL configurations at that finer level
of granularity. For instance, consider a situation where we have an FPGA and an ASIC implementation/architecure that
differ only in the memory IPs they use. In such a case, it might be sufficient to simulate only one of the architectures
for the test cases not involving memory operations.

To illustrate this using the flip-flop example, let's create a test where we set ``width`` to 32 and exclusively
simulate it using the RTL architecture:

.. raw:: html
    :file: img/vhdl_configuration/vhdl_configuration_on_a_test_case.html

Now, we have an additional entry in our list of tests:

.. raw:: html
    :file: img/vhdl_configuration/tb_selecting_dut_with_vhdl_configuration_stdout.html

Choosing between VHDL configurations and generics is primarily a matter of personal preference. The generic approach led
us to multiple direct entity instantiations and code duplication. However, the configuration approach demands a
component declaration, which essentially duplicates the DUT entity declaration. Additionally, VHDL configuration
declarations are also necessary.

Selecting Test Runner Using VHDL Configurations
-----------------------------------------------

In the previous examples, the VUnit test cases were located in a process called ``test_runner`` residing alongside the
DUT. This is the most straightforward arrangement, as it provides the test cases with direct access to the DUT's
interface. An alternative approach involves encapsulating ``test_runner`` within an entity, which is subsequently
instantiated within the testbench. Such a ``test_runner`` entity needs access to the ``runner_cfg`` and ``width``
generics, in addition to the ``clk_period`` constant and the interface ports of the DUT.

.. raw:: html
    :file: img/vhdl_configuration/test_runner_entity.html

Note that the runner configuration generic is called ``nested_runner_cfg`` and not ``runner_cfg``. The reason is that
``runner_cfg`` is the signature used to identify a testbench, the top-level of a simulation. The ``test_runner`` entity
is not a simulation top-level and must not be mistaken as such.

We can now replace the testbench ``test_runner`` process and watchdog with an instantiation of this component:

.. raw:: html
    :file: img/vhdl_configuration/test_runner_component_instantiation.html

Having relocated ``test_runner`` into an entity, we can have VHDL configurations selecting which test runner to use, and
let each such test runner represent a single test. This setup is the conventional methodology seen in OSVVM
testbenches. With VUnit's extended support for VHDL configurations, it becomes possible to keep that structure when
adding VUnit capabilities. For example, this is the architecture for the reset test:

.. raw:: html
    :file: img/vhdl_configuration/test_reset_architecture_of_test_runner.html

.. NOTE::
    When using several configurations to select what test runner to use, each test runner can only contain a single test, i.e. no test cases specified by the use of the ``run`` function are allowed.

Below are the two configurations that select this particular test along with one of the ``rtl`` and ``behavioral``
architectures for the DUT:

.. raw:: html
    :file: img/vhdl_configuration/test_reset_configurations.html

This example highlights a drawback of VHDL configurations: every combination of architectures to use in a test has to be
manually created. When we use generics and if generate statements to select architectures, we create all combinations
**programatically** in the Python script using the ``itertools.product`` function. Despite this, Python can continue to
play a role in alleviating certain aspects of the combinatorial workload:

.. raw:: html
    :file: img/vhdl_configuration/create_vunit_configuration_for_selecting_dut_and_runner_with_a_vhdl_configuration.html

.. raw:: html
    :file: img/vhdl_configuration/tb_selecting_test_runner_with_vhdl_configuration_stdout.html

That concludes our discussion for now. As always, we highly value your feedback and appreciate any insights you might have to offer.

