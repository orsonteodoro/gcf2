# gentoo-cflags

My per-package cflags on Gentoo Linux.

These are my current flags.

## Production status

* Development mode (current / now): [master/head] (https://github.com/orsonteodoro/gentoo-cflags)
* Semi-production ready (Aug 26, 2021): [7c47245133fc6bee15106960aa87def4f9f62976] (https://github.com/orsonteodoro/gentoo-cflags/tree/7c47245133fc6bee15106960aa87def4f9f62976)

The semi-production ready image may need to be modified a bit on your side due
to differences in package versions or hardware configuration.

The development mode can be used with LTO parts disabled or removed.  Proper
systemwide LTO support is being re-added.

## The default make.conf *FLAGS:

* CFLAGS="-march=native -Os -fno-inline -freorder-blocks-algorithm=simple
-fomit-frame-pointer -frename-registers -fno-plt -mindirect-branch=thunk
-mindirect-branch-register -flto=thin -fopt-info-vec -pipe"

* CXXFLAGS="${CFLAGS}"

* LDFLAGS="${LDFLAGS} -flto=thin"

## Additional implicit hardened flags

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

## Package placement strategy at these target compiler optimization levels

* O3 -- enabled for only 3D math and 3D game engines, computational geometry 
algorithms, bitwise math, physics libraries and engines, FFT, audio and video 
codecs and image processing
* O2 -- non turn based games, assembly like code, parsers, crypto
* Os -- default

## Reasons for the chosen flags

* -fprefetch-loop-arrays is enabled for package that process sequential data.
* -ftree-parallelize-loops=4 is enabled for single threaded libraries with 
plenty of data (e.g. pixel manipulation libraries).  Change 4 to the number of 
cores on your system.
* -fomit-frame-pointer -frename-registers are enabled to maximize register use
* -ffast-math is enabled for 3D games, game engines and libraries, and audio 
processing.  For those using bullet for scientific purposes, consider removing 
fast-math (or applying [[1]](#footnote1)).
* -fopt-info-vec -- show SIMD optimized loops [[3]](#footnote3)
* -flto -- used primarly for reduction of binary size and cache use
efficiency [[4]](#footnote4)

For Spectre mitigation virtually all packages were filtered with Retpoline
compiler support with these flags:

* -mindirect-branch=thunk -mindirect-branch-register (the GCC version) --
compiled for most apps if not stripped by ebuild.
* -mretpoline (found in clang-retpoline.conf) -- the Clang version [[5]](#footnote5)
* -Wl,-z,retpolineplt -- for lazy binded shared libraries or drivers.
It is recommended to use Clang + LLD when applying these LDFLAGS as
a Spectre v2 mitigation strategy.
* -fno-plt -- for now binded shared libraries as a Spectre mitigation
strategy.[[2]](#footnote2)

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

<a name="footnote1">[1]</a> I_WANT_LOSSLESS=1 can be added to make.conf or
applied per-package to remove or convert flags to their lossless counterparts
in packages related to games, graphics, audio.

<a name="footnote2">[2]</a> If you have a package that does lazy binding
(LDFLAGS=-Wl,lazy) then -fno-plt is not compatible with that package especially
the x11-drivers.  You need to add a  ${CATEGORY}/${PN} disable-fno-plt.conf
z-retpolineplt.conf  row in the package.env. This assumes that the contents of
the bashrc have been copied into /etc/portage/bashrc or sourced from an external
file.

<a name="footnote3">[3]</a> If you have a clang package, you may need to add a
${CATEGORY}/${PN} disable-fopt-info.conf row to disable fopt-info since
this is only a GCC only flag if it is not auto removed.

<a name="footnote4">[4]</a> Not all packages can successfully use LTO.  Both
remove-clang-lto.conf and remove-gcc-lto.conf has been provided to remove the
flag for select packages.  You may only choose one LTO compiler from
beginning to end.  If a package doesn't support the chosen systemwide LTO
default, you must strip the -flto flag from that package especially if that
package produces a static library.

<a name="footnote5">[5]</a> Sometimes I may choose mostly built @world with
clang or with gcc.  You may choose to switch between -mindirect-branch=thunk or
-mretpoline for the default {C,CXX}FLAGS and apply manually per-package
clang-retpoline.conf or gcc-retpoline-thunk.conf.  It helps to grep the
saved build logs to determine which packages should rebuild with retpoline.
Adding to the make.conf with envvars PORTAGE_LOGDIR="/var/log/emerge/build-logs"
and FEATURES="${FEATURES} binpkg-logs" then grepping them can help discover
which packages need a per-package retpoline or which package needs
an -fno-plt or -fopt-info-vec removal scripts.

## Files involved

* bashrc -- used to dynamically modify *FLAGS
* env/*.conf -- per-package config definitions
* make.conf -- contains default *FLAGS.  To be modified manually on your end.
DO NOT `cp ${REPO_DIR}/make.conf /etc/portage/make.conf`
* package.env -- per-package and per-category config
* gen_pkg_lists.sh -- generator for LTO blacklist and whitelists, and CFI lists

## bashrc

The bashrc script is also provided to control applying, removing, translating
*FLAGS and adjusting MAKEOPTS.  You may place it and source it in an external
script, or place it directly in the bashrc.  Per-package environment variables
are used to control *FLAG filtering.

### Environment variables

The following can added to make.conf be applied as global defaults for the
provided bashrc script.

* CC_LIBC -- The C LTO compiler toolchain used to build the libc [glibc/musl]
or @system
* CC_LTO -- The C LTO compiler toolchain to use for @world
* CFI_BASELINE -- Set the default Clang CFI flags
* CXX_LIBC -- The C++ LTO compiler toolchain used to build the libc or @system
* CXX_LTO -- The C++ LTO compiler toolchain to use for @world
* GCF_SHOW_FLAGS -- Display the contents of all *FLAGS
* FORCE_PREFETCH_LOOP_ARRAYS -- Force use of GCC so that -fprefetch-loop-arrays
is utilized
* NCORES -- The number of CPU Cores
* MPROCS -- The number of compiler/linker processes per CPU core
* USE_CLANG_CFI -- Use Clang CFI (Uses only CFI Cross-DSO mode.  Experimental
and unstable systemwide.)
* USE_GOLDLTO -- Use Gold as the default LTO linker for @system and/or @world
* USE_THINLTO -- Use ThinLTO as the default LTO linker for @world

The bashrc will prioritize ThinLTO over GoldLTO.  This can be controlled with
use-gold.conf, use-thinlto.conf, disable-gold.conf, disable-thinlto.conf.
Some packages will not build with ThinLTO so fall back to either Gold LTO,
BFD LTO, or no LTO in that order.

### Per-package environment variables

The following can be added to the package.env per package-wise to control
bashrc:

* bypass-fallow-store-data-races-check.conf -- disables -Ofast or
-fallow-store-data-races safety check
* disable-clang-cfi.conf -- Turn off use of Clang CFI
* disable-gcf-lto.conf -- Disables use of the LTO module in the bashrc
* disable-lto-compiler-switch.conf -- Disables LTO compiler switching
* disable-lto-stripping.conf -- Disables auto removal of LTO *FLAGS
* disable-gold.conf -- Turn off use of Gold LTO
* disable-thinlto.conf -- Turn off use of ThinLTO
* disable-override-compiler-check.conf -- Disables CC/CXX override checks.  The
ebuild itself or the build scripts may forcefully switch compilers.
* force-translate-clang-retpoline.conf -- Converts the retpoline flags as Clang
 *FLAGS
* force-translate-gcc-retpoline.conf -- Converts the retpoline flags as GCC
 *FLAGS
* remove-no-inline.conf -- Removes -fno-inline
* remove-lto.conf -- Removes the -flto flag
* skip-lib-correctness-check.conf -- Disables static/shared lib correctness
checking
* skip-ir-check.conf -- Disables (static-libs) IR compatibility checks when
LTOing systemwide
* skipless.conf -- Force use of GCC to utilize -fprefetch-loop-arrays (
applied to audio/video packages that do decoding playback.)
* use-gold.conf -- Turn on use of Gold LTO
* use-thinlto.conf -- Turn on use of ThinLTO

Some .conf files may contain additional information about the flag or the
environment variable.

## The gen_pkg_lists.sh generator

The `gen_pkg_lists.sh` script is provided to generate LTO blacklist and
whitelists.  Before running the list generator, both `CC_LTO` and `CC_LIBC` in
the generator script should be set to either clang or gcc in make.conf.  The
list generator can be run by doing `bash gen_pkg_lists.sh`.

The following files are generated for LTO flags:

* /etc/portage/emerge-system-lto-agnostic.lst -- Packages in this list are allowed any compiler for LTO for @system and @world
* /etc/portage/emerge-system-lto-restricted.lst -- Packages in this list are only allowed the default compiler for @system.  If no static-libs are linked, you can use LTO.  Otherwise, LTO must be disabled.
* /etc/portage/emerge-system-lto-skip.lst -- Packages in this do not require LTO for @system set.
* /etc/portage/emerge-system-no-data.lst -- Packages are missing the emerged file list for @system
* /etc/portage/emerge-system-no-lto.lst -- Packages in this are disallowed LTO for @system and @world
* /etc/portage/emerge-world-lto-agnostic.lst -- Packages in this list are allowed any compiler for LTO for @world
* /etc/portage/emerge-world-lto-restricted.lst -- Packages in this list are only allowed the default compiler without LTO for @world if statically-linked.  Otherwise, you may use LTO with the preferred compiler.
* /etc/portage/emerge-world-lto-skip.lst -- Packages in this do not require LTO for @world set.
* /etc/portage/emerge-world-no-data.lst -- Packages are missing the emerged file list for @world
* /etc/portage/emerge-world-no-lto.lst -- Packages in this list are disallowed LTO for @world
* /etc/portage/emerge-requirements-not-met.lst -- Generated by bashrc if LTO requirements are not met.  List can be re-emerge after fixing the LTO requirements.

The following files are generated for CFI flags:

* /etc/portage/emerge-cfi-no-cfi.lst -- Packages that cannot use CFI flags
* /etc/portage/emerge-cfi-no-data.lst -- Packages that are missing installed files list and cannot be determined if CFI flags applies
* /etc/portage/emerge-cfi-skip.lst -- Packages that don't require CFI flags
* /etc/portage/emerge-cfi-system.lst -- Packages that may use CFI flags.  Only applies if CC_LIBC=clang and CXX_LIBC=clang.  Otherwise, do not apply CFI flags.
* /etc/portage/emerge-cfi-world.lst -- Packages that may use CFI flags.  Only applies if CC_LTO=clang and CXX_LTO=clang.  Otherwise, do not apply CFI flags.

When a static-libs USE flag is enabled in the future, the package with the
changed USE flag must be manually moved from the lto-agnostic into either a
no-lto or a lto-restricted list.

The bashrc will process these lists.  They should be re-generated before a
`emerge -ev @system` or `emerge -ev @world` is performed.  It cannot be
gathered ahead of time due to lack of ebuild metadata or hints.

The packages in either `emerge-*-no-lto.lst` and `emerge-*-lto-restricted.lst`
contain static-libs which may have compiler specific IR (Intermediate
Representation) which may not be compatible.  To maximize compatibility
when linking static-libs, LTO is disabled or uses the same IR as the chosen
default systemwide LTO used for @world.

If LTO was never applied due to it previously placed in no-data list or
was a new package, but placed later in the lto-agnostic lists after
running `gen_pkg_lists.sh`, you may re-enable the lto USE flag and
re-emerge those packages afterwards with LTO.  If it was later placed in
lto-restricted, you can only enable LTO for that particular package if
there is no hard dependence on CC_LIBC compiler for packages that use
it as a static-libs dependency.
