# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Preprocessor base class.
"""


class Preprocessor:
    """
    Preprocessor base class.
    """

    def __init__(self, order: int = 0) -> None:
        """Preprocessor constructor.

        :param order: Controls which order preprocessors are applied to code. Preprocessor with lowest value \
is applied first. Preprocessors with the same value are applied in the order they were added.
        """
        self.order = order

    def run(self, code: str, file_name: str) -> str:  # pylint: disable=unused-argument
        """
        Preprocess code.

        :param code: Code to process.
        :param file_name: File name of original code file.

        :return: Preprocessed code
        """
        return code
