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

from vunit.test_configuration import TestConfiguration, Configuration, create_scope


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
        scope = create_scope("lib", "tb_entity")
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration()])

    def test_set_generic(self):
        scope = create_scope("lib", "tb_entity")
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration()])

        self.cfg.set_generic("global_generic", "global", scope=create_scope())
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration(generics={"global_generic": "global"})])

        self.cfg.set_generic("global_generic", "library", scope=create_scope("lib"))
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration(generics={"global_generic": "library"})])

        self.cfg.set_generic("global_generic", "entity", scope=create_scope("lib", "tb_entity"))
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration(generics={"global_generic": "entity"})])

    def test_set_pli(self):
        scope = create_scope("lib", "tb_entity")
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration("")])

        self.cfg.set_pli(["libglobal.so"], scope=create_scope())
        self.cfg.set_pli(["libfoo.so"], scope=create_scope("lib2"))
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration(pli=["libglobal.so"])])

        self.cfg.set_pli(["libfoo.so"], scope=create_scope("lib"))
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration(pli=["libfoo.so"])])

        self.cfg.set_pli(["libfoo2.so"], scope=create_scope("lib", "tb_entity"))
        self.assertEqual(self.cfg.get_configurations(scope),
                         [Configuration(pli=["libfoo2.so"])])

    def test_add_config(self):
        for value in range(1, 3):
            self.cfg.add_config(scope=create_scope("lib", "tb_entity"),
                                name="value=%i" % value,
                                generics=dict(value=value,
                                              global_value="local value"))

        self.cfg.add_config(scope=create_scope("lib", "tb_entity", "configured test"),
                            name="specific_test_config",
                            generics=dict())

        # Local value should take precedence
        self.cfg.set_generic("global_value", "global value")

        self.assertEqual(self.cfg.get_configurations(create_scope("lib", "tb_entity")),
                         [Configuration("value=1",
                                        generics={"value": 1, "global_value": "local value"}),
                          Configuration("value=2",
                                        generics={"value": 2, "global_value": "local value"})])

        self.assertEqual(self.cfg.get_configurations(create_scope("lib", "tb_entity", "test")),
                         [Configuration("value=1",
                                        generics={"value": 1, "global_value": "local value"}),
                          Configuration("value=2",
                                        generics={"value": 2, "global_value": "local value"})])

        self.assertEqual(self.cfg.get_configurations(create_scope("lib", "tb_entity", "configured test")),
                         [Configuration("specific_test_config", dict(global_value="global value"))])

    def test_disable_ieee_warnings(self):
        lib_scope = create_scope("lib")
        ent_scope = create_scope("lib", "entity")
        self.assertEqual(self.cfg.get_configurations(lib_scope),
                         [Configuration(disable_ieee_warnings=False)])

        self.assertEqual(self.cfg.get_configurations(ent_scope),
                         [Configuration(disable_ieee_warnings=False)])

        self.cfg.disable_ieee_warnings(ent_scope)
        self.assertEqual(self.cfg.get_configurations(lib_scope),
                         [Configuration(disable_ieee_warnings=False)])

        self.assertEqual(self.cfg.get_configurations(ent_scope),
                         [Configuration(disable_ieee_warnings=True)])

        self.cfg.disable_ieee_warnings(lib_scope)
        self.assertEqual(self.cfg.get_configurations(lib_scope),
                         [Configuration(disable_ieee_warnings=True)])

        self.assertEqual(self.cfg.get_configurations(ent_scope),
                         [Configuration(disable_ieee_warnings=False)])

    def test_more_specific_configurations(self):
        self.cfg.set_generic("name", "value", scope=create_scope("lib", "entity3"))
        self.cfg.set_generic("name", "value", scope=create_scope("lib", "entity", "test"))
        self.cfg.disable_ieee_warnings(scope=create_scope("lib", "entity_ieee", "test"))
        self.cfg.add_config(name="name", generics=dict(), scope=create_scope("lib", "entity2", "test"))
        self.assertEqual(self.cfg.more_specific_configurations(create_scope("lib", "entity")),
                         [create_scope("lib", "entity", "test")])
        self.assertEqual(self.cfg.more_specific_configurations(create_scope("lib", "entity2")),
                         [create_scope("lib", "entity2", "test")])
        self.assertEqual(self.cfg.more_specific_configurations(create_scope("lib", "entity3")),
                         [])
        self.assertEqual(self.cfg.more_specific_configurations(create_scope("lib", "entity_ieee")),
                         [create_scope("lib", "entity_ieee", "test")])

    @staticmethod
    def write_file(name, contents):
        with open(name, "w") as fwrite:
            fwrite.write(contents)


def out(*args):
    return join(dirname(__file__), "test_configuration_out", *args)
