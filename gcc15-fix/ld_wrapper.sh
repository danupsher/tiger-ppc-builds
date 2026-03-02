#!/bin/sh
exec /usr/bin/ld -read_only_relocs suppress -force_cpusubtype_ALL "$@"
