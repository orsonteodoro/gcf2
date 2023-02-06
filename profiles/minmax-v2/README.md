# MinMax v2 Profile

(PRE-ALPHA.  This profile is still in development.  Do not use at this time.)

This profile is designed for maximum security at the highest performance.

Min because security lowers performance.  Max because of -O3.

By default it is Max, but it can be configured as MinMax.

The build time is expected to improve and be in balance with the runtime use time.

## Requirements

* CFI has LTO as a mandatory requirement.
* Security requires both Hardened GCC and Hardened Clang (Not available in distro but on oiledmachine-overlay)
* Security requires -O1 and above for -D_FORTIFY_SOURCE=2

## Tradeoffs / benefits

* Maximum security first policy
* Performance is secondary
* Systemwide LTO but optional for performance configs.
* Build times are no more than 2 days per package but installing all required
dependencies may take several days for using a large package.
* Implied SIMD optimized.
* Generated lists
* Heavy bashrc time cost
* Assumes use of the hardened compilers, but users may use non-hardened for max
performance.
* ThinLTO first policy
* ~54% may be LTOed
* ~29% of actual @world may be CFIed
* Multitasking during build can be very bad

## Specifics

* {C,CXX}FLAGS = -march=native -O1 -freorder-blocks-algorithm=simple -fno-inline -fomit-frame-pointer -frename-registers -fno-plt -mindirect-branch=thunk -mindirect-branch-register -flto=thin -fopt-info-vec -pipe
* LDFLAGS = -flto=thin
* -Ofast -- 3D gaming, art, float based crypto, music, science, web-browsers (requires patches)
* -O2 -- 2D gaming, build tools, compression libs, crypto, drivers, net libs, parsers, x11
* -O1 -- default
* Systemwide -D_FORTIFY_SOURCE=2, Full RELRO, Retpoline, SSP, Stack Clash Protection
* Control Flow Integrity (CFI) for everything but @system
* Disables -ffast-math sub-options upon keyword or expression matching violations
to reduce bugs.
* For performance configs, one may start out with -O0 (as the default {C,CXX}FLAGS), but rely on auto bumps.
* -O1 auto bumps happen for packages with large estimated MLOCs which typically have sloppy code.
* -O3 auto bumps happen for packages with opengl or linear math keywords.
* Modders should arrange it so lowest level bumps come first and higher bumps override for dynamic lists.
* Currently, on ice

## Wishlist

* Shrink or delete bashrc

## In planning or dev ideas

* Scudo for heap/malloc protection.
* gwp-asan for beta and live ebuilds.
* Recheck if -Ofast and -ffast-math sub-options are disabled for www-browsers and derivatives, JavaScript engines.
* Re-evaluate gen_float_math_list placement.  Does it need to go after static lists?
* Adding hooks/extentions to gen_package_env.sh or bashrc may be considered for ease of updating.

## Performance estimates

* -Ofast is +- 2% performance drop or benefit ; A to A+ grade
* -O3 is 100% reference ; A grade
* -O2 is +1% benefit to -3% to -9% performance drop ; A grade
* -Os is -7% to -25% performance drop ; A to C grade
* -O1 is -17% to -32% performance drop ; B to D grade ; D grade for the newest codecs
* -Og is -19% to -26% ; B to C grade
* -O0 is -55% to -90% worst case performance drop ; F grade for crypto/codecs/security.  C to F grade for basic programs.
* -march=native is a 5% performance benefit
* -fomit-frame-pointer is a 4% to 85% benefit (default ON in -O1) or &lt; 1% drop
* PGO is 10% performance benefit with 40% benefit outliers
* BOLT is 10-15% performance benefit
* LTO is less than +- 0.3% performance cost/benefit ; The benefits come mostly from space savings.
* CFI is &lt;= 1% performance cost

## Notes

* For performance configs, it recommended to drop LTO.
* Beginning commit:  9a2df41007c0571ed9b785fdcf0442c097999d4c
* End commit:  HEAD
