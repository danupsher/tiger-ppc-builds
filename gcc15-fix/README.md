# GCC 15 Tiger PPC Fix Scripts

These scripts fix two issues with GCC 15 on Mac OS X Tiger PPC:

1. **Missing PIC stubs**: GCC 15 generates direct `bl` calls to external functions without PIC symbol stubs. Tiger's dyld requires stubs for dynamic library calls.

2. **Broken C++ exception handling**: GCC 15's eh_frame uses PC-relative encodings that the cross-compiled ld64 cannot resolve, causing SIGBUS/SIGABRT when throwing exceptions.

## Files

- `fix_exc.py` — Assembly post-processor (runs via Python 3). Converts eh_frame to absolute pointer encoding, fixes LSDA tables, and generates PIC stubs for all external calls.
- `as_wrapper.sh` — Assembler wrapper. Intercepts GCC 15's assembly output, cleans corrupted bytes, and runs fix_exc.py before passing to Apple's assembler.
- `ld_wrapper.sh` — Linker wrapper. Calls Apple's native cctools ld with `-read_only_relocs suppress`.

## Installation

Requires Python 3 at `/usr/local/bin/python3` and Apple's Developer Tools (for `/usr/bin/as` and `/usr/bin/ld`).

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
