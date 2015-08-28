# Topological sorting of a directed ascylic graph
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to compute a dependency graph
"""


class DependencyGraph(object):
    """
    A dependency graph
    """
    def __init__(self):
        self._forward = {}
        self._backward = {}
        self._nodes = []

    def toposort(self):
        """
        Perform a topological sort returning a list of nodes such that
        every node is located after its dependency nodes
        """
        def visit(node):
            """
            Recursive function to visit a node and all its dependencies
            """
            if node in visited:
                raise RuntimeError('Found circular dependencies')

            visited.add(node)
            if node in self._forward:
                for other_node in self._forward[node]:
                    if other_node in not_visited:
                        visit(other_node)
            not_visited.remove(node)
            sorted_nodes.append(node)

        sorted_nodes = []
        visited = set()
        not_visited = set(self._nodes)
        while len(not_visited) > 0:
            node = list(not_visited)[0]
            visit(node)

        sorted_nodes = list(reversed(sorted_nodes))
        return sorted_nodes

    def add_node(self, node):
        self._nodes.append(node)

    def add_dependency(self, start, end):
        """
        Add a dependency edge between the start and end node such that
        end node depends on the start node
        """
        new_dependency = (start not in self._forward or
                          end not in self._forward[start])

        if start not in self._forward:
            self._forward[start] = set()

        if end not in self._backward:
            self._backward[end] = set()

        self._forward[start].add(end)
        self._backward[end].add(start)

        return new_dependency

    @staticmethod
    def _visit(nodes, graph):
        """
        Follow graph edges starting from the nodes iteratively
        returning all the nodes visited
        """
        dependencies = set()
        leafs = set(nodes)

        while len(leafs) > 0:
            next_leafs = set()
            for node in leafs:
                dependencies.add(node)
                if node not in graph:
                    continue

                for next_node in graph[node]:
                    next_leafs.add(next_node)
            leafs = next_leafs

        return dependencies

    def get_dependent(self, nodes):
        """
        Get all nodes which are directly or indirectly dependent on
        the input nodes
        """
        return self._visit(nodes, self._forward)

    def get_dependencies(self, nodes):
        """
        Get all nodes which are directly or indirectly dependencies of
        the input nodes
        """
        return self._visit(nodes, self._backward)

    def get_direct_dependencies(self, node):
        """
        Get the direct dependencies of node
        """
        return self._backward.get(node, set())
