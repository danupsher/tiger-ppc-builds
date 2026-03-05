# Tiger PPC Builds

Pre-compiled modern software for **Mac OS X 10.4 Tiger** on **PowerPC**.

These are statically linked binaries cross-compiled from Linux, targeting `powerpc-apple-darwin8` with the 10.4 universal SDK. Download, copy to your Tiger Mac, and run.

## Available Packages

| Package | Version | GCC 15 / ld64 | GCC 7.5 / G5 | GCC 7.5 / G3 | Notes |
|---------|---------|:-------------:|:------------:|:------------:|-------|
| GCC | 15.2.0 | **Yes** | Yes | -- | C/C++ compiler with C++23. 137/137 tests. |
| Python | 3.13.12 | **Yes** | Yes | Yes | Full stdlib: sqlite3, ssl, ctypes, readline, lzma, bz2 |
| OpenSSL | 3.6.1 | **Yes** | Yes | Yes | Static libraries + headers |
| curl | 8.12.1 | **Yes** | Yes | Yes | HTTPS via OpenSSL 3.6.1, TLS 1.2/1.3 |
| git | 2.48.1 | **Yes** | Yes | Yes | Full git with HTTPS clone support |
| ffmpeg | 7.1.1 | **Yes** | Yes | Yes | ffmpeg + ffprobe |

### Which release should I download?

- **GCC 15 / ld64** -- recommended: Latest builds compiled with GCC 15.2.0 using the fully local ld64 pipeline. Better optimized code, C++17/20/23 standards compliance. G3/G4/G5 compatible.
- **GCC 7.5 / G3**: Compiled with GCC 7.5.0. G3/G4/G5 compatible.
- **GCC 7.5 / G5**: Compiled with GCC 7.5.0. G5 only.

## Compatibility

All GCC 15 / ld64 builds and GCC 7.5 / G3 builds run on **any PowerPC Mac** -- G3, G4, or G5. GCC 7.5 / G5 builds require a G5 processor.

**OS**: Mac OS X 10.4.x Tiger, any point release.

## Installation

