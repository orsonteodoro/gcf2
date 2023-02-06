# Gaming profile

## Summary

The gaming profile is designed for a basic gaming system.

## Requirements

* No visual or auditory studdering
* &gt;= 25 FPS for video playback with no noticible slow down
* &gt;= 30 FPS for old school games with lowest settings with no noticible FPS lag
or annoying glitches that that will produce unfair play.
* &gt;= 57 FPS for high motion gaming with newer games.
* The fast install is a necessary requirement to maximize play time over build
time, but at the same time the gameplay should not be unfair.

## Tradeoffs / performance

* Modest runtime performance (or perceived B+ grade) is top priority
* Build time is secondary.
* Performance bumps for observed dips in performance.
* No security
* Fastest install time
* Fastest updates
* No LTO
* Energy inefficient
* No bashrc time cost
* Multitasking during build is smooth
* GCC first policy

## Details

* {C,CXX}FLAGS = -O0 pipe [implied -march=generic]
* Curated lists
* No premature optimization
* Reactive optimization
* Development is active at this time

## Performance bump policy

### Hypothetical / theorycraft

Take for example 30 FPS with the following penalties:

* 50% reduction is 15 FPS. (Unacceptable)
* 25% reduction is 22.5 FPS. (Unacceptable)
* 20% reduction is 24 FPS.  (Barely meets)
* 16.67% reduction is 25 FPS.  (Meets)
* 10% reduction is 27 FPS. (Meets 25 FPS for movies)

* A newer codec's age adds -10% penalty for newer while older will be 0%.
* If the lib/app is already optimized, add +10% benefit.

Take for example 60 FPS with the following penalties:

* 41.6% reduction is 24.9 FPS.  (Unacceptable at high motion.)
* 50% reduction is 30 FPS. (Acceptable at high motion.  Acceptable if FPS counter hidden for old school gaming.)
* 25% reduction is 45 FPS. (Not acceptable if looking at FPS counter while looking at GL Aquarium.)
* 20% reduction is 48 FPS.  (Not acceptable if looking at FPS counter while looking at GL Aquarium.)
* 16.67% reduction is 50 FPS.  (Meets performance counter.  Tolerable.)
* 10% reduction is 54 FPS. (Meets performance counter.   Tolerable.)
* 5% reduction is 57 FPS. (Acceptable for a 60 FPS gamer if looking at FPS counter and when the FPS counter is off.)
* 0% reduction is 60 FPS. (High satisfaction for a 60 FPS gamer if looking at FPS counter.)

### Solution

The Rational solution, -Oflag(s) that are no less than 16.67 performance penalty
is/are required to achive 25 FPS or more, so find the -Oflag level(s) that fits
it.  -O3 (Solution by ricers), -O2 (Solution by distro), -Os (best case or by
chance or trial or error).  The side-effect is increased build time.

The Intuitive solution, performance bumps are done to get over the 50% drop, so
keep bumping the -Oflag (through divide and conquer) until it appears to be 25
FPS.  (Solution used by this repo).  The side-effect is random increased
runtime cost.  The quirk descriptions for performace degration are listed below.

* No apparent performance penalty stays:  -O0
* Observed visual studder bump:  -O1
* Observed visual studder again bump:  -O2
* 1.5+ minute durations with no artifacts:  -Ofast
* 1.5+ minute durations with artifacts:  -O3

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
* LTO is less than +- 0.3% performance
* CFI is &lt;= 1% performance cost
* -O0 is preferred to reduce build times by 60%.
