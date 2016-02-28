from subprocess import check_call
import sys

BUILD_NAME = sys.argv[1]


def call(cmd):
    check_call(cmd, shell=True)

call("python setup.py install")

if BUILD_NAME == "UNIT":
    if sys.version_info.major == 2:
        call("pip install mock")

    call("python -m unittest discover vunit/test/unit")

elif BUILD_NAME == "LINT":
    call("pip install pep8 pylint")

    # License header check does not work in travis
    call('python -m unittest discover vunit/test/lint -p "*pep8*"')
    call('python -m unittest discover vunit/test/lint -p "*pylint*"')

elif BUILD_NAME == "DOCS":
    call("pip install sphinx sphinx-argparse ablog")
    call("sphinx-build -T -W -E -a -n -b html docs docs/_build")

elif BUILD_NAME == "ACCEPTANCE":
    call('python -m unittest discover vunit/test/acceptance')

else:
    raise ValueError(BUILD_NAME)
