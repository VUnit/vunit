# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import

"""
Verilog parsing functionality
"""

from os.path import dirname
from vunit.parsing.tokenizer import TokenStream, EOFException, LocationException
from vunit.parsing.verilog.tokenizer import VerilogTokenizer
from vunit.parsing.verilog.preprocess import VerilogPreprocessor
from vunit.parsing.verilog.tokens import *

import logging
LOGGER = logging.getLogger(__name__)


class VerilogParser(object):
    """
    Parse a single Verilog file
    """

    def __init__(self):
        self._tokenizer = VerilogTokenizer()
        self._preprocessor = VerilogPreprocessor(self._tokenizer)

    def parse(self, code, file_name, include_paths, content_hash=None):  # pylint: disable=unused-argument
        """
        Parse verilog code
        """
        include_paths = [] if include_paths is None else include_paths
        tokens = self._tokenizer.tokenize(code, file_name=file_name)
        included_files = []
        pp_tokens = self._preprocessor.preprocess(tokens,
                                                  include_paths=[dirname(file_name)] + include_paths,
                                                  included_files=included_files)

        return VerilogDesignFile.parse(pp_tokens, included_files)


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
    def parse(cls, tokens, included_files):
        """
        Parse verilog file
        """
        tokens = [token
                  for token in tokens
                  if token.kind not in (WHITESPACE,
                                        COMMENT,
                                        NEWLINE,
                                        MULTI_COMMENT)]
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

            if token.kind != IMPORT:
                continue
            import_token = token
            try:
                token = stream.pop()
                if token.kind == IDENTIFIER:
                    results.append(token.value)
                else:
                    LocationException.warning("import bad argument",
                                              token.location).log(LOGGER)
            except EOFException:
                LocationException.warning("EOF reached when parsing import",
                                          location=import_token.location).log(LOGGER)
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

            if not token.kind == IDENTIFIER:
                continue
            modulename = token.value

            try:
                token = stream.pop()
            except EOFException:
                continue

            if token.kind == HASH:
                results.append(modulename)
                continue
            elif token.kind == IDENTIFIER:
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
        if not tokens[idx].kind == PARAMETER:
            return None

        if tokens[idx + 2].kind == IDENTIFIER:
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

            if tokens[idx].kind == MODULE:
                if balance == 0:
                    name = tokens[idx + 1].value
                    parameters = []
                balance += 1

            elif tokens[idx].kind == ENDMODULE:
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
            if tokens[idx].kind == PACKAGE:
                idx += 1
                name = tokens[idx].value
                results.append(cls(name))
            idx += 1
        return results
