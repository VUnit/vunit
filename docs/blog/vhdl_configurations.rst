:tags: VUnit, OSVVM, configurations
:author: lasplund
:excerpt: 1

Improved Support for VHDL Configurations and OSVVM
==================================================

The last few months there have been a number of initiatives to improve
VUnit and OSVVM integration. For example, issue
`#776 <https://github.com/VUnit/vunit/pull/776>`__ discusses how we can
exchange VUnit and OSVVM log entires to provide consistents logs.
Another example is the added support of top-level VHDL configurations
which

1.  makes it possible to select what device under test (DUT) to use in a
    VUnit testbench
2.  simplifies running traditional OSVVM testbenches under VUnit

Top-level configurations will be the focus of this article but before we dig into the
details of these use cases we will describe how VUnit solved this in the
past.

Selecting DUT Using Generics
----------------------------

Sometimes the VHDL DUT comes in different variants (architectures) and
there is a need to verify all of these with the same testbench. It could
be an FPGA and an ASIC implimentation or an RTL and a behavioral
architecture. The way this has been done in VUnit in the past is to use
a combination of generics and an if-generate statement.

.. code:: vhdl

   entity tb_selecting_dut_with_generate_statement is
     generic(
       runner_cfg : string;
       dut_arch : string
     );
   end entity;

   architecture tb of tb_selecting_dut_with_generate_statement is
     ...
   begin
     test_runner : process
     begin
       test_runner_setup(runner, runner_cfg);

       while test_suite loop
         if run("Test reset") then
           ...
         elsif run("Test state change") then
           ...
         end if;
       end loop;

       test_runner_cleanup(runner);
     end process;

     dut_selection : if dut_arch = "rtl" generate
       dut : entity work.dff(rtl)
         port map(
           clk => clk,
           reset => reset,
           d => d,
           q => q
         );

     elsif dut_arch = "behavioral" generate
       dut : entity work.dff(behavioral)
         port map(
           clk => clk,
           reset => reset,
           d => d,
           q => q
         );

     else generate
       error("Unknown DUT architecture");
     end generate;

   end architecture;

The different settings of the ``dut_arch`` generics is handled with a
VUnit configuration in the Python run script.

The use of both VUnit and VHDL configuration concepts may be confusing
at first but as we will see the VHDL configuration is a special case of
the larger VUnit configuration concept.

.. code:: python

   tb = lib.test_bench("tb_selecting_dut_with_generate_statement")
   for arch in ["rtl", "behavioral"]:
       tb.add_config(name=f"dut_{arch}", generics=dict(dut_arch=arch))

If we list all tests we will now see that there are two for each test
case in the testbench.

.. code:: console

   $ python run.py --list                                                                                                                                        
   lib.tb_selecting_dut_with_generate_statement.dut_rtl.Test reset                   
   lib.tb_selecting_dut_with_generate_statement.dut_behavioral.Test reset                     
   lib.tb_selecting_dut_with_generate_statement.dut_rtl.Test state change            
   lib.tb_selecting_dut_with_generate_statement.dut_behavioral.Test state change                                                                
   Listed 4 tests

Using this approach to DUT selection has no real weaknesses. In fact, as
we will explain later, it may actually be the approach to prefer.
However, VHDL configurations is a well-established approach and VUnit
philosophy dictates that existing VHDL testbenches should be supported
with minimum adaptation.


Selecting DUT Using VHDL Configurations
---------------------------------------

When using VHDL configurations you need to have

1. A component declaration for the DUT. In the example below it has been
   placed in the declarative part of the testbench architecture but it
   can also be placed in a separate package.
2. A component instantiation of the declared component. Note that the
   ``component`` keyword is optional and can be excluded.
3. A configuration declaration for each DUT architecture

