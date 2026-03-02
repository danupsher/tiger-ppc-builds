# GCC 15 Tiger PPC Fix Scripts

These scripts fix three issues with GCC 15 on Mac OS X Tiger PPC:

1. **Missing PIC stubs**: GCC 15 generates direct `bl` (call) and `b` (tail call) instructions to external functions without PIC symbol stubs. Tiger's dyld requires stubs for dynamic library calls. The cctools linker only generates stubs for `bl`, not `b`, so both must be handled.

2. **Broken C++ exception handling**: GCC 15's eh_frame uses PC-relative encodings that the cross-compiled ld64 cannot resolve, causing SIGBUS/SIGABRT when throwing exceptions.

3. **cc1plus debug output corruption**: GCC 15's cc1plus emits `flags: %08lx ...` debug format strings into assembly output, which corrupts the assembled binary. These are replaced with `.text` directives.

## Files

- `fix_exc.py` — Assembly post-processor (runs via Python 3). Converts eh_frame to absolute pointer encoding, fixes LSDA tables, and generates PIC stubs for all external calls (both `bl` and `b` tail calls).
- `as_wrapper.sh` — Assembler wrapper. Intercepts GCC 15's assembly output, cleans corrupted bytes and debug output, and runs fix_exc.py before passing to Apple's assembler.
- `ld_wrapper.sh` — Linker wrapper. Calls Apple's native cctools ld with `-read_only_relocs suppress -force_cpusubtype_ALL`.

## Installation

Requires Python 3 at `/usr/local/bin/python3` and Apple's Developer Tools (for the system assembler `/usr/bin/as` and linker `/usr/bin/ld`).

**Important**: `/usr/bin/ld` must be the original cctools ld (847324 bytes, cctools-622.9~2), NOT ld64. The cctools ld correctly resolves SECTDIFF relocations in `__eh_frame`; ld64-62.1 does not. If you've installed Xcode and it replaced `/usr/bin/ld` with ld64, recover the original from the DeveloperToolsCLI.pkg on your Tiger install DVD.

```bash
# Install fix script
sudo cp fix_exc.py /usr/local/lib/gcc/powerpc-apple-darwin8/15.2.0/fix_exc.py

# Install assembler wrapper (replaces GCC 15's as)
sudo cp as_wrapper.sh /usr/local/libexec/gcc/powerpc-apple-darwin8/15.2.0/as
sudo chmod 755 /usr/local/libexec/gcc/powerpc-apple-darwin8/15.2.0/as

# Install linker wrapper (replaces GCC 15's ld)
# IMPORTANT: First remove any existing symlink at this path
sudo rm -f /usr/local/libexec/gcc/powerpc-apple-darwin8/15.2.0/ld
sudo cp ld_wrapper.sh /usr/local/libexec/gcc/powerpc-apple-darwin8/15.2.0/ld
sudo chmod 755 /usr/local/libexec/gcc/powerpc-apple-darwin8/15.2.0/ld
```

## What Changed (v2)

- **fix_exc.py**: Now handles `b` (tail call) instructions in addition to `bl` (branch-and-link). GCC 15 emits tail calls like `b ___cxa_atexit` which the cctools linker leaves as unresolved external relocations that dyld rejects at runtime.
- **as_wrapper.sh**: Added cleanup for cc1plus debug format strings (`flags: %08lx ...`) which were being emitted into assembly output. These are replaced with `.text` directives to prevent code from ending up in the wrong section.
- **ld_wrapper.sh**: Added `-force_cpusubtype_ALL` flag to allow linking ppc970 library objects (libstdc++, etc.) with ppc750 user code when targeting G3/G4 with `-mcpu=G3`.
