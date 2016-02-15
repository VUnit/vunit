# Topological sorting of a directed ascylic graph
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

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
        sorted_nodes = []
        self._visit(sorted(self._nodes),
                    dict((key, sorted(values)) for key, values in self._forward.items()),
                    sorted_nodes.append)
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
    def _visit(nodes, graph, callback):
        """
        Follow graph edges starting from the nodes iteratively
        returning all the nodes visited
        """
        def visit(node):
            """
            Visit a single node and all following nodes in the graph
            that have not already been visisted.
            Detects circular dependencies
            """
            if node in path:
                start = path_ordered.index(node)
                raise CircularDependencyException(path_ordered[start:] + [node, ])

            path.add(node)
            path_ordered.append(node)
            if node in graph:
                for other_node in graph[node]:
                    if other_node not in visited:
                        visit(other_node)
            path.remove(node)
            path_ordered.pop()
            visited.add(node)
            callback(node)

        visited = set()
        for node in nodes:
            if node not in visited:
                path = set()
                path_ordered = []
                visit(node)

    def get_dependent(self, nodes):
        """
        Get all nodes which are directly or indirectly dependent on
        the input nodes
        """
        result = set()
        self._visit(nodes, self._forward, result.add)
        return result

    def get_dependencies(self, nodes):
        """
        Get all nodes which are directly or indirectly dependencies of
        the input nodes
        """
        result = set()
        self._visit(nodes, self._backward, result.add)
        return result

    def get_direct_dependencies(self, node):
        """
        Get the direct dependencies of node
        """
        return self._backward.get(node, set())


class CircularDependencyException(Exception):
    """
    Raised when there are circular dependencies
    """

    def __init__(self, path):
        Exception.__init__(self)
        self.path = path

    def __repr__(self):
        return "CircularDependencyException(%r)" % self.path
