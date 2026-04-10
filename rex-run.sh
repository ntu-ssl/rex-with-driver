#!/bin/bash

meson compile -C build && cd build/linux && ../../scripts/q-script/yifei-q
