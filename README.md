# gentoo-cflags

My per-package cflags for Hardened Gentoo Linux.

These are my current flags.

Compiler optimization levels
* O3 -- enabled for only apps/libraries using cryptographic ciphers and hashing algorithms, 3d math, compression algorithms, pixel image manipulation, bitwise math, (3d) game engines, physics engines, fft, audio and video codecs
* O2 -- default

* -fprefetch-loop-arrays is enabled for GUI toolkits, data structures with random access and databases
* -ftree-parallelize-loops=4 is enabled for single threaded libraries with plenty of data (e.g. pixel manipulation libraries).  Change 4 to the number of cores on your system.
* -fomit-frame-pointer -frename-registers are enabled to maximize register use

For Spectre mitigation virtually all packages were filtered with Retpoline compiler support,
* -fno-plt -mindirect-branch=thunk -mindirect-branch-register -- compiled for most apps
* -mindirect-branch=thunk-extern -mindirect-branch-register -- default for kernels with CONFIG_RETPOLINE=y
* -fuse-ld=gold -Wl,-z,retpolineplt -- used for LDFLAGS if -fno-plt is not possible.  It requires the patch from Sriraman Tallam at https://sourceware.org/ml/binutils/2018-01/msg00030.html and gold enabled binutils (https://wiki.gentoo.org/wiki/Gold) with the cxx USE flag.

Miscellaneous:
* -fno-asynchronous-unwind-tables was used to remove the cfi assembler lines for gcc -S when viewing generated assembly.

I fed before running the kernel compilation process with genkernel:
* export CFLAGS="-fomit-frame-pointer -fno-asynchronous-unwind-tables -frename-registers -pipe"
* export CXXFLAGS="${CFLAGS}"

The result produced `Mitigation: Full AMD retpoline`.

To ensure that your kernel is properly patched use `cat /sys/devices/system/cpu/vulnerabilities/spectre_v2` to view if the Spectre mitigation works.  It should report `Mitigation: Full AMD retpoline` or `Mitigation: Full generic retpoline`.  On my machine it reports the former.

To ensure that all Meltdown and Spectre mitigations are in place for the Linux kernel do `cat /sys/devices/system/cpu/vulnerabilities/*`.

It should look like:

<pre>
Not affected
Mitigation: __user pointer sanitization
Mitigation: Full AMD retpoline
</pre>

All packages were compiled with sys-devel/gcc-7.3.0-r1, sys-devel/clang-6.0.9999, sys-devel/llvm-6.0.9999, sys-devel/binutils-2.30 .

I am using sys-kernel/zen-sources-4.15.9999 from cynede's overlay and enabled -O3 (Compiler optimization level: Optimize harder), -march=native (Processor family (Native optimizations autodetected by GCC)).  The native optimization comes from GraySky2's patch and the Optimize Harder is a zen-kernel patch https://github.com/torvalds/linux/commit/c41ed11fc416424d508803f861b6042c8c75f9ba.

TODO:
I need to find more single threaded -O3 apps and libraries that would benefit and not break from use of -ftree-parallelize-loops=4 .

----

My make.conf cflags:

* CFLAGS="-march=native -O2 -fomit-frame-pointer -fno-asynchronous-unwind-tables -frename-registers -fno-plt -mindirect-branch=thunk -mindirect-branch-register -pipe"
* CXXFLAGS="${CFLAGS}"

