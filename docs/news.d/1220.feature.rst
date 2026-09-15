VHDL testbenches can now execute Python code and call Python functions
directly from the simulator: NumPy reference models, checkers, file access and
anything else the Python ecosystem offers. The VHDL API is ``python_pkg`` and
it is enabled with ``add_python()`` after ``add_vhdl_builtins()``. Values of
all the common VHDL types cross the boundary in both directions, as arguments
and as results. The API is available on NVC, GHDL and Questa/ModelSim through
the VUnit Python bridge, and on Riviera-PRO/Active-HDL through a VHPI
application, both of which ``add_python()`` builds under the output path. See
:ref:`python_bridge`.