Download the tarball from [Releases](https://github.com/danupsher/tiger-ppc-builds/releases), then:

```bash
tar xzf <package>.tar.gz -C /
```

Most binaries install to `/usr/local/bin`. See individual release notes for details.

### Package-specific notes

**Python 3.13**: Set `PYTHONHOME=/usr/local` before running.

**GCC 15**: Installs to `/usr/local/bin/gcc` and `/usr/local/bin/g++`. G3/G4/G5 compatible. Includes assembly fixup scripts for Tiger compatibility. Requires original Apple Developer Tools for the system assembler and linker. **Important**: `/usr/bin/ld` must be the original cctools ld, not ld64 -- see `gcc15-fix/README.md`.

**curl**: CA certificate bundle at `/usr/local/etc/ssl/cert.pem`.

**git**: Set `GIT_EXEC_PATH=/usr/local/libexec/git-core` and `SSL_CERT_FILE=/usr/local/etc/ssl/cert.pem`.

## Test Results

All packages verified on a real iMac G5 -- PowerMac8,2, PPC G5 2GHz, 1GB RAM, Tiger 10.4.11.
**All tests passing** across two test suites:

| Package | Tests | Count | Result |
|---------|-------|:-----:|--------|
| GCC 15 | C/C++ compile+run, STL, exceptions, C++17/20/23, optimization, linking, patterns | 137 | All pass |
| Python 3.13 | Core language, 48 stdlib modules, file I/O, subprocess, threading, sqlite3, compression, ssl/HTTPS | 105 | All pass |
| git 2.48.1 | init/add/commit/log, branch/merge/tag/stash/reset, cherry-pick/blame/archive, format-patch/apply/am, grep, HTTPS clone | 58 | All pass |
| ffmpeg 7.1.1 | Audio gen, format conversion, filters, ffprobe, video gen, containers, metadata | 46 | All pass |
| curl 8.12.1 | HTTP/HTTPS verbs, headers, auth, redirects, downloads, TLS verification, file:// protocol | 29 | All pass |
| OpenSSL 3.6.1 | Tested via Python ssl and curl HTTPS: contexts, ciphers, TLS 1.2, cert verification | 24 | All pass |

Test suites: [`run_309_tests.sh`](run_309_tests.sh) (package integration), [`test_gcc15_comprehensive.sh`](test_gcc15_comprehensive.sh) (137 GCC compiler tests)

## How These Were Built

### GCC 15 / ld64 builds -- recommended
Cross-compiled on Linux using a **fully self-contained pipeline** -- no Mac needed:
- **GCC 15.2.0** cc1/cc1plus as native x86_64 ELF binaries
- **ld64-97.17** -- Apple's linker, built for Linux
- cctools assembler for Mach-O object files
- fix_exc_ld64.py + ppc-darwin-fixup.py for assembly post-processing
- tiger-compat.h for 10.5+ API shims when building against the Tiger SDK
- Apple 10.4u SDK for headers and frameworks
- `-mcpu=G3` targeting -- runs on any PPC Mac

The native GCC 15 compiler itself (`gcc-15.2.0-g3`) was also built with this pipeline -- GCC 15 compiling GCC 15 source into a PPC binary.

### GCC 7.5 builds -- legacy
Cross-compiled on Linux using GCC 7.5.0 with SSH-proxied linking on a real Tiger Mac.

## Cross-Compiler Toolchains

### GCC 15 + ld64 v1.3 -- Standalone, No Mac Needed

**[Download PPC Tiger Cross-Compiler v1.3, GCC 15.2.0 + ld64](https://github.com/danupsher/tiger-ppc-builds/releases/tag/gcc15-xcompiler-1.3)** -- 66 MB

```bash
tar xf ppc-tiger-gcc15-xcompiler.tar.gz
export PATH="$PWD/ppc-tiger-xcompiler/bin:$PATH"

# C
ppc-ld64-gcc -O2 hello.c -o hello

# C++ with exceptions, STL, C++17
ppc-ld64-g++ -std=c++17 -O2 program.cpp -o program
```

Everything runs locally on x86_64 Linux. No Mac, no SSH. Includes GCC 15 cc1/cc1plus, ld64-97.17, cctools assembler, assembly fixup scripts, runtime libraries, tiger-compat.h, and the Mac OS X 10.4u SDK. Targets `-mcpu=G3` by default -- binaries run on any PPC Mac. **137/137 comprehensive tests passing** (C11, C++17/20/23, exceptions, STL, optimization, real-world patterns). Successfully builds a full Mozilla-based browser from source.

**v1.3 changes**: G3-safe runtime libraries (libgcc.a, libstdc++.a rebuilt with -mcpu=G3), assembler wrapper runs fix_exc_ld64.py on all input, libstdc++ cross-compiled from GCC 15 source for Tiger.

**Requirements**: x86_64 Linux, Python 3, ~250 MB disk space.

### GCC 7.5 -- SSH-based

**[Download PPC Tiger Cross-Compiler, GCC 7.5.0](https://github.com/danupsher/tiger-ppc-builds/releases/tag/cross-compiler-1.0)** -- 86 MB

Compiles and assembles locally on x86_64 Linux. Final linking runs via SSH on your Tiger Mac.

## ld64 Pipeline Source

The [`ld64-pipeline/`](ld64-pipeline/) directory contains the source for the cross-compiler wrapper scripts:

| File | Description |
|------|-------------|
| `ppc-ld64-gcc` | C compiler wrapper (GCC 15 cc1 + ld64) |
| `ppc-ld64-g++` | C++ compiler wrapper (GCC 15 cc1plus + ld64) |
| `fix_exc_ld64.py` | Exception handling assembly fixups for ld64 |
| `ppc-darwin-fixup.py` | Darwin PPC assembly post-processing |
| `tiger-compat.h` | Tiger 10.4 SDK compatibility header (10.5+ API shims) |

## License

Each package retains its original license. This repo only distributes pre-compiled binaries.
