# -*- coding: utf-8 -*-

from sys import path as sys_path
from os.path import abspath
from pathlib import Path


ROOT = Path(__file__).resolve().parent

sys_path.insert(0, abspath("."))

# -- Sphinx Options -----------------------------------------------------------

# If your project needs a minimal Sphinx version, state it here.
needs_sphinx = "3.0"

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.extlinks",
    "sphinx.ext.intersphinx",
    "sphinx.ext.todo",
    "sphinxarg.ext",  # Automatic argparse command line argument documentation
    "exec",
]

autodoc_default_options = {
    "members": True,
}

# The suffix(es) of source filenames.
source_suffix = {
    ".rst": "restructuredtext",
    # '.txt': 'markdown',
    # '.md': 'markdown',
}

master_doc = "index"

project = "VUnit"
copyright = "2014-2022, Lars Asplund"
author = "LarsAsplund, kraigher and contributors"

version = ""
release = ""

language = "en"

exclude_patterns = ["release_notes/*.*"]

pygments_style = "sphinx"

todo_include_todos = False

# -- Options for HTML output ----------------------------------------------

if (ROOT / "_theme").is_dir():
    html_theme_path = ["."]
    html_theme = "_theme"
    html_theme_options = {
        "analytics_id": "UA-112393863-1",
        "logo_only": True,
        "vcs_pageview_mode": "blob",
        "style_nav_header_background": "#0c479d",
        "home_breadcrumbs": False,
    }
    html_context = {
        "conf_py_path": f"{ROOT.name}/",
        "display_github": True,
        "github_user": "VUnit",
        "github_repo": "vunit",
        "github_version": "master/",
    }
else:
    html_theme = "alabaster"

html_static_path = ["_static"]

html_logo = str(Path(html_static_path[0]) / "VUnit_logo.png")

html_favicon = str(Path(html_static_path[0]) / "vunit.ico")

# Output file base name for HTML help builder.
htmlhelp_basename = "VUnitDoc"

# -- InterSphinx ----------------------------------------------------------

intersphinx_mapping = {
    "python": ("https://docs.python.org/3.8/", None),
    "pytest": ("https://docs.pytest.org/en/latest/", None),
}

# -- ExtLinks -------------------------------------------------------------

extlinks = {
    "vunit_example": ("https://github.com/VUnit/vunit/tree/master/examples/%s/", "%s"),
    "vunit_file": ("https://github.com/VUnit/vunit/tree/master/%s/", "%s"),
    "vunit_commit": ("https://github.com/vunit/vunit/tree/%s/", "@%s"),
    "vunit_issue": ("https://github.com/VUnit/vunit/issues/%s/", "#%s"),
}
