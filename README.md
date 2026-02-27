# Tiger PPC Builds

Pre-compiled modern software for **Mac OS X 10.4 Tiger** on **PowerPC G5** (PPC970).

These are statically linked binaries cross-compiled from Linux, targeting `powerpc-apple-darwin8` with the 10.4 universal SDK. Download, copy to your Tiger Mac, and run.

## Available Packages

| Package | Version | Notes |
|---------|---------|-------|
| GCC | 15.2.0 | C/C++ compiler with C++23 support. Full exception handling. |
| Python | 3.13.12 | Full stdlib including sqlite3, ssl, ctypes, readline, lzma, bz2 |
| OpenSSL | 3.6.1 | Static libraries + headers for building other software |
| curl | 8.12.1 | HTTPS support via OpenSSL 3.6.1 (TLS 1.2/1.3) |
| git | 2.48.1 | Full git with HTTPS clone support |
| ffmpeg | 7.1.1 | ffmpeg + ffprobe (AAC, FLAC, H.264, and more) |

## Compatibility

- **CPU**: PowerPC G5 (PPC970) — compiled with `-mcpu=970`
- **OS**: Mac OS X 10.4.x Tiger (any point release)
- **NOT compatible** with G3 or G4 processors (uses G5-specific instructions)

## Installation

Download the tarball from [Releases](https://github.com/danupsher/tiger-ppc-builds/releases), then:

```bash
tar xzf <package>.tar.gz -C /
```

Most binaries install to `/usr/local/bin`. See individual release notes for details.

### Package-specific notes

**Python 3.13**: Set `PYTHONHOME=/usr/local` before running. HTTPS works out of the box (statically linked OpenSSL 3.6.1).

**GCC 15**: Installs to `/usr/local/bin/gcc` and `/usr/local/bin/g++`. Includes assembly fixup scripts that automatically handle Tiger compatibility (PIC stubs, exception handling). Requires the original Apple Developer Tools to be installed (for the system assembler and linker).

**curl**: CA certificate bundle included at `/usr/local/etc/ssl/cert.pem`.

## Test Results

All packages verified on a real iMac G5 (PowerMac8,2, PPC G5 2GHz, 1GB RAM, Tiger 10.4.11):

| Package | Tests | Result |
|---------|-------|--------|
| GCC 15 | C, C++, STL, exceptions, math, multi-file | All pass |
| Python 3.13 | imports, HTTPS, sqlite3, subprocess, file I/O | All pass |
| curl 8.12.1 | HTTP, HTTPS, POST, redirects, downloads | All pass |
| git 2.48.1 | init, commit, log, HTTPS clone, branch | All pass |
| ffmpeg 7.1.1 | audio gen, format conversion, ffprobe | All pass (no MP3 encoder) |
| OpenSSL 3.6.1 | TLS 1.2/1.3 via curl and Python ssl | All pass |

## How These Were Built

Cross-compiled on Linux (Ubuntu 24.04, i5-9400) using GCC 7.5.0 targeting `powerpc-apple-darwin8`, with:

- Apple's 10.4 universal SDK for headers and frameworks
- cctools (assembler, ar, ranlib, strip) for Mach-O object file handling
- Custom assembly fixup pipeline (`ppc-darwin-fixup.py`) for Darwin PPC compatibility
- SSH-proxied linking on a real Tiger Mac for final binary linking
- GCC 15 includes additional on-target fixup scripts for exception handling and PIC stub generation

## License

Each package retains its original license (GPL, MIT, etc). This repo only distributes pre-compiled binaries.
