# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=unused-wildcard-import
# pylint: disable=wildcard-import

"""
Verilog parsing functionality
"""

import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from typing_extensions import Self
from vunit.ostools import read_file
from vunit.parsing.encodings import HDL_FILE_ENCODING
from vunit.parsing.tokenizer import Token, TokenStream, EOFException, LocationException
from vunit.parsing.verilog.tokenizer import VerilogTokenizer
from vunit.parsing.verilog.preprocess import (
    Defines,
    IncludePaths,
    IncludedFiles,
    VerilogPreprocessor,
    find_included_file,
    Macro,
)
from vunit.parsing.verilog.tokens import KeywordKind, TokenKind
from vunit.cached import file_content_hash

LOGGER = logging.getLogger(__name__)


class VerilogParser:
    """
    Parse a single Verilog file
    """

    _tokenizer: VerilogTokenizer
    _preprocessor: VerilogPreprocessor
    _database: Any
    _content_cache: Dict[str, str]

    def __init__(self, database: Optional[Any] = None):
        self._tokenizer = VerilogTokenizer()
        self._preprocessor = VerilogPreprocessor(self._tokenizer)
        self._database = database
        self._content_cache = {}

    def parse(
        self, file_name: str, include_paths: Optional[List[str]] = None, defines: Optional[Dict[str, Macro]] = None
    ) -> "VerilogDesignFile":
        """
        Parse verilog code
        """

        defines = {} if defines is None else defines
        include_paths = [] if include_paths is None else include_paths
        include_paths = [str(Path(file_name).parent)] + include_paths

        cached = self._lookup_parse_cache(file_name, include_paths, defines)
        if cached is not None:
            return cached

        initial_defines = dict((key, Macro(key, self._tokenizer.tokenize(value))) for key, value in defines.items())
        code = read_file(file_name, encoding=HDL_FILE_ENCODING)
        tokens = self._tokenizer.tokenize(code, file_name=file_name)
        included_files = []
        pp_tokens = self._preprocessor.preprocess(
            tokens,
            include_paths=include_paths,
            defines=initial_defines,
            included_files=included_files,
        )

        included_files_for_design_file = [name for _, name in included_files if name is not None]
        result = VerilogDesignFile.parse(pp_tokens, included_files_for_design_file)

        if self._database is None:
            return result

        self._store_result(file_name, result, included_files, defines)
        return result

    @staticmethod
    def _key(file_name: str) -> bytes:
        """
        Returns the database key for parse results of file_name
        """
        return f"CachedVerilogParser.parse({str(Path(file_name).resolve)})".encode()

    def _store_result(
        self, file_name: str, result: "VerilogDesignFile", included_files: List[Tuple[str, str]], defines: Defines
    ) -> "VerilogDesignFile":
        """
        Store parse result into back into cache
        """
        new_included_files = []
        for short_name, full_name in included_files:
            new_included_files.append((short_name, full_name, self._content_hash(full_name)))

        key = self._key(file_name)
        self._database[key] = (
            self._content_hash(file_name),
            new_included_files,
            defines,
            result,
        )
        return result

    def _content_hash(self, file_name: Optional[str]) -> Optional[str]:
        """
        Hash the contents of the file
        """
        if file_name is None or not Path(file_name).exists():
            return None
        if file_name not in self._content_cache:
            self._content_cache[file_name] = file_content_hash(
                file_name, encoding=HDL_FILE_ENCODING, database=self._database
            )
        return self._content_cache[file_name]

    def _lookup_parse_cache(
        self, file_name: str, include_paths: IncludePaths, defines: Defines
    ) -> "Optional[VerilogDesignFile]":
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


