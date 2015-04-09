# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the global test bench configuration
"""


import unittest
from os.path import join, dirname, exists
from shutil import rmtree
from os import makedirs

from vunit.test_configuration import TestConfiguration, Configuration


class TestTestConfiguration(unittest.TestCase):
    """
    Test the global test bench configuration
    """
    def setUp(self):
        self.cfg = TestConfiguration()

        self.output_path = out()
        if exists(self.output_path):
            rmtree(self.output_path)
        makedirs(self.output_path)

    def test_has_default_configuration(self):
        entity = EntityStub(name="tb_entity",
                            library_name="lib",
                            architecture_names={"arch": out("arch.vhd")},
                            generic_names=[])

        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity")])

    def test_set_generic(self):
        entity = EntityStub(name="tb_entity",
                            library_name="lib",
                            architecture_names={"arch": out("arch.vhd")},
                            generic_names=["global_generic"])

        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity")])

        self.cfg.set_generic("global_generic", False, scope="")
        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity", generics={"global_generic": False})])

        self.cfg.set_generic("global_generic", True, scope="lib")
        self.cfg.set_generic("generic_not_present", True, scope="lib")
        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity", generics={"global_generic": True})])

        self.cfg.set_generic("global_generic", None, scope="lib.tb_entity")
        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity", generics={"global_generic": None})])

    def test_set_pli(self):
        entity = EntityStub(name="tb_entity",
                            library_name="lib",
                            architecture_names={"arch": out("arch.vhd")},
                            generic_names=[])

        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity")])

        self.cfg.set_pli(["libglobal.so"], scope="")
        self.cfg.set_pli(["libfoo.so"], scope="lib2")
        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity", pli=["libglobal.so"])])

        self.cfg.set_pli(["libfoo.so"], scope="lib")
        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity", pli=["libfoo.so"])])

        self.cfg.set_pli(["libfoo2.so"], scope="lib.tb_entity")
        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity", pli=["libfoo2.so"])])

    def test_add_config(self):
        entity = EntityStub(name="tb_entity",
                            library_name="lib",
                            architecture_names={"arch": out("arch.vhd")},
                            generic_names=["value",
                                           "global_value"])

        for value in range(1, 3):
            self.cfg.add_config("lib.tb_entity",
                                name="value=%i" % value,
                                generics=dict(value=value,
                                              global_value="local value"))

        # Local value should take precedence
        self.cfg.set_generic("global_value", "global value")

        self.assertEqual(self.cfg.get_configurations(entity, "arch"),
                         [Configuration("lib.tb_entity.value=1",
                                        generics={"value": 1, "global_value": "local value"}),
                          Configuration("lib.tb_entity.value=2",
                                        generics={"value": 2, "global_value": "local value"})])

    @staticmethod
    def write_file(name, contents):
        with open(name, "w") as fwrite:
            fwrite.write(contents)


def out(*args):
    return join(dirname(__file__), "test_configuration_out", *args)


class EntityStub(object):
    def __init__(self, name, library_name, architecture_names, generic_names):
        self.name = name
        self.library_name = library_name
        self.architecture_names = architecture_names
        self.generic_names = generic_names
