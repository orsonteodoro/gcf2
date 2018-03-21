# gentoo-cflags

My per-package cflags for Hardened Gentoo Linux.

These are my current flags.

Compiler optimization levels
* O3 -- enabled for only apps using cryptographic ciphers and hashing algorithms, 3d math, compression algorithms, pixel image manipulation, bitwise math, (3d) game engines, physics engines, fft
* O2 -- default

* -fprefetch-loop-arrays is enabled for GUI toolkits, data structures with random access
* -ftree-parallelize-loops=4 is enabled for single threaded libraries with plenty of data (e.g. pixel manipulation libraries).  Change 4 to the number of cores on your system.
* -fomit-frame-pointer -frename-registers are enabled to maximize register use

For Spectre mitigation virtually all packages were filtered with Retpoline compiler support,
* -fno-plt -mindirect-branch=thunk -mindirect-branch-register -- compiled for most apps
* -mindirect-branch=thunk-extern -mindirect-branch-register -- default for kernels with CONFIG_RETPOLINE=y

Miscellaneous:
* -fno-asynchronous-unwind-tables was used to remove the cfi assembler lines for -S when viewing generated assembly.

All packages were compiled with sys-devel/gcc-7.3.0-r1 and Clang sys-devel/clang-6.0.9999

TODO:
I need to find more single threaded -O3 apps and libraries that would benefit and not break from use of -ftree-parallelize-loops=4 .

----

My make.conf cflags:

> CFLAGS="-march=native -O2 -fomit-frame-pointer -fno-asynchronous-unwind-tables -frename-registers -fno-plt -mindirect-branch=thunk -mindirect-branch-register -pipe"
> CXXFLAGS="${CFLAGS}"

