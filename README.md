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
are still a lot of packages that are not able to be CFIed, with some unmergable
packages (x11-libs/vte, dev-util/bazel) one of them due to the missing UBSan
symbols problem even though CFI was disabled and UBSan was used.  Using
systemwide CFI is not recommended until this issue is solved along with
eliminating the UBSan sanitizer choose game when CFI is disabled.  It maybe
would take an additional compiler patch to eliminate the guessing game with
maybe making it a default or an additional compiler switch to solve these
problems to smooth things out.  The reason for not recommended yet is that this
block could prevent critical updates but it is unlikely to block a major package
from being updated, but other packages that have this kind of unresolvable
symbol bug with disabled CFI can block critical updates or increase the
backlog of critical updates.

The bashrc with the latest package.env has processed 786 packages with
3 unmerged left with systemwide LTO and CFI ON.

So, if you want to use development mode, it is fine to use systemwide LTO
but not systemwide CFI just yet.  If you choose to try systemwide CFI
and I haven't tested the package, you have to fix the CFI problems
yourself which is preferred or send an issue request.  Enough documentation
in this readme has been provided to solve CFI related problems.

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

* All source based packages require a rebuild if linking to CFIed libraries.
* All binary based packages require LD_PRELOAD described in the troubleshooting
section below.
* Pre-downloaded all packages with `emerge -f @world` in case networking
packages break with CFI.
* A Rescue CD -- During bootstrapping, the network related packages and all
linkers may break if missing CFI symbols.  The LLD linker may break itself if
CFIed completely.
* Graphical login disabled until @world is completely emerged and tested.
* The @world set should be completely emerged before running `gen_pkg_lists.sh`
to minimize temporary blocks.  The USE_CLANG_CFI=0 should be set or commented
with a # in from of the line in make.conf when doing just LTO without CFI.
The temporary blocks may result in unwanted manual rollbacks discussed later.
* Modified `sys-devel/clang` and `sys-libs/compiler-rt-sanitizers` for
disabling assert for autoconf and Cross-DSO linking changes.  See the
[oiledmachine-overlay](http://github.com/orsonteodoro/oiledmachine-overlay).
It also requires remove the hard mask for the package and the experimental USE
flag.

Changes required for modded clang ebuild:

```Shell
# Edit /etc/portage/profile/package.use.mask
# to remove hard USE mask
sys-devel/clang -experimental
```

### Coverage

* Clang LTO packages qualify
* Above the @system set only, but may allow to include some parts of @system in
the future.
* Only binary executables and shared-libs are CFIed.
* Packages that install static-libs will disable CFI for that package.  This
problem is due to -fvisibility requirements which can cause missing symbols
and unusable shared libraries problem due to differences in enablement of CFI
in CFI Basic mode and CFI Cross-DSO mode.  In addition, this prevents the
applying the -fsanitize-cfi-cross-dso to object files for static-libs.
* Around 34% of the entire @world set will be CFIed.  Most of the @world set
are skipped due to a lack of binaries.  Others are skip due to containing
static-libs, build-time failures, first time install.  Around 16% of @world
belonging to the @system set are candidates for CFI but currently not being
CFIed.
* Around 18% of the packages that may be CFIable were unable to be CFIed.
Most of these are due to the init problem related to "ERROR: SanitizerTool
failed to allocate noreserve 0x0 (0) bytes of CFI shadow (error code: 22)".

### Troubleshooting

Special treatment is required if the following message appears:

`undefined symbol: __ubsan_handle_cfi_check_fail_abort`

Prebuilt binary packages need to add the full path of
libclang_rt.ubsan_standalone-${ARCH}.so to LD_PRELOAD.  The full path and the
ARCH can be obtained from `equery f sys-libs/compiler-rt-sanitizers`.  It
is recommended to use a wrapper script.

Source based packages will require a rebuild of the package containing the app
or executable if that message appears in the command line.

lld may need to be rebuilt without CFI bad cast and to remove the above error
when linking other packages.

libnl need to be rebuilt without CFI in order for wpa_supplicant and linkers to
work.

ccache needs to temporarly be disabled in FEATURES when reverting being CFIed.

#### Wrapper script example

```Shell
#!/bin/bash
# Place in /usr/local/bin with 0755 permissions
export LD_PRELOAD="/usr/lib/clang/14.0.0/lib/linux/libclang_rt.ubsan_standalone-x86_64.so"
your_program "${@}"

```

#### Depenency rollback(s) without CFI

Currently no automated way to avoid the above problem, but some cases the
wrapper technique does not work because the executable is being forced to link
with the GCC toolchain but needs to link against the ubsan library mentioned
above.

Some rollback to remove CFI of the dependencies may be required.

Steps to resolve in order with one re-emerge per case:

1. Manually recategorize the package in /etc/portage/emerge*.lst if
temporarly blocked.
2. Try disabling all CFI flags first, and if it works then converge
towards the minimal CFI exception set for this package.
3. Disable CFI for this package.    UBSan may still need to be linked.
It's discussed several sections below.
4. Switch back to GCC.
5. If this package is placed in the no-data LTO list, disable CFI
in each named dependency temporary until this package is emerged
then re-emerge back the dependencies with CFI.
6. If this package is permenently blacklisted (because it contains
a static-lib or other), the dependencies need to be re-emerged
without CFI depending on the importance of the executable in this
package.

For cases 5 and 6 use \`equery b libfile\` to determine the package
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
`emerge -ev @world` passes.

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

#### Pulseaudio can't record mic

It depends on the security tradeoff.  You can use LD_PRELOAD or unCFI more
packages to get rid of missing symbols.  This issue affects web browsers.
Increased mitigation for a dependency of pulseaudio was favored resulting
in a broken `pulseaudio -k`, so using `killall -9 pulseaudio` with the
same user should be used instead.

## Helper script(s)

### Sorted list of completion times

If you enabled logging for bashrc in make.conf, you can get a sorted list of
ebuild completion times by doing the following:

```Shell
for f in $(ls /var/log/emerge/build-logs) ; do \
	l=$(grep  -e "Completion Time:" "/var/log/emerge/build-logs/${f}") \
		&& echo "${l} ${f}" ; \
done | sort -V
```

## Required re-emerges

Jan 6, 2022 - A change was made to rid of sanitizer checks and just link to
UBSan to simplify and eliminate the UBSan sanitizer check guessing game.  This
requires the rebuilding of shared-lib packages with -lubsan or -Wl,-lubsan if
any of the above undefined symbol message is encountered, packages that got
UBSan checks removed, and linker-errors-as-warnings.conf removal in package.env.
So the following need to be updated if you installed any of the following below:

```Shell
emerge -1vO dev-libs/dbus-glib \
	xfce-base/xfconf \
	x11-libs/cairo \
	net-libs/libpsl \
	x11-libs/libXext \
	dev-libs/fribidi \
	x11-libs/libXcomposite \
	x11-libs/libXdamage \
	x11-libs/libXfixes \
	x11-libs/libXi
emerge -1vO gnome-base/librsvg \
	app-admin/keepassxc \
	app-text/poppler \
	dev-libs/dbus-glib \
	dev-libs/gobject-introspection \
	dev-libs/libpeas \
	dev-qt/qtgui \
	dev-qt/qtwidgets \
	media-gfx/eog \
	net-libs/cef-bin \
	net-libs/libndp \
	net-libs/libsoup \
	x11-libs/gtk+ \
	x11-libs/gtksourceview \
	x11-libs/pango \
	xfce-base/xfconf \
	media-plugins/alsa-plugins \
	net-libs/libasyncns
```

If any of the above packages is a new package, you don't need to re-emerge
it at this time.

For more comprehensive fix, you can do the following:

1. Selective with logging
If you enabled logging and want a more comprehensive fix you may also do:
```Shell
emerge -1vO $(grep -r -l -E -e "Package flags.*(S|X)" /var/log/emerge/build-logs/ \
	| cut -f 1-2 -d ":" \
	| sed -e "s|/var/log/emerge/build-logs/||g" \
	| sed -e "s|:|/|g" \
	| sed -r -e "s/(_p.*|-r[0-9]+)//g" \
	| sed -r -e "s|-[0-9.]+([a-z])?$||g" \
	| sort \
	| uniq)
```
2. Re-emerge the lib ebuild-package if the UBSan undefined symbol is encountered.
3. `emerge -ve world`
