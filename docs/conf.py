# -*- coding: utf-8 -*-

from sys import path as sys_path
from os import environ
from os.path import abspath
from pathlib import Path
from shutil import copyfile


ROOT = Path(__file__).resolve().parent

sys_path.insert(0, abspath("."))

from create_release_notes import create_release_notes

create_release_notes()

copyfile(str(ROOT.parent / "LICENSE.rst"), str(ROOT / "license.rst"))

# -- Generate examples.inc ----------------------------------------------------

from examples import examples

examples()

# -- Sphinx Options -----------------------------------------------------------

# If your project needs a minimal Sphinx version, state it here.
needs_sphinx = "3.0"

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.extlinks",
    "sphinx.ext.intersphinx",
    "sphinx.ext.todo",
    "sphinxarg.ext",  # Automatic argparse command line argument documentation
]

autodoc_default_options = {
    "members": True,
}

autosectionlabel_prefix_document = True

# The suffix(es) of source filenames.
source_suffix = {
    ".rst": "restructuredtext",
    # '.txt': 'markdown',
    # '.md': 'markdown',
}

master_doc = "index"

project = "VUnit"
copyright = "2014-2024, Lars Asplund"
author = "LarsAsplund, kraigher and contributors"

version = ""
release = ""

language = "en"

exclude_patterns = ["release_notes/*.*", "news.d/*.*"]

todo_include_todos = False

# -- Options for HTML output --------------------------------------------------

html_theme = "furo"

html_css_files = [
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/fontawesome.min.css",
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/solid.min.css",
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/brands.min.css",
]

html_theme_options = {
    "source_repository": "https://github.com/VUnit/vunit",
    "source_branch": environ.get("GITHUB_REF_NAME", "master"),
    "source_directory": "docs",
    "sidebar_hide_name": True,
    "footer_icons": [
        {
            "name": "Twitter @VUnitFramework",
            "url": "https://twitter.com/VUnitFramework",
            "html": "",
            "class": "fa-solid fa-brands fa-twitter",
        },
        {
            "name": "Gitter VUnit/vunit",
            "url": "https://gitter.im/VUnit/vunit",
            "html": "",
            "class": "fa-solid fa-brands fa-gitter",
        },
        {
            "name": "GitHub VUnit/vunit",
            "url": "https://github.com/VUnit/vunit",
            "html": "",
            "class": "fa-solid fa-brands fa-github",
        },
    ],
}

html_static_path = ["_static"]

html_logo = str(Path(html_static_path[0]) / "VUnit_logo.png")

html_favicon = str(Path(html_static_path[0]) / "vunit.ico")

# Output file base name for HTML help builder.
htmlhelp_basename = "VUnitDoc"

# -- InterSphinx --------------------------------------------------------------

intersphinx_mapping = {
    "python": ("https://docs.python.org/3.13/", None),
    "pytest": ("https://docs.pytest.org/en/latest/", None),
    "osvb": ("https://umarcor.github.io/osvb", None),
}

nitpick_ignore_regex = [
    ("py:class", r".*"),
]
# -- ExtLinks -----------------------------------------------------------------

extlinks = {
    "vunit_example": ("https://github.com/VUnit/vunit/tree/master/examples/%s/", "%s"),
    "vunit_file": ("https://github.com/VUnit/vunit/tree/master/%s/", "%s"),
    "vunit_commit": ("https://github.com/vunit/vunit/tree/%s/", "@%s"),
    "vunit_issue": ("https://github.com/VUnit/vunit/issues/%s/", "#%s"),
}
