Added experimental support for the yavs VHDL simulator (VHDL-2008 and VHDL-2019). Select it with
``VUNIT_SIMULATOR=yavs``; it is never picked automatically when another simulator is found. It adds the ``yavs.*``
compile and simulation options and the ``yavs_version`` package marker. The ``--gui`` flag runs ``yavs run --gui``
with the arguments of the normal run, which opens the run in ``yavs-gui``.
