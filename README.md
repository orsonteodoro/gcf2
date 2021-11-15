# gentoo-cflags

My per-package cflags on Gentoo Linux.

These are my current flags.

My current profile is hardened.

The hardened profile comes with the following built in defaults on:

* -D_FORTIFY_SOURCE=2 -- for buffer overflow protection
* -fstack-protector-strong -param=ssp-buffer-size=4 -- medium buffer overflow
							checking
* -fstack-clash-protection  -- protect against this class of attacks when
				heap and stack clash with each other with
				a program/daemon running as root (suid)
* -Wl,relro -Wl,now -- Full RELRO for LDFLAGS to close hole to prevent
			arbitrary code execution of overritten GOT entry
			of jump address

These flags are also default ON via a modified ebuild with hardened clang
is on the [oiledmachine-overlay](http://github.com/orsonteodoro/oiledmachine-overlay).

PGO (profile-guided optimization) is done on the ebuild level instead of these
the environment variables because they require some training assets and maybe
some additional coding.  Modified packages with support for PGO flags
(-fprofile-generate/-fprofile-use) can be found in the
[PGO section](https://github.com/orsonteodoro/oiledmachine-overlay#pgo-packages).
in the the same overlay.

Compiler optimization levels
* O3 -- enabled for only apps/libraries using cryptographic ciphers and 
hashing algorithms, 3D math and 3D game engines, computational geometry 
algorithms, bitwise math, physics libraries and engines, FFT, audio and video 
codecs and image processing, compression algorithms.
* O2 -- default

* -fprefetch-loop-arrays is enabled for package that process sequential data.
* -ftree-parallelize-loops=4 is enabled for single threaded libraries with 
plenty of data (e.g. pixel manipulation libraries).  Change 4 to the number of 
cores on your system.
* -fomit-frame-pointer -frename-registers are enabled to maximize register use
* -ffast-math is enabled for 3D games, game engines and libraries, and audio 
processing.  For those using bullet for scientific purposes, consider removing 
fast-math.
* -fno-plt -- additional code reduction [1]
* -fopt-info-vec -- show SIMD optimized loops, added when using O3.conf [3]
* -flto=auto -- used primarly for reduction of binary size [4]

For Spectre mitigation virtually all packages were filtered with Retpoline compiler support,
* -mindirect-branch=thunk -mindirect-branch-register (the GCC version) --
compiled for most apps if not stripped by ebuild.
* -mindirect-branch=thunk-extern -mindirect-branch-register -- default for 
kernels with CONFIG_RETPOLINE=y
* -fuse-ld=gold -Wl,-z,retpolineplt -- used for LDFLAGS if -fno-plt is not 
possible.  It requires the patch from Sriraman Tallam at 
https://sourceware.org/ml/binutils/2018-01/msg00030.html and gold enabled 
binutils (https://wiki.gentoo.org/wiki/Gold) with the cxx USE flag.
* -mretpoline (found in clang-retpoline.conf) -- the Clang version [2]
* -Wl,-z,retpolineplt -- for lazy binded shared libraries or drivers
* -fno-plt -- for now binded shared libraries

One may remove -mindirect-branch=thunk -mindirect-branch-register 
if the processor has already fixed the side-channel attack hardware flaw. 
According to Wikipedia, all pre 2019 hardware had this flaw.

To ensure that your kernel is properly patched use 
`cat /sys/devices/system/cpu/vulnerabilities/spectre_v2` to view if the 
Spectre mitigation works.  It should report `Mitigation: Full AMD retpoline` 
or `Mitigation: Full generic retpoline`.  On my machine it reports the former.

To ensure that all Meltdown and Spectre mitigations are in place for the Linux 
kernel do `cat /sys/devices/system/cpu/vulnerabilities/*`.

It should look like:

<pre>
Not affected
Mitigation: __user pointer sanitization
Mitigation: Full AMD retpoline
</pre>

This test was performed circa Mar 2018 with sys-devel/gcc-7.3.0-r1, 
sys-devel/clang-6.0.9999, sys-devel/llvm-6.0.9999, sys-devel/binutils-2.30. 
It used sys-kernel/zen-sources-4.15.9999 from cynede's overlay and enabled 
-O3 (Compiler optimization level: Optimize harder), -march=native (Processor 
family (Native optimizations autodetected by GCC)).  The native optimization 
comes from GraySky2's patch and the Optimize Harder is a zen-kernel patch 
https://github.com/torvalds/linux/commit/c41ed11fc416424d508803f861b6042c8c75f9ba.

Entries for inclusion for the package.env are only those installed or may in 
 the future be installed on my system.

[1] If you have a package that does lazy binding (LDFLAGS=-Wl,lazy) then
-fno-plt is not compatible with that package especially the x11-drivers.  You
need to add a  ${CATEGORY}/${PN} disable-fno-plt.conf z-retpolineplt.conf  row
in the package.env. This assumes that the contents of bashrc have been copied
into /etc/portage/bashrc.

[2] Sometimes I may choose mostly built @world with clang or with gcc.
You may choose to switch between -mindirect-branch=thunk or -mretpoline
for the default {C,CXX}FLAGS and apply manually per-package
clang-retpoline.conf or gcc-retpoline-thunk.conf.  It helps to grep the
saved build logs to determine which packages should rebuild with retpoline.
Adding to the make.conf with envvars PORTAGE_LOGDIR="/var/log/emerge/build-logs"
and FEATURES="${FEATURES} binpkg-logs" then grepping them can help discover
which packages need a per-package retpoline or which package needs
an -fno-plt or -fopt-info-vec removal scripts.

[3] If you have a clang package, you need to add a
${CATEGORY}/${PN} disable-fopt-info.conf  row to disable fopt-info since
this is only a GCC only flag.

[4] Not all packages can successfully use LTO.  A remove-lto.conf has
been provided to remove the flag for select packages.

----

My make.conf cflags:

* CFLAGS="-march=native -O2 -fomit-frame-pointer -frename-registers -fno-plt 
-mindirect-branch=thunk -mindirect-branch-register -pipe"
* CXXFLAGS="${CFLAGS}"
