# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Verilog preprocessing
"""

from __future__ import print_function
import argparse
from vunit.parsing.tokenizer import Tokenizer, Token, new_token_kind

TOKENIZER = Tokenizer()


def slice_value(token, start=None, end=None):
    return Token(token.kind, token.value[start:end])


def remove_value(token):
    return Token(token.kind, '')


def ignore_value(token):  # pylint: disable=unused-argument
    return None


PREPROCESSOR = TOKENIZER.add(
    "preprocessor",
    r"`[a-zA-Z][a-zA-Z0-9_]*",
    lambda token: slice_value(token, start=1))

STRING = TOKENIZER.add(
    "string",
    r'(?<!\\)"(.*?)(?<!\\)"',
    lambda token: slice_value(token, start=1, end=-1))

COMMENT = TOKENIZER.add(
    "comment",
    r'//.*$',
    lambda token: slice_value(token, start=2))


__KEYWORDS__ = {}


def new_keyword(name):
    """
    Create a new keyword
    """
    kind = new_token_kind(name)
    __KEYWORDS__[name] = kind
    return kind


def replace_keywords(token):
    if token.value in __KEYWORDS__:
        return Token(__KEYWORDS__[token.value], '')
    else:
        return token


MODULE = new_keyword("module")
ENDMODULE = new_keyword("endmodule")
PACKAGE = new_keyword("package")
IMPORT = new_keyword("import")
ENDPACKAGE = new_keyword("endpackage")
PARAMETER = new_keyword("parameter")

# Complete list of SystemVerilog keywords
__COMPLETE_KEYWORDS__ = """
accept_on
alias
always
always_comb
always_ff
always_latch
and
assert
assign
assume
automatic
before
begin
bind
bins
binsof
bit
break
buf
bufif0
bufif1
byte
case
casex
casez
cell
chandle
checker
class
clocking
cmos
config
const
constraint
context
continue
cover
covergroup
coverpoint
cross
deassign
default
defparam
design
disable
dist
do
edge
else
end
endcase
endchecker
endclass
endclocking
endconfig
endfunction
endgenerate
endgroup
endinterface
endmodule
endpackage
endprimitive
endprogram
endproperty
endspecify
endsequence
endtable
endtask
enum
event
eventually
expect
export
extends
extern
final
first_match
for
force
foreach
forever
fork
forkjoin
function
generate
genvar
global
highz0
highz1
if
iff
ifnone
ignore_bins
illegal_bins
implements
implies
import
incdir
include
initial
inout
input
inside
instance
int
integer
interconnect
interface
intersect
join
join_any
join_none
large
let
liblist
library
local
localparam
logic
longint
macromodule
matches
medium
modport
module
nand
negedge
nettype
new
nexttime
nmos
nor
noshowcancelled
not
notif0
notif1
null
or
output
package
packed
parameter
pmos
posedge
primitive
priority
program
property
protected
pull0
pull1
pulldown
pullup
pulsestyle_ondetect
pulsestyle_onevent
pure
rand
randc
randcase
randsequence
rcmos
real
realtime
ref
reg
reject_on
release
repeat
restrict
return
rnmos
rpmos
rtran
rtranif0
rtranif1
s_always
s_eventually
s_nexttime
s_until
s_until_with
scalared
sequence
shortint
shortreal
showcancelled
signed
small
soft
solve
specify
specparam
static
string
strong
strong0
strong1
struct
super
supply0
supply1
sync_accept_on
sync_reject_on
table
tagged
task
this
throughout
time
timeprecision
timeunit
tran
tranif0
tranif1
tri
tri0
tri1
triand
trior
trireg
type
typedef
union
unique
unique0
unsigned
until
until_with
untyped
use
uwire
var
vectored
virtual
void
wait
wait_order
wand
weak
weak0
weak1
while
wildcard
wire
with
within
wor
xnor
xor
""".split()

# Add keywords that we do not yet care about
for keyword in __COMPLETE_KEYWORDS__:
    if keyword not in __KEYWORDS__:
        new_keyword(keyword)

IDENTIFIER = TOKENIZER.add(
    "identifier",
    r"[a-zA-Z_][a-zA-Z0-9_]*",
    replace_keywords)

ESCAPED_NEWLINE = TOKENIZER.add(
    "escaped_newline",
    r"\\\n",
    ignore_value)

NEWLINE = TOKENIZER.add(
    "newline",
    r"\n",
    remove_value)

WHITESPACE = TOKENIZER.add(
    "whitespace",
    r"\s +",
    remove_value)

MULTI_COMMENT = TOKENIZER.add(
    "multi_line_comment",
    r"/\*(.|\n)*?\*/",
    lambda token: slice_value(token, start=2, end=-2))

SEMI_COLON = TOKENIZER.add(
    "semi_colon",
    r";",
    remove_value)

HASH = TOKENIZER.add(
    "hash",
    r"\#",
    remove_value)

EQUAL = TOKENIZER.add(
    "equal",
    r"=",
    remove_value)

LPAR = TOKENIZER.add(
    "left_parenthesis",
    r"\(",
    remove_value)

RPAR = TOKENIZER.add(
    "right_parenthesis",
    r"\)",
    remove_value)

COMMA = TOKENIZER.add(
    "comma",
    r",",
    remove_value)

OTHER = TOKENIZER.add(
    "other",
    r".+?")

TOKENIZER.finalize()


def tokenize(code):
    """
    Tokenize Verilog code to be preprocessed
    """

    return TOKENIZER.tokenize(code)


def main():
    """
    Print tokenization of a file
    """
    parser = argparse.ArgumentParser(description="Verilog preprocessor")

    parser.add_argument('file_name', nargs=1,
                        help='File name')

    args = parser.parse_args()
    with open(args.file_name[0], "r") as fptr:
        for tok in tokenize(fptr.read()):
            if tok.kind not in (WHITESPACE, NEWLINE):
                print(tok)


if __name__ == "__main__":
    main()
