# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com


from flask import Flask, jsonify, request


import ctypes
import _ctypes
from sys import platform
from os.path import isfile
from vunit.cosim import *
from base64 import b64encode
from io import BytesIO
from PIL import Image
import numpy


def b64enc_int_list(lst, width, height):
    """
    Encode list of numbers as a base64 encoded PNG image.

    :param lst: list of pixel values (len = height x width) in row-major order
    :param width: spatial width
    :param height: spatial height
    """
    buf = BytesIO()
    Image.fromarray(
        numpy.array(numpy.reshape(lst, (height, width)), dtype=numpy.uint16)
    ).save(buf, format="PNG")
    return b64encode(buf.getvalue()).decode("utf8")


def b64enc_list_of_int_lists(lst, width, height):
    """
    Convert list of lists of numbers to list of base64 encoded PNG images.

    :param lst: list of lists of pixel values (len = height x width) in row-major order
    :param width: spatial width
    :param height: spatial height
    """
    b64 = [[] for idx in range(len(lst))]
    for idx, val in enumerate(lst):
        b64[idx] = b64enc_int_list(val, width, height)
    return b64


class WebSim(object):
    def __init__(self, dist, load_cb=None, unload_cb=None, update_cb=None):
        self._load_cb = load_cb
        self._unload_cb = unload_cb
        self._update_cb = update_cb

        self._ghdl = None

        app = Flask("VUnitCoSim", static_folder=dist)

        self._app = app

        def index():
            return app.send_static_file("index.html")

        def favicon():
            return app.send_static_file("favicon.ico")

        def serve_js(path):
            return app.send_static_file("js/" + path)

        def serve_img(path):
            return app.send_static_file("img/" + path)

        def serve_css(path):
            return app.send_static_file("css/" + path)

        def serve_fonts(path):
            return app.send_static_file("fonts/" + path)

        def step():
            response = {"exitcode": 1}
            g = self._ghdl
            if g:
                mode = request.json["mode"]
                val = request.json["val"]
                step = 0
                if mode in "for":
                    val = g.read_integer(0, 0) + int(val)
                elif mode in "every":
                    step = val
                    val = g.read_integer(0, 0) + int(val)
                elif mode in "until":
                    val = -(2 ** 31) + int(val)

                g.write_integer(0, 2, int(step))
                if val is not 0:
                    # FIXME We should also consider values which are larger than 32bits
                    g.write_integer(0, 0, int(val))
                response = {"exitcode": 0}
            return jsonify(response)

        def load():
            response = {"exitcode": 0}
            if self._load_cb is not None:
                response = {"exitcode": self._load_cb()}
            return jsonify(response)

        def unload():
            response = {"exitcode": 0}
            if self._unload_cb is not None:
                response = {"exitcode": self._unload_cb()}
            return jsonify(response)

        def update():
            g = self._ghdl
            response = {"update": 0}
            if g:
                sts = g.read_integer(0, 3)
                if sts != 0:
                    if self._update_cb is not None:
                        response = self._update_cb()
                response["update"] = sts
                g.write_integer(0, 3, 0)
            return jsonify(response)

        self.add_url_rules(
            [
                ["/favicon.ico", "favicon", favicon],
                ["/", "index", index],
                ["/js/<path>", "js", serve_js],
                ["/img/<path>", "img", serve_img],
                ["/css/<path>", "css", serve_css],
                ["/fonts/<path>", "fonts", serve_fonts],
                ["/api/step", "step", step, ["GET", "POST"]],
                ["/api/load", "load", load],
                ["/api/unload", "unload", unload],
                ["/api/update", "update", update],
            ]
        )

    def add_url_rules(self, lst):
        for r in lst:
            if len(r) > 3:
                self._app.add_url_rule(r[0], r[1], r[2], methods=r[3])
            else:
                self._app.add_url_rule(r[0], r[1], r[2])

    def run(self, host="0.0.0.0"):
        self._app.run(host=host)

    def handler(self, h=None):
        if h is not None:
            self._ghdl = h
        else:
            return self._ghdl