.. code:: vhdl

   architecture tb of tb_selecting_dut_with_vhdl_configuration is
     ...

     -- Component declaration
     component dff is
       port(
         clk : in std_logic;
         reset : in std_logic;
         d : in std_logic_vector(width - 1 downto 0);
         q : out std_logic_vector(width - 1 downto 0)
       );
     end component;
   begin
     test_runner : process
     begin
       test_runner_setup(runner, runner_cfg);

       while test_suite loop
         if run("Test reset") then
           ...
         elsif run("Test state change") then
           ...
         end if;
       end loop;

       test_runner_cleanup(runner);
     end process;

     ...

     -- Component instantiation
     dut : component dff
       port map(
         clk => clk,
         reset => reset,
         d => d,
         q => q
       );
   end architecture;

   -- Configuration declarations
   configuration rtl of tb_selecting_dut_with_vhdl_configuration is
     for tb
       for dut : dff
         use entity work.dff(rtl);
       end for;
     end for;
   end;

   configuration behavioral of tb_selecting_dut_with_vhdl_configuration is
     for tb
       for dut : dff
         use entity work.dff(behavioral);
       end for;
     end for;
   end;

The result when listing the tests is the same as when we use generics to
switch DUT architectures.

.. code:: console

   $ python run.py --list
   lib.tb_selecting_dut_with_vhdl_configuration.rtl.Test reset
   lib.tb_selecting_dut_with_vhdl_configuration.behavioral.Test reset
   lib.tb_selecting_dut_with_vhdl_configuration.rtl.Test state change
   lib.tb_selecting_dut_with_vhdl_configuration.behavioral.Test state change

The main drawback with VHDL configurations is that the VHDL standard
doesn’t allow them to be combined with top-level generics. This is a
fundamental problem for VUnit which use a ``runner_cfg`` generic to pass
information from the VUnit run script to the testbench, for example what
test cases to run.

.. code:: vhdl

   entity tb_selecting_test_runner_with_vhdl_configuration is
     generic(runner_cfg : string := null_runner_cfg);
   end entity;

The solution to this is not to remove the ``runner_cfg`` generic but to
give it the initial value ``null_runner_cfg`` to indicate that it holds
no information. Despite not providing any information the generic must
still be present since it is the signature used by VUnit to identify
VUnit testbenches when scanning the code base.

When ``test_runner_setup`` is called with a ``null_runner_cfg`` the
procedure will get its configuration from a file named ``runner_cfg``
that is placed by VUnit in the simulator working directory.

Traditional OSVVM Testbenches
-----------------------------

In the previous example the VUnit test cases were located in a process
called ``test_runner``. Having ``test_runner`` co-located with the DUT
is the simplest possible arrangement since the test cases have direct
access to the DUT interface. An alternative to this arrangement is to
place ``test_runner`` in an separate entity which is instantiated into
the the testbench. Such a ``test_runner`` entity needs access to
``runner_cfg`` and the interface ports of the DUT.

.. code:: vhdl

   entity test_runner is
     generic(
       nested_runner_cfg : string
     );
     port(
       reset : out std_logic;
       clk : in std_logic;
       d : out std_logic_vector(width - 1 downto 0);
       q : in std_logic_vector(width - 1 downto 0)
     );
   end entity;

Note that the runner configuration generic is called
``nested_runner_cfg`` and not ``runner_cfg`` which is the case in the
testbench. As mentioned before ``runner_cfg`` is the signature used to
identify a testbench, the top-level of a simulation. The ``test_runner``
entity is not a simulation top-level and must not be mistaken for being
one.

We can now replace the ``test_runner`` process with an instantiation of
this entity.

.. code:: vhdl

   test_runner_inst : test_runner
     generic map(
       nested_runner_cfg => runner_cfg
     )
     port map(
       reset => reset,
       clk => clk,
       d => d,
       q => q
     );

Now that we’ve moved ``test_runner`` to a separate entity we can take
this arrangement one step further. Rather than having all test cases in
a single architecture to the ``test_runner`` entity we can put each test
case in a separate architecture along with a configuration selecting
that architecture for the testbench. Just like we used configurations to
select the DUT architecture.

