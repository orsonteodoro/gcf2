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
* A sys-apps/portage [patch](https://raw.githubusercontent.com/orsonteodoro/gcf2/master/profiles/minmax-v1/patches/sys-apps/portage/no-stripping-cfi-symbols.patch)
to prevent stripping of CFI symbols.  (This is optional, but it's better than
the alternative of a die after cfi post verify after merging.  You can use
either this per-package patch or the no-strip.conf.)

Changes required for modded clang ebuild:

```Shell
# Edit /etc/portage/profile/package.use.mask
# to remove hard USE mask
sys-devel/clang -experimental
```

### Steps

Read everything before continuing.  Some steps may be skipped or be simplified.

#### Overview

* Perform the usual install/update as recommended by the distro handbox
* Update to the latest binutils, glibc, gcc
* Rebuild @system with the latest gcc and glibc
* Build clang and lld
* Install scripts from this overlay
* Reconstruct black- and white-list and missing metadata with gen_pkg_lists.sh
* Rebuild the safer CFIed @world
* Rebuild the more dangerously risky CFIed @system then @world
* Increase the quality of the build with scan-cfied-broken-binaries with fixes
* Finalize and polish without debug and test flags

#### The gen_pkg_lists.sh generator

The `gen_pkg_lists.sh` script is provided to generate CFI whitelists and
blacklists.  Before running the list generator, both `CC_LTO` and `CC_LIBC` in
the generator script should be set to either clang or gcc in make.conf.  The
list generator can be run by doing `bash gen_pkg_lists.sh`.

The following files are generated for Clang CFI flags:

* /etc/portage/emerge-cfi-no-cfi.lst -- Packages that must not use CFI flags
* /etc/portage/emerge-cfi-no-data.lst -- Packages that are missing installed files list and cannot be determined if CFI flags applies
* /etc/portage/emerge-cfi-skip.lst -- Packages that don't require CFI flags because no binaries exists
* /etc/portage/emerge-cfi-system.lst -- Packages that may use CFI flags.  Only applies if CC_LIBC=clang and CXX_LIBC=clang.  Otherwise, do not apply CFI flags.
* /etc/portage/emerge-cfi-world.lst -- Packages that may use CFI flags.  Only applies if CC_LTO=clang and CXX_LTO=clang.  Otherwise, do not apply CFI flags.

The bashrc will filter package for viability of Clang CFI support.  It requires
to regenerate new lists with `gen_pkg_lists.sh` that will scan binaries for
presence of binaries and dlopen().

If the package is temporarly LTO or CFI blocked or a new install, you may try to
manually move the package from no-data to lto-agnostic and cfi-world /
cfi-system in the emerge*.lst files in order to bypass the pre IR compatibility
check only if static-libs will be not built or will have static-libs disabled or
will have its LTO disabled.  Disabling LTO will also disable Clang CFI which
also weakens the security.

#### Detailed steps

1. Do the following edits:
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
```Shell
# Appended contents of /var/lib/portage/world
sys-devel/clang:14
sys-devel/clang:13
sys-devel/clang:10
sys-devel/llvm:14
sys-devel/llvm:13
sys-devel/llvm:10
sys-devel/lld
```
Any package with a 14 or 10 is optional if you don't use packages that depend on them.

All live llvm toolchain ebuilds should have a fixed commit with exceptions to
prevent symbol breakage.  Details are covered in the
[metadata.xml](https://github.com/orsonteodoro/oiledmachine-overlay/blob/master/sys-devel/clang/metadata.xml#L151)
in the oiledmachine-overlay.

2. `emerge --sync`
3. `emerge -vuDN @world`
4. `emerge -1v binutils glibc gcc`
(Add ccache if you don't have it yet.)
```Shell
# Contents of /etc/portage/make.conf to enable ccache for faster rebuilds
FEATURES="${FEATURES} ccache"
```
5. Set up the default gcc compiler
```Shell
eselect gcc list
eselect gcc set <newest_gcc_version>
source /etc/profile
```
6. `emerge -ve @system`

AND

```Shell
# Rebuild the highest installed slot replacing or keeping 14
emerge -1v \
	sys-devel/llvm:14 \
	sys-devel/clang:14 \
	=sys-devel/lld-14* \
	=sys-devel/clang-common-14* \
	=sys-devel/clang-runtime-14* \
	=sys-libs/compiler-rt-14* \
	=sys-libs/compiler-rt-sanitizers-14* \
	=sys-libs/libomp-14* \
	=sys-devel/llvmgold-14* \
	=sys-libs/libcxxabi-14* \
	=sys-libs/libcxx-14*
# Also any slotted use-clang-*.conf overrides in package.env should be re-emerged
```

7. Choose a recovery image for @system:
   - (a) `emerge -ve --quickpkg-direct y --root=/bak @system`
   - (b) `Unpack stage 3 tarball into /bak`
   - (c) `Copy / into /bak`
(/bak can be any location)

8. Install repo files:
   * `cp -a bashrc /etc/portage/gcf-bashrc`
   * `! grep -q -e "source /etc/portage/gcf-bashrc" && echo "source /etc/portage/gcf-bashrc" >> /etc/portage/bashrc` (Do only once)
   * `cp -a package.cfi_ignore /etc/portage`
   * `cp -a env /etc/portage`
   * `cp -a patches /etc/portage`
   * `chown -R root:root /etc/portage/{env,package.cfi_ignore,gcf-bashrc,bashrc,patches}`
   * `find /etc/portage/{env,package.cfi_ignore,gcf-bashrc,bashrc,patches} -type f -print0 | xargs -0 chmod 0644`
   * `find /etc/portage/{env,package.cfi_ignore,patches} -type d -print0 | xargs -0 chmod 0755`
   * Manually copy sections of make.conf to your personal /etc/portage/make.conf
   * Manually copy sections of package.env to your personal /etc/portage/package.env
   * Enable logging

```Shell
# Contents of make.conf:
FEATURES="${FEATURES} binpkg-logs"
PORTAGE_LOGDIR="/var/log/emerge/build-logs"
```

9. Run `./gen_pkg_lists.sh`
10. Set `USE_CLANG_CFI=1`, `USE_CLANG_CFI_AT_SYSTEM=0`, `GCF_CFI_DEBUG=1`, `CC_LTO="clang"`,
`CXX_LTO="clang++"` in make.conf.
11. `emerge -f @world`
12. `emerge -ve @world`
13. (UNSAFE, SKIP THIS STEP) Set `USE_CLANG_CFI_AT_SYSTEM=1` in make.conf.
14. `emerge -ve @system`
15. Run `./gen_pkg_lists.sh`
16. `emerge -ve @world`
17. Run `scan-cfied-broken-binaries`  (For details see that
[section](CFI-support.md#checking-for-early-cfi-violations-and-missing-symbols))
18. Fix all CFI issues.
19. Set `GCF_CFI_DEBUG=0` in make.conf.
20. Run `./gen_pkg_lists.sh`
21. `emerge -ve @world`

Step 3 again is to minimize temporarly blocks and rollbacks, and to ensure
that all installed packages are capable of being installed to weed out bad
poor quality ebuilds.  The unmergable poor quality ebuilds should be removed
from the world list or replaced with a working version or one from a different
overlay.  This is to prevent emerge from dropping a set of packages that
should be re-emerge with new LTO/CFI flags.

In step 3 in preparation for step 13, one may decide to use the test USE flag
and test FEATURES in order possibly to increase the coverage of testing for CFI
violations.  It is not recommended because of possibly ebuild quality issues
that may slow down or block an atomically updated @world.  The test is enabled
early so the dependencies are pulled and the test USE flag disabled for
problematic packages especially for those packages that do not provide a
production version of the library (depending on if steps 20-21 will not be
performed) but install the designed to fail fuzzed one.

After step 6, it's recommended to re-build at least the highest installed slot
of the clang toolchain only if clang hasn't been built against the latest gcc
and glibc yet.  This is because LLVM references gcc and glibc packages in ldd
for some reason.  Any packages that use specific slot of clang/llvm (e.g.
use-clang-12.conf or others) should also be re-emerged since *DEPENDs does not
take in account package.env overrides.

Step 7 is to make an unCFIed backup of the @system set in /bak before breaking
it with CFI violations that will likely cause an interruption in the build
process.  If breakage is encountered, you can restore parts from this /bak
image.  You may also use an unpacked stage 3 tarball or a copied image of /
instead of emerging @system again.  CFI will tell you the library or program
that caused the CFI violation, all you need to do is replace that exe or lib
from /bak.  7a and 7c have an advantage of  less likely having SOVERSION (or
library version) compatibility issues.  7b can be used if using mostly stable
versions and not keyworded ones.  Also, you should have the rescue CD in case
of failure with broken system apps (like bash).

In step 8, logging is enabled for helper scripts.  If you have a very fast
computer and do `emerge -e @world` frequently, you may disable it.  For older
computers, logging should be enabled for making it easier to rebuild new
packages.  The folder /var/log/emerge/build-logs should be cleared before
`emerge -e @world` or `emerge -e @system`.

In step 10, USE_LIBCXX_AS_DEFAULT=1 could be used at that time, but it has not
been tested systemwide.  It may require to disable it with
disable-libcxx-as-default.conf for some packages.  The flags have been used in
other ebuilds without problems, but may result in two standard C++ libraries
being used which has been observed with ldd.

It is recommended in steps 12-16 that you test your software every 10-100 emerged
packages to find runtime CFI violations instead of waiting too long.  Long waits
could make it difficult to backtrack the broken package in
`/var/log/emerge.log`.

The reasons for emerging @world CFIed 2 times (in steps 12 and 16) with 1 CFIed
@system emerge (corresponding to step 14) is for CFI violation or init
problem(s) discovery.  The CFI volation is not really isolated in the @system
set but can affect the @world set like with zlib.  To fix the violation(s) see
the [fixing CFI violations](CFI-support.md#fixing-cfi-violations)
section.  This discovery is done in the startup portions in step 17 in mostly
all executables in the system.  See also the
[Troubleshooting](CFI-support.md#troubleshooting)
section.

In steps 12-18, it is recommended to use a personal
[resume list](CFI-support.md#resume-list)
not the one managed by emerge when testing packages or applying CFI an ignore
list or exclusions.  The entries can be changed if one decides to use a
different ebuild revision with fixes, or can be rearraged so that unmergables
get moved to the end of the list.  Unmergeable rearragement should be done
for already installed packages, app packages, or dependency less packages.

In steps 12-18, before doing repairs, preview the resume list before saving
the copy.  After the toolchain is repaired by replacing the shared-lib or
executable, add or disable CFI or its schemes and `emerge -1vO <pkgname>`
the package belonging to that shared-lib or executable then `--resume`.

The reasons of CFIing @system later on in steps 13-14 is so that disruption
is minimized in steps 3-6 and to at least have one working compiler toolchain as
the fallback to fix the broken one.  It may be possible to eliminate 14 and 15
now that the package.env is matured and tested enough for @system, but due to
different USE flags used by others and being more dangerous it is kept disjoint.
Initially, it was made optional to CFI @system, but now it's decided that it is
working enough without problems to apply it to that set and to increase the
mitgation further.

In step 13, if one decides to continue CFIing @system, one needs to hardmask
newer versions of gcc but unmask selectively newer major versions so both old
and new versions exist simultaneously.  Umasking patch versions of gcc may be
safe.  For details about why the issue exists, see
[Updating minor versions of gcc with USE_CLANG_CFI_AT_SYSTEM](CFI-support.md#updating-minor-versions-of-gcc-with-use_clang_cfi_at_system)

Steps 15 and 20 are optional if no new packages were added.  It is a good
idea to run `gen_pkg_lists.sh` before each `emerge -ve @world` or after a full
update with `emerge -vuDN @world`.  `gen_pkg_lists.sh` is only useful after
a new package is installed.

Steps 17-18 are required because each build (or computer) has a unique set of USE
flags with conditionally installed packages.  This step may be integrated in
step 12 in regular intervals if possible.

Steps 20-21 are optional for disablement of GCF_CFI_DEBUG mode, but makes the
build more production ready.  Disabling CFI debug can make it difficult to
determine the type of CFI violation or even to decide if it was a miscompile or
CFI itself.  Also, remove the test USE flag and test FEATURES from make.conf
then perform a `emerge -vuDN world` or `emerge -ve world` (depending if
static-libs were built with fuzzed flags).  It is required that the test USE and
test FEATURE flags be removed to prevent the possibility of dangerous fuzzed
libs or unusable fuzzed libs in the final image.

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
for Jan 30, 2022.

* Skips are due to a lack of binaries because they are either purely
metapackages, header only packages, non C-family, art assets (fonts, graphics),
etc.  The actual skips are due to static-libs (to avoid IR incompatibilies
[corresponding to some restricted and all disallowed]), build-time failures,
first time install [corresponding to no-data].

* disable-clang-cfi.conf corresponds to errors for "ERROR: SanitizerTool
failed to allocate noreserve 0x0 (0) bytes of CFI shadow (error code: 22)".

##### Estimates before emerging

###### Set sizes

* @world:  816 (100 %)
* @world - @system:  551 (67.52450980392157 %)
* @system:  265 (32.47549019607843 %)

###### LTO only estimates

* LTO agnostic:  447 (54.779411764705884 %)
   * @world - @system:  323 (39.58333333333333 %)
   * @system:  124 (15.196078431372548 %)
* LTO restricted:  27 (3.308823529411765 %)
   * @world - @system:  27 (3.308823529411765 %)
   * @system:  0 (0 %)
* LTO disallowed:  14 (1.715686274509804 %)
   * @world - @system:  0 (0 %)
   * @system:  14 (1.715686274509804 %)
* LTO skip:  309 (37.86764705882353 %)
   * @world - @system:  187 (22.916666666666664 %)
   * @system:  122 (14.950980392156863 %)
* No data:  0 (0 %)
   * @world - @system:  0 (0 %)
   * @system:  0 (0 %)

The above percents are relative to the @world.

Multi slots are reduced to one.

###### CFI only estimates

* CFIable:  473 (57.96568627450981 %)
   * @world - @system:  349 (42.76960784313725 %)
   * @system:  124 (15.196078431372548 %)
* Allowable cfi-icall candidates:  180 (22.058823529411764 %)
   * @world - @system:  154 (18.872549019607842 %)
   * @system:  26 (3.1862745098039214 %)
* CFI restricted:  33 (4.044117647058823 %)
   * @world - @system:  33 (4.044117647058823 %)
   * @system:  0 (0 %)
* Not CFIable:  15 (1.8382352941176472 %)
* CFI skippable:  309 (37.86764705882353 %)
* No Data:  0 (0 %)

The above percents are relative to the @world.

Multi slots are reduced to one.

Not CFIable is interpreted as the not LTOable @system set with
a static-lib.

##### CFI only actual

Last updated Jan 31, 2022

* Set sizes
  * @world:  816
  * @world - @system:  551
  * @system:  265

* CFIed:
  * @world:  351 (43.01470588235294 %_rel_world)
  * @world - @system:  243 (44.1016333938294 %_rel_world_minus_system, 29.77941176470588 %_rel_world)
  * @system:  108 (40.75471698113208 %_rel_system, 13.23529411764706 %_rel_world)

* NOT CFIed:
  * @world:  465 (56.98529411764706 %_rel_world)
  * @world - @system:  308 (55.898366606170605 %_rel_world_minus_system, 37.745098039215684 %_rel_world)
  * @system:  157 (59.24528301886792 %_rel_system, 19.240196078431374 %_rel_world)

##### Misc

Last updated Jan 31, 2022

* 68 marked with disable-clang-cfi.conf (8.333333333333332 %)
* 28 marked with use-gcc.conf (3.431372549019608 %)
* 121 marked with no-cfi-icall.conf (14.82843137254902 %)
* 7 marked with no-cfi-vcall.conf (0.857843137254902 %)
* 9 marked with no-cfi-cast.conf (1.1029411764705883 %)
* 9 marked with no-cfi-nvcall.conf (1.1029411764705883 %)
* 0 marked with no-cfi-mfcall.conf (0 %)
* 14 marked with remove-lto.conf (1.715686274509804 %)
* 11 marked with remove-gcc-lto.conf (1.3480392156862746 %)
* 26 marked with skipless.conf (3.1862745098039214 %)
* 4 marked with no-strip.conf (0.49019607843137253 %)
* 118 marked with prefetch-loop-arrays.conf (14.460784313725492 %)
* 4 marked with stc.conf (0.49019607843137253 %)
* 1 marked with no-cfi-canonical-jump-tables.conf (0.12254901960784313 %)
* Max package build time: 128295 seconds ( 1 days 11 hours 38 minutes 15 seconds )
* Min package build time: 3 seconds

The no-cfi-icall.conf numbers is higher because it does not count the auto
applied -fno-sanitize=cfi-icall which is around maybe 232 unique packages
(obtained from difference of CFIable - Allowable CFI icall candidates).

No source base browser tested yet for build time.

The above percents are relative to the @world.

### Plans

* Built CFIed @world (on top of agnostic LTO) -- done
* Built CFIed @system (on top of agnostic LTO) -- done
* Testing pre startup -- done but ongoing for new packages
* Increased mitigation with ignore lists converting from -fno-sanitize=cfi* form -- in progress
(Disabled CFI schemes is being used currently for reasons to get a working
system up as fast as possible.  Difficulties with ignore lists disincentivize
using them.)
* Rebuild with USE_LIBCXX_AS_DEFAULT=1 with package.env exceptions if necessary
to increase CFI coverage -- on hold
* LTO/CFI rust programs -- on hold

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

#### undefined symbol: __cfi_slowpath_diag with isl

This error will actually break both clang and gcc at least the configure time
checks.  To fix this, you need to find libisl.so.23 or the one with the same
number (23) and architecture.  You will not find this in the stage 3 tarball
but you can obtain this prebuilt library from a trusted distro or another
computer with Gentoo on your LAN.  This library should not be CFIed.  This
is why you should have a backup copy of / that hasn't been CFIed before doing
systemwide CFI.

You can use rpm2tgz to convert the rpm and replace the library temporarly.
Then, you will re-emerge the package without CFI.

```Shell
rpm2tgz <rpm>
tar -xvf foo.tgz
cp -a <src_path> <dest_path>
emerge -1vO isl
```

#### Depenency rollback(s) without CFI

Before rolling back, please create a
[resume list](CFI-support.md#resume-list) first.

Currently there are no automated ways to avoid the above problem, but some cases
the wrapper technique does not work because the executable is being forced to
link with the GCC toolchain but needs to link against the ubsan library
mentioned above.

Some rollback to remove CFI of the dependencies may be required.

Steps to resolve in order with one re-emerge per case:

1. Try re-emerging the shared-lib with auto or forced -Wl,-lubsan.
2. Manually recategorize the package in /etc/portage/emerge*.lst if
temporarly blocked.
3. Try disabling all CFI flags first, and if it works then converge
towards the minimal CFI exception set for this package.
4. Switch back to GCC if all clang flags were all disabled.  It could
be a clang bug or source code incompatibility with clang.
5. UBSan may still need to be linked in dependencies of the package
that have missing symbols.  Re-emerge these dependency packages
using step 1.
6. Disable CFI for this package.  If this package is has a noreserve or CFI init
problem corresponding to [Err 7] and [Err 13] in package.env, disable CFI in
each named dependency temporary until this package is emerged then re-emerge
back the dependencies with CFI.   When you rollback, this may cause CFI missing
symbols.  Resolution is also discussed in
[the next section below](CFI-support.md#resolving-the-case-6-error).

For case 6 use \`equery b libfile\` to determine the package
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

##### Resolving the case 6 error

Before rolling back, please create a
[resume list](CFI-support.md#resume-list) first.

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

During the rollback search, it is very important that you log every package that
was rolled back in the package.env with comments (#).  When the process is done
the final set will be created and then delete the commented rows with packages
with default ON with CFI.  For, example:

```Shell
# The 3 images (or states) of /etc/portage/package.env.

start -> S1 -> S2 -> S3 -> end

# S1:  Start of search
# bar1, bar2, bar3, ..., bar10 are dependencies of category/foo with all
# dependencies being CFI disabled resulting in a working program.

# Testing:
category/bar1 disable-clang-cfi.conf 
category/bar2 disable-clang-cfi.conf
category/bar3 disable-clang-cfi.conf
category/bar4 disable-clang-cfi.conf
category/bar5 disable-clang-cfi.conf
category/bar6 disable-clang-cfi.conf
category/bar7 disable-clang-cfi.conf
category/bar8 disable-clang-cfi.conf
category/bar9 disable-clang-cfi.conf
category/bar10 disable-clang-cfi.conf

# S2:  Undo step
# Roll back in multiples of M with `emerge -1vO bar_i bar_i-1 bar_i-3 ... bar_i-4`
# If M=5, undo 10, 9, 8, 7, 6 as partition1; then 5, 4, 3, 2, 1 as partition2.  If a
# batch fails, then undoing or reapplying individually 1 at a time the emerge of
# disable-clang-cfi.conf.  Anytime, you apply or unapply disable-clang-cfi.conf,
# you need to `emerge -1vO bar_i`.  The goal is to find the min set of
# disable-clang-cfi.conf per partition.

# Testing:
#category/bar1 disable-clang-cfi.conf # <- the test exe works with full CFI flags (delete row)
#category/bar2 disable-clang-cfi.conf # <- the test exe works with full CFI flags (delete row)
#category/bar3 disable-clang-cfi.conf # <- the test exe works with full CFI flags (delete row)
category/bar4 disable-clang-cfi.conf # <- causes noreserve bug
#category/bar5 disable-clang-cfi.conf # <- the test exe works with full CFI flags (delete row)
category/bar6 disable-clang-cfi.conf # <- causes noreserve bug
category/bar7 disable-clang-cfi.conf # <- causes noreserve bug
#category/bar8 disable-clang-cfi.conf # <- the test exe works with full CFI flags (delete row)
#category/bar9 disable-clang-cfi.conf # <- the test exe works with full CFI flags (delete row)
category/bar10 disable-clang-cfi.conf # <- causes noreserve bug

# S3: Final image, the min_cfi_disabled({bar1, bar2, bar3, ..., bar10}) results
# in a functioning category/foo with max possible apparent CFI coverage.
# {bar1, bar2, bar3, bar5, bar8, bar9} get full CFI mitigations.
# {bar4, bar6, bar7, bar10} are CFI unprotected.

# Move these lines into the disable CFI section or your section of choice.
category/bar4 disable-clang-cfi.conf 
category/bar6 disable-clang-cfi.conf 
category/bar7 disable-clang-cfi.conf 
category/bar10 disable-clang-cfi.conf

# You may also do `emerge -1vO bar1 ... bar10` at this point.
```

Not taking good notes or not properly re-emerging can result in a
non-functioning app or a reduction in mitigation.  The word apparent is
presented that there is a possibility that one hidden package of the working set
(for example bar3) that may need to be disabled or a CFI scheme disabled if an
undesirable bug is encountered later on as a result of CFI flags.

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

### Re-emerging new packages that were not CFIed

It is important to re-emerge these packages so some of these can be CFI
protected.  This can be achieved if logging is enabled.

1. Resolve all merge conflicts and keyword/unmasked packages before preceeding
to increase coverage.

2. Run `./gen_pkg_lists.sh`

3. Run `emerge-uncfied.sh`

Use the resume-emerge-lst script or --skipfirst to skip unmergable.

The script can be modified to add additional options for emerge.

The PACKAGE_ENV_PATH environment variable may be set to change the location of
disable-clang-cfi.conf exceptions.

### Checking for early CFI violations and missing symbols

This does a simple --help and --version check.  Add any potentially dangerous
commands in the
[exclude list](https://github.com/orsonteodoro/gcf2/blob/master/profiles/minmax-v1/scan-cfied-broken-binaries#L68)
inside the script.  This only tests a few code paths at start.  You may still
encounter CFI violations from event based portions or deeper in the code.

For testing some deeper code paths, add test to systemwide USE flags and systemwide
FEATURES in make.conf.  Preparation for the test USE flag should be done
(in step 3 of the [steps section](https://github.com/orsonteodoro/gcf2/blob/master/profiles/minmax-v1/docs/CFI-support.md#steps)
early on to increase chances of a complete atomic update from beginning to
end.

IMPORTANT:  Before running the script, save your work.  You may need to run
this outside of X to prevent crash with X.

The script is called
[scan-cfied-broken-binaries](https://github.com/orsonteodoro/gcf2/blob/master/profiles/minmax-v1/scan-cfied-broken-binaries).

Use `<path> --help`, `<path> --version`, or `<exe_path>` to see the violation or
missing symbol problem.

The script has several environment variables to control scanning, reporting, and
analysis and are found at the top of the script.  Example: 

`ANALYSIS=1 GEN_LOG=1 CHECK_NO_ARGS=1 CHECK_HELP=0 CHECK_VERSION=0 ./scan-cfied-broken-binaries`

To form just analysis after the required /var/log/cfi-scan.log has been produced do:

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

This tool will not detect a stall or lack of progression when executing a program.
Manual inspection is required for this kind of error.  The stall could be caused
by a missing symbol problem.

### Checking for broken stripped shared-libs

The script `find-broken-so-stripping.sh` has been provided to scan for
unloadable libs as a result of stripping.  These packages require
`no-strip.conf` if a list of libs are not able to be produced with `ldd`.

## Required re-emerges

If any of the undefined symbols is encountered, it requires a rebuild:

* __ubsan_handle_cfi_check_fail_abort
* __cfi_slowpath_diag (There's a small chance it could be fixed with auto
-Wl,-lubsan but may require an explicit add of -fno-sanitize=cfi-icall
(with no-cfi-icall.conf) or more.)

The following is required if using systemwide CFI at and before Jan 6, 2022.

Update: In Jan 23, 2022, x11-libs/libva should be re-emerged since 
scan-cfied-broken-binaries will not detect __ubsan_handle_cfi_check_fail_abort
missing symbol but stall with vainfo instead.

Update: In Jan 24, 2022, app-text/libpaper should be re-emerged with the same
problems as above.

Update: In May 29, 2022, dev-libs/jemalloc should be re-emerged if an app
that uses the package hangs.

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
	app-text/libpaper \
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
	x11-libs/libva \
	x11-libs/gtk+ \
	x11-libs/gtksourceview \
	x11-libs/pango \
	xfce-base/xfconf
```

If any of the above package(s) is either a or are new package(s), you don't need
to re-emerge it at this time.

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

#### Updating minor versions of gcc with USE_CLANG_CFI_AT_SYSTEM

This issue is currently under investigation as of Jun 4, 2022.  The usual
version scheme is major.minor.patch.  Do not update between gcc 11.2 and 11.3 or
between minor versions.

A walkthrough of the experience... what happens is the ebuild maintainer decides
to KEYWORD stable gcc.  I or you update gcc to a newer minor version within the
same slot.  When the ebuild system unemerges the older minor version, bash or
env-update both will break because it cannot find libgcc_s.so.1 or maybe
libubsan.so after unCFIing some coreutils programs.  Yes ls from coreutils
broke, so did env-update dependencies.  The dyanmic loader claimed the lib is
missing because the older minor version was unemerged.  The source of the
problem is unknown at this point.  I attempted to run `env-update` and
`source /etc/profile` and `gcc-config` to fix path issues but I still ran into
the missing lib problem.  It maybe due to either a hardcoded RPATH (not likely)
or stale /etc/ld.so.cache, but libgcc_s.so.1 does exist in the just installed
newer version of gcc but cannot search that new path yet, or maybe CFIed parts
landed in libgcc_s.so.1 that shouldn't been there that make it unusable. Since
env-update dependencies broke, it was likley why env-update likely failed and
likely never properly updated ld.so.cache to the new gcc installation.  So
knowing this, one may choose to disable CFI for portage, coreutils, python,
etc, but there may be more packages related to prevent this from happening again
but not enough data collected to have confidence that minimal set of packages
responsible or to confirm that unCFIing them is the correct solution.  More
time would be needed to replicate and test more of @system that needed to be
unCFIed for production safe CFIed @system.

As of now it is strongly not recommended to CFI @system until the gcc
update issue is eliminated.

One may try the LD_PRELOAD trick to attempt to have the dynamic
loader find libgcc_s.so.1.

This problem is due to an undesireable slotting issue which breaks entire @system
because it unemerges the minor inadvertantly making it unsafe to emerge
@system.  It may be considered more safe to update between major gcc versions
(e.g. 11 -&gt; 12).

If your @system is completely borked because of this, you can replace the whole
@system with a stage3 tarball with with a backup of /etc, /var/lib/portage/world,
/home, /root, local repos, and other important files before restoring @system
to vanilla, corresponding to dirty solution 2 below.  You will find the that
proposals 1 and 2 are the better ones below.

Here are the three proposed solutions for fixing a completely borked @system:

1. Move old installation in a new folder, copy stage3 in /, and replace stage3
tarball parts restoring backups (e.g. /etc, /home, ...).
2. Stage3 tarball on top of existing. (This may not work for everyone if the
stage3 tarball doesn't contain the same gcc major.minor release.)
3. Backup and clean install.
