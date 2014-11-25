# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

from vunit.dependency_graph import DependencyGraph
import unittest


class TestDependencyGraph(unittest.TestCase):
    def _add_nodes_and_dependencies(self, graph, nodes, dependencies):
        for n in nodes:
            graph.add_node(n)
        for d in dependencies:
            graph.add_dependency(d[0], d[1])
            
    def test_should_return_empty_compile_order_for_no_nodes(self):
        g = DependencyGraph()
        self.assertEqual(g.toposort(), [], 'Should return empty list')

    def test_should_return_list_of_nodes_when_there_are_no_dependencies(self):
        nodes = ['a', 'b', 'c', 'd']
        g = DependencyGraph()
        self._add_nodes_and_dependencies(g, nodes, [])
        result = g.toposort()
        self.assertEqual(result.sort(), nodes.sort(), 'Should return the node list in any order')

    def test_should_sort_in_topological_order_when_there_are_dependencies(self):
        nodes = ['a', 'b', 'c', 'd', 'e', 'f']
        dependencies = [('a', 'b'), ('a', 'c'), ('b', 'd'), ('e', 'f')]
        g = DependencyGraph()
        self._add_nodes_and_dependencies(g, nodes, dependencies)
        result = g.toposort()
        for d in dependencies:
            self.assertTrue(result.index(d[0]) < result.index(d[1]), "%s is not before %s" % d)

    def test_should_raise_runtime_error_exception_on_self_dependency(self):
        nodes = ['a', 'b', 'c', 'd']
        dependencies = [('a', 'b'), ('a', 'c'), ('b', 'd'), ('d', 'd')]
        g = DependencyGraph()
        self._add_nodes_and_dependencies(g, nodes, dependencies)
        self.assertRaises(RuntimeError, g.toposort)

    def test_should_raise_runtime_error_exception_on_long_circular_dependency(self):
        nodes = ['a', 'b', 'c', 'd']
        dependencies = [('a', 'b'), ('a', 'c'), ('b', 'd'), ('d', 'a')]
        g = DependencyGraph()
        self._add_nodes_and_dependencies(g, nodes, dependencies)
        self.assertRaises(RuntimeError, g.toposort)

    def test_should_resort_after_additions(self):
        nodes = ['a', 'b', 'c', 'd', 'e', 'f']
        dependencies = [('a', 'b'), ('a', 'c'), ('b', 'd'), ('e', 'f')]
        g = DependencyGraph()
        self._add_nodes_and_dependencies(g, nodes, dependencies)
        g.toposort()
        dependencies = [('a', 'b'), ('a', 'c'), ('b', 'd'), ('e', 'f'), ('b', 'g')]
        g.add_node('g')
        g.add_dependency('b', 'g')
        result = g.toposort()
        for d in dependencies:
            self.assertTrue(result.index(d[0]) < result.index(d[1]), "%s is not before %s" % d)

if __name__ == '__main__':
    unittest.main()
