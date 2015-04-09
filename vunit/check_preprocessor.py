# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Preprocessing of check functions
"""

import re


class CheckPreprocessor(object):
    """
    Preprocessing of check functions adding helpful message to check_relation calls
    """
    def __init__(self):
        self._find_operators = re.compile(r'\?/=|\?<=|\?>=|\?<|\?>|\?=|/=|<=|>=|<|>|=', re.MULTILINE)
        self._find_quotes = re.compile(r'"|' + r"'", re.MULTILINE)
        self._find_comments = re.compile(r'--|/\*|\*/', re.MULTILINE)
        self._actual_formal = re.compile(r'=>(?P<actual>.*)', re.MULTILINE)
        self._leading_paranthesis = re.compile(r'[\s(]*')
        self._trailing_paranthesis = re.compile(r'[\s)]*')

    def run(self, code, file_name):  # pylint: disable=unused-argument
        """
        Preprocess code and return result also given the file_name of the original file
        """
        check_relation_pattern = re.compile(r'[^a-zA-Z0-9_](?P<call>check_relation)\s*(?P<parameters>\()',
                                            re.MULTILINE)

        check_relation_calls = list(check_relation_pattern.finditer(code))
        check_relation_calls.reverse()

        for match in check_relation_calls:
            relation, offset_to_point_before_closing_paranthesis = self._extract_relation(code, match)
            if relation:
                auto_msg_parameter = ', auto_msg => %s' % relation.make_error_msg()
                code = (code[:match.end('parameters') + offset_to_point_before_closing_paranthesis] +
                        auto_msg_parameter +
                        code[match.end('parameters') + offset_to_point_before_closing_paranthesis:])

        return code

    def _extract_relation(self, code, check):
        # pylint: disable=missing-docstring
        def end_of_parameter(token):
            return ((token.value == ',') and (token.level == 1)) or (token.level == 0)
        parameter_tokens = []
        index = 1
        relation = None
        for token in self._classify_tokens(code[check.start('parameters') + 1:]):
            add_token = True
            if token.type == Token.NORMAL:
                # The first found parameter containing a top-level relation is assumed
                # to be the expr parameter. This is a very reasonable assumption since
                # the return types of normal relational operators are boolean, std_ulogic,
                # or bit. The expr parameter is the only input of these types.
                if not relation:
                    if end_of_parameter(token):
                        relation = self._get_relation_from_parameter(parameter_tokens)
                        parameter_tokens = []
                        add_token = False

                if token.level == 0:
                    break
            elif token.is_comment:
                add_token = False

            if add_token:
                parameter_tokens.append(token)

            index += 1

        if not relation:
            raise SyntaxError('Failed to find relation in %s' %
                              code[check.start('call'): check.end('parameters') + index])

        return relation, index - 1

    @staticmethod
    def _classify_tokens(code):
        # pylint: disable=missing-docstring
        # pylint: disable=too-many-branches
        def even_quotes(code):
            n_quotes = 0
            for index in range(0, len(code), 2):
                if code[index] != "'":
                    break
                n_quotes += 1

            return (n_quotes % 2) == 0

        code_section = Token.NORMAL
        level = 1
        index = 0
        for char in code:
            token = Token(char)
            if code_section == Token.NORMAL:
                if char == '"':
                    code_section = Token.STRING
                elif char == "'":
                    # Used to avoid mixing up qualified expressions and
                    # character literals, e.g. std_logic'('1').
                    if even_quotes(code[index:]):
                        code_section = Token.CHARACTER_LITERAL
                elif code[index:index + 2] == '--':
                    code_section = Token.LINE_COMMENT
                elif code[index:index + 2] == '/*':
                    code_section = Token.BLOCK_COMMENT
                elif char == '(':
                    level += 1
                elif char == ')':
                    level -= 1

                next_code_section = code_section

            elif code_section == Token.STRING:
                if char == '"':
                    next_code_section = Token.NORMAL
            elif code_section == Token.CHARACTER_LITERAL:
                if char == "'":
                    next_code_section = Token.NORMAL
            elif code_section == Token.LINE_COMMENT:
                if char == '\n':
                    next_code_section = Token.NORMAL
            elif code_section == Token.BLOCK_COMMENT:
                if code[index - 1:index + 1] == '*/':
                    next_code_section = Token.NORMAL

            token.type = code_section
            token.level = level
            index += 1

            yield token

            code_section = next_code_section

    def _get_relation_from_parameter(self, tokens):
        # pylint: disable=missing-docstring
        def find_top_level_match(matches, tokens, top_level=1):
            if matches:
                for match in matches:
                    if not tokens[match.start()].is_quote and tokens[match.start()].level == top_level:
                        return match

            return None

        relation = None
        token_string = ''.join([token.value for token in tokens]).strip()
        actual_formal = find_top_level_match(self._actual_formal.finditer(token_string), tokens)
        if actual_formal:
            expr = actual_formal.group('actual')
            start = actual_formal.start('actual')
        else:
            expr = token_string
            start = 0

        # VHDL only allows one relational operator at the top level of an expression.
        # This operator divides the relation between left and right. The token.level
        # is normally one for the top level but may be higher if the expression is
        # enclosed with parenthesis.
        top_level = min([self._leading_paranthesis.match(expr).group().count('('),
                         self._trailing_paranthesis.match(expr[::-1]).group().count(')')]) + 1
        top_level_match = find_top_level_match(self._find_operators.finditer(expr), tokens[start:], top_level)
        if top_level_match:
            if top_level == 1:
                left = expr[:top_level_match.start()].strip()
                right = expr[top_level_match.end():].strip()
            else:
                left = expr[:top_level_match.start()].replace('(', '', top_level - 1).strip()
                right = expr[:top_level_match.end():-1].replace(')', '', top_level - 1).strip()[::-1]

            relation = Relation(left, top_level_match.group(), right)

        return relation


class Token(object):
    # pylint: disable=missing-docstring
    NORMAL = 0
    STRING = 1
    CHARACTER_LITERAL = 2
    LINE_COMMENT = 3
    BLOCK_COMMENT = 4

    def __init__(self, value):
        self.value = value
        self.type = None
        self.level = None

    @property
    def is_comment(self):
        return self.type in [self.LINE_COMMENT, self.BLOCK_COMMENT]

    @property
    def is_quote(self):
        return self.type in [self.CHARACTER_LITERAL, self.STRING]


class Relation(object):
    # pylint: disable=missing-docstring
    def __init__(self, left, operand, right):
        self._left = left
        self._operand = operand
        self._right = right

    def make_error_msg(self):
        return ('"Relation %s %s %s failed! Left is " & to_string(%s) & ". Right is " & to_string(%s) & "."'
                % (self._left.replace('"', '""'),
                   self._operand,
                   self._right.replace('"', '""'),
                   self._left,
                   self._right))
