# Tiger PPC Builds

Pre-compiled modern software for **Mac OS X 10.4 Tiger** on **PowerPC G5** (PPC970).

These are statically linked binaries cross-compiled from Linux, targeting `powerpc-apple-darwin8` with the 10.4 universal SDK. Download, copy to your Tiger Mac, and run.

## Available packages

| Package | Version | Notes |
|---------|---------|-------|
| GCC | 15.2.0 | C/C++ compiler with C++23 support |
| Python | 3.13.12 | Full Python 3.13 with pip |
| OpenSSL | 3.6.1 | Static libraries + headers |
| curl | 8.x | HTTPS support via OpenSSL |
| git | 2.48.1 | Full git with HTTPS clone support |
| ffmpeg | 7.1.1 | ffmpeg + ffprobe |

## Compatibility

- **CPU**: PowerPC G5 (PPC970) — compiled with `-mcpu=970`
- **OS**: Mac OS X 10.4.x Tiger (any point release)
- **NOT compatible** with G3 or G4 processors (G5-specific instructions)

## Installation

Download the tarball from the release, then:

```bash
tar xzf <package>.tar.gz -C /usr/local
```

Most binaries install to `/usr/local/bin`. See individual release notes for details.

## How these were built

Cross-compiled on Linux using GCC 7.5.0 targeting `powerpc-apple-darwin8`, with a custom assembly fixup pipeline for Darwin compatibility and SSH-proxied linking on a real Tiger Mac.



## License

Each package retains its original license (GPL, MIT, etc). This repo only distributes pre-compiled binaries.
