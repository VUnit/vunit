# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Verilog parsing functionality
"""

from os.path import dirname
from vunit.parsing.tokenizer import TokenStream
from vunit.parsing.verilog.tokenizer import tokenize
from vunit.parsing.verilog.preprocess import preprocess
import vunit.parsing.verilog.tokenizer as tokenizer


class VerilogParser(object):
    """
    Parse a single Verilog file
    """

    def __init__(self):
        pass

    @staticmethod
    def parse(code, file_name, include_paths, content_hash):  # pylint: disable=unused-argument
        return VerilogDesignFile.parse(code, file_name, include_paths)


class VerilogDesignFile(object):
    """
    Contains Verilog objecs found within a file
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 modules=None,
                 packages=None,
                 imports=None,
                 instances=None,
                 included_files=None):
        self.modules = [] if modules is None else modules
        self.packages = [] if packages is None else packages
        self.imports = [] if imports is None else imports
        self.instances = [] if instances is None else instances
        self.included_files = [] if included_files is None else included_files

    @classmethod
    def parse(cls, code, file_name, include_paths=None):
        """
        Parse verilog file
        """
        include_paths = [] if include_paths is None else include_paths
        tokens = tokenize(code)
        included_files = []
        pp_tokens = preprocess(tokens, include_paths=[dirname(file_name)] + include_paths,
                               included_files=included_files)
        tokens = [token
                  for token in pp_tokens
                  if token.kind not in (tokenizer.WHITESPACE,
                                        tokenizer.COMMENT,
                                        tokenizer.NEWLINE,
                                        tokenizer.MULTI_COMMENT)]
        return cls(modules=VerilogModule.find(tokens),
                   packages=VerilogPackage.find(tokens),
                   imports=cls.find_imports(tokens),
                   instances=cls.find_instances(tokens),
                   included_files=included_files)

    @staticmethod
    def find_imports(tokens):
        """
        Find imports
        """
        results = []
        stream = TokenStream(tokens)
        while not stream.eof:
            token = stream.pop()
            if token.kind == tokenizer.IMPORT:
                stream.skip_until(tokenizer.IDENTIFIER)
                name = stream.pop().value
                results.append(name)
        return results

    @staticmethod
    def find_instances(tokens):
        """
        Find module instances
        """
        results = []
        stream = TokenStream(tokens)
        while not stream.eof:
            token = stream.pop()

            if not token.kind == tokenizer.IDENTIFIER:
                continue
            modulename = token.value

            token = stream.pop()
            if token.kind == tokenizer.HASH:
                results.append(modulename)
                continue
            elif token.kind == tokenizer.IDENTIFIER:
                results.append(modulename)
                continue

        return results


class VerilogModule(object):
    """
    A verilog module
    """

    def __init__(self, name, parameters):
        self.name = name
        self.parameters = parameters

    @classmethod
    def parse_parameter(cls, idx, tokens):
        """
        Parse parameter at point
        """
        if not tokens[idx].kind == tokenizer.PARAMETER:
            return None

        if tokens[idx + 2].kind == tokenizer.IDENTIFIER:
            return tokens[idx + 2].value
        else:
            return tokens[idx + 1].value
        assert False

    @classmethod
    def find(cls, tokens):
        """
        Find all modules within code, nested modules are ignored
        """
        idx = 0
        name = None
        balance = 0
        results = []
        parameters = []
        while idx < len(tokens):

            if tokens[idx].kind == tokenizer.MODULE:
                if balance == 0:
                    name = tokens[idx + 1].value
                    parameters = []
                balance += 1

            elif tokens[idx].kind == tokenizer.ENDMODULE:
                balance -= 1
                if balance == 0:
                    results.append(cls(name, parameters))

            elif balance == 1:
                parameter = cls.parse_parameter(idx, tokens)
                if parameter is not None:
                    parameters.append(parameter)

            idx += 1
        return results


class VerilogPackage(object):
    """
    A verilog package
    """

    def __init__(self, name):
        self.name = name

    @classmethod
    def find(cls, tokens):
        """
        Find all modules within code, nested modules are ignored
        """
        idx = 0
        results = []
        while idx < len(tokens):
            if tokens[idx].kind == tokenizer.PACKAGE:
                idx += 1
                name = tokens[idx].value
                results.append(cls(name))
            idx += 1
        return results
