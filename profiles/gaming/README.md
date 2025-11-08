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
* GCC &ge; 12 for mold<a href="#footnote-1">[1]</a>, or GCC 11 with
  [mold patch](../patches/sys-devel/gcc:11/0000-gcc-11.3.1_p20230120-r1-ld.mold-support.patch).
* Stable profile, stable keywords, stable release branches are preferred

## Tradeoffs / performance

* Modest runtime performance (or perceived B+ grade) is top priority
* Security is optional but deferred to the oiledmachine-overlay for eclasses and
  hardened ebuilds on the security perimeter
* Decent install time
* Stable
* High uptime for hardcore mode or grinding competition
* ~90% runtime performance systemwide without hardening
* No LTO
* No bashrc time cost
* Multitasking during build is smooth
* GCC first policy

## Details

* {C,CXX}FLAGS = -O2 pipe (implied -march=generic)
* -Oflag bumps based on unacceptable runtime duration, studder, or under FPS
minimums.
* The PGO USE flag is disabled by default, but enabled for select small
packages (&lt; 2 MLOC) with severe long run (3+ min) performance
* Curated lists
* No premature optimization
* Reactive optimization
* Development is active at this time
* Use of the mold linker for codebases that are &ge; 20 MLOC or &ge; 1 hr link
  time. (WIP)
* For competitive gaming, hardening is not recommended, but it is manageable in
  several ways.  Possibilities:

  - Two partitions and two kernels - 1 partition for gaming without userland
    hardening and without kernel hardening, 1 partition for general use with
    userland hardening and with kernel hardening.  This is uncommon.

  - Unhardened whole drive for gaming, hardened USB stick for general use.  This
    is uncommon.

  - Harden the whole disk and keep 2 kernels but limit the worst case penalty
    based on needs.  For example, one may set hardening at -10% with
    oiledmachine-overlay and set CFLAGS_HARDENED_TOLERANCE_USER="1.10" in
    /etc/portage/make.conf for borderline A- or B+ grade performance.  The
    tolerance manages and limits the worst case performance penalty for
    hardening.

    - 1.10 keeps SSP on, _FORITIFY_SOURCE (a poor man's ASan) on, Retpoline off.
    - 1.35 keeps SSP on, _FORITIFY_SOURCE on, Retpoline on and is the overlay
      default.
    - For competitive gaming, you can set

      ```
      CFLAGS_HARDENED_DISABLED=1
      RUSTFLAGS_HARDENED_DISABLED=1
      ```

      to disable userland hardening, or set

      ```
      CFLAGS_HARDENED_TOLERANCE_USER="1.01"
      RUSTFLAGS_HARDENED_TOLERANCE_USER="1.01"
      ```

      for a 60 FPS system, or set

      ```
      CFLAGS_HARDENED_TOLERANCE_USER="1.03"
      RUSTFLAGS_HARDENED_TOLERANCE_USER="1.03"
      ```

      for a 30 FPS system to limit to 1 FPS drop and to avoid the unstable 3
      FPS drop possibility.  You can also apply it per-package with per-package
      env files (aka .conf files).  The hardened eclasses has the details of
      which hardening flags are activiated based on the tolerance level.

  - General kernel configuration policy

    - Gaming kernel config:  SSP on, _FORTIFY_SOURCE on, KFENCE off,
      UBSan off, KCFI off, swap off, CPU frequency set to performance, 1000 HZ, power
      management off.

    - General use kernel and builder kernel with full hardening config:  SSP on,
      _FORTIFY_SOURCE on, KFENCE on, UBSan on, KCFI on, swap on, CPU frequency set
      to schedutil or ondemand, 250 HZ for throughput in builder kernel.

    - For both types of kernel, security defaults should be mostly default because
      too much hardening overheats or touches untested buggy code.  Too little
      hardening can run into untested buggy code.  Settings closer to defaults
      are preferred for stability and uptime since the heavy lifting for testing
      has already been done.

    - For the gaming kernel, disruptive options like power management or
      allow for studder like swap should be disabled.  Options that degrade
      availability should be disabled or changed to the higher availability
      alternative.

    - If just casual gaming, then full hardening is acceptable so only one
      partition and one kernel.

    - For the hardened kernel, options that improve CIA - Confidentiality,
      Integrity, Availability - should all be increased or enabled.

    - Sometimes the choice between integrity improvement and availability
      improvement is mutually exclusive.

    - We prioritize availability over integrity for gaming kernels.

    - We prioritize integrity over availability for hardened kernels.

    - We change or disable performance options that hurt uptime and hurt
      availability which can cause premature permadeath in the gaming
      kernel.

    - If competitive gaming, availability comes first but performance-critical
      preferences are prioritized second.  For grinding, live tournament play,
      or live game streaming, we want to focus on actual gaming rather than
      wasting time fixing and finding the cause of availability loss.

    - For competitive gaming, hardening is not acceptable because of the -30%
      performance drop with Retpoline and the kernel has UBSan (~3x worst case
      performance) and KFENCE (~1.08x performance penalty) are enabled by default.
      It will studder gameplay or cause the computer to reset on false positive
      on hardcore mode during aggro.

    - For the hardened kernel to perform live memory corruption detection, it is
      a user choice that must be enabled.  Virtually all proper hardened kernels
      will enable a flavor of ASan.  The trade-off is a speed versus
      comprehensive check or comprehensive security.  The choices are between
      KFENCE (~1.08x worst case penalty), Generic KASAN (4x worst case penalty),
      HW_TAGS KASAN (~1.2x worst case penalty), SW_TAGS KASAN (~1.8x worst case
      penalty).  The distro kernel will enable KASAN but it should be disabled
      for competitive gaming to avoid a false positive unintended consequence
      scenario that leads to premature permadeath.  For casual gaming, KFENCE
      has acceptable performance tolerance.  For competitive gaming, the
      performance is unacceptable.  KASAN may cause a 2-4 FPS drop.

    - For trusted code integrity on both kernels, KCFI may have a 1.08x worst
      case performance penalty which may go over the 1 FPS drop for 60 FPS
      systems.  For 30 FPS systems, 2 FPS drop. For 60 FPS systems, 5 FPS drop.
      For 180 FPS systems, 10 FPS drop.  It is acceptable for casual gaming but
      not for hardcore mode and competitive gaming.  The KCFI may contribute to
      the possibility of premature permadeath.


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
* lld link times can be up to ~2-5x longer than mold; gold link times can be up to ~22-24x longer than mold; bfd link times can be up to ~88-120x longer than mold.  All multithreaded.
* gold link times can be up to ~2x longer than lld with single thread linking.
* For hardening
  - Retpoline - 1.30x worst case performance 
  - ASan - 4.00x worst case performance
  - UBSan - 2.00x worst case performance

#### Section footnotes

1. -Oflags percents are measured relative to -O3.
2. Link times can be about the same between different linkers in some cases with short link times, but disparity increases with longer link times.
3. The other flags percents are relative to the same -Oflag.

## Footnotes

<a name="footnote-1">1.</a> The mold linker can only be used in non-commercial purposes.  See that project for details.
