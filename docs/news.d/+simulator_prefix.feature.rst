The context given to the setup function of a VUnit package tells where the selected simulator was
found with ``simulator_prefix`` and how the installation there was built with ``simulator_backend``,
the GHDL code generator for GHDL and ``None`` for a simulator with no such notion. A simulator
interface gives a simulator hook the same prefix with its new ``prefix`` property.
