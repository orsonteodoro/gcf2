# gentoo-cflags

My per-package cflags on Gentoo Linux.

These are my current flags.

----

The default make.conf *FLAGS:

* CFLAGS="-march=native -Os -freorder-blocks-algorithm=simple
-fomit-frame-pointer -frename-registers -fno-plt -mindirect-branch=thunk
-mindirect-branch-register -flto -fopt-info-vec -pipe"

* CXXFLAGS="${CFLAGS}"

* LDFLAGS="${LDFLAGS} -flto"

----

Additional implicit hardened flags

My current profile is hardened and comes with the following built in defaults ON:

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

----

Package placement strategy at these target compiler optimization levels

* O3 -- enabled for only 3D math and 3D game engines, computational geometry 
algorithms, bitwise math, physics libraries and engines, FFT, audio and video 
codecs and image processing
* O2 -- non turn based games, assembly like code, parsers, crypto
* Os -- default

----

Reasons for chosen flags

* -fprefetch-loop-arrays is enabled for package that process sequential data.
* -ftree-parallelize-loops=4 is enabled for single threaded libraries with 
plenty of data (e.g. pixel manipulation libraries).  Change 4 to the number of 
cores on your system.
* -fomit-frame-pointer -frename-registers are enabled to maximize register use
* -ffast-math is enabled for 3D games, game engines and libraries, and audio 
processing.  For those using bullet for scientific purposes, consider removing 
fast-math (or applying [1]).
* -fno-plt -- additional code reduction [2]
* -fopt-info-vec -- show SIMD optimized loops, added when using O3.conf [3]
* -flto -- used primarly for reduction of binary size [4]

For Spectre mitigation virtually all packages were filtered with Retpoline compiler support,
* -mindirect-branch=thunk -mindirect-branch-register (the GCC version) --
compiled for most apps if not stripped by ebuild.
* -mretpoline (found in clang-retpoline.conf) -- the Clang version [5]
* -Wl,-z,retpolineplt -- for lazy binded shared libraries or drivers.
It is recommended to use clang/lld when applying these LDFLAGS.
* -fno-plt -- for now binded shared libraries

One may remove -mindirect-branch=thunk -mindirect-branch-register 
if the processor has already fixed the side-channel attack hardware flaw. 
According to Wikipedia, just about all pre 2019 hardware had this flaw.

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

You may also try `lscpu` to obtain more info about CPU hardware vulnerabilities.

This test was performed circa Mar 2018 with sys-devel/gcc-7.3.0-r1, 
sys-devel/clang-6.0.9999, sys-devel/llvm-6.0.9999, sys-devel/binutils-2.30. 
It used sys-kernel/zen-sources-4.15.9999 from cynede's overlay and enabled 
-O3 (Compiler optimization level: Optimize harder), -march=native (Processor 
family (Native optimizations autodetected by GCC)).  The native optimization 
comes from GraySky2's patch and the Optimize Harder is a zen-kernel patch 
https://github.com/torvalds/linux/commit/c41ed11fc416424d508803f861b6042c8c75f9ba.

Entries for inclusion for the package.env are only those installed or may in 
 the future be installed on my system.

[1] I_WANT_LOSSLESS=1 can be added to make.conf or applied per-package to
remove or convert flags to their lossless counterparts in packages related to
games, graphics, audio.

[2] If you have a package that does lazy binding (LDFLAGS=-Wl,lazy) then
-fno-plt is not compatible with that package especially the x11-drivers.  You
need to add a  ${CATEGORY}/${PN} disable-fno-plt.conf z-retpolineplt.conf  row
in the package.env. This assumes that the contents of bashrc have been copied
into /etc/portage/bashrc.

[3] If you have a clang package, you need to add a
${CATEGORY}/${PN} disable-fopt-info.conf row to disable fopt-info since
this is only a GCC only flag.

[4] Not all packages can successfully use LTO.  A remove-lto.conf has
been provided to remove the flag for select packages.  Due to the heavy time
and memory cost, only ThinLTO will be used.

[5] Sometimes I may choose mostly built @world with clang or with gcc.
You may choose to switch between -mindirect-branch=thunk or -mretpoline
for the default {C,CXX}FLAGS and apply manually per-package
clang-retpoline.conf or gcc-retpoline-thunk.conf.  It helps to grep the
saved build logs to determine which packages should rebuild with retpoline.
Adding to the make.conf with envvars PORTAGE_LOGDIR="/var/log/emerge/build-logs"
and FEATURES="${FEATURES} binpkg-logs" then grepping them can help discover
which packages need a per-package retpoline or which package needs
an -fno-plt or -fopt-info-vec removal scripts.

----

Files involved

bashrc -- used to dynamically modify *FLAGS
env/*.conf -- per-package config definitions
make.conf -- contains default *FLAGS.  To be modified manually on your end.  DO
 NOT `cp ${REPO_DIR}/make.conf /etc/portage/make.conf`
package.env -- per-package config

----

bashrc

The bashrc script is also provided to control applying, removing, translating
*FLAGS.  You may place it and source it in an external script,
or place it directly in the bashrc.  Per-package environment variables are used
to control filtering.

The following can be added to the package.env per package-wise to control bashrc:
bypass-fallow-store-data-races-check.conf -- disables -Ofast or -fallow-store-data-races safety check
disable-gcf-lto.conf -- Disables Clang + ThinLTO
disable-lto-stripping.conf -- Disables auto removal of LTO *flags 
force-translate-clang-retpoline.conf -- Converts the retpoline flags as Clang *flags
force-translate-gcc-retpoline.conf -- Converts the retpoline flags as GCC *flags
remove-no-inline.conf -- Removes -fno-inline

Some .conf files may contain additional information about the flag or envvar.
