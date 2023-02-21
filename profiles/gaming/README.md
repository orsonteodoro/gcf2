# Gaming profile

## Summary

The gaming profile is designed for a basic gaming system.

## Requirements

* No visual or auditory studdering
* &gt;= 25 FPS for video playback with no noticible slow down
* &gt;= 30 FPS for old school games with lowest settings with no noticible FPS
lag or annoying glitches that that will produce unfair play.
* &gt;= 57 FPS for high motion gaming with newer games.
* The fast install is a necessary requirement to maximize play time over build
time, but at the same time the gameplay should not be unfair.
* GCC &ge; 12 for mold<a href="#footnote-1">[1]</a>, or GCC 11 with [mold patch](../patches/sys-devel/gcc:11/0000-gcc-11.3.1_p20230120-r1-ld.mold-support.patch).
* Stable profile, stable keywords, stable release branches are preferred

## Tradeoffs / performance

* Modest runtime performance (or perceived B+ grade) is top priority
* Build time is secondary.
* No security
* Fastest install time
* Fastest updates
* No LTO
* Energy inefficient
* No bashrc time cost
* Multitasking during build is smooth
* GCC first policy

## Details

* {C,CXX}FLAGS = -O0 pipe (implied -march=generic)
* -Oflag bumps based on unacceptable runtime duration, studder, or under FPS
minimums.
* The PGO USE flag is disabled by default, but enabled for select small
packages (&lt; 2 MLOC) with severe long run (3+ min) performance
* Curated lists
* No premature optimization
* Reactive optimization
* Development is active at this time
* Use of the mold linker for codebases that are &ge; 20 MLOC or &ge; 1 hr link time. (WIP)

## Performance bump policy

### Hypothetical / theorycraft

Take for example 30 FPS with the following penalties:

* 50% reduction is 15 FPS. (Unacceptable)
* 25% reduction is 22.5 FPS. (Unacceptable)
* 20% reduction is 24 FPS.  (Barely meets)
* 16.67% reduction is 25 FPS.  (Meets)
* 10% reduction is 27 FPS. (Meets 25 FPS like in the movies)

* A newer codec's age adds -10% penalty for newer while older will be 0%.
* If the lib/app is already optimized, add +10% benefit.

Take for example 60 FPS with the following penalties:

* 41.6% reduction is 24.9 FPS.  (Unacceptable at high motion.  Maybe acceptable for a high poly raid event but not in competition.)
* 50% reduction is 30 FPS. (Acceptable at high motion.  Acceptable if FPS counter hidden for old school gaming.)
* 25% reduction is 45 FPS. (Not acceptable if looking at FPS counter while looking at GL Aquarium.)
* 20% reduction is 48 FPS.  (Not acceptable if looking at FPS counter while looking at GL Aquarium.)
* 16.67% reduction is 50 FPS.  (Meets performance counter.  Tolerable.)
* 10% reduction is 54 FPS. (Meets performance counter.   Tolerable.)
* 5% reduction is 57 FPS. (Acceptable for a 60 FPS gamer if looking at FPS counter and when the FPS counter is off.)
* 0% reduction is 60 FPS. (High satisfaction for a 60 FPS gamer if looking at FPS counter.)

### Solution

The rational solution, -Oflag(s) that are no less than 16.67% performance penalty
is/are required to achieve 25 FPS or more, so find the -Oflag level(s) that
fits.  -O3 (Solution by ricers), -O2 (Solution by distro), -Os (best case or by
chance or trial or error).  The side-effect is increased build time.

The intuitive solution, performance bumps are done to get over the 50% drop, so
keep bumping the -Oflag (through divide and conquer) until it appears to be 25
FPS.  (Solution used by this repo).  One side-effect is random increased
runtime cost.  The quirk descriptions for performace degration are listed below.

* No apparent performance penalty stays:  -O0
* Observed visual studder bump:  -O1
* Observed visual studder encountered again bump:  -O2
* An easy trivial task not completed in 1 minute bump:  -O1
* An easy trivial task not completed in 1 minute encountered again bump:  -O2
* 1.5+ minute durations with no problems:  -Ofast
* 1.5+ minute durations with problems:  -O3

* Problems may manifest as visual artifacts, flicker, wrong behavior, missing
data.

* If the duration is still too long, a backtrack and evaluation of the
dependency tree is made and -Oflag bumps are made to packages that may relate to
the issue.  Once it is found, we restore the -Oflag to -O0 for irrelevant
packages.  If a package is known to be slow (or is the performance bottleneck),
backtracking will be cut short or end.

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
* -O0 is preferred to reduce build times by 60-70%.
* lld link times can be up to ~2-5x longer than mold; gold link times can be up to ~22-24x longer than mold; bfd link times can be up to ~120-88x longer than mold.  All multithreaded.
* gold link times can be up to ~2 longer than lld with single thread linking.

-Oflags percents are measured relative to -O3.
-Link times can be about the same between different compilers in some cases in short link times, but disparity increases with longer link times.

The other flags percents are relative to the same -Oflag.

## Footnotes

<a name="footnote-1">1.</a> The mold linker can only be used in non-commercial purposes.  See that project for details.
