# Tiger PPC Builds

Pre-compiled modern software for **Mac OS X 10.4 Tiger** on **PowerPC**.

These are statically linked binaries cross-compiled from Linux, targeting `powerpc-apple-darwin8` with the 10.4 universal SDK. Download, copy to your Tiger Mac, and run.

## Available Packages

| Package | Version | G5 (ppc970) | G3/G4 (ppc750) | Notes |
|---------|---------|:-----------:|:--------------:|-------|
| GCC | 15.2.0 | Yes | No | C/C++ compiler with C++23 support. G5-only binary, but can target G3 with `-mcpu=G3`. |
| Python | 3.13.12 | Yes | Yes | Full stdlib including sqlite3, ssl, ctypes, readline, lzma, bz2 |
| OpenSSL | 3.6.1 | Yes | Yes | Static libraries + headers for building other software |
| curl | 8.12.1 | Yes | Yes | HTTPS support via OpenSSL 3.6.1 (TLS 1.2/1.3) |
| git | 2.48.1 | Yes | Yes | Full git with HTTPS clone support |
| ffmpeg | 7.1.1 | Yes | Yes | ffmpeg + ffprobe (AAC, FLAC, H.264, and more) |

## Compatibility

**G5 builds** (ppc970): Require a PowerPC G5 processor. Use the standard release tarballs.

**G3 builds** (ppc750): Run on any PowerPC Mac (G3, G4, or G5). Use the `-g3` release tarballs. GCC 15 is G5-only because its cc1plus compiler miscompiles itself when built for non-G5 targets, but it can still produce G3 binaries via `-mcpu=G3`.

**OS**: Mac OS X 10.4.x Tiger (any point release).

## Installation

Download the tarball from [Releases](https://github.com/danupsher/tiger-ppc-builds/releases), then:

```bash
tar xzf <package>.tar.gz -C /
```

Most binaries install to `/usr/local/bin`. See individual release notes for details.

### Package-specific notes

**Python 3.13**: Set `PYTHONHOME=/usr/local` before running. HTTPS works out of the box (statically linked OpenSSL 3.6.1).

**GCC 15**: Installs to `/usr/local/bin/gcc` and `/usr/local/bin/g++`. Includes assembly fixup scripts that automatically handle Tiger compatibility (PIC stubs for `bl` and `b` tail calls, exception handling, debug output cleanup). Requires the original Apple Developer Tools to be installed (for the system assembler and linker). **Important**: `/usr/bin/ld` must be the original cctools ld, not ld64 — see `gcc15-fix/README.md` for details.

**curl**: CA certificate bundle included at `/usr/local/etc/ssl/cert.pem`.

**git**: Set `GIT_EXEC_PATH=/usr/local/libexec/git-core` and `SSL_CERT_FILE=/usr/local/etc/ssl/cert.pem`.

## Test Results

All packages verified on a real iMac G5 (PowerMac8,2, PPC G5 2GHz, 1GB RAM, Tiger 10.4.11).
309 total tests, all passing:

| Package | Tests | Count | Result |
|---------|-------|:-----:|--------|
| GCC 15 | C/C++ compile+run, STL, exceptions, templates, multi-file, optimization levels (-O0 to -O3/-Os), static archives, `-mcpu=G3` targeting | 49 | All pass |
| Python 3.13 | core language, 50+ stdlib modules, file I/O, subprocess, threading, sqlite3, ctypes, zlib/bz2/lzma, ssl/TLS, HTTPS fetch, data formats | 105 | All pass |
| curl 8.12.1 | HTTP/HTTPS GET/POST/PUT/DELETE/HEAD, custom headers, auth, redirects, file download, timeouts, TLS verification | 29 | All pass |
| git 2.48.1 | init, add, commit, log, branch, checkout, merge, tag, stash, reset, cherry-pick, blame, archive, HTTPS clone | 58 | All pass |
| ffmpeg 7.1.1 | audio gen (sine/silence/noise), format conversion (WAV/FLAC/AAC/PCM), filters (volume/speed/fade/resample), ffprobe (JSON/format/streams), video gen, container ops, metadata | 44 | All pass |
| OpenSSL 3.6.1 | TLS 1.2/1.3, SSL contexts, cipher suites, hashlib (SHA-256/384/512/SHA3/BLAKE2/MD5), HTTPS via Python and curl, certificate verification | 24 | All pass |

G3 builds tested with the same suite — all packages work identically on G3/G4/G5.


## How These Were Built

Cross-compiled on Linux (Ubuntu 24.04, i5-9400) using GCC 7.5.0 targeting `powerpc-apple-darwin8`, with:

- Apple's 10.4 universal SDK for headers and frameworks
- cctools (assembler, ar, ranlib, strip) for Mach-O object file handling
- Custom assembly fixup pipeline (`ppc-darwin-fixup.py`) for Darwin PPC compatibility
- SSH-proxied linking on a real Tiger Mac for final binary linking
- GCC 15 includes additional on-target fixup scripts for exception handling and PIC stub generation

G3 builds use `-mcpu=G3` and produce ppc750 (or generic ppc) Mach-O binaries that run on any PowerPC Mac.

## License

Each package retains its original license (GPL, MIT, etc). This repo only distributes pre-compiled binaries.

## Cross-Compiler Toolchain

Want to compile your own software for Tiger PPC? The cross-compiler toolchain
is available as a separate download:

**[Download PPC Tiger Cross-Compiler (GCC 7.5.0)](https://github.com/danupsher/tiger-ppc-builds/releases/tag/cross-compiler-1.0)** — 87 MB

```bash
tar xf ppc-tiger-xcompiler.tar.gz
export PATH="$PWD/toolchain/bin:$PATH"
export PPC_TIGER_HOST="user@your-tiger-mac"

ppc-tiger-gcc -O2 hello.c -o hello
```

Compiles and assembles locally on x86_64 Linux. Linking runs via SSH on your
Tiger Mac (requires passwordless SSH and ld64 from Apple Developer Tools).
Always use `ppc-tiger-gcc` / `ppc-tiger-g++` — not `powerpc-apple-darwin8-gcc` directly.

See the [release page](https://github.com/danupsher/tiger-ppc-builds/releases/tag/cross-compiler-1.0) for full setup instructions.
