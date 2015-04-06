# Topological sorting of a directed ascylic graph
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com


class DependencyGraph:
    def __init__(self):
        self._forward = {}
        self._backward = {}
        self._nodes = []

    def toposort(self):
        def visit(node):
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
        new_dependency = (start not in self._forward or
                          end not in self._forward[start])

        if start not in self._forward:
            self._forward[start] = set()

        if end not in self._backward:
            self._backward[end] = set()

        self._forward[start].add(end)
        self._backward[end].add(start)

        return new_dependency

    def get_affected(self, nodes):
        affected = set()
        leafs = set(nodes)

        while len(leafs) > 0:
            next_leafs = set()
            for node in leafs:
                affected.add(node)
                if node not in self._forward:
                    continue

                for next_node in self._forward[node]:
                    next_leafs.add(next_node)
            leafs = next_leafs

        return affected

    def get_dependencies(self, node):
        return self._backward.get(node, [])
