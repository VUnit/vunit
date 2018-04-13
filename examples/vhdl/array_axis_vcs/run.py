from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

vu = VUnit.from_argv()

vu.add_osvvm()
vu.add_array_util()
vu.add_verification_components()

lib = vu.add_library("lib")
lib.add_source_files(join(root, "src/*.vhd"))
lib.add_source_files(join(root, "src/**/*.vhd"))

#vu.set_sim_option('modelsim.init_files.after_load',['runall_addwave.do'])

vu.main()
