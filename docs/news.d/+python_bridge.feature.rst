VHDL testbenches can now execute Python code and call Python functions, for
example NumPy reference models, through the ``python_pkg`` API: ``exec``,
``eval``/``eval_<type>``, and ``call``/``arg``/``kwarg``/``to_call_str``, the
latter also taking ``std_logic`` and arbitrarily wide ``unsigned``/``signed``
argument values and keyword argument groups combined with ``&``. Enable with
``add_vhdl_builtins()`` followed by ``add_python()``. The operations
implemented by the VUnit Python bridge are available on NVC and GHDL
(VHPIDIRECT) and on Questa/ModelSim (FLI): exchanging ``integer_array_t``
values as NumPy arrays, boolean, std_logic and width-checked vector results,
executing files with ``exec_file`` and isolating models in named sessions.
Riviera-PRO/Active-HDL (VHPI) use a VHPI application, which ``add_python()``
builds under the output path as well, and lack those operations. See
:ref:`python_bridge`.
