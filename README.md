# gentoo-cflags

My per-package cflags on Gentoo Linux.

These are my current flags.

## Production status

* Development mode (current / now): [master/head] (https://github.com/orsonteodoro/gentoo-cflags)
* Semi-production ready (Aug 26, 2021): [7c47245133fc6bee15106960aa87def4f9f62976] (https://github.com/orsonteodoro/gentoo-cflags/tree/7c47245133fc6bee15106960aa87def4f9f62976)

The semi-production ready image may need to be modified a bit on your side due
to differences in package versions or hardware configuration.

### Development mode progress

LTO with CFI is mostly working and on par with a basic www setup.  Current
development is focused on systemwide CFI.  Performance degration with CFI is
indiscernible mostly maybe except for loading times.

Systemwide Clang CFI support has been applied for many packages but there
are still a lot of important packages that are not able to be CFIed due to the
"failed to allocate noreserve 0x0 (0) bytes of CFI shadow" problem.

The bashrc with the latest package.env has processed 786 packages with
2 unmerged left with systemwide LTO and CFI ON.

Also, there is an issue with the stats for CFI shown sections below.  Using
systemwide CFI is not recommended with my bashrc and package.env until the ratio
of 261 actual to 464 estimate are near the same or a good reason to justify
the discrepancy.

So, if you want to use development mode, it is fine to use systemwide LTO.
Systemwide CFI can be used but it is better to wait for the above problems to get
fixed first to avoid a possible mandatory rebuild @world if the fix for this
build is found.  If you choose to try systemwide CFI and I haven't tested the
package, you have to fix the CFI problems yourself which is preferred or send an
issue request.  Enough documentation in this readme and in the code comments of
this repo to solve CFI related problems.

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
(i.e. LDFLAGS=-Wl,lazy), then -fno-plt is not compatible with that package
especially the x11-drivers.  You need to add a
`${CATEGORY}/${PN} disable-fno-plt.conf z-retpolineplt.conf`
row in the package.env. This assumes that the contents of the bashrc have been
copied into /etc/portage/bashrc or sourced from an external file.

<a name="footnote3">[3]</a> If you have a clang package, you may need to add a
`${CATEGORY}/${PN} disable-fopt-info.conf` row to disable fopt-info since
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
* gen_pkg_lists.sh -- generator for LTO blacklist and whitelists, and CFI lists
* make.conf -- contains default *FLAGS to be modified manually on your end.
DO NOT `cp ${REPO_DIR}/make.conf /etc/portage/make.conf`
* package.cfi_ignore -- per-package CFI ignore list (Allow / Permit rules.
Limited to build time and common use or basic features.  Expand for your use
case.)
* package.env -- per-package and per-category config

## bashrc

The bashrc script is also provided to control applying, removing, translating
*FLAGS and adjusting MAKEOPTS.  You may place it and source it in an external
script, or place it directly in the bashrc.  Per-package environment variables
are used to control *FLAG filtering.

### Environment variables

The following can added to make.conf be applied as global defaults for the
provided bashrc script.

* ALLOW_LTO_REQUIREMENTS_NOT_MET_TRACKING -- Allow bashrc to add to
/etc/portage/emerge-requirements-not-met.lst for packages or toolchain not
meeting LTO requirements
* CC_LIBC -- The C LTO compiler toolchain used to build the libc [glibc/musl]
or @system
* CC_LTO -- The C LTO compiler toolchain to use for @world
* CFI_BASELINE -- Set the default Clang CFI flags
* GCF_CFI_DEBUG -- Sets to print Clang CFI violations.  Disable in production.
* CXX_LIBC -- The C++ LTO compiler toolchain used to build the libc or @system
* CXX_LTO -- The C++ LTO compiler toolchain to use for @world
* GCF_SHOW_FLAGS -- Display the contents of all *FLAGS
* FORCE_PREFETCH_LOOP_ARRAYS -- Force use of GCC so that -fprefetch-loop-arrays
is utilized.  It is mutually exclusive with USE_CLANG_CFI which has a higher
precedence to reduce the attack surface.
* NCORES -- The number of CPU Cores
* MPROCS -- The number of compiler/linker processes per CPU core
* USE_CLANG_CFI -- Use Clang CFI (Uses only CFI Cross-DSO mode.  Experimental
and unstable systemwide.  bashrc support in development.)
* USE_CLANG_CFI_AT_SYSTEM -- Use Clang CFI for @system.  It should only be
enabled after emerging @world.
* USE_GOLDLTO -- Use Gold as the default LTO linker for @system and/or @world
* USE_THINLTO -- Use ThinLTO as the default LTO linker for @world

The bashrc will prioritize ThinLTO over GoldLTO.  This can be controlled with
use-gold.conf, use-thinlto.conf, disable-gold.conf, disable-thinlto.conf.
Some packages will not build with ThinLTO so fall back to either Gold LTO,
BFD LTO (for LTO agnostic only), or no LTO in that order.

### Per-package environment variables

The following can be added to the package.env per package-wise to control
bashrc:

* bypass-fallow-store-data-races-check.conf -- disables -Ofast or
-fallow-store-data-races safety check
* disable-cfi-verify.conf
* disable-clang-cfi.conf -- Turn off use of Clang CFI
* disable-gcf-lto.conf -- Disables use of the LTO module in the bashrc
* disable-lto-compiler-switch.conf -- Disables LTO compiler switching
* disable-lto-stripping.conf -- Disables auto removal of LTO *FLAGS
* disable-gold.conf -- Turn off use of Gold LTO
* disable-thinlto.conf -- Turn off use of ThinLTO
* disable-override-compiler-check.conf -- Disables CC/CXX override checks.  The
ebuild itself or the build scripts may forcefully switch compilers.
* disable-cfi-at-system.conf -- Disable CFIing this package in the @system set
* force-translate-clang-retpoline.conf -- Converts the retpoline flags as Clang
 *FLAGS
* force-translate-gcc-retpoline.conf -- Converts the retpoline flags as GCC
 *FLAGS
* no-cfi-cast.conf -- Turn off Clang CFI bad cast schemes (specifically cfi-derived-cast, cfi-unrelated-cast)
* no-cfi-icall.conf -- Turn off Clang CFI icall
* no-cfi-nvcall.conf -- Turn off Clang CFI nvcall
* no-cfi-vcall.conf -- Turn off Clang CFI vcall (i.e. Forward Edge CFI, disable as a last resort)
* remove-no-inline.conf -- Removes -fno-inline
* remove-lto.conf -- Removes the -flto flag
* remove-split-lto-unit.conf -- Disables auto applying of -fsplit-lto-unit
* skip-lib-correctness-check.conf -- Disables static/shared lib correctness
checking
* skip-ir-check.conf -- Disables (static-libs) IR compatibility checks when
LTOing systemwide
* skipless.conf -- Force use of GCC to utilize -fprefetch-loop-arrays (
applied to audio/video packages that do decoding playback.)
* split-lto-unit.conf -- Enables LTO splitting.  It should be applied
to packages that Clang LTOed static-libs.  It is implied in CFIed packages.
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
* /etc/portage/emerge-system-lto-restricted.lst -- Packages in this list are only allowed the default compiler for @system.  If no static-libs are linked, you can use LTO.  Otherwise, LTO must be disabled for the package with static-libs.
* /etc/portage/emerge-system-lto-skip.lst -- Packages in this do not require LTO for @system set due to lack of binaries
* /etc/portage/emerge-system-no-data.lst -- Packages are missing the emerged file list for @system
* /etc/portage/emerge-system-no-lto.lst -- Packages in this are disallowed LTO for @system and @world
* /etc/portage/emerge-world-lto-agnostic.lst -- Packages in this list are allowed any compiler for LTO for @world
* /etc/portage/emerge-world-lto-restricted.lst -- Packages in this list are only allowed the systemwide LTO compiler for @world.  If no static-libs are linked, you can use LTO.  Otherwise, LTO must be disabled for the package with static-libs.
* /etc/portage/emerge-world-lto-skip.lst -- Packages in this do not require LTO for @world set due to lack of binaries
* /etc/portage/emerge-world-no-data.lst -- Packages are missing the emerged file list for @world
* /etc/portage/emerge-world-no-lto.lst -- Packages in this list are disallowed LTO for @world
* /etc/portage/emerge-requirements-not-met.lst -- Generated by bashrc if LTO requirements are not met.  List can be re-emerged after fixing the LTO requirements.

The following files are generated for Clang CFI flags:

* /etc/portage/emerge-cfi-no-cfi.lst -- Packages that must not use CFI flags
* /etc/portage/emerge-cfi-no-data.lst -- Packages that are missing installed files list and cannot be determined if CFI flags applies
* /etc/portage/emerge-cfi-skip.lst -- Packages that don't require CFI flags because no binaries exists
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

The bashrc will filter package for viability of Clang CFI support.  It requires
to regenerate new lists with `gen_pkg_lists.sh` that will scan binaries for
presence of binaries and dlopen().

If the package is temporarly LTO or CFI blocked or a new install, you may try to
manually move the package from no-data to lto-agnostic and cfi-world /
cfi-system in the emerge*.lst files in order to bypass the pre IR compatibility
check only if static-libs will be not built or will have static-libs disabled or
will have its LTO disabled.  Disabling LTO will also disable Clang CFI which
also weakens the security.

## CFI

You may skip this if you use a hardware based implementation.  This section
applies to systemwide Clang CFI (Code Flow Integrity).

### Requirements

* All source based packages may require a rebuild if linking to CFIed libraries.
* Pre-downloaded all packages with `emerge -f @world` in case networking
packages break with CFI.
* A Rescue CD/USB -- During bootstrapping, the network related packages and all
linkers may break if missing CFI symbols or if a CFI violation is encountered.
The LLD linker may break itself if CFIed completely.
* Keys, instructions, experience to access drive manually and also WIFI if any.
Do not continue unless you are sure you know how to access these devices
with that Rescue CD/USB.
* Graphical login disabled until @world is completely emerged and tested.
* The @world set should be completely emerged before running `gen_pkg_lists.sh`
to minimize temporary blocks.  The USE_CLANG_CFI=0 should be set or commented
with a # in from of the line in make.conf when doing just LTO without CFI.
The temporary blocks may result in unwanted manual rollbacks discussed later.
* Modified `sys-devel/clang` and `sys-libs/compiler-rt-sanitizers` for
disabling assert for autoconf and Cross-DSO linking changes.  See the
[oiledmachine-overlay](http://github.com/orsonteodoro/oiledmachine-overlay).
It also requires the removal of the hard mask for the package's
experimental USE flag.

Changes required for modded clang ebuild:

```Shell
# Edit /etc/portage/profile/package.use.mask
# to remove hard USE mask
sys-devel/clang -experimental
```

### Steps

Read everything before continuing.  Some steps may be skipped or be simplified.

-2. Install repo files:
   * `cp -a bashrc /etc/portage/gcf-bashrc`
   * `! grep -q -e "source /etc/portage/gcf-bashrc" && echo "source /etc/portage/gcf-bashrc" >> /etc/portage/bashrc` (Do only once)
   * `cp -a package.cfi_ignore /etc/portage`
   * `cp -a env /etc/portage`
   * `chown -R root:root /etc/portage/{env,package.cfi_ignore,gcf-bashrc,bashrc}`
   * `find /etc/portage/{env,package.cfi_ignore,gcf-bashrc,bashrc} -type f -print0 | xargs -0 chmod 0644`
   * `find /etc/portage/{env,package.cfi_ignore} -type d -print0 | xargs -0 chmod 0755`
   * Manually copy sections of make.conf to your personal /etc/portage/make.conf
   * Manually copy sections of package.env to your personal /etc/portage/package.env

-1. Do the following edits:
```Shell
# Contents of /etc/portage/package.use/clang
sys-devel/binutils plugins gold
sys-devel/clang hardened
sys-devel/llvm binutils-plugin gold
sys-libs/compiler-rt-sanitizers cfi ubsan
```
```Shell
# Contents of /etc/portage/profile/package.use.mask
sys-devel/clang -experimental
```
0. Run `./gen_pkg_lists.sh`
1. `emerge --sync`
2. Set `USE_CLANG_CFI=0`, `USE_CLANG_CFI_AT_SYSTEM=0`, `CC_LTO="clang"`,
`CXX_LTO="clang++"` in make.conf.
3. `emerge -f @world`
4. `emerge -vuDN @world`
5. Run `./gen_pkg_lists.sh`
6. Choose a recovery image for @system:
   - (a) `emerge -ve --quickpkg-direct y --root=/bak @system`
   - (b) `Unpack stage 3 tarball into /bak`
   - (c) `Copy / into /bak`
(/bak can be any location)
7. Set `USE_CLANG_CFI=1`, `GCF_CFI_DEBUG=1` in make.conf.
8. `emerge -1v binutils glibc gcc`
9. Set up the default gcc compiler
```Shell
eselect gcc list
eselect gcc set <newest_gcc_version>
source /etc/profile
```
10. `emerge -ve @system`
11.  Install the Clang/LLVM toolchain:
```Shell
emerge -v sys-devel/binutils \
	sys-devel/llvm:13 \
	sys-devel/llvm:14 \
	sys-devel/lld \
	sys-devel/clang:13 \
	sys-devel/clang:14 \
	=sys-devel/clang-runtime-13* \
	=sys-libs/compiler-rt-13* \
	=sys-libs/compiler-rt-sanitizers-13* \
	=sys-libs/compiler-rt-14* \
	=sys-devel/clang-runtime-14* \
	=sys-libs/compiler-rt-sanitizers-14* \
	sys-devel/llvmgold
```

Any package with a 14 is optional if you don't use packages that depend on them.

All live llvm toolchain ebuilds should have a fixed commit with exceptions to
prevent symbol breakage.  Details are covered in the
[metadata.xml](https://github.com/orsonteodoro/oiledmachine-overlay/blob/master/sys-devel/clang/metadata.xml#L76)
in the oiledmachine-overlay.

12. Run `./gen_pkg_lists.sh`
13. `emerge -ve @world`
14. Set `USE_CLANG_CFI_AT_SYSTEM=1` in make.conf.
15. `emerge -ve @system`
16. Run `./gen_pkg_lists.sh`
17. `emerge -ve @world`
18. Run `scan-cfied-broken-binaries`  (For details see that
[section](https://github.com/orsonteodoro/gentoo-cflags#checking-for-early-cfi-violations-and-missing-symbols))
19. Fix all CFI issues.
20. Set `GCF_CFI_DEBUG=0` in make.conf.
21. Run `./gen_pkg_lists.sh`
22. `emerge -ve @world`

Step 2-4 again is to minimize temporarly blocks and rollbacks, and to insure
that all installed packages are capable of being installed to weed out bad
poor quality ebuilds.  The unmergable poor quality ebuilds should be removed
from the world list or replaced with a working version or one from a different
overlay.  This is to prevent emerge from dropping a set of packages that
should be re-emerge with new LTO/CFI flags.

In step 4 in preparation for step 13, one may decide to use the test USE flag
and test FEATURES in order possibly to increase the coverage of testing for CFI
violations.  It is not recommended because of possibly ebuild quality issues
that may slow down or block an atomically updated @world.  The test is enabled
early so the dependencies are pulled and the test USE flag disabled for
problematic packages.

In steps 4-10, the package.env may be needed to be slightly modified so that
packages that use clang explicitly need to temporarly use gcc.  Once the clang
compiler is installed, you may undo the changes.

Step 6 is to make an unCFIed backup of the @system set in /bak before breaking
it with CFI violations that will likely cause an interruption in the build
process.  If breakage is encountered, you can restore parts from this /bak
image.  You may also use an unpacked stage 3 tarball or a copied image of /
instead of emerging @system again.  CFI will tell you the library or program
that caused the CFI violation, all you need to do is replace that exe or lib
from /bak.  6a and 6c have an advantage of  less likely having SOVERSION (or
library version) compatibility issues.  6b can be used if using mostly stable
versions and not keyworded ones.  Also, you should have the rescue CD in case
of failure with broken system apps (like bash).

Step 11 can be skipped if Clang/LLVM is installed in step 4.

It is recommended in steps 13-17 that you test your software every 10-100 emerged
packages to find runtime CFI violations instead of waiting too long.  Long waits
could make it difficult to backtrack the broken package in
`/var/log/emerge.log`.

The reasons for emerging @world CFIed 2 times (in steps 13 and 17) with 1 CFIed
@system emerge (corresponding to step 15) is for CFI violation or init
problem(s) discovery.  The CFI volation is not really isolated in the @system
set but can affect the @world set like with zlib.  To fix the violation(s) see
the [fixing CFI violations](https://github.com/orsonteodoro/gentoo-cflags#fixing-cfi-violations)
section.  This discovery is done in the startup portions in step 18 in mostly
all executables in the system.  See also the
[Troubleshooting](https://github.com/orsonteodoro/gentoo-cflags#troubleshooting)
section.

In steps 13 and 15, it is recommended to use a personal
[resume list](https://github.com/orsonteodoro/gentoo-cflags#resume-list)
not the one managed by emerge when testing packages or applying CFI an ignore
list or exclusions.  The entries can be changed if one decides to use a
different ebuild revision with fixes, or can be rearraged so that unmergables
get moved to the end of the list.  Unmergeable rearragement should be done
for already installed packages, app packages, or dependency less packages.

In step 15, before doing repairs, preview the resume list before saving
the copy.  After the toolchain is repaired by replacing the shared-lib or
executable, add or disable CFI or its schemes and `emerge -1vO <pkgname>`
the package belonging to that shared-lib or executable then `--resume`.

Steps 14-17 should only be used after emerging @world with clang installed,
corresponding to step 13.  The reasons of CFIing @system later on in steps 14
and 15 is so that Clang/LLVM is in @world (in step 11) and to not disrupt the
bootstrapping process.

Steps 16 and 21 are optional if no new packages were added.  It is a good
idea to run `gen_pkg_lists.sh` before each `emerge -ve @world` or after a full
update with `emerge -vuDN @world`.  `gen_pkg_lists.sh` is only useful after
a new package is installed.

Steps 18-19 are required because each build (or computer) has a unique set of USE
flags with conditionally installed packages.  This step may be integrated in
step 13 in regular intervals if possible.

Steps 20-22 are optional, but makes the build more production ready.  Disabling
CFI debug can make it difficult to determine the type of CFI violation or
even to decide if it was a miscompile or CFI itself.

### Coverage

* Clang LTO packages qualify
* Both @system and @world are CFIed but not entirely.  The details covered in
the next section.
* Only binary executables and shared-libs are CFIed.
* Packages that install static-libs will disable CFI for that package.  This
problem is due to -fvisibility requirements which can cause missing symbols
and unusable shared libraries problem due to differences in enablement of CFI
in CFI Basic mode and CFI Cross-DSO mode.  In addition, this prevents the
applying the -fsanitize-cfi-cross-dso to object files for static-libs.

#### Stats

These proportions will differ from your @world set.  This is a stat snapshot
for Jan 7, 2022.

* Skips are due to a lack of binaries because they are either purely
metapackages, header only packages, non C-family, art assets (fonts, graphics),
etc.  The actual skips are due to static-libs (to avoid IR incompatibilies
[corresponding to some restricted and all disallowed]), build-time failures,
first time install [corresponding to no-data].

* disable-clang-cfi.conf corresponds to errors for "ERROR: SanitizerTool
failed to allocate noreserve 0x0 (0) bytes of CFI shadow (error code: 22)".

##### Estimates before emerging

###### Set sizes

* @world:  788 (100 %)
* @world - @system:  493 (62.56345177664975 %)
* @system:  295 (37.43654822335025 %)

###### LTO only estimates

* LTO agnostic:  436 (55.32994923857868 %)
   * @world - @system:  310 (39.340101522842644 %)
   * @system:  126 (15.989847715736042 %)
* LTO restricted:  29 (4.187817258883249 %)
   * @world - @system: 29 (4.187817258883249 %)
   * @system: 0 (0 %)
* LTO disallowed:  13 (1.6624040920716114 %)
   * @world - @system: 0 (0 %)
   * @system: 13 (1.6624040920716114 %)
* LTO skip:  296 (37.56345177664975 %)
   * @world - @system:  145 (18.401015228426395 %)
   * @system:  151 (19.16243654822335 %)
* No data:  0 (0.0 %)

The above percents are relative to the @world.

Multi slots are reduced to one.

###### CFI only estimates

* CFIable:  464 (58.88324873096447 %)
   * @world - @system:  338 (42.89340101522843 %)
   * @system:  126 (15.989847715736042 %)
* Allowable cfi-icall candidates:  232 (29.441624365482234 %)
   * @world - @system: 141 (17.893401015228427 %)
   * @system: 91 (11.548223350253807 %)
* CFI restricted: 29 (3.6802030456852792)
   * @world - @system: 29 (3.6802030456852792 %)
   * @system: 0 (0 %)
* Not CFIable:  14 (1.7766497461928936 %)
* CFI skippable:  296 (37.56345177664975 %)
* No Data:  0 (0.0 %)

The above percents are relative to the @world.

Multi slots are reduced to one.

Not CFIable is interpreted as the not LTOable @system set with
a static-lib.

##### CFI only actual

Last updated Jan 10, 2022

* Set sizes
  * @world:  788
  * @world - @system:  493
  * @system:  295

* CFIed:
  * @world:  261 (33.121827411167516 %_rel_world)
  * @world - @system:  164 (33.2657200811359 %_rel_world_minus_system, 20.812182741116754 %_rel_world)
  * @system:  97 (32.88135593220339 %_rel_system, 12.30964467005076 %_rel_world)
* NOT CFIed:
  * @world:  527 (66.87817258883248 %_rel_world)
  * @world - @system:  329 (66.73427991886409 %_rel_world_minus_system, 41.75126903553299 %_rel_world)
  * @system:  198 (67.11864406779661 %_rel_system, 25.12690355329949 %_rel_world)

@system numbers are a WIP (Work In Progress) and may change.

##### Misc

Last updated Jan 10, 2022

* 47 marked with disable-clang-cfi.conf (5.964467005076142 %)
* 22 marked with use-gcc.conf (2.7918781725888326 %)
* 104 marked with no-cfi-icall.conf (13.19796954314721 %)
* 6 marked with no-cfi-vcall.conf (0.7614213197969544 %)
* 8 marked with no-cfi-cast.conf (1.015228426395939 %)
* 8 marked with no-cfi-nvcall.conf (1.015228426395939 %)
* 0 marked with no-cfi-mfcall.conf (0 %)
* 13 marked with remove-lto.conf (1.6497461928934012 %)
* 10 marked with remove-gcc-lto.conf (1.2690355329949239 %)
* 26 marked with skipless.conf (3.2994923857868024 %)
* 3 marked with no-strip.conf (0.3807106598984772 %)
* 118 marked with prefetch-loop-arrays.conf (14.974619289340103 %)
* 4 marked with stc.conf (0.5076142131979695 %)
* 1 marked with no-cfi-canonical-jump-tables.conf (0.12690355329949238 %)
* Max package build time:  87526 seconds ( 1 days 0 hours 18 minutes 46 seconds )
* Min package build time:  4 seconds

The no-cfi-icall.conf numbers is higher because it does not count the auto
applied -fno-sanitize=cfi-icall which is around maybe 232 unique packages
(obtained from difference of CFIable - Allowable CFI icall candidates).

No source base browser tested yet for build time.

The above percents are relative to the @world.

### Plans

* Built CFIed @world (on top of agnostic LTO) -- done
* Built CFIed @system (on top of agnostic LTO) -- done
* Testing pre startup -- done but ongoing for new packages
* Increased mitigation with ignore lists converting from -fno-sanitize=cfi* form -- on hold
(Disabled CFI schemes is being used currently for reasons to get a working
system up as fast as possible.  Difficulties with ignore lists disincentivize
using them.)

### Troubleshooting

#### Logs

Build logs can found in `${T}/build.log` or `${BUILD_DIR}/config.log`.  The
latter is not completely revealed in the build.log but helps a lot when finding
missing symbols and CFI violations.  Find the error by doing a search on
"error:" or "symbol:".

`dmesg` could also be used to find segfaults that may be related to CFI flags.
The direct package of some segfaults may not be the actual cause.  Using
`ldd <lib_path or exe_path>` or the ebuilds themselves can be used to traverse
the dependency tree.

#### Package issues

Special treatment is required if the following message appears:

`undefined symbol: __ubsan_handle_cfi_check_fail_abort`

lld may need to be rebuilt without CFI bad cast and to remove the above error
when linking other packages.

libnl need to be rebuilt without CFI in order for wpa_supplicant and linkers to
work.

ccache needs to temporarly be disabled in FEATURES when reverting being CFIed.

#### Depenency rollback(s) without CFI

Currently no automated way to avoid the above problem, but some cases the
wrapper technique does not work because the executable is being forced to link
with the GCC toolchain but needs to link against the ubsan library mentioned
above.

Some rollback to remove CFI of the dependencies may be required.

Steps to resolve in order with one re-emerge per case:

1. Try re-emerging the shared-lib with auto or forced -Wl,-lubsan.
2. Manually recategorize the package in /etc/portage/emerge*.lst if
temporarly blocked.
3. Try disabling all CFI flags first, and if it works then converge
towards the minimal CFI exception set for this package.
4. Disable CFI for this package.    UBSan may still need to be linked.
It's discussed several sections below.
5. Switch back to GCC.
6. If this package is placed in the no-data LTO list, disable CFI
in each named dependency temporary until this package is emerged
then re-emerge back the dependencies with CFI.
7. If this package is permenently blacklisted (because it contains
a static-lib or other), the dependencies need to be re-emerged
without CFI depending on the importance of the executable in this
package.

For cases 6 and 7 use \`equery b libfile\` to determine the package
and \`emerge -1vO depend_pkg_name\` to revert with package.env
changes"

Important:  When the cause is found, a partial revert of changes what were not
the cause needs to happen so that the attack surface is minimized.

Sometimes it is not obvious which dependency is the problem.  You may need to
backtrack and rollback 2 levels deep or more while unCFIing those that block
re-emerging the package.  It is sometimes those CFIed blocks that should be
unCFIed are cause of the CFI violation.  The more hints are provided, the more
easy to fix the problem.  It is a good idea to use the GCF_CFI_DEBUG=1
variable in the first `emerge -ev @world` pass for your own personal
configuration and set of packages.  Then, disable the flag in subsequent
`emerge -ev @world` passes when no new additional packages will be added.

Setting GCF_CFI_DEBUG may help but expect random unannounced runtime feature
breakage as a result of enabling CFI.  You may need to disable CFI schemes
or completely disable CFI to fix these types of bugs.

`ccache` is recommended to speed up rollbacks for packages that normally take
hours to be restored back in minutes.  Details are covered in the
[wiki](https://wiki.gentoo.org/wiki/Ccache).

##### Resolving the case 4 error

Sometimes disabling all CFI schemes will not work.  If the following message is
encountered with a list of shared libraries:

==558==ERROR: SanitizerTool failed to allocate noreserve 0x0 (0) bytes of CFI shadow (error code: 22)

To fix this problem, first disable CFI for the app / exe and then work backwards
to unCFI some of the dependencies.  Everytime you rollback a package; you test
the breaking executable.

Associated with the above message is a list of libraries.  Look up the package
for that library and cross reference it with /etc/portage/emerge-cfi-world.cfi
and /etc/portage/emerge.lst.  If that package has been CFIed use
disable-clang-cfi.conf and re-emerge to fix the package.

Several CFIed shared libraries could be responsible for this message.

Once, the message goes away, try to re-emerge back the max set of CFIed
packages with CFI that were not responsible for triggering that message to
reduce the attack surface and to increase mitigation.

#### Linking a disabled CFI app package to other CFI shared libraries

When you completely disable CFI on the app package, you may encounter
the `undefined symbol: __ubsan_handle_cfi_check_fail_abort` error again.

The following can be used:

1.  Link to UBSan automatically with the new bashrc changes which is preferred
or by force with link-ubsan.conf.
2.  Rollback dependencies without CFI.  This is not desirable since it lowers
mitigation.
3.  Ignore linker errors with linker-errors-as-warnings.conf added per
package.  This should only be done for shared-lib packages without executables.
It is assumed that these packages will link to an executable package that is or
will be linked to UBSan or be CFIed.

#### Perl modules

The some perl-modules will copy the CC corresponding to the compiler that
was used when building dev-lang/perl.  In some packages, it won't allow you
to override this.  Use the use-gcc.conf, use-clang.conf, 
disable-lto-compiler-switch.conf, disable-perl-makemaker-autoedit.conf,
enable-perl-makemaker-autoedit.conf to control how to build the perl module
packages.

When a temporarly LTO disabled perl module fails to build, it may need to
be manually placed in one of the agnostic lists
(/etc/portage/emerge-*-lto-agnostic.lst) and removed from the no-data list(s)
(/etc/portage/emerge-system-no-data.lst) in order to build it.

#### Runtime error: control flow integrity check

The problematic sources could be the binary is in parenthesis or could be
the source code being referred to.  Use `equery b <path>` to find the package
name corresponding to that binary.

##### Fixing CFI violations

When a CFI violation is encountered it should be fixed as follows (ordered
from best to worst):

1.  Fix the exposed bug (or vulnerability)
2.  If not able to be fixed, then add exceptions to the ignore list while
continuing to use the CFI scheme.  Add cfi-ignore-list.conf to package.env and
add the ignore list to /etc/portage/package.cfi_ignore/${CATEGORY}/${PN}.  See
docs for details.
3.  If the ignore list doesn't work well, use the -fno-sanitize to completely
disable the scheme.  These correspond to one or more the no-cfi-*.conf files.

When choosing the fix, one should pick the solution that will maximize
mitigation while minimizing or eliminating the security hole.  This pertains
to choices in #2 (fun: versus src:) and exclusions.

## Helper script(s)

### Sorted list of completion times

If you enabled logging for bashrc in make.conf, you can get a sorted list of
ebuild completion times by doing the following:

```Shell
for f in $(ls /var/log/emerge/build-logs) ; do \
	l=$(grep  -e "Completion Time:" "/var/log/emerge/build-logs/${f}") \
		&& echo "${l} ${f}" ; \
done | sort -rV
```

### Resume list

Many times emerge is forgetful about the resume list as a result of
one shotting too many times after trying to find fixes.

Before generating the resume list, preview it to ensure that the resume
list is the actual one.  Do not resume off the 1 to a few packages
you are trying to repair.

The following script has been added to allow you to resume emerging.  It
requires `emerge -pv --resume | grep -e "^\[" > ~/resume.lst` or copy
paste the resume list and remove the header and footer only keeping the
square bracket rows.  Keep the resume.lst updated once in a while or
after emerge failure after --resume.

```Shell
#!/bin/bash
# Can be named as ~/resume-emerge-lst.
# Run as ~/resume-emerge-lst ~/resume.lst

main() {
        local list="${1}"
        echo "Resume list path: ${list}"
        if [[ ! -e "${list}" ]] ; then
                echo "Missing a resume list"
                exit 1
        fi
	local o=()
        for p in $(cat "${list}" | cut -c 18- | cut -f 1 -d " ") ; do
                o+=( "=${p}" )
        done
	# You can add sudo before the following
	emerge -1vO ${o[@]}
}

main "${1}"
```

After running the script, the `--resume` arg can be used in subsequent calls 
to `emerge`.

### Checking for early CFI violations and missing symbols

This does a simple --help and --version check.  Add any potentially dangerous
commands in the
[exclude list](https://github.com/orsonteodoro/gentoo-cflags/blob/master/scan-cfied-broken-binaries#L57)
inside the script.  This only tests a few code paths at start.  You may still
encounter CFI violations from event based portions or deeper in the code.

For testing some deeper code paths, add test to systemwide USE flags and systemwide
FEATURES in make.conf.  Preparation for the test USE flag should be done
(in step 4 of the [steps section](https://github.com/orsonteodoro/gentoo-cflags#steps)
early on to increase chances of a complete atomic update from beginning to
end.

IMPORTANT:  Before running the script, save your work.  You may need to run
this outside of X to prevent crash with X.

The script is called
[scan-cfied-broken-binaries](https://github.com/orsonteodoro/gentoo-cflags/blob/master/scan-cfied-broken-binaries).

Use `<path> --help`, `<path> --version`, or `<exe_path>` to see the violation or
missing symbol problem.

The script has several environment variables to control scanning, reporting, and
analysis and are found at the top of the script.  Example: 

`ANALYSIS=1 GEN_LOG=1 CHECK_NO_ARGS=1 CHECK_HELP=0 CHECK_VERSION=0 ./scan-cfied-broken-binaries`

To form just analysis do:

`ANALYSIS=1 GEN_LOG=0 CHECK_NO_ARGS=0 CHECK_HELP=0 CHECK_VERSION=0 ./scan-cfied-broken-binaries`

Some of the environment vararibles described with 0=off and 1=on:

* ANALYSIS -- generate condensed report mapping shared-libs and the ebuilds they come from.
* GEN_LOG -- generate output log in /var/log/cfi-scan.log
* CHECK_VERSION -- run and check stderr for `program --version`
* CHECK_HELP -- run and check stderr for `program --help`
* CHECK_NO_ARGS -- run and check stderr for `program` while starting it normally
* ALLOW_ONLY_EMERGED -- allow only emerged files to be executed
* ALLOW_MODDED_BINARIES -- allow modded binaries to be executed.  Otherwise,
allow only the executable with same md5sum (aka file fingerprint) recorded by
emerge to be executed.

The `equery b <path>` is slow.  Use `grep -l "<path>" /var/db/pkg/*/*/CONTENTS`
instead.

## Required re-emerges

If any of the undefined symbols is encountered, it requires a rebuild:

* __ubsan_handle_cfi_check_fail_abort
* __cfi_slowpath_diag (There's a small chance it could be fixed with auto
-Wl,-lubsan but may require an explicit add of -fno-sanitize=cfi-icall
(with no-cfi-icall.conf) or more.)

The following is required if using systemwide CFI at and before Jan 6, 2022.

This requires bashrc be updated to commit `ed89cbf` or newer before emerging
the list below.

A change was made to rid of sanitizer checks and just link to UBSan to simplify
and eliminate the UBSan sanitizer check guessing game.  This requires the
rebuilding of shared-lib packages with -lubsan or -Wl,-lubsan if any of the
above undefined symbol message is encountered, packages that got UBSan checks
removed, and linker-errors-as-warnings.conf removal in package.env.  So the
following need to be updated if you installed any of the following below:

```Shell
emerge -1vO \
	dev-libs/fribidi \
	dev-libs/dbus-glib \
	net-libs/libpsl \
	xfce-base/xfconf \
	x11-libs/cairo \
	x11-libs/libXcomposite \
	x11-libs/libXdamage \
	x11-libs/libXext \
	x11-libs/libXfixes \
	x11-libs/libXi
emerge -1vO \
	app-crypt/libmd \
	app-admin/keepassxc \
	app-text/poppler \
	dev-libs/dbus-glib \
	dev-libs/gobject-introspection \
	dev-libs/libpeas \
	dev-qt/qtgui \
	dev-qt/qtwidgets \
	gnome-base/librsvg \
	media-gfx/eog \
	net-libs/cef-bin \
	net-libs/libasyncns \
	net-libs/libndp \
	net-libs/libsoup \
	x11-libs/gtk+ \
	x11-libs/gtksourceview \
	x11-libs/pango \
	xfce-base/xfconf
```

If any of the above package(s) is a or are new package(s), you don't need to re-emerge
it at this time.

For a more comprehensive fix, you can do one the following ordered by time
required:

1. Re-emerge the shared-lib ebuild-package if the UBSan undefined symbol is
encountered.
2. Selective with logging

If you enabled logging and want a more comprehensive fix you may also do:
```Shell
emerge -1vO $(grep -r -l -E -e "Package flags:" /var/log/emerge/build-logs/ \
	| cut -f 1-2 -d ":" \
	| sed -e "s|/var/log/emerge/build-logs/||g" \
	| sed -e "s|:|/|g" \
	| sed -r -e "s/(_p.*|-r[0-9]+)//g" \
	| sed -r -e "s|-[0-9.]+([a-z])?$||g" \
	| sort \
	| uniq)
```

3. Use `scan-cfied-broken-binaries` to list __ubsan_handle_cfi_check_fail_abort
missing symbol and others.  Re-emerge all packages listed.
4. `emerge -ve world`
