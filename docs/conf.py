# -*- coding: utf-8 -*-

import os
import sys
from pathlib import Path

# blog_title = u"VUnit Blog"
# blog_baseurl = "http://vunit.github.io"
# blog_authors = {"Olof Kraigher": ("kraigher", None), "Lars Asplund": ("lasplund", None)}

# -- Disqus Integration -------------------------------------------------------

# You can enable Disqus_ by setting ``disqus_shortname`` variable.
# Disqus_ short name for the blog.
disqus_shortname = "vunitframework"

# -- Sphinx Options -----------------------------------------------------------

# If your project needs a minimal Sphinx version, state it here.
needs_sphinx = "1.2"

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.extlinks",
    "sphinx.ext.intersphinx",
    "sphinx.ext.todo",
    "sphinxarg.ext",  # Automatic argparse command line argument documentation
]

autodoc_default_flags = ["members"]

# The suffix(es) of source filenames.
source_suffix = ".rst"

master_doc = "index"

project = u"VUnit"
copyright = u"2014-2020, Lars Asplund"
author = u"lasplund"

version = ""
release = ""

language = None

exclude_patterns = ["release_notes/*.*"]

pygments_style = "sphinx"

todo_include_todos = False

# -- Options for HTML output ----------------------------------------------

# html_theme_path = []

# html_theme = "sphinx_rtd_theme"

html_theme_options = {
    "analytics_id": "UA-112393863-1",
    # "github_button": True,
    # "github_type": "star",
    # "github_user": "VUnit",
    # "github_repo": "vunit",
    # "description": "A test framework for HDL",
    # "logo": "VUnit_logo_420x420.png",
    # "logo_name": True,
    # "travis_button": True,
    # "page_width": "75%",
}

html_static_path = ["_static"]

html_logo = str(Path(html_static_path[0]) / "VUnit_logo_420x420.png")

html_favicon = str(Path(html_static_path[0]) / "vunit.ico")

# Output file base name for HTML help builder.
htmlhelp_basename = "vunitdoc"

# -- ExtLinks -------------------------------------------------------------

extlinks = {
    "vunit_example": ("https://github.com/VUnit/vunit/tree/master/examples/%s/", ""),
    "vunit_file": ("https://github.com/VUnit/vunit/tree/master/%s/", ""),
    "vunit_commit": ("https://github.com/vunit/vunit/tree/%s/", "@"),
    "vunit_issue": ("https://github.com/VUnit/vunit/issues/%s/", "#"),
}