class VerilogDesignFile:
    """
    Contains Verilog objects found within a file
    """

    modules: "List[VerilogModule]"
    packages: "List[VerilogPackage]"
    imports: List[str]
    package_references: List[str]
    instances: List[str]
    included_files: IncludedFiles

    def __init__(  # pylint: disable=too-many-arguments
        self,
        modules: "Optional[List[VerilogModule]]" = None,
        packages: "Optional[List[VerilogPackage]]" = None,
        imports: Optional[List[str]] = None,
        package_references: Optional[List[str]] = None,
        instances: Optional[List[str]] = None,
        included_files: Optional[IncludedFiles] = None,
    ):
        self.modules = [] if modules is None else modules
        self.packages = [] if packages is None else packages
        self.imports = [] if imports is None else imports
        self.package_references = [] if package_references is None else package_references
        self.instances = [] if instances is None else instances
        self.included_files = [] if included_files is None else included_files

    @classmethod
    def parse(cls, tokens: List[Token], included_files: IncludedFiles) -> Self:
        """
        Parse verilog file
        """
        tokens = [
            token
            for token in tokens
            if token.kind not in (TokenKind.WHITESPACE, TokenKind.COMMENT, TokenKind.NEWLINE, TokenKind.MULTI_COMMENT)
        ]
        return cls(
            modules=VerilogModule.find(tokens),
            packages=VerilogPackage.find(tokens),
            imports=cls.find_imports(tokens),
            package_references=cls.find_package_references(tokens),
            instances=cls.find_instances(tokens),
            included_files=included_files,
        )

    @staticmethod
    def find_imports(tokens: List[Token]) -> List[str]:
        """
        Find imports
        """
        results: List[str] = []
        stream = TokenStream(tokens)
        while not stream.eof:
            token = stream.pop()

            if token.kind != KeywordKind.IMPORT:
                continue
            import_token = token
            try:
                token = stream.pop()
                if token.kind == TokenKind.IDENTIFIER:
                    results.append(token.value)
                else:
                    LocationException.warning("import bad argument", token.location).log(LOGGER)
            except EOFException:
                LocationException.warning("EOF reached when parsing import", location=import_token.location).log(LOGGER)
        return results

    @staticmethod
    def find_package_references(tokens: List[Token]) -> List[str]:
        """
        Find package_references pkg::func
        """
        results: List[str] = []
        stream = TokenStream(tokens)
        while not stream.eof:
            token = stream.pop()
            if token.kind == KeywordKind.IMPORT:
                stream.skip_until(TokenKind.SEMI_COLON)
                if not stream.eof:
                    stream.pop()

            elif token.kind == TokenKind.IDENTIFIER and not stream.eof:
                kind = stream.pop().kind
                if kind == TokenKind.DOUBLE_COLON:
                    results.append(token.value)
                    stream.skip_while(TokenKind.IDENTIFIER, TokenKind.DOUBLE_COLON)
        return results

    @staticmethod
    def find_instances(tokens: List[Token]) -> List[str]:
        """
        Find module instances
        """
        results: List[str] = []
        stream = TokenStream(tokens)
        while not stream.eof:
            token = stream.pop()

            if token.kind in (KeywordKind.BEGIN, KeywordKind.END):
                _parse_block_label(stream)
                continue

            if not token.kind == TokenKind.IDENTIFIER:
                continue
            modulename = token.value

            try:
                token = stream.pop()
            except EOFException:
                continue

            if token.kind == TokenKind.HASH:
                results.append(modulename)
            elif token.kind == TokenKind.IDENTIFIER:
                results.append(modulename)

        return results


def _parse_block_label(stream: TokenStream) -> None:
    """
    Parse a optional block label after begin|end keyword
    """
    try:
        token = stream.peek()

        if token.kind != TokenKind.COLON:
            # Is not block label
            return

        stream.pop()
        stream.expect(TokenKind.IDENTIFIER)

    except EOFException:
        return


class VerilogModule:
    """
    A verilog module
    """

    name: str
    parameters: List[str]

    def __init__(self, name: str, parameters: List[str]):
        self.name = name
        self.parameters = parameters

    @classmethod
    def parse_parameter(cls, idx: int, tokens: List[Token]) -> Optional[str]:
        """
        Parse parameter at point
        """
        if not tokens[idx].kind == KeywordKind.PARAMETER:
            return None

        if tokens[idx + 2].kind == TokenKind.IDENTIFIER:
            return tokens[idx + 2].value

        return tokens[idx + 1].value

    @classmethod
    def find(cls, tokens: List[Token]) -> List[Self]:
        """
        Find all modules within code, nested modules are ignored
        """
        idx = 0
        name = ""
        balance = 0
        results: List[Self] = []
        parameters: List[str] = []
        while idx < len(tokens):
            if tokens[idx].kind == KeywordKind.MODULE:
                if balance == 0:
                    name = tokens[idx + 1].value
                    parameters = []
                balance += 1

            elif tokens[idx].kind == KeywordKind.ENDMODULE:
                balance -= 1
                if balance == 0:
                    results.append(cls(name, parameters))

            elif balance == 1:
                parameter = cls.parse_parameter(idx, tokens)
                if parameter is not None:
                    parameters.append(parameter)

            idx += 1
        return results


class VerilogPackage:
    """
    A verilog package
    """

    name: str

    def __init__(self, name: str):
        self.name = name

    @classmethod
    def find(cls, tokens: List[Token]) -> List[Self]:
        """
        Find all modules within code, nested modules are ignored
        """
        idx = 0
        results: List[Self] = []
        while idx < len(tokens):
            if tokens[idx].kind == KeywordKind.PACKAGE:
                idx += 1
                name = tokens[idx].value
                results.append(cls(name))
            idx += 1
        return results
