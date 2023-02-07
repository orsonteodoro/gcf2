# MinMax 2018 Profile

(A.k.a. prod as in production)

This profile is designed for maximum security at the highest performance.

Min because security lowers performance.  Max because of -O3.

By default it is MinMax, but it can be edited as Max.

The build time is expected to exceed the runtime use time.

This profile started around Jan 2018 (same month as Retpoline) and EOLed in 2021
before the introduction of the version with the bashrc assist script.

## Requirements

* Hardened GCC

## Tradeoffs / benefits

* Maximum security first policy
* Performance is secondary
* Build time comes last
* No LTO
* Implied SIMD optimized.
* Curated lists
* Assumes use of the hardened compilers, but users may use non-hardened for max
performance.
* No bashrc time overhead
* No thrash control.  You must configure it yourself.
* Multitasking during build may stall or OOM if no thrash control or not enough swap.

## Specifics

* {C,CXX}FLAGS = -march=native -O2 -fomit-frame-pointer -frename-registers -fno-plt -mindirect-branch=thunk -mindirect-branch-register -pipe
* -O3 -- archival, crypto, games, graphics, media, science, sound, video, www browsers, x11
* -ffast-math applied to audio apps/libs, visualization, 3D editors
* Systemwide Full -D_FORTIFY_SOURCE=2, RELRO, Retpoline, SSP
* End of Life (EOL)

## Performance estimates

* -Ofast is +- 2% performance drop or benefit ; A to A+ grade
* -O3 is 100% reference ; A grade
* -O2 is +1% benefit to -3% to -9% performance drop ; A grade
* -Os is -7% to -25% performance drop ; A to C grade
* -O1 is -17% to -32% performance drop ; B to D grade ; D grade for the newest codecs
* -Og is -19% to -26% ; B to C grade
* -O0 is -55% to -90% worst case performance drop ; F grade for	crypto/codecs/security.  C to F grade for basic programs.
* -march=native is a 5% performance benefit
* -fomit-frame-pointer is a 4% to 85% benefit (default ON in -O1) or &lt; 1% drop
* PGO is 10% performance benefit with 40% benefit outliers
* BOLT is 10-15% performance benefit
* LTO is real world -15% cost to +5% benefit ; outliers/synthetic 41% performance benefit ; +17% mode avg space savings ; up to 5x build times
* CFI is &lt;= 1% performance cost

## Notes

* LTO was possibly removed because of possible IR incompatibilities or for build
time reduction reasons.  See 5fd9aa499c9c66aa224110916d284a5a28a73de6 to restore
LTO.
* Snapshot:  7c47245133fc6bee15106960aa87def4f9f62976
* Beginning commit:  020bf5fe9d0c466f935f63ddab71b39a1156f632
* End commit:  c1610383442ff76c0ea397f8668cb3ea1d3ed184
* If using clang, the -fopt-info-vec should be removed from env/O3.conf and -fopt-info-loop removed from env/multicoreloops.conf
