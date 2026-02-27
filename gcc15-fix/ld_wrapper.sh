#!/bin/sh
# GCC 15 linker wrapper for Tiger
# Uses Apple native cctools ld with -read_only_relocs suppress
# Required because GCC 15 generates direct bl calls without PIC stubs
exec /usr/bin/ld -read_only_relocs suppress "$@"
