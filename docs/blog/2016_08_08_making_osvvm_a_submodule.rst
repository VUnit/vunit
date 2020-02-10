:tags: VUnit, OSVVM
:author: lasplund
:excerpt: 1

Making OSVVM a Git Submodule
====================================================

Prior to the 0.67.0 release the OSVVM library included with VUnit was a
modified copy of the original project to support GHDL. Nowadays the OSVVM
project supports GHDL natively and it is also available from GitHub so we
made it a submodule instead. The submodule is a way
to keep another Git repository (OSVVM) in a subdirectory of the VUnit
repository while keeping their histories separate. Updates to OSVVM doesn't
affect the VUnit history and vice versa. This makes no difference if you're
downloading VUnit from `PyPi <https://pypi.python.org/pypi/vunit_hdl>`__ but
if you're cloning VUnit from GitHub there are some things to consider. If you're
pulling version 0.67.0 to update your local Git clone the OSVVM subdirectory of
VUnit will become empty. To populate the directory you have to do

.. code-block:: console

   path/to/my/vunit/repo> git submodule update --init --recursive

This will populate the directory again with the files from OSVVM's GitHub repository.
If you're making a new VUnit clone you can skip this second step by doing

.. code-block:: console

   git clone --recursive https://github.com/VUnit/vunit.git
