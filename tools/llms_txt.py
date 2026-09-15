#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Generate llms.txt and llms-full.txt from the plain text build of the documentation.

The text build (sphinx -b text) renders every page completely, including the VHDL
package headers the pages include and the generated Python and command line
references, which is what makes it suitable for AI agents.
"""

from dataclasses import dataclass
from pathlib import Path

BASE_URL = "https://vunit.github.io"
TEXT_DIR_NAME = "_text"
API_SECTION = "API reference"
OTHER_SECTION = "Other"
OPTIONAL_SECTION = "Optional"

# The sections of llms.txt in order. A page belongs to the first section with a
# matching prefix, which is either a document name or a directory ending with "/".
# Pages matching no prefix are listed under OTHER_SECTION such that a new page never
# breaks the build. Pages under OPTIONAL_SECTION are left out of llms-full.txt.
SECTIONS = (
    ("Getting started", ("index", "installing", "user_guide", "cli", "examples", "hdl_libraries")),
    (
        "User guides",
        (
            "run/",
            "check/user_guide",
            "logging/",
            "com/",
            "data_types/user_guide",
            "data_types/event_user_guide",
            "id/",
            "verification_components/",
            "ci/",
        ),
    ),
    (API_SECTION, ("py/", "check/", "data_types/")),
    (OTHER_SECTION, ()),
    (OPTIONAL_SECTION, ("blog/", "release_notes", "testimonials/", "about", "contributing", "license")),
)
EXCLUDED = ("genindex",)
API_FILES = (
    ("VHDL API (JSON)", "api/vunit_lib.json"),
    ("Python API (JSON)", "api/python.json"),
)


@dataclass
class Page:
    """
    A page of the text build
    """

    docname: str
    title: str
    text: str

    @property
    def text_url(self):
        """
        URL of the text version of the page
        """
        return f"{BASE_URL}/{TEXT_DIR_NAME}/{self.docname}.txt"

    @property
    def html_url(self):
        """
        URL of the HTML version of the page
        """
        return f"{BASE_URL}/{self.docname}.html"


def _matches(docname, prefix):
    return docname == prefix or (prefix.endswith("/") and docname.startswith(prefix))


def _placement(docname):
    """
    The section index and the prefix index of a page, None for a page that is left out
    """
    if docname in EXCLUDED:
        return None
    for section_index, (_, prefixes) in enumerate(SECTIONS):
        for prefix_index, prefix in enumerate(prefixes):
            if _matches(docname, prefix):
                return section_index, prefix_index
    return [title for title, _ in SECTIONS].index(OTHER_SECTION), 0


def section_of(docname):
    """
    The llms.txt section of a page, None for a page that is left out
    """
    placement = _placement(docname)
    return None if placement is None else SECTIONS[placement[0]][0]


def read_pages(text_dir):
    """
    The pages of a text build in llms.txt order, without the pages that are left out
    """
    text_dir = Path(text_dir)
    pages = []
    for path in text_dir.rglob("*.txt"):
        docname = path.relative_to(text_dir).with_suffix("").as_posix()
        if _placement(docname) is None:
            continue
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        pages.append(Page(docname, lines[0].strip() if lines else docname, text))

    return sorted(pages, key=lambda page: (_placement(page.docname), page.docname))


def _summary(pages):
    """
    The first paragraph of the front page that is not an image
    """
    for page in pages:
        if page.docname == "index":
            paragraphs = page.text.split("\n\n")[1:]
            for paragraph in paragraphs:
                lines = [line.strip() for line in paragraph.strip().splitlines()]
                if lines and not lines[0].startswith("[image"):
                    return " ".join(lines)
    raise RuntimeError("The text build has no front page (index.txt) with a summary paragraph")


def render_llms_txt(pages, api=True):
    """
    The content of llms.txt

    :param api: Include the links to the API reference JSON files
    """
    lines = ["# VUnit", "", f"> {_summary(pages)}", ""]
    for title, _ in SECTIONS:
        entries = []
        if title == API_SECTION and api:
            entries += [f"- [{name}]({BASE_URL}/{path})" for name, path in API_FILES]
        entries += [
            f"- [{page.title}]({page.text_url}): {page.html_url}" for page in pages if section_of(page.docname) == title
        ]
        if entries:
            lines += [f"## {title}", "", *entries, ""]

    return "\n".join(lines)


def render_llms_full_txt(pages):
    """
    The content of llms-full.txt: all pages except the optional ones
    """
    return "\n".join(
        f"# {page.title}\n\nSource: {page.html_url}\n\n{page.text.rstrip()}\n"
        for page in pages
        if section_of(page.docname) != OPTIONAL_SECTION
    )


def write_llms_files(output_path, api=True):
    """
    Write llms.txt and llms-full.txt to a documentation build with a text build in TEXT_DIR_NAME

    :param api: Include the links to the API reference JSON files
    """
    output_path = Path(output_path)
    pages = read_pages(output_path / TEXT_DIR_NAME)
    (output_path / "llms.txt").write_text(render_llms_txt(pages, api), encoding="utf-8")
    (output_path / "llms-full.txt").write_text(render_llms_full_txt(pages), encoding="utf-8")
