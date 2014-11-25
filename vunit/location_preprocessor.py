# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

from re import compile, MULTILINE, DOTALL, split

class LocationPreprocessor:
    def __init__(self):
        self._subprograms = ['log', 'verbose_high2', 'verbose_high1', 'verbose',
                            'verbose_low1', 'verbose_low2', 'debug_high2', 'debug_high1',
                            'debug', 'debug_low1', 'debug_low2', 'info_high2', 'info_high1',
                            'info', 'info_low1', 'info_low2', 'warning_high2', 'warning_high1',
                            'warning', 'warning_low1', 'warning_low2', 'error_high2',
                            'error_high1', 'error', 'error_low1', 'error_low2', 'failure_high2',
                            'failure_high1', 'failure', 'failure_low1', 'failure_low2', 'check',
                            'check_true', 'check_false', 'check_implication',
                            'check_stable', 'check_not_unknown', 'check_zero_one_hot',
                            'check_one_hot', 'check_next', 'check_sequence', 'lock_entry',
                            'lock_exit', 'unlock_entry', 'unlock_exit']
    def add_subprogram(self, subprogram):
        self._subprograms.append(subprogram)
    @staticmethod
    def _find_closing_parenthesis(args):
        p = compile(r'\(|\)')
        balance = 0
        for m in p.finditer(args):
            balance += 1 if m.group() == '(' else -1
            if balance == 0:
                return m.start()
    def run(self, code, file_name):
        potential_subprogram_call_with_arguments_pattern = compile(r'[^a-zA-Z0-9_](?P<subprogram>' + '|'.join(self._subprograms) + \
                                                                   ')\s*(?P<args>\()', MULTILINE)
        potential_subprogram_call_without_arguments_pattern = compile(r'[^a-zA-Z0-9_](?P<subprogram>' + '|'.join(self._subprograms) + \
                                                                      ')\s*;', MULTILINE)
        
        matches = list(potential_subprogram_call_with_arguments_pattern.finditer(code))
        matches += list(potential_subprogram_call_without_arguments_pattern.finditer(code))
        matches.sort(key = lambda match : match.start('subprogram'), reverse = True)
        
        already_fixed_file_name_pattern = compile(r'file_name\s*=>', MULTILINE)
        already_fixed_line_num_pattern = compile(r'line_num\s*=>', MULTILINE)
        subprogram_declaration_start_backwards_pattern = compile(r'\s+(erudecorp|noitcnuf)')
                
        for m in matches:
            if subprogram_declaration_start_backwards_pattern.match(code[m.start():0:-1]):
                continue
            file_name_association = ', file_name => "' + file_name + '"'
            line_num_association = ', line_num => ' + str(1 + code[:m.start('subprogram')].count('\n'))
            if 'args' in m.groupdict():
                closing_paranthesis_start = self._find_closing_parenthesis(code[m.start('args'):])
                
                args = code[m.start('args') : m.start('args') + closing_paranthesis_start]
                already_fixed_file_name = already_fixed_file_name_pattern.search(args) != None 
                already_fixed_line_num = already_fixed_line_num_pattern.search(args) != None
                file_name_association = file_name_association if not already_fixed_file_name else ''
                line_num_association = line_num_association if not already_fixed_line_num else ''

                code = code[:m.start('args') + closing_paranthesis_start] + \
                line_num_association + file_name_association + code[m.start('args') + closing_paranthesis_start:]
            else:
                code = code[:m.end('subprogram')] + '(' + line_num_association[2:] + file_name_association + ')' + code[m.end('subprogram'):]
        return code
