A VUnit package can provide a setup function with the ``setup`` key of its ``vunit_pkg.toml`` file.
The function is called with a :class:`PackageContext <vunit.package_context.PackageContext>` once the
sources of the package have been added and allows a package to do work that cannot be expressed with
static sources, such as building a native library or adding generated sources.
Running the function takes both the package declaring it and the ``add_package`` call allowing it with
``allow_setup=True``, such that a project adding a package of nothing but VHDL never runs code of the
package and the code it does allow to run is visible in the run script.
