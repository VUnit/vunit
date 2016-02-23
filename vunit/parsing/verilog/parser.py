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

import logging
from os.path import dirname, exists, abspath
from vunit.ostools import read_file
from vunit.parsing.tokenizer import TokenStream, EOFException, LocationException
from vunit.parsing.verilog.tokenizer import VerilogTokenizer
from vunit.parsing.verilog.preprocess import VerilogPreprocessor, find_included_file, Macro
from vunit.parsing.verilog.tokens import *
from vunit.hashing import hash_string

LOGGER = logging.getLogger(__name__)


class VerilogParser(object):
    """
    Parse a single Verilog file
    """

    def __init__(self, database=None):
        self._tokenizer = VerilogTokenizer()
        self._preprocessor = VerilogPreprocessor(self._tokenizer)
        self._database = database
        self._content_cache = {}

    def parse(self, code, file_name, include_paths=None, defines=None):
        """
        Parse verilog code
        """

        defines = {} if defines is None else defines
        include_paths = [] if include_paths is None else include_paths

        cached = self._lookup_parse_cache(file_name, include_paths, defines)
        if cached is not None:
            return cached

        initial_defines = dict((key, Macro(key, self._tokenizer.tokenize(value)))
                               for key, value in defines.items())
        tokens = self._tokenizer.tokenize(code, file_name=file_name)
        included_files = []
        pp_tokens = self._preprocessor.preprocess(tokens,
                                                  include_paths=[dirname(file_name)] + include_paths,
                                                  defines=initial_defines,
                                                  included_files=included_files)

        included_files_for_design_file = [name for _, name in included_files if name is not None]
        result = VerilogDesignFile.parse(pp_tokens, included_files_for_design_file)

        if self._database is None:
            return result

        self._store_result(file_name, result, included_files, defines)
        return result

    @staticmethod
    def _key(file_name):
        """
        Returns the database key for parse results of file_name
        """
        return ("CachedVerilogParser.parse(%s)" % abspath(file_name)).encode()

    def _store_result(self, file_name, result, included_files, defines):
        """
        Store parse result into back into cache
        """
        new_included_files = [(short_name, full_name, self._content_hash(full_name))
                              for short_name, full_name in included_files]
        key = self._key(file_name)
        self._database[key] = self._content_hash(file_name), new_included_files, defines, result
        return result

    def _content_hash(self, file_name):
        """
        Hash the contents of the file
        """
        if file_name is None or not exists(file_name):
            return None
        if file_name not in self._content_cache:
            self._content_cache[file_name] = "sha1:" + hash_string(read_file(file_name))
        return self._content_cache[file_name]

    def _lookup_parse_cache(self, file_name, include_paths, defines):
        """
        Use verilog code from cache
        """
        # pylint: disable=too-many-return-statements

        if self._database is None:
            return None

        key = self._key(file_name)
        if key not in self._database:
            return None

        old_content_hash, old_included_files, old_defines, old_result = self._database[key]
        if old_defines != defines:
            return None

        if old_content_hash != self._content_hash(file_name):
            return None

        for include_str, included_file_name, last_content_hash in old_included_files:
            if last_content_hash != self._content_hash(included_file_name):
                return None

            if find_included_file(include_paths, include_str) != included_file_name:
                return None

        LOGGER.debug("Re-using cached Verilog parse results for %s", file_name)

        return old_result


class VerilogDesignFile(object):
    """
    Contains Verilog objecs found within a file
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 modules=None,
                 packages=None,
                 imports=None,
                 package_references=None,
                 instances=None,
                 included_files=None):
        self.modules = [] if modules is None else modules
        self.packages = [] if packages is None else packages
        self.imports = [] if imports is None else imports
        self.package_references = [] if package_references is None else package_references
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
                   package_references=cls.find_package_references(tokens),
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
    def find_package_references(tokens):
        """
        Find package_references pkg::func
        """
        results = []
        stream = TokenStream(tokens)
        while not stream.eof:
            token = stream.pop()
            if token.kind == IMPORT:
                stream.skip_until(SEMI_COLON)
                if not stream.eof:
                    stream.pop()

            elif token.kind == IDENTIFIER and not stream.eof:
                kind = stream.pop().kind
                if kind == DOUBLE_COLON:
                    results.append(token.value)
                    stream.skip_while(IDENTIFIER, DOUBLE_COLON)
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