.. code:: vhdl

   architecture test_reset_a of test_runner is
   begin
     process
     begin
       test_runner_setup(runner, nested_runner_cfg);

       -- Test code here

       test_runner_cleanup(runner);
     end process;
   end;

   configuration test_reset of tb_selecting_test_runner_with_vhdl_configuration is
     for tb
       for test_runner_inst : test_runner
         use entity work.test_runner(test_reset_a);
       end for;
     end for;
   end;

This arrangement is the traditional approach to OSVVM testbenches and
with the extended VUnit support for VHDL configurations you can now keep
that structure when adding VUnit capabilities. Below is the updated
testbench with the component declaration and instantiation.

.. code:: vhdl

   architecture tb of tb_selecting_test_runner_with_vhdl_configuration is
     ...

     -- Component declaration
     component test_runner is
       generic(
         nested_runner_cfg : string
       );
       port(
         reset : out std_logic;
         clk : in std_logic;
         d : out std_logic_vector(width - 1 downto 0);
         q : in std_logic_vector(width - 1 downto 0)
       );
     end component;
   begin
     test_runner_inst : test_runner
       generic map(
         nested_runner_cfg => runner_cfg
       )
       port map(
         reset => reset,
         clk => clk,
         d => d,
         q => q
       );

     ...

     dut : entity work.dff(rtl)
       port map(
         clk => clk,
         reset => reset,
         d => d,
         q => q
       );
   end architecture;

If we list all tests to the testbench we will see this.

.. code:: console

   $ python run.py --list
   lib.tb_selecting_test_runner_with_vhdl_configuration.test_reset
   lib.tb_selecting_test_runner_with_vhdl_configuration.test_state_change

It looks like a regular VUnit testbench with two test cases but in
reality it is a testbench with two configurations. In practice that
makes no bigger difference.

In the example above the DUT was an entity instantiation but nothing
prevents us from also making it a configurable component instantiation.
That will allow us to create configurations for all four combinations of
test case and DUT architecture. Here is one of those configuration
declarations:

.. code:: vhdl

   configuration test_reset_rtl of tb_selecting_test_runner_with_vhdl_configuration is
     for tb
       for test_runner_inst : test_runner
         use entity work.test_runner(test_reset_a);
       end for;

       for test_fixture
         for dut : dff
           use entity work.dff(rtl);
         end for;
       end for;
     end for;
   end;

This highlights a problem with configurations. All configuration
combinations have to be coded manually which doesn’t scale well as more
configuration options are added. What is needed is a way to do this
programatically and we’ll get back to that topic a bit later.

Extending VHDL Configurations
-----------------------------

Rather than treating VHDL configrations as a separate concept, VUnit
treats it as a part of the VUnit configuration concept. You can think of
the VHDL configuration as a VUnit configuration defined in VHDL instead
of in the Python run script.

Being a part of the VUnit configuration concept means that you can
extend the VHDL configration with the other features provided by VUnit
configurations. This is done in the run script and the first step is to
retrieve one or several VHDL configrations from the testbench using
pattern matching. In the example below the pattern (``"*"``) matches all
VHDL configurations. This is also the default pattern if no argument is
provided to the ``get_configs`` method.

.. code:: python

   tb = lib.test_bench("tb_selecting_dut_with_vhdl_configuration")
   configs = tb.get_configs("*")

Then we can extend the configurations. For example

.. code:: python

   configs.set_post_check(my_post_check_function)

It’s also possible to loop over the matching configurations and deal
with them independently. For example

.. code:: python

   for config in configs:
       config.set_pre_config(my_create_pre_config_function(config_name=config.name))

The problem with generics remains though and VHDL prevents us from doing
something like this:

.. code:: python

   config.set_generic("my_integer_generic", 17)

Using testbench generics to generate variants of the same testbench is
one of the more commonly used features for VUnit configurations which
makes this a serious limitation.

Dealing with the Generics Dilemma
---------------------------------

To be written.
