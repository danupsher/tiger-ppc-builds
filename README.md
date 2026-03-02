# Tiger PPC Builds

Pre-compiled modern software for **Mac OS X 10.4 Tiger** on **PowerPC**.

These are statically linked binaries cross-compiled from Linux, targeting `powerpc-apple-darwin8` with the 10.4 universal SDK. Download, copy to your Tiger Mac, and run.

## Available Packages

| Package | Version | GCC 15 / ld64 | GCC 7.5 / G5 | GCC 7.5 / G3 | Notes |
|---------|---------|:-------------:|:------------:|:------------:|-------|
| GCC | 15.2.0 | — | Yes | No | C/C++ compiler with C++23. G5-only (can target G3 with `-mcpu=G3`). |
| Python | 3.13.12 | **Yes** | Yes | Yes | Full stdlib: sqlite3, ssl, ctypes, readline, lzma, bz2 |
| OpenSSL | 3.6.1 | **Yes** | Yes | Yes | Static libraries + headers |
| curl | 8.12.1 | **Yes** | Yes | Yes | HTTPS via OpenSSL 3.6.1 (TLS 1.2/1.3) |
| git | 2.48.1 | **Yes** | Yes | Yes | Full git with HTTPS clone support |
| ffmpeg | 7.1.1 | **Yes** | Yes | Yes | ffmpeg + ffprobe |

### Which release should I download?

- **GCC 15 / ld64** (recommended): Latest builds compiled with GCC 15.2.0 using the fully local ld64 pipeline. Better optimized code, C++17/20/23 standards compliance. G3/G4/G5 compatible.
- **GCC 7.5 / G3**: Compiled with GCC 7.5.0. G3/G4/G5 compatible.
- **GCC 7.5 / G5**: Compiled with GCC 7.5.0. G5 only.

## Compatibility

All GCC 15 / ld64 builds and GCC 7.5 / G3 builds run on **any PowerPC Mac** (G3, G4, or G5). GCC 7.5 / G5 builds require a G5 processor.

**OS**: Mac OS X 10.4.x Tiger (any point release).

## Installation

Download the tarball from [Releases](https://github.com/danupsher/tiger-ppc-builds/releases), then:

```bash
tar xzf <package>.tar.gz -C /
```

Most binaries install to `/usr/local/bin`. See individual release notes for details.

### Package-specific notes

**Python 3.13**: Set `PYTHONHOME=/usr/local` before running.

**GCC 15**: Installs to `/usr/local/bin/gcc` and `/usr/local/bin/g++`. Includes assembly fixup scripts for Tiger compatibility. Requires original Apple Developer Tools (system assembler and linker). **Important**: `/usr/bin/ld` must be the original cctools ld, not ld64 — see `gcc15-fix/README.md`.

**curl**: CA certificate bundle at `/usr/local/etc/ssl/cert.pem`.

**git**: Set `GIT_EXEC_PATH=/usr/local/libexec/git-core` and `SSL_CERT_FILE=/usr/local/etc/ssl/cert.pem`.

## Test Results

All packages verified on a real iMac G5 (PowerMac8,2, PPC G5 2GHz, 1GB RAM, Tiger 10.4.11).
**309 tests, all passing** (86 seconds):

| Package | Tests | Count | Result |
|---------|-------|:-----:|--------|
| Python 3.13 | Core language, 48 stdlib modules, file I/O, subprocess, threading, sqlite3, compression, ssl/HTTPS | 105 | All pass |
| git 2.48.1 | init/add/commit/log, branch/merge/tag/stash/reset, cherry-pick/blame/archive, format-patch/apply/am, grep, HTTPS clone | 58 | All pass |
| GCC 15 | C/C++ compile+run, STL, exceptions (6 types), C++17, optimization levels, static archives, -mcpu=G3 | 50 | All pass |
| ffmpeg 7.1.1 | Audio gen, format conversion (WAV/FLAC/AAC/PCM/AIFF/AU), filters, ffprobe, video gen, containers, metadata | 46 | All pass |
| curl 8.12.1 | HTTP/HTTPS verbs, headers, auth, redirects, downloads, TLS verification, file:// protocol | 29 | All pass |
| OpenSSL 3.6.1 | Tested via Python ssl and curl HTTPS: contexts, ciphers, TLS 1.2, cert verification, HTTPS connections | 24 | All pass |

Test suite: [`run_309_tests.sh`](https://github.com/danupsher/tiger-ppc-builds/blob/main/run_309_tests.sh) — saved and reusable.

## How These Were Built

### GCC 15 / ld64 builds (recommended)
Cross-compiled on Linux using a **fully self-contained pipeline** — no Mac needed:
- **GCC 15.2.0** cc1/cc1plus (native x86_64 ELF) for compilation
- **ld64-97.17** (Apple's linker, built for Linux) for linking
- cctools assembler for Mach-O object files
- fix_exc_ld64.py + ppc-darwin-fixup.py for assembly post-processing
- Apple 10.4u SDK for headers and frameworks
- `-mcpu=G3` targeting — runs on any PPC Mac

### GCC 7.5 builds (legacy)
Cross-compiled on Linux using GCC 7.5.0 with SSH-proxied linking on a real Tiger Mac.

## Cross-Compiler Toolchain

Want to compile your own software for Tiger PPC?

**[Download PPC Tiger Cross-Compiler (GCC 7.5.0)](https://github.com/danupsher/tiger-ppc-builds/releases/tag/cross-compiler-1.0)** — 86 MB

```bash
tar xf ppc-tiger-xcompiler.tar.gz
export PATH="$PWD/toolchain/bin:$PATH"
export PPC_TIGER_HOST="user@your-tiger-mac"
ppc-tiger-gcc -O2 hello.c -o hello
```

Compiles locally on x86_64 Linux, links via SSH on your Tiger Mac. Default target is G3.

## Standalone Cross-Compiler (Coming Soon)

A fully self-contained GCC 15 cross-compilation toolchain — runs entirely on Linux:
- GCC 15 cc1/cc1plus + ld64-97.17 + cctools as
- Assembly fixup scripts, runtime libraries, 10.4u SDK
- Wrapper scripts: `ppc-ld64-gcc`, `ppc-ld64-g++`

No Mac needed. No SSH. Unpack and cross-compile modern C/C++ for Tiger PPC.

## License

Each package retains its original license (GPL, MIT, etc). This repo only distributes pre-compiled binaries.
