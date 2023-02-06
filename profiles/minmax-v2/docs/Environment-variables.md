### Environment variables

The following can added to make.conf be applied as global defaults for the
provided bashrc script.

#### Compiler choice

* CC_LIBC -- The C LTO compiler toolchain used to build the libc [glibc/musl]
or @system
* CC_LTO -- The C LTO compiler toolchain to use for @world
* CXX_LIBC -- The C++ LTO compiler toolchain used to build the libc or @system
* CXX_LTO -- The C++ LTO compiler toolchain to use for @world

#### Standard C++ runtime lib choice

* USE_LIBCXX_AS_DEFAULT -- Use libc++ instead of libstdc++ as the default
if C++ files are detected.  It's used primarily for being CFI protected.
(UNTESTED SYSTEMWIDE, EXPERIMENTAL)

#### LTO

* USE_CLANG_CFI -- Use Clang CFI (Uses only CFI Cross-DSO mode.  Experimental
and unstable systemwide.  bashrc support in development.)
* USE_CLANG_CFI_AT_SYSTEM -- Use Clang CFI for @system.  It should only be
enabled after emerging @world. (EXPERIMENTAL)
* USE_GOLDLTO -- Use Gold as the default LTO linker for @system and/or @world
* USE_THINLTO -- Use ThinLTO as the default LTO linker for @world

The bashrc will prioritize ThinLTO over GoldLTO.  This can be controlled with
use-gold.conf, use-thinlto.conf, disable-gold.conf, disable-thinlto.conf.
Some packages will not build with ThinLTO so fall back to either Gold LTO,
BFD LTO (for LTO agnostic only), or no LTO in that order.

#### CFI

* CFI_BASELINE -- Set the default Clang CFI flags
* GCF_CFI_DEBUG -- Sets to print Clang CFI violations.  Disable in production.

#### BOLT

* GCF_BOLT_PREP -- Prepares packages with static-libs for use with the BOLT
post-link optimizer used to optimize app packages.  (EXPERIMENTAL)

#### Swap / trashing control

* DISABLE_SWAP_REPORT -- Disables swap reporting recommendations and monitoring
* MPROCS -- The number of compiler/linker processes per CPU core
* NCORES -- The number of CPU Cores
* NSEC_FREEZE -- The number of tolerable seconds for freeze (aka severe swap).
* NSEC_LAG -- The number of tolerable seconds for lag (aka slow swap).
* GIB_PER_CORE -- Number of gigabytes (GiB) per core used to check swap
condition.  It can be in decimal (e.g. 1.5).
* HEAVY_SWAP_MARGIN -- The amount in GiB that the computer freezes.  When it
accumulates NSEC_FREEZE ticks at or above this level, it will recommend applying
makeopts-severe-swapping.conf to the package.  To measure it use the one liner
in make.conf and divide the GiB by total RAM and change the factor.
* LIGHT_SWAP_MARGIN -- The amount in GiB that the hard drive light on the
computer is always on or starts to delay.  When accumulates NSEC_LAG ticks at or
above this level, it will recommend applying makeopts-swappy.conf to the
package.  One way to measure ahead of time is to calculate the typical total RSS
load in GiB when not emerging subtract it out of RAM.  The one-liner is provided
in make.conf.

#### Debugging

* GCF_SHOW_FLAGS -- Display the contents of all *FLAGS

#### Misc

* ALLOW_LTO_REQUIREMENTS_NOT_MET_TRACKING -- Allow bashrc to add to
/etc/portage/emerge-requirements-not-met.lst for packages or toolchain not
meeting LTO requirements
* FORCE_PREFETCH_LOOP_ARRAYS -- Force use of GCC so that -fprefetch-loop-arrays
is utilized.  It is mutually exclusive with USE_CLANG_CFI which has a higher
precedence to reduce the attack surface.

#### Deprecated

* USE_SOUPER -- Add flags for systemwide Souper for code reduction (EXPERIMENTAL)
* USE_SOUPER_SIZE -- Add static profile counters in relation to size reduction
* USE_SOUPER_SPEED -- Add dynamic profile counters in relation to execution
speed


### Per-package environment variables config files

Some .conf files may contain additional information about the flag or the
environment variable.

The following can be added to the package.env per package-wise to control
bashrc:

#### Compiler

* disable-libcxx-as-default.conf -- Use libstdc++ instead of libc++
* disable-override-compiler-check.conf -- Disables CC/CXX override checks.  The
ebuild itself or the build scripts may forcefully switch compilers.

#### BOLT

* bolt-app.conf -- Change flags for a BOLT optimized app package.  (For build
failure only)

#### LTO

* disable-gcf-lto.conf -- Disables use of the LTO module in the bashrc
* disable-gold.conf -- Turn off use of Gold LTO
* disable-lto-compiler-switch.conf -- Disables LTO compiler switching
* disable-lto-stripping.conf -- Disables auto removal of LTO *FLAGS
* disable-thinlto.conf -- Turn off use of ThinLTO
* remove-lto.conf -- Removes the -flto flag
* remove-split-lto-unit.conf -- Disables auto applying of -fsplit-lto-unit
* skip-ir-check.conf -- Disables (static-libs) IR compatibility checks when
LTOing systemwide
* split-lto-unit.conf -- Enables LTO splitting.  It should be applied
to packages that Clang LTOed static-libs.  It is implied in CFIed packages.
* use-gold.conf -- Turn on use of Gold LTO
* use-thinlto.conf -- Turn on use of ThinLTO

#### CFI

* disable-cfi-at-system.conf -- Disable CFIing this package in the @system set
* disable-cfi-verify.conf -- Disable checking .so and exes for CFI symbols for
unprotected CFI security holes
* disable-clang-cfi.conf -- Turn off use of Clang CFI
* disable-so-load-verify.conf -- Disable checking .so files for broken stripping
* no-cfi-cast.conf -- Turn off Clang CFI bad cast schemes (specifically cfi-derived-cast, cfi-unrelated-cast)
* no-cfi-icall.conf -- Turn off Clang CFI icall
* no-cfi-nvcall.conf -- Turn off Clang CFI nvcall
* no-cfi-vcall.conf -- Turn off Clang CFI vcall (i.e. Forward Edge CFI, disable as a last resort)

#### Optimization

* remove-no-inline.conf -- Removes -fno-inline
* skipless.conf -- Force use of GCC to utilize -fprefetch-loop-arrays (
applied to audio/video packages that do decoding playback.)

#### Security

* bypass-fallow-store-data-races-check.conf -- disables -Ofast or
-fallow-store-data-races safety check
* force-translate-clang-retpoline.conf -- Converts the retpoline flags as Clang
 *FLAGS
* force-translate-gcc-retpoline.conf -- Converts the retpoline flags as GCC
 *FLAGS

#### Deprecated

* disable-souper.conf -- Disable Souper
* skip-lib-correctness-check.conf -- Disables static/shared lib correctness
checking
* souper-size.conf -- Adds static profile counters in relation to size reduction
* souper-speed.conf -- Adds dynamic profile counters in relation to execution speed
* use-souper.conf -- Turn on Souper
