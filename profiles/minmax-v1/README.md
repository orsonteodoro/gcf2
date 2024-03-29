# MinMax v1 Profile

This profile is designed for maximum security at the highest performance.

Min because security lowers performance.  Max because of -O3.

By default it is Max, but it can be configured as MinMax.

The build time is expected to exceed the runtime use time.

It improves upon previous LTO attempts.

## Requirements

* CFI has LTO as a mandatory requirement.
* Security requires both Hardened GCC and Hardened Clang (Not available in distro but on oiledmachine-overlay)
* Security requires -O1 and above for -D_FORTIFY_SOURCE=2
* Stable profile, stable keywords, stable release branches are preferred

## Tradeoffs / benefits

* Maximum security first policy
* Performance is secondary
* Build time comes last.
* Systemwide LTO but optional for performance configs.
* Build times are no more than 2 days per package but installing all required
dependencies may take several days for using a large package.
* Lower satisfaction since time to build is a major issue.
* Implied SIMD optimized.
* Curated lists
* Heavy bashrc time cost
* Assumes use of the hardened compilers, but users may use non-hardened for max
performance.
* ThinLTO first policy
* ~54% may be LTOed
* ~29% of actual @world may be CFIed
* Multitasking during build can be very bad
* Some compromises on performance (-Os, -Oz, -freorder-blocks-algorithm=simple,
-fno-inline) to try to improve cache use and possible performance regressions
at that time.

## Specifics

* {C,CXX}FLAGS = -march=native -Os -freorder-blocks-algorithm=simple -fno-inline -fomit-frame-pointer -frename-registers -fno-plt -mindirect-branch=thunk -mindirect-branch-register -flto=thin -fopt-info-vec -pipe
* LDFLAGS = -flto=thin
* -O3 -- 3D gaming, art, music, science
* -O2 -- 2D gaming, build tools, crypto
* -Os -- default
* -Oz -- The -Os gets converted to -Oz upon clang use.
* Systemwide Full RELRO, Retpoline, SSP, Stack Clash Protection, -D_FORTIFY_SOURCE=2
* Control Flow Integrity (CFI) for everything but @system
* This collection is equivalent to before automated lists.
* See also README-detailed.md
* End of Life (EOL)

## Performance estimates

* -Ofast is +- 3% performance drop or benefit, +10% benefit for outliers ; A to A+ grade
* -O3 is 100% reference ; A grade
* -O2 is +1% benefit to -3% to -9% performance drop ; A grade
* -Os is -7% to -25% performance drop ; A to C grade
* -O1 is -17% to -32% performance drop ; B to D grade ; D grade for the newest codecs
* -Og is -19% to -26% ; B to C grade
* -O0 is -55% to -95% worst case performance drop, possibly +3x execution time ; F grade for crypto/codecs/security.  C to F grade for basic programs.
* -march=native is &lt; 2% drop to &lt;= 12% performance benefit
* -fomit-frame-pointer is a 4% to 85% benefit (default ON in -O1) or &lt; 1% drop
* -ffast-math is 10% benefit or possibly 40% processing time reduction (outlier), based on -Ofast stats.
* PGO is 10% performance benefit with 40% benefit outliers
* BOLT is 10-15% performance benefit
* LTO is -15% cost to +5% benefit for real world ; 41% performance benefit for outliers/synthetic ; +17% mode avg for space savings ; up to 5x the normal build times
* CFI is &lt;= 1% performance cost
* _FORITIFY_SOURCE=2 is &lt;= 1% performance cost
* gold link times can be up to 11x longer than lld; bfd link times can be up to 5.1x longer than gold; bfd link times can be up to 56x longer than lld.  All multithreaded.
* gold link times can be up to ~2x longer than lld with single thread linking.

#### Section footnotes

1. -Oflags percents are measured relative to -O3.
2. Link times can be about the same between different linkers in some cases with short link times, but disparity increases with longer link times.
3. The other flags percents are relative to the same -Oflag.

## Notes

* For performance configs, it recommended to drop LTO.
* Beginning commit:  08798b13569bc7f4577626a7b640bdce0cb81b6b
* End commit:  0bb5a1dea12235fb521f07e9606da555234d3c62
