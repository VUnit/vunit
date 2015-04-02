# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from re import compile, MULTILINE


class CheckPreprocessor:
    def __init__(self):
        self._find_operators = compile(r'\?/=|\?<=|\?>=|\?<|\?>|\?=|/=|<=|>=|<|>|=', MULTILINE)
        self._find_quotes = compile(r'"|' + r"'", MULTILINE)
        self._find_comments = compile(r'--|/\*|\*/', MULTILINE)
        self._actual_formal = compile(r'=>(?P<actual>.*)', MULTILINE)
        self._leading_paranthesis = compile(r'[\s(]*')
        self._trailing_paranthesis = compile(r'[\s)]*')

    def run(self, code, file_name):
        check_relation_pattern = compile(r'[^a-zA-Z0-9_](?P<call>check_relation)\s*(?P<parameters>\()', MULTILINE)

        check_relation_calls = list(check_relation_pattern.finditer(code))
        check_relation_calls.reverse()

        for c in check_relation_calls:
            relation, offset_to_point_before_closing_paranthesis = self._extract_relation(code, c)
            if relation:
                auto_msg_parameter = ', auto_msg => %s' % relation.make_error_msg()
                code = (code[:c.end('parameters') + offset_to_point_before_closing_paranthesis] +
                        auto_msg_parameter + code[c.end('parameters') + offset_to_point_before_closing_paranthesis:])

        return code

    def _extract_relation(self, code, check):
        def end_of_parameter(token):
            return ((token.value == ',') and (token.level == 1)) or (token.level == 0)
        parameter_tokens = []
        index = 1
        relation = None
        for t in self._classify_tokens(code[check.start('parameters') + 1:]):
            add_token = True
            if t.type == Token.NORMAL:
                # The first found parameter containing a top-level relation is assumed
                # to be the expr parameter. This is a very reasonable assumption since
                # the return types of normal relational operators are boolean, std_ulogic,
                # or bit. The expr parameter is the only input of these types.
                if not relation:
                    if end_of_parameter(t):
                        relation = self._get_relation_from_parameter(parameter_tokens)
                        parameter_tokens = []
                        add_token = False

                if t.level == 0:
                    break
            elif t.is_comment:
                add_token = False

            if add_token:
                parameter_tokens.append(t)

            index += 1

        if not relation:
            raise SyntaxError('Failed to find relation in %s' %
                              code[check.start('call'): check.end('parameters') + index])

        return relation, index - 1

    @staticmethod
    def _classify_tokens(s):
        def even_quotes(s):
            n_quotes = 0
            for index in range(0, len(s), 2):
                if s[index] != "'":
                    break
                n_quotes += 1

            return (n_quotes % 2) == 0

        code_section = Token.NORMAL
        level = 1
        index = 0
        for c in s:
            t = Token(c)
            if code_section == Token.NORMAL:
                if c == '"':
                    code_section = Token.STRING
                elif c == "'":
                    # Used to avoid mixing up qualified expressions and
                    # character literals, e.g. std_logic'('1').
                    if even_quotes(s[index:]):
                        code_section = Token.CHARACTER_LITERAL
                elif s[index:index+2] == '--':
                    code_section = Token.LINE_COMMENT
                elif s[index:index+2] == '/*':
                    code_section = Token.BLOCK_COMMENT
                elif c == '(':
                    level += 1
                elif c == ')':
                    level -= 1

                next_code_section = code_section

            elif code_section == Token.STRING:
                if c == '"':
                    next_code_section = Token.NORMAL
            elif code_section == Token.CHARACTER_LITERAL:
                if c == "'":
                    next_code_section = Token.NORMAL
            elif code_section == Token.LINE_COMMENT:
                if c == '\n':
                    next_code_section = Token.NORMAL
            elif code_section == Token.BLOCK_COMMENT:
                if s[index-1:index+1] == '*/':
                    next_code_section = Token.NORMAL

            t.type = code_section
            t.level = level
            index += 1

            yield t

            code_section = next_code_section

    def _get_relation_from_parameter(self, tokens):
        def find_top_level_match(matches, tokens, top_level=1):
            if matches:
                for m in matches:
                    if not tokens[m.start()].is_quote and tokens[m.start()].level == top_level:
                        return m

            return None

        relation = None
        token_string = ''.join([t.value for t in tokens]).strip()
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
        o = find_top_level_match(self._find_operators.finditer(expr), tokens[start:], top_level)
        if o:
            if top_level == 1:
                left = expr[:o.start()].strip()
                right = expr[o.end():].strip()
            else:
                left = expr[:o.start()].replace('(', '', top_level - 1).strip()
                right = expr[:o.end():-1].replace(')', '', top_level - 1).strip()[::-1]

            relation = Relation(left, o.group(), right)

        return relation


class Token:
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


class Relation:
    def __init__(self, left, op, right):
        self._left = left
        self._op = op
        self._right = right

    def make_error_msg(self):
        return ('"Relation %s %s %s failed! Left is " & to_string(%s) & ". Right is " & to_string(%s) & "."'
                % (self._left.replace('"', '""'),
                   self._op,
                   self._right.replace('"', '""'),
                   self._left,
                   self._right))
