# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Preprocessing of VHDL files to add file_name and line_num arguments to function calls
to enable better messages
"""


import re


class LocationPreprocessor(object):
    """
    Preprocessing of VHDL files to add file_name and line_num
    arguments to calls of known function and procedures
    """
    def __init__(self):
        self._subprograms_with_arguments = [
            'log', 'verbose_high2', 'verbose_high1', 'verbose',
            'verbose_low1', 'verbose_low2', 'debug_high2', 'debug_high1',
            'debug', 'debug_low1', 'debug_low2', 'info_high2', 'info_high1',
            'info', 'info_low1', 'info_low2', 'warning_high2', 'warning_high1',
            'warning', 'warning_low1', 'warning_low2', 'error_high2',
            'error_high1', 'error', 'error_low1', 'error_low2', 'failure_high2',
            'failure_high1', 'failure', 'failure_low1', 'failure_low2', 'check',
            'check_failed', 'check_true', 'check_false', 'check_implication',
            'check_stable', 'check_equal', 'check_not_unknown', 'check_zero_one_hot',
            'check_one_hot', 'check_next', 'check_sequence', 'check_relation',
            'lock_entry', 'lock_exit', 'unlock_entry', 'unlock_exit']
        self._subprograms_without_arguments = []

    def add_subprogram(self, subprogram):
        """
        Add a subprogram name to the list of known names to preprocess
        """
        self._subprograms_without_arguments.append(subprogram)
        self._subprograms_with_arguments.append(subprogram)

    @staticmethod
    def _find_closing_parenthesis(args):
        """
        Find the balanced closing parentesis

        @TODO duplicate with vhdl_parser.py
        """
        pattern = re.compile(r'\(|\)')
        balance = 0
        for match in pattern.finditer(args):
            balance += 1 if match.group() == '(' else -1
            if balance == 0:
                return match.start()

    _already_fixed_file_name_pattern = re.compile(r'file_name\s*=>', re.MULTILINE)
    _already_fixed_line_num_pattern = re.compile(r'line_num\s*=>', re.MULTILINE)
    _subprogram_declaration_start_backwards_pattern = re.compile(r'\s+(erudecorp|noitcnuf)')

    def run(self, code, file_name):
        """
        Return preprocessed code given file_name of original file
        """
        potential_subprogram_call_with_arguments_pattern = re.compile(
            r'[^a-zA-Z0-9_](?P<subprogram>' + '|'.join(self._subprograms_with_arguments) + r')\s*(?P<args>\()',
            re.MULTILINE)

        potential_subprogram_call_without_arguments_pattern = re.compile(
            r'[^a-zA-Z0-9_](?P<subprogram>' + '|'.join(self._subprograms_without_arguments) + r')\s*;',
            re.MULTILINE)

        matches = list(potential_subprogram_call_with_arguments_pattern.finditer(code))
        if self._subprograms_without_arguments:
            matches += list(potential_subprogram_call_without_arguments_pattern.finditer(code))
        matches.sort(key=lambda match: match.start('subprogram'), reverse=True)

        for match in matches:
            if self._subprogram_declaration_start_backwards_pattern.match(code[match.start():0:-1]):
                continue
            file_name_association = ', file_name => "' + file_name + '"'
            line_num_association = ', line_num => ' + str(1 + code[:match.start('subprogram')].count('\n'))
            if 'args' in match.groupdict():
                closing_paranthesis_start = self._find_closing_parenthesis(code[match.start('args'):])

                args = code[match.start('args'): match.start('args') + closing_paranthesis_start]
                already_fixed_file_name = self._already_fixed_file_name_pattern.search(args) is not None
                already_fixed_line_num = self._already_fixed_line_num_pattern.search(args) is not None
                file_name_association = file_name_association if not already_fixed_file_name else ''
                line_num_association = line_num_association if not already_fixed_line_num else ''

                code = (code[:match.start('args') + closing_paranthesis_start] +
                        line_num_association +
                        file_name_association + code[match.start('args') + closing_paranthesis_start:])
            else:
                code = (code[:match.end('subprogram')] +
                        '(' + line_num_association[2:] + file_name_association + ')' +
                        code[match.end('subprogram'):])
        return code
